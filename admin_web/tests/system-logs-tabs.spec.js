const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test('System Logs has side-by-side segmented tab buttons and instant panel switching', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page);

  // Navigate to System Logs
  await page.locator('.nav-link[data-page="systemLogs"]').click();
  await expect(page.locator('#page-systemLogs')).toBeVisible();

  // Verify command deck and period capsule
  const commandDeck = page.locator('#page-systemLogs .system-logs-command-bar');
  await expect(commandDeck).toBeVisible();
  const periodSelect = page.locator('#systemLogsRange');
  await expect(periodSelect).toBeVisible();

  // Verify the two side-by-side tab buttons
  const opTabBtn = page.locator('#tabBtnOperationsLog');
  const loginTabBtn = page.locator('#tabBtnLoginActivity');
  await expect(opTabBtn).toBeVisible();
  await expect(loginTabBtn).toBeVisible();

  // Verify side-by-side geometry (both have similar top coordinate)
  const opBox = await opTabBtn.boundingBox();
  const loginBox = await loginTabBtn.boundingBox();
  expect(Math.abs(opBox.y - loginBox.y)).toBeLessThan(10);
  expect(loginBox.x).toBeGreaterThan(opBox.x);

  // Initially, Operations Log should be active
  await expect(opTabBtn).toHaveClass(/is-active/);
  await expect(page.locator('#reportActivityPanel')).toBeVisible();
  await expect(page.locator('#reportLoginActivityPanel')).toBeHidden();

  // Click Login Activity button
  await loginTabBtn.click();
  await expect(loginTabBtn).toHaveClass(/is-active/);
  await expect(opTabBtn).not.toHaveClass(/is-active/);
  await expect(page.locator('#reportLoginActivityPanel')).toBeVisible();
  await expect(page.locator('#reportActivityPanel')).toBeHidden();

  // Click Operations Log button back
  await opTabBtn.click();
  await expect(opTabBtn).toHaveClass(/is-active/);
  await expect(loginTabBtn).not.toHaveClass(/is-active/);
  await expect(page.locator('#reportActivityPanel')).toBeVisible();
  await expect(page.locator('#reportLoginActivityPanel')).toBeHidden();
});
