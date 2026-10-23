const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

async function setup(page) {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__operationsAudit = { state, auth, byId, fillSettingsForm, loadResidentVerifications, EmailAuthProvider };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => window.__operationsAudit);
  await page.evaluate(async () => {
    const { state, auth, byId } = window.__operationsAudit;
    await auth.authStateReady();
    Object.defineProperty(auth, 'currentUser', {
      configurable: true, value: { uid: 'operations-audit', email: 'audit@example.test' },
    });
    byId('login-screen').hidden = true;
    byId('login-screen').style.display = 'none';
    byId('admin-dashboard').hidden = false;
    byId('admin-dashboard').style.display = '';
    window.configureRoleAccess({ id: 'operations-audit', role: 'super_admin',
      email: 'audit@example.test', name: 'Audit Official', status: 'approved',
      departmentId: 'it-department', contactNumber: '09123456789', address: 'Barili Municipal Hall' });
    state.sessionGeneration = 1;
    window.navigateTo('settings');
  });
}

test('profile drafts and passwords survive live page refreshes, and Cancel restores saved values', async ({ page }) => {
  await setup(page);
  await page.locator('#orgEditProfileBtn').click();
  await page.locator('#organizationProfileContactPerson').fill('Unsaved official');
  await page.locator('#orgCurrentPassword').fill(' current password ');
  await page.evaluate(() => window.__operationsAudit.fillSettingsForm());
  await expect(page.locator('#organizationProfileContactPerson')).toHaveValue('Unsaved official');
  await expect(page.locator('#orgCurrentPassword')).toHaveValue(' current password ');
  await expect(page.locator('#orgFooterEditing')).toBeVisible();
  await page.locator('#orgCancelEditBtn').click();
  await expect(page.locator('#organizationProfileContactPerson')).toHaveValue('Audit Official');
  await expect(page.locator('#orgCurrentPassword')).toHaveValue('');
});

test('a new session clears the previous profile draft and password', async ({ page }) => {
  await setup(page);
  await page.locator('#orgEditProfileBtn').click();
  await page.locator('#organizationProfileContactPerson').fill('Previous session draft');
  await page.locator('#orgCurrentPassword').fill('private password');
  await page.evaluate(() => {
    const { state, fillSettingsForm } = window.__operationsAudit;
    state.sessionGeneration++;
    state.currentProfile = { ...state.currentProfile, name: 'New session official' };
    fillSettingsForm();
  });
  await expect(page.locator('#organizationProfileContactPerson')).toHaveValue('New session official');
  await expect(page.locator('#orgCurrentPassword')).toHaveValue('');
  await expect(page.locator('#orgEditProfileBtn')).toBeVisible();
});

test('password confirmation compares exactly what was typed, including spaces', async ({ page }) => {
  await setup(page);
  await page.locator('#orgEditProfileBtn').click();
  await page.locator('#orgCurrentPassword').fill('old password');
  await page.locator('#orgNewPassword').fill(' new password ');
  await page.locator('#orgConfirmPassword').fill('new password');
  await page.locator('#saveOrganizationProfile').click();
  await expect(page.locator('#toastRegion')).toContainText('New passwords do not match');
});

test('current password keeps its spaces and a reauthentication failure stops the save', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => {
    window.__operationsAudit.EmailAuthProvider.credential = (email, password) => {
      window.__capturedCurrentPassword = password;
      throw { code: 'auth/network-request-failed', message: 'offline' };
    };
  });
  await page.locator('#orgEditProfileBtn').click();
  await page.locator('#orgCurrentPassword').fill(' old password ');
  await page.locator('#orgNewPassword').fill(' new password ');
  await page.locator('#orgConfirmPassword').fill(' new password ');
  await page.locator('#saveOrganizationProfile').click();
  await expect(page.locator('#toastRegion')).toContainText('Could not update password');
  expect(await page.evaluate(() => window.__capturedCurrentPassword)).toBe(' old password ');
  await expect(page.locator('#orgFooterEditing')).toBeVisible();
  await expect(page.locator('#saveOrganizationProfile')).toBeEnabled();
});

test('a stale verification response cannot replace another session or finish its loading state', async ({ page }) => {
  await setup(page);
  let resolveFirst;
  let resolveSecond;
  let count = 0;
  await page.route('**/listResidentVerifications', async route => {
    count++;
    const requestNumber = count;
    await new Promise(resolve => { if (count === 1) resolveFirst = resolve; else resolveSecond = resolve; });
    await route.fulfill({ json: { result: { residents: [{ id: requestNumber === 1 ? 'stale-resident' : 'new-resident' }], oversight: true } } });
  });
  await page.evaluate(() => { window.__firstVerification = window.__operationsAudit.loadResidentVerifications(); });
  await expect.poll(() => count).toBe(1);
  await page.evaluate(() => {
    const { state } = window.__operationsAudit;
    state.sessionGeneration++;
    state.verificationsLoading = false;
    state.residentVerifications = [];
    window.__secondVerification = window.__operationsAudit.loadResidentVerifications();
  });
  await expect.poll(() => count).toBe(2);
  resolveFirst();
  await page.evaluate(() => window.__firstVerification);
  expect(await page.evaluate(() => ({ residents: window.__operationsAudit.state.residentVerifications,
    loading: window.__operationsAudit.state.verificationsLoading }))).toEqual({ residents: [], loading: true });
  resolveSecond();
  await page.evaluate(() => window.__secondVerification);
  expect(await page.evaluate(() => window.__operationsAudit.state.residentVerifications.map(item => item.id))).toEqual(['new-resident']);
  expect(await page.evaluate(() => window.__operationsAudit.state.verificationsLoading)).toBe(false);
});
