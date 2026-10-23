const { test, expect } = require('@playwright/test');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

function publishHarness(overrides = {}, manageable = true) {
  const source = readFileSync(path.join(__dirname, '../app.js'), 'utf8');
  const start = source.indexOf('window.publishAnnouncementNow = async (id) => {');
  const end = source.indexOf('window.publishDraftNow =', start);
  const item = { id: 'draft', title: 'Community update', content: 'Official message',
    status: 'draft', revision: 2, ...overrides };
  const writes = [];
  const messages = [];
  const scope = {
    window: {}, state: { posts: [item], currentProfile: { role: 'barangay_secretary' } },
    auth: { currentUser: { uid: 'peer' } }, canonicalRole: role => role,
    findAnnouncementById: () => item, canManageAnnouncement: () => manageable,
    announcementUiStatus: post => post.status === 'approved' ? 'published' : post.status,
    isAnnouncementExpired: post => post.status !== 'draft' && Boolean(post.expired),
    db: {}, doc: (...parts) => parts,
    serverTimestamp: () => 'server-time',
    writeBatch: () => ({ update: (_, payload) => writes.push(payload), commit: async () => {} }),
    updateDoc: async (_, payload) => writes.push(payload), addAuditToBatch() {},
    closeModal() {}, renderAnnouncements() {}, showToast: message => messages.push(message),
    callableErrorMessage: error => error.message,
  };
  vm.runInNewContext(source.slice(start, end), scope);
  return { publish: scope.window.publishAnnouncementNow, writes, messages };
}

test('Publish now uses the permitted publishing timestamp for shared-office posts', async () => {
  const h = publishHarness();
  await h.publish('draft');
  expect(h.writes).toHaveLength(1);
  expect(h.writes[0]).toEqual({ status: 'approved', publishAt: 'server-time',
    notificationRequested: true, revision: 3, updatedAt: 'server-time' });
  const rules = readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
  for (const name of ['mayorPostUpdate', 'barangayPostEdit', 'partnerPostUpdate']) {
    const block = rules.slice(rules.indexOf(`function ${name}()`));
    const fields = block.match(/\.hasOnly\(\[([\s\S]*?)\]\)/)[1];
    const allowed = [...fields.matchAll(/'([^']+)'/g)].map(match => match[1]);
    expect(Object.keys(h.writes[0]).filter(key => !allowed.includes(key)), name).toEqual([]);
  }
});

test('authors retain the original published-at timestamp when publishing their own draft', async () => {
  const h = publishHarness({ authorId: 'peer' });
  await h.publish('draft');
  expect(h.writes).toHaveLength(1);
  expect(h.writes[0].publishedAt).toBe('server-time');
  expect(h.writes[0].publishAt).toBeNull();
});

for (const [label, overrides, manageable, message] of [
  ['another publisher', {}, false, /only publish.*managed/i],
  ['empty draft', { content: ' ' }, true, /title and message/i],
  ['event draft without a date', { announcementType: 'event' }, true, /event date.*publishing/i],
  ['expired restored event', { expired: true }, true, /expired.*dates/i],
  ['already published post', { status: 'approved' }, true, /draft.*scheduled/i],
]) {
  test(`Publish now rejects ${label} before writing`, async () => {
    const h = publishHarness(overrides, manageable);
    await h.publish('draft');
    expect(h.writes).toEqual([]);
    expect(h.messages.join(' ')).toMatch(message);
  });
}

test('saving a title-only draft gives actionable message validation before contacting the backend', async ({ page }) => {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle('window.__draftValues = { announcementFormValues, byId };') });
  });
  await page.goto('/');
  await page.waitForFunction(() => window.__draftValues);
  const error = await page.evaluate(() => {
    const { byId, announcementFormValues } = window.__draftValues;
    byId('announcementTitle').value = 'Draft title';
    byId('announcementMessage').value = '';
    try { announcementFormValues('draft'); } catch (error) { return error.message; }
    return '';
  });
  expect(error).toMatch(/message.*save a draft/i);
});

test('CSV exports preserve ordinary text and neutralize spreadsheet formulas', () => {
  const source = readFileSync(path.join(__dirname, '../app.js'), 'utf8');
  const start = source.indexOf('function csvCell(value)');
  const end = source.indexOf('\nfunction ', start + 1);
  const csvCell = vm.runInNewContext(`${source.slice(start, end)}; csvCell`);
  expect(csvCell('Official "name"')).toBe('"Official ""name"""');
  expect(csvCell(42)).toBe('"42"');
  for (const text of ['=1+1', '+SUM(1,2)', '-1+2', '@SUM(A1)', '\t=1+1']) {
    expect(csvCell(text)).toBe(`"'${text}"`);
  }
});
