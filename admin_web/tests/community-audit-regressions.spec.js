const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

async function loadCommunityAudit(page, role = 'barangay_captain') {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__communityAudit = { state, auth, renderAnnouncements, announcementUiStatus, isAnnouncementExpired, renderEmergency };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__communityAudit));
  await page.evaluate(() => window.__communityAudit.auth.authStateReady());
  await page.evaluate(role => {
    const { state, auth } = window.__communityAudit;
    Object.defineProperty(auth, 'currentUser', { configurable: true, value: { uid: 'community-audit' } });
    document.getElementById('login-screen').hidden = true;
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('admin-dashboard').hidden = false;
    document.getElementById('admin-dashboard').style.display = '';
    window.configureRoleAccess({ role, id: 'community-audit', status: 'approved', barangay: 'Vito', barangayId: 'vito' });
    state.posts = ['general', 'event'].map(type => ({
      id: `archived-${type}`, title: `Archived ${type}`, content: 'Archived fixture',
      authorId: 'community-audit', authorRole: 'barangay_captain', authorBarangay: 'Vito',
      targetBarangay: 'Vito', targetBarangays: ['Vito'], status: 'archived', announcementType: type,
    }));
    window.navigateTo('announcements');
  }, role);
}

for (const role of ['barangay_captain', 'super_admin']) {
  test(`archived announcement type filters and Clear Filter work for ${role}`, async ({ page }) => {
    await loadCommunityAudit(page, role);
    await page.locator('[data-announcement-tab="archived"]').click();
    await page.locator('[data-announcement-summary="event"]').click();
    await expect(page.locator('#announcementTable .announcement-title-text')).toHaveText(['Archived event']);
    await page.locator('#announcementFilterButton').click();
    await page.locator('#clearAnnouncementFilters').click();
    await expect(page.locator('#announcementTable .announcement-title-text')).toHaveCount(2);
    await expect(page.locator('#announcementFilterCount')).toBeHidden();
    await expect(page.locator('[data-announcement-summary="event"]')).toHaveAttribute('aria-pressed', 'false');
  });
}

test('empty-result recovery clears search and sorting while retaining the selected status tab', async ({ page }) => {
  await loadCommunityAudit(page);
  await page.evaluate(() => window.__communityAudit.state.posts.push({
    id: 'draft-general', title: 'Draft general', status: 'draft',
    authorId: 'community-audit', authorRole: 'barangay_captain', targetBarangay: 'Vito',
    announcementType: 'general',
  }));
  await page.locator('[data-announcement-tab="draft"]').click();
  await page.locator('#announcementSearch').fill('missing audit post');
  await page.locator('#announcementFilterButton').click();
  await page.locator('#announcementSort').selectOption('oldest');
  await page.locator('#announcementFilterButton').click();
  await page.getByRole('button', { name: 'Clear search and filters' }).click();
  await expect(page.locator('[data-announcement-tab="draft"]')).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('#announcementSort')).toHaveValue('newest');
  await expect(page.locator('#announcementSearch')).toHaveValue('');
  await expect(page.locator('#announcementTable .announcement-title-text')).toHaveText(['Draft general']);
});

test('restored event drafts remain editable even when their old event dates have ended', async ({ page }) => {
  await loadCommunityAudit(page);
  const status = await page.evaluate(() => {
    const { announcementUiStatus, isAnnouncementExpired } = window.__communityAudit;
    const dates = { eventStartAt: '2020-01-01T00:00:00+08:00', eventEndAt: '2020-01-01T23:59:59+08:00', expiresAt: '2020-01-01T23:59:59+08:00' };
    return {
      draft: announcementUiStatus({ ...dates, status: 'draft' }),
      draftExpired: isAnnouncementExpired({ ...dates, status: 'draft' }),
      published: announcementUiStatus({ ...dates, status: 'approved' }),
      archived: announcementUiStatus({ ...dates, status: 'archived' }),
    };
  });
  expect(status).toEqual({ draft: 'draft', draftExpired: false, published: 'archived', archived: 'archived' });
});

test('a municipal administrator home barangay does not change the emergency publishing role', async ({ page }) => {
  await loadCommunityAudit(page, 'super_admin');
  await page.evaluate(() => window.navigateTo('emergency'));
  await expect(page.locator('#emergencyFeatureHeader')).toBeVisible();
  await expect(page.locator('#newAlertButton')).toHaveAccessibleName('Send Emergency Alert to Residents');
  await page.evaluate(() => {
    window.configureRoleAccess({ role: 'barangay_captain', barangay: 'Vito', barangayId: 'vito' });
    window.navigateTo('emergency');
    window.__communityAudit.renderEmergency();
  });
  await expect(page.locator('#emergencyFeatureHeader')).toBeHidden();
  await expect(page.locator('#newAlertButton')).toHaveAccessibleName('Send Emergency Alert to Barangay Vito');
});
