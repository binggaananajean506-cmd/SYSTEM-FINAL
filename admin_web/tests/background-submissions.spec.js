const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');
const { loadAdminSession } = require('./helpers/admin-session');
const { mkdirSync } = require('node:fs');
const path = require('node:path');
const review = path.resolve(__dirname, '../../output/background-submissions'); mkdirSync(review, {recursive:true});

async function postingSession(page) {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    const body = await instrumentAdminBundle('window.__posting = { state, auth, saveAnnouncement, backgroundActions };', source => {
      const start = source.indexOf('async function saveAnnouncement(statusOverride)');
      const end = source.indexOf('function validateAnnouncementPublisher()', start);
      const section = source.slice(start, end).replaceAll('writeBatch(db)', 'window.__submissionHarness.batch()')
        .replace('getDocFromServer(doc(db, "posts", id))', 'window.__submissionHarness.read()')
        .replace('uploadBytesResumable(imageReference, uploadImage, {', 'window.__submissionHarness.upload(uploadImage, {')
        .replace('getDownloadURL(imageReference)', 'Promise.resolve("https://example.test/cover.webp")');
      return source.slice(0, start) + section + source.slice(end);
    });
    await route.fulfill({ response, body });
  });
  await page.goto('/');
  await page.waitForFunction(() => !!window.__posting);
  await page.evaluate(async () => {
    await window.__posting.auth.authStateReady();
    window.__posting.auth.currentUser = { uid: 'posting-official' };
    const profile = { id: 'posting-official', name: 'Test Official', role: 'barangay_captain', barangay: 'Vito', barangayId: 'barili_vito', status: 'approved' };
    document.querySelector('#login-screen').hidden = true; document.querySelector('#login-screen').style.display = 'none';
    document.querySelector('#admin-dashboard').hidden = false; document.querySelector('#admin-dashboard').style.display = '';
    window.configureRoleAccess(profile);
    window.__submissionHarness = {
      writes: [], commits: [], uploads: [],
      read: async () => ({ exists: () => false }),
      batch() {
        const writes = [];
        return { set: (ref, data) => writes.push({ path: ref.path, data }), update: (ref, data) => writes.push({ path: ref.path, data }),
          commit: () => new Promise((resolve, reject) => { this.writes.push(...writes); this.commits.push({ resolve, reject }); }) };
      },
      upload(file) { return { on: (_, progress, reject, complete) => { this.uploads.push({ file, progress, reject, complete }); } }; },
    };
    window.openAnnouncementComposer();
  });
}
async function fillPost(page, title) {
  await page.locator('#announcementTitle').fill(title);
  await page.locator('#announcementMessage').fill('A complete community announcement to test background posting.');
}
async function freezeNoticeClock(page) {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.clock.install({ time: new Date('2026-10-30T04:00:00Z') });
  await page.clock.pauseAt(new Date('2026-10-30T04:00:01Z'));
}

test('completed notice and collapsed header disappear three seconds after success', async ({ page }) => {
  await postingSession(page); await freezeNoticeClock(page);
  await fillPost(page, 'Timed completion'); await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(1);
  await page.evaluate(() => window.__submissionHarness.commits[0].resolve());
  await expect(page.locator('.background-task--completed')).toBeVisible();
  await page.locator('.background-actions-heading').click();
  await page.clock.runFor(2999);
  await expect(page.locator('.background-actions')).toBeVisible();
  await page.clock.runFor(1);
  await expect(page.locator('.background-task--completed')).toHaveCount(0);
  await expect(page.locator('.background-actions')).toBeHidden();
});

test('completion expiry preserves running submissions and failures needing recovery', async ({ page }) => {
  await postingSession(page); await freezeNoticeClock(page);
  await fillPost(page, 'Finishes first'); await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(1);
  await page.evaluate(() => window.openAnnouncementComposer()); await fillPost(page, 'Still saving');
  await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(2);
  await page.evaluate(() => window.__submissionHarness.commits[0].resolve());
  await expect(page.locator('.background-task--completed')).toHaveCount(1);
  await page.clock.runFor(3000);
  await expect(page.locator('.background-task--completed')).toHaveCount(0);
  await expect(page.locator('.background-task--running')).toBeVisible();
  await page.evaluate(() => window.__submissionHarness.commits[1].reject(new Error('Save unavailable')));
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await page.clock.runFor(6000);
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await expect(page.getByRole('button', {name:'Review submission', exact:true})).toBeVisible();
});

test('an old completion timer cannot delete a newer submission with the same key', async ({ page }) => {
  await postingSession(page); await freezeNoticeClock(page);
  await page.evaluate(() => window.__posting.backgroundActions.start({key:'same-case',title:'First update',success:'First saved',run:async()=>{}}));
  await expect(page.locator('.background-task--completed')).toHaveCount(1);
  await page.clock.runFor(2000);
  await page.evaluate(() => window.__posting.backgroundActions.start({key:'same-case',title:'Next update',success:'Next saved',run:()=>new Promise(resolve=>{window.__finishNext=resolve;})}));
  await page.clock.runFor(1000);
  await expect(page.locator('.background-task--running')).toContainText('Next update');
  await page.evaluate(() => window.__finishNext());
  await expect(page.locator('.background-task--completed')).toContainText('Next saved');
  await page.clock.runFor(3000);
  await expect(page.locator('.background-actions')).toBeHidden();
});

