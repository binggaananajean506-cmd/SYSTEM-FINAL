const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

for (const width of [390, 768, 960]) {
  test(`login fields fit and account links remain reachable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 700 });
    await page.goto('/');
    await page.locator('#openOrganizationRegistration').scrollIntoViewIfNeeded();
    const bounds = await page.evaluate(() => {
      const selectors = ['#loginForm', '#email', '#password', '#openOrganizationRegistration'];
      return selectors.map(selector => {
        const rect = document.querySelector(selector).getBoundingClientRect();
        return { selector, left: rect.left, right: rect.right, bottom: rect.bottom };
      });
    });
    for (const element of bounds) {
      expect(element.left, element.selector).toBeGreaterThanOrEqual(0);
      expect(element.right, element.selector).toBeLessThanOrEqual(width);
    }
    expect(bounds.at(-1).bottom).toBeLessThanOrEqual(700);
  });
}

for (const width of [1280, 1440, 1920]) {
  test(`login fills the viewport and hidden overlays stay hidden at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('/');
    const layout = await page.evaluate(() => {
      const rect = document.getElementById('login-screen').getBoundingClientRect();
      return {
        left: rect.left, top: rect.top, right: rect.right,
        viewport: innerWidth, bodyMargin: getComputedStyle(document.body).margin,
        hiddenOverlays: [...document.querySelectorAll('.modal-overlay[hidden]')]
          .every(element => getComputedStyle(element).display === 'none'),
      };
    });
    expect(layout).toEqual({ left: 0, top: 0, right: width, viewport: width, bodyMargin: '0px', hiddenOverlays: true });
  });

  test(`all admin pages can be clicked and retain shared styles at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await loadAdminSession(page);
    const destinations = await page.locator('.nav-link:not([hidden])').evaluateAll(buttons => buttons.map(button => button.dataset.page));
    expect(destinations).toHaveLength(11);
    for (const destination of destinations) {
      await page.locator(`.nav-link[data-page="${destination}"]`).click();
      await expect(page.locator(`#pageOutlet > #page-${destination}`)).toBeVisible();
      await expect(page.locator('#pageOutlet > .page-section')).toHaveCount(1);
      const layout = await page.evaluate(() => ({
        width: document.documentElement.scrollWidth,
        viewport: innerWidth,
        surfaceStyles: [...document.querySelectorAll('#pageOutlet .surface')]
          .filter(surface => surface.offsetWidth > 0)
          .every(surface => parseFloat(getComputedStyle(surface).borderRadius) > 0 && getComputedStyle(surface).boxShadow !== 'none'),
      }));
      expect(layout.width, destination).toBeLessThanOrEqual(layout.viewport);
      expect(layout.surfaceStyles, destination).toBe(true);
    }
    await page.mouse.move(width - 20, 880);
    await expect(page.locator('#sidebar')).toHaveCSS('width', '98px');
    const alignment = await page.evaluate(() => {
      const rail = document.getElementById('sidebar').getBoundingClientRect();
      return [...document.querySelectorAll('.nav-link:not([hidden]) > .material-symbols-rounded')].map(icon => {
        const rect = icon.getBoundingClientRect();
        return Math.abs(rect.left + rect.width / 2 - (rail.left + rail.width / 2));
      });
    });
    expect(Math.max(...alignment)).toBeLessThanOrEqual(1);
    expect(errors).toEqual([]);
  });
}

test('barangay graph shows the empty state only when the selected period has no data', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    const today = new Date().toISOString();
    state.concerns = [
      { id: 'active-layout', barangayId: 'vito', createdAt: today, status: 'new' },
      { id: 'resolved-layout', barangayId: 'vito', createdAt: today, status: 'resolved', resolvedAt: today },
    ];
    window.navigateTo('dashboard');
  });
  await expect(page.locator('#barangayAnalyticsEmpty')).toBeHidden();
  const total = await page.evaluate(() => window.__adminSession.state.charts.barangayAnalyticsChart.data.datasets[0].data.reduce((sum, value) => sum + value, 0));
  expect(total).toBe(2);
  await page.evaluate(() => {
    window.__adminSession.state.concerns = [];
    window.__adminSession.renderBarangayAnalyticsChart();
  });
  await expect(page.locator('#barangayAnalyticsEmpty')).toBeVisible();
  await expect(page.locator('#accountApprovalsNavButton')).toBeHidden();
});

test('account approval tabs and filters respond after switching pages', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page);
  await page.evaluate(() => {
    window.__adminSession.state.accountRequests = [
      { id: 'request-pending', name: 'Pending Official', email: 'pending@example.test', role: 'barangay_secretary', barangay: 'Vito', status: 'pending' },
      { id: 'request-approved', name: 'Approved Official', email: 'approved@example.test', role: 'barangay_secretary', barangay: 'Vito', status: 'approved' },
    ];
  });
  await page.locator('#accountApprovalsNavButton').click();
  await expect(page.locator('#staffRequestTable')).toContainText('Pending Official');
  await page.locator('[data-account-approval-tab="approved"]').click();
  await expect(page.locator('#staffRequestTable')).toContainText('Approved Official');
  await expect(page.locator('#staffRequestTable')).not.toContainText('Pending Official');
  await page.locator('#accountApprovalType').selectOption('organization');
  await expect(page.locator('#staffRequestTable')).toContainText('No approved requests yet');
  await expect(page.locator('#staffRequestTable')).not.toContainText('Approved Official');
});

