const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test.describe('Universal Profile Page across All Dashboards', () => {
  test('Barangay Captain has Profile in sidebar navigation and opens Official Profile', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay_captain');

    // Sidebar has Profile link
    const profileNavLink = page.locator('.nav-link[data-page="settings"]');
    await expect(profileNavLink).toBeVisible();
    await expect(profileNavLink.locator('span:last-child')).toHaveText('Profile');

    // Click Profile in sidebar
    await profileNavLink.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Official Profile');
    await expect(page.locator('#organizationProfileHeading')).toHaveText('Layout Test');
    await expect(page.locator('#organizationProfileEyebrowText')).toHaveText('Verified Barangay Official');
    await expect(page.locator('#organizationProfileStatus')).toHaveText('Active');

    // Profile opens directly without a settings tab switcher
    await expect(page.locator('#settingsTabsDeck')).toBeHidden();

    // Topbar account button navigates to profile
    await page.locator('.nav-link[data-page="dashboard"]').click();
    await expect(page.locator('#page-dashboard')).toBeVisible();
    await page.locator('#accountButton').click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Official Profile');
  });

  test('LGU Department Staff has Profile in sidebar and opens Department Staff Profile', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'lgu');

    const profileNavLink = page.locator('.nav-link[data-page="settings"]');
    await expect(profileNavLink).toBeVisible();
    await expect(profileNavLink.locator('span:last-child')).toHaveText('Profile');

    await profileNavLink.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Department Staff Profile');
    await expect(page.locator('#organizationProfileEyebrowText')).toHaveText('LGU Department Personnel');
  });

  test('Municipal Mayor has Profile in sidebar and opens Municipal Mayor Profile', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'mayor');

    const profileNavLink = page.locator('.nav-link[data-page="settings"]');
    await expect(profileNavLink).toBeVisible();
    await expect(profileNavLink.locator('span:last-child')).toHaveText('Profile');

    await profileNavLink.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Municipal Mayor Profile');
    await expect(page.locator('#organizationProfileEyebrowText')).toHaveText('Municipal Mayor');
  });

  test('Super Admin Settings displays only Administrator Profile', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'super_admin');

    const settingsNavLink = page.locator('.nav-link[data-page="settings"]');
    await expect(settingsNavLink).toBeVisible();
    await settingsNavLink.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Administrator Profile');
    await expect(page.locator('#organizationProfileForm')).toBeVisible();
    await expect(page.locator('#organizationProfileEyebrowText')).toHaveText('System Administrator');
    await expect(page.locator('#settingsTabsDeck')).toHaveCount(0);
    await expect(page.locator('#tabBtnMunicipalitySettings')).toHaveCount(0);
    await expect(page.locator('#settingsForm')).toBeHidden();

    // Editing remains available and leaving/reopening Settings keeps the profile view.
    await page.locator('#orgEditProfileBtnFooter').click();
    await expect(page.locator('#orgFooterEditing')).toBeVisible();
    await page.locator('#orgCancelEditBtn').click();
    await page.locator('.nav-link[data-page="dashboard"]').click();
    await settingsNavLink.click();
    await expect(page.locator('#page-title')).toHaveText('Administrator Profile');
    await expect(page.locator('#organizationProfileForm')).toBeVisible();
    await expect(page.locator('#settingsForm')).toBeHidden();

    // The topbar account shortcut opens the same profile view.
    await page.locator('.nav-link[data-page="dashboard"]').click();
    await page.locator('#accountButton').click();
    await expect(page.locator('#page-title')).toHaveText('Administrator Profile');
    await expect(page.locator('#organizationProfileForm')).toBeVisible();
  });

  test('Both accountButton and sidebarMunicipalityChip directly open profile and have consistent styles', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay_captain');

    // Start on Dashboard
    await page.locator('.nav-link[data-page="dashboard"]').click();
    await expect(page.locator('#page-dashboard')).toBeVisible();

    const accountButton = page.locator('#accountButton');
    const municipalityChip = page.locator('#sidebarMunicipalityChip');

    await expect(accountButton).toBeVisible();
    await expect(municipalityChip).toBeVisible();

    // 1. Click sidebar municipality chip -> goes to Official Profile
    await municipalityChip.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Official Profile');

    // 2. accountButton should NOT have 'is-active' class on profile page
    await expect(accountButton).not.toHaveClass(/is-active/);

    // 3. Return to Dashboard and click accountButton -> goes to Official Profile
    await page.locator('.nav-link[data-page="dashboard"]').click();
    await expect(page.locator('#page-dashboard')).toBeVisible();
    await accountButton.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Official Profile');
    await expect(accountButton).not.toHaveClass(/is-active/);
  });

  test('Notification button opens Notifications modal with barangay scoping', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay_captain');

    const workQueueButton = page.locator('#workQueueButton');
    await expect(workQueueButton).toBeVisible();

    // Click Notifications button
    await workQueueButton.click();

    // Modal opens with title "Notifications"
    const modalTitle = page.locator('#modalTitle');
    await expect(modalTitle).toBeVisible();
    await expect(modalTitle).toHaveText('Notifications');

    // Subtitle / Eyebrow displays barangay scope
    const modalEyebrow = page.locator('#modalEyebrow');
    await expect(modalEyebrow).toBeVisible();
    const subText = await modalEyebrow.textContent();
    expect(subText).toContain('Barangay');

    // Close modal
    await page.locator('#adminModal .button--secondary').click();
    await expect(page.locator('#adminModal')).toBeHidden();
  });
});