test('posting closes immediately; a later success cannot overwrite another draft or modal', async ({ page }) => {
  await postingSession(page); await fillPost(page, 'First community announcement');
  await page.locator('#publishAnnouncement').click();
  await expect(page.locator('#announcementComposerPanel')).toBeHidden();
  await expect(page.locator('.background-task--running')).toContainText('Posting announcement');
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(1);
  await page.evaluate(() => window.openAnnouncementComposer()); await fillPost(page, 'Another draft in progress');
  await page.evaluate(() => window.__submissionHarness.commits[0].resolve());
  await expect(page.locator('.background-task--completed')).toContainText('Announcement saved');
  await expect(page.locator('#announcementTitle')).toHaveValue('Another draft in progress');
  await expect(page.locator('#announcementComposerPanel')).toBeVisible();
  expect(await page.evaluate(() => window.__submissionHarness.writes.find(write => write.path.startsWith('posts/')).data.title)).toBe('First community announcement');
});

test('upload percentage is real; failure keeps its original file and draft without replacing new work', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await postingSession(page); await fillPost(page, 'An announcement to recover');
  await page.locator('#announcementImage').setInputFiles({ name: 'test-cover.png', mimeType: 'image/png', buffer: Buffer.from('test-image') });
  await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.uploads.length)).toBe(1);
  await page.evaluate(() => window.__submissionHarness.uploads[0].progress({ bytesTransferred: 47, totalBytes: 100 }));
  await expect(page.locator('.background-task progress')).toHaveAttribute('value', '47');
  await page.screenshot({path:path.join(review,'upload-390.png'),animations:'disabled'});
  await page.evaluate(() => window.openAnnouncementComposer()); await fillPost(page, 'New unsaved work');
  await page.evaluate(() => window.__submissionHarness.uploads[0].reject(new Error('Upload connection lost')));
  await expect(page.locator('.background-actions-heading')).toContainText('need attention');
  await page.locator('.background-actions-heading').click();
  await expect(page.locator('.background-task--failed')).toContainText('Upload connection lost');
  await page.getByRole('button', {name:'Review submission',exact:true}).click();
  await expect(page.locator('#announcementTitle')).toHaveValue('New unsaved work');
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await page.evaluate(() => window.resetAnnouncementForm());
  await page.getByRole('button', {name:'Review submission',exact:true}).click();
  await expect(page.locator('#announcementTitle')).toHaveValue('An announcement to recover');
  expect(await page.locator('#announcementImage').evaluate(input => input.files[0].name)).toBe('test-cover.png');
});

test('independent posts run concurrently with separate payloads and completion notices', async ({ page }) => {
  await postingSession(page); await fillPost(page, 'Concurrent first post');
  await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(1);
  await page.evaluate(() => window.openAnnouncementComposer()); await fillPost(page, 'Concurrent second post');
  await page.locator('#publishAnnouncement').click();
  await expect.poll(() => page.evaluate(() => window.__submissionHarness.commits.length)).toBe(2);
  await expect(page.locator('.background-task--running')).toHaveCount(2);
  const posts = await page.evaluate(() => window.__submissionHarness.writes.filter(write => write.path.startsWith('posts/')).map(write => ({path:write.path,title:write.data.title})));
  expect(posts.map(post => post.title)).toEqual(['Concurrent first post','Concurrent second post']);
  expect(posts[0].path).not.toBe(posts[1].path);
  expect(await page.evaluate(() => !window.dispatchEvent(new Event('beforeunload', {cancelable:true})))).toBe(true);
  await page.evaluate(() => window.__submissionHarness.commits[1].resolve());
  await expect(page.locator('.background-task--completed')).toHaveCount(1);
  await expect(page.locator('.background-task--running')).toHaveCount(1);
  await page.evaluate(() => window.__submissionHarness.commits[0].resolve());
  await expect(page.locator('.background-task--completed')).toHaveCount(2);
  expect(await page.evaluate(() => !window.dispatchEvent(new Event('beforeunload', {cancelable:true})))).toBe(false);
});

test('floating progress supports dark mode, keyboard collapse and reduced motion', async ({ page }) => {
  await page.setViewportSize({width:390,height:844});
  await page.emulateMedia({ reducedMotion:'reduce' });
  await postingSession(page); await fillPost(page, 'Accessible progress'); await page.locator('#publishAnnouncement').click();
  await page.evaluate(() => document.documentElement.dataset.theme='dark');
  await expect(page.locator('.background-actions')).toHaveCSS('background-color','rgb(24, 46, 37)');
  await expect(page.locator('.background-task')).toHaveCSS('animation-name','none');
  const heading=page.locator('.background-actions-heading');
  await heading.focus(); await page.keyboard.press('Space');
  await expect(heading).toHaveAttribute('aria-expanded','false');
  await page.keyboard.press('Space'); await expect(heading).toHaveAttribute('aria-expanded','true');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({path:path.join(review,'saving-dark-390.png'),animations:'disabled'});
  await page.evaluate(() => window.__submissionHarness.commits[0].resolve());
});