for (const width of [390, 768, 1024]) {
  test(`admin pages fit and drawer navigation works at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await loadAdminSession(page);
    const destinations = await page.locator('.nav-link:not([hidden])').evaluateAll(buttons => buttons.map(button => button.dataset.page));
    for (const destination of destinations) {
      await page.locator('#menuButton').click();
      await page.locator(`.nav-link[data-page="${destination}"]`).click();
      await expect(page.locator(`#pageOutlet > #page-${destination}`)).toBeVisible();
      await expect(page.locator('#menuButton')).toHaveAttribute('aria-expanded', 'false');
      const dimensions = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, viewport: innerWidth }));
      expect(dimensions.width, destination).toBeLessThanOrEqual(dimensions.viewport);
    }
  });
}

test('signing out from announcements resets route to dashboard on next sign in', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page, 'barangay_captain');
  await page.locator('.nav-link[data-page="announcements"]').click();
  await expect(page.locator('#pageOutlet > #page-announcements')).toBeVisible();

  await page.locator('.logout-btn').click();

  await expect(page.locator('#login-screen')).toBeVisible();
  const activeNav = await page.evaluate(() => {
    return document.querySelector('.nav-link.active')?.dataset?.page;
  });
  expect(activeNav).toBe('dashboard');

  await page.evaluate(() => {
    const { byId } = window.__adminSession;
    byId('login-screen').hidden = true;
    byId('login-screen').style.display = 'none';
    byId('admin-dashboard').hidden = false;
    byId('admin-dashboard').style.display = '';
    window.configureRoleAccess({
      role: 'super_admin',
      email: 'admin@example.test',
      name: 'System Admin',
      status: 'approved',
    });
  });

  await expect(page.locator('#pageOutlet > #page-dashboard')).toBeVisible();
  await expect(page.locator('#page-title')).toHaveText('Dashboard');
  const postLoginActiveNav = await page.evaluate(() => {
    return document.querySelector('.nav-link.active')?.dataset?.page;
  });
  expect(postLoginActiveNav).toBe('dashboard');
});

test('appearance button is right of notification button and toggles dark/light theme modal', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page, 'super_admin');

  const appearanceBtn = page.locator('#appearanceButton');
  const workQueueBtn = page.locator('#workQueueButton');
  await expect(appearanceBtn).toBeVisible();
  await expect(workQueueBtn).toBeVisible();

  // Verify appearanceButton is to the right of workQueueButton
  const workQueueRect = await workQueueBtn.boundingBox();
  const appearanceRect = await appearanceBtn.boundingBox();
  expect(appearanceRect.x).toBeGreaterThan(workQueueRect.x);

  // Click appearance button to open modal
  await appearanceBtn.click();
  const modal = page.locator('#appearanceModal');
  await expect(modal).toBeVisible();
  await expect(modal.locator('#appearanceModalTitle')).toHaveText('Appearance');
  await expect(modal.locator('.appearance-subtitle')).toHaveText('Choose how E-Sugid looks on this device.');
  await expect(modal.locator('.appearance-footer-note')).toContainText('Your selection is saved automatically and applied to every page.');

  // Click Dark mode
  const darkModeCard = modal.locator('[data-appearance-mode="dark"]');
  await darkModeCard.click();
  await expect(darkModeCard).toHaveClass(/is-active/);
  const themeAfterDark = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  expect(themeAfterDark).toBe('dark');
  const storedThemeDark = await page.evaluate(() => localStorage.getItem('esugid_theme'));
  expect(storedThemeDark).toBe('dark');

  // Click Light mode
  const lightModeCard = modal.locator('[data-appearance-mode="light"]');
  await lightModeCard.click();
  await expect(lightModeCard).toHaveClass(/is-active/);
  const themeAfterLight = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  expect(themeAfterLight).toBe('light');

  // Close modal via close button
  await page.locator('#appearanceModalClose').click();
  await expect(modal).toBeHidden();
});

test('dark mode deep forest theme interacts properly on every page', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await loadAdminSession(page, 'super_admin');

  // Switch to dark mode
  await page.locator('#appearanceButton').click();
  await page.locator('[data-appearance-mode="dark"]').click();
  await page.locator('#appearanceModalClose').click();

  // Verify the shared charcoal/green canvas.
  const bodyBg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  expect(bodyBg).toBe('rgb(16, 30, 25)');

  // Navigate across pages and verify they stay interactive and properly styled
  const pages = ['dashboard', 'announcements', 'concerns', 'complaints', 'emergency', 'directory', 'reports', 'systemLogs', 'settings'];
  for (const pageName of pages) {
    const navBtn = page.locator(`.nav-link[data-page="${pageName}"]`);
    if (await navBtn.isVisible()) {
      await navBtn.click();
      const pageEl = page.locator(`#pageOutlet > #page-${pageName}`);
      await expect(pageEl).toBeVisible();

      // Cards may retain gradients while using the shared dark surface palette.
      const surfaceColor = await page.evaluate((selector) => {
        const surfaces = [...document.querySelectorAll(`${selector} .surface, ${selector} .dashboard-card, ${selector} .tracking-panel, ${selector} .summary-card, ${selector} .metric-card`)];
        const visible = surfaces.find(el => el.offsetWidth > 0 && !el.hasAttribute('hidden'));
        return visible ? getComputedStyle(visible).background : null;
      }, `#page-${pageName}`);
      if (surfaceColor) {
        expect(surfaceColor).toContain('rgb(25, 44, 36)');
      }
    }
  }

  // Switch back to light mode and verify clean restoration
  await page.locator('#appearanceButton').click();
  await page.locator('[data-appearance-mode="light"]').click();
  await page.locator('#appearanceModalClose').click();
  const themeRestored = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
  expect(themeRestored).toBe('light');
});



