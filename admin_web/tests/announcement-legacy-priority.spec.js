const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

async function setup(page) {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__legacyAnnouncements = { state, auth, byId, announcementFormValues, renderAnnouncements };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__legacyAnnouncements));
  await page.evaluate(() => window.__legacyAnnouncements.auth.authStateReady());
  await page.evaluate(() => {
    const { state, auth, byId } = window.__legacyAnnouncements;
    Object.defineProperty(auth, 'currentUser', { configurable: true,
      value: { uid: 'tourism-peer', email: 'peer@example.test' } });
    state.currentProfile = { role: 'lgu', departmentId: 'tourism-department', name: 'Tourism Official' };
    state.capabilities = new Set(['dashboard', 'announcements']);
    byId('admin-dashboard').hidden = false;
    byId('admin-dashboard').style.display = '';
    byId('login-screen').hidden = true;
    byId('login-screen').style.display = 'none';
    const post = { id: 'legacy', title: 'Legacy department advisory', content: 'Original advisory message',
      status: 'approved', authorId: 'tourism-peer', authorRole: 'lgu', authorName: 'Tourism Official',
      departmentId: 'tourism-department', category: 'General Information', announcementType: 'general',
      priority: 'urgent', visibility: 'public', targetBarangay: 'All Barangays', targetBarangays: [],
      createdAt: '2026-10-26T01:00:00Z' };
    state.posts = [post, { ...post, id: 'important', priority: 'important', title: 'Important advisory' }];
  });
}

test('editing a legacy urgent announcement needs no hidden pin date', async ({ page }) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const { state, byId, announcementFormValues } = window.__legacyAnnouncements;
    window.editAnnouncement('legacy');
    byId('announcementTitle').value = 'Updated advisory';
    try { return { error: '', priority: state.announcementPriority, status: announcementFormValues().status }; }
    catch (error) { return { error: error.message, priority: state.announcementPriority }; }
  });
  expect(result.error).toBe('');
  expect(result.priority).toBe('regular');
  expect(result.status).toBe('approved');
  await expect(page.locator('#announcementExpiresAt')).toHaveCount(0);
});

test('legacy announcement details do not show an Urgent badge', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => window.openAnnouncement('legacy'));
  await expect(page.locator('.modal-card--announcement-preview')).toContainText('Legacy department advisory');
  await expect(page.locator('.preview-badge-3d--urgent')).toHaveCount(0);
  await page.evaluate(() => { window.closeModal(); window.openAnnouncement('important'); });
  await expect(page.locator('.preview-badge-3d--important')).toBeVisible();
});

test('announcement importance filters no longer offer Urgent', async ({ page }) => {
  await setup(page);
  await expect(page.locator('#announcementPriorityFilter option[value="urgent"]')).toHaveCount(0);
});

test('legacy posts appear in Regular results and preview without an Urgent badge', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => {
    const { byId, renderAnnouncements } = window.__legacyAnnouncements;
    window.navigateTo('announcements');
    byId('announcementPriorityFilter').value = 'regular';
    renderAnnouncements();
  });
  await expect(page.locator('#announcementTable')).toContainText('Legacy department advisory');
  await expect(page.locator('#announcementTable')).not.toContainText('Important advisory');
  await page.evaluate(() => {
    window.editAnnouncement('legacy');
    window.__legacyAnnouncements.byId('previewAnnouncement').click();
  });
  await expect(page.locator('.modal-card--announcement-preview')).toBeVisible();
  await expect(page.locator('.modal-card--announcement-preview')).toContainText('Legacy department advisory');
  await expect(page.locator('.preview-badge-3d--urgent')).toHaveCount(0);
});

test('removing pin expiry keeps publishing and event date validation', async ({ page }) => {
  await setup(page);
  const result = await page.evaluate(() => {
    const { byId, announcementFormValues } = window.__legacyAnnouncements;
    window.editAnnouncement('legacy');
    function errorFor(status) {
      try { announcementFormValues(status); return ''; } catch (error) { return error.message; }
    }
    byId('announcementPublishAt').value = '';
    const scheduleError = errorFor('scheduled');
    byId('announcementPublishAt').value = '2099-01-01T09:00';
    const scheduledAt = announcementFormValues('scheduled').publishAt.getFullYear();
    byId('announcementType').value = 'event';
    const missingEventError = errorFor();
    byId('announcementEventAllDay').checked = false;
    byId('announcementEventStartAt').value = '2099-01-02T09:00';
    byId('announcementEventEndAt').value = '2099-01-02T08:00';
    const eventOrderError = errorFor();
    byId('announcementEventEndAt').value = '2099-01-02T10:00';
    const values = announcementFormValues();
    return { scheduleError, scheduledAt, missingEventError, eventOrderError,
      addToCalendar: values.addToCalendar, duration: values.eventEndAt - values.eventStartAt };
  });
  expect(result.scheduleError).toBe('Choose a future publishing time.');
  expect(result.scheduledAt).toBe(2099);
  expect(result.missingEventError).toMatch(/select the date/i);
  expect(result.eventOrderError).toMatch(/valid event start and end time/i);
  expect(result.addToCalendar).toBe(true);
  expect(result.duration).toBe(3600000);
});