test('complaint save allows navigation, keeps server state truthful and retries the same operation', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(() => {
    window.__adminSession.state.complaints = [{ id: 'BC-2026-123456', kind: 'complaint', complaintTrackingVersion: 1,
      workflowVersion: 0, status: 'filed', residentName: 'Test Resident', barangay: 'Vito', description: 'A complete statement.', hearings: [] }];
    window.openComplaintCase('BC-2026-123456');
  });
  const requests = []; let release;
  await page.route('**/advanceComplaintWorkflow', async route => {
    requests.push(route.request().postDataJSON().data);
    if (requests.length === 1) await new Promise(resolve => { release = resolve; });
    await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Please retry.'}})});
  });
  await page.locator('[data-tracking-action="review"]').click(); await page.locator('#trackingSave').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect(page.locator('.background-task--running')).toBeVisible();
  await expect.poll(() => requests.length).toBe(1);
  await page.evaluate(() => window.navigateTo('dashboard'));
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].status)).toBe('filed');
  release(); await expect(page.locator('.background-task--failed')).toBeVisible();
  await page.getByRole('button',{name:'Retry',exact:true}).click();
  await expect.poll(() => requests.length).toBe(2);
  expect(requests[0].operationId).toBe(requests[1].operationId);
  await expect(page.locator('#adminModal')).toBeHidden();
});

test('verification and report updates finish independently without closing another open form', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  let finishVerification, failReport;
  await page.route('**/listResidentVerifications', route => route.fulfill({contentType:'application/json',body:JSON.stringify({result:{users:[],items:[],counts:{pending:0,verified:1,needsResubmission:0}}})}));
  await page.route('**/reviewResidentVerification', async route => {
    await new Promise(resolve => { finishVerification = resolve; });
    await route.fulfill({contentType:'application/json',body:JSON.stringify({result:{residentId:'resident-test',status:'verified'}})});
  });
  await page.route('**/reviewConcern', async route => {
    await new Promise(resolve => { failReport = resolve; });
    await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Connection lost'}})});
  });
  await page.evaluate(() => {
    window.__adminSession.state.currentProfile.barangayId = 'barili_vito';
    window.__adminSession.state.residentVerifications = [{id:'resident-test',role:'resident',name:'Test Resident',barangay:'Vito',barangayId:'barili_vito',verificationStatus:'submitted',status:'approved',accountStatus:'active'}];
    window.__adminSession.state.concerns = [{id:'CON-2026-123456',kind:'concern',status:'new',barangay:'Vito',title:'Test report',description:'A public concern.'}];
    window.confirmVerificationApproval('resident-test');
  });
  await page.locator('#modalActions .button--primary').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect.poll(() => !!finishVerification).toBe(true);
  await page.evaluate(() => window.openHandleConcernModal('CON-2026-123456'));
  await page.locator('#handleConcernNoteInput').fill('A new report note while verification saves.');
  finishVerification();
  await expect(page.locator('.background-task--completed')).toContainText('Verification decision saved');
  await expect(page.locator('#adminModal')).toBeVisible();
  await expect(page.locator('#handleConcernNoteInput')).toHaveValue('A new report note while verification saves.');
  await page.locator('#modalActions .button--primary').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect.poll(() => !!failReport).toBe(true);
  failReport();
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await page.getByRole('button',{name:'Review submission',exact:true}).click();
  await expect(page.locator('#handleConcernNoteInput')).toHaveValue('A new report note while verification saves.');
  await page.evaluate(() => window.closeModal());
  await expect(page.locator('#confirmDialog')).toBeVisible();
  await page.locator('#confirmDialogCancel').click();
  await expect(page.locator('#handleConcernNoteInput')).toHaveValue('A new report note while verification saves.');
});

test('failed verification notes are recoverable and protected when closing the restored form', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await page.route('**/reviewResidentVerification', route => route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:{status:'UNAVAILABLE',message:'Try again'}})}));
  await page.evaluate(() => {
    window.__adminSession.state.currentProfile.barangayId='barili_vito';
    window.__adminSession.state.residentVerifications=[{id:'resident-note',role:'resident',name:'Test Resident',barangay:'Vito',barangayId:'barili_vito',verificationStatus:'submitted',status:'approved'}];
    window.openVerificationNeedsAttention('resident-note');
  });
  await page.locator('#verificationAttentionReason').selectOption('Other');
  await page.locator('#verificationAttentionNote').fill('Please upload a clearer document showing your address.');
  await page.locator('#modalActions .button--danger').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await page.getByRole('button',{name:'Review submission',exact:true}).click();
  await expect(page.locator('#verificationAttentionReason')).toHaveValue('Other');
  await expect(page.locator('#verificationAttentionNote')).toHaveValue('Please upload a clearer document showing your address.');
  await page.evaluate(() => window.closeModal());
  await expect(page.locator('#confirmDialog')).toBeVisible();
});
