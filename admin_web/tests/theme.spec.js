const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { auditTheme } = require('./helpers/theme-audit');
const { writeFileSync } = require('node:fs');
const { seedThemeRecords } = require('./helpers/theme-records');

test('theme resolves before the bundle, follows System, persists and synchronizes tabs', async ({ page, context }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.route('**/app.bundle.js*', route => route.abort());
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await expect(page.locator('html')).toHaveAttribute('data-theme-preference', 'system');
  await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(16, 30, 25)');
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await page.evaluate(() => window.ESugidTheme.set('dark'));
  await page.reload();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  const second = await context.newPage();
  await second.goto('/');
  await second.evaluate(() => window.ESugidTheme.set('light'));
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
  await second.evaluate(() => localStorage.clear());
  await expect(page.locator('html')).toHaveAttribute('data-theme-preference', 'system');
});

test('invalid or unavailable storage safely defaults to System', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.addInitScript(() => {
    Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('Blocked', 'SecurityError'); } });
  });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.evaluate(() => window.ESugidTheme.set('light'));
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
});

test('invalid saved preferences fall back to System and print keeps the preference', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.addInitScript(() => localStorage.setItem('esugid_theme', 'invalid'));
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-theme-preference', 'system');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.emulateMedia({ media: 'print' });
  await expect(page.locator('html')).toHaveCSS('color-scheme', 'light');
  await expect(page.locator('body')).toHaveCSS('color', 'rgb(16, 42, 34)');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
});

test('appearance is keyboard accessible on login and retains focus in its dialog', async ({ page }) => {
  await page.goto('/');
  await page.locator('[data-open-appearance]').click();
  const system = page.locator('[data-appearance-mode="system"]');
  await expect(system).toBeFocused();
  await system.press('Home');
  await expect(page.locator('[data-appearance-mode="light"]')).toHaveAttribute('aria-checked', 'true');
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.keyboard.press('Tab');
  await expect(page.locator('#appearanceModalClose')).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(page.locator('[data-appearance-mode="dark"]')).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(page.locator('[data-open-appearance]')).toBeFocused();
});

for (const width of [390, 768, 1440]) {
  for (const role of ['super_admin', 'lgu', 'barangay_captain', 'barangay_councilor', 'organization', 'mayor']) {
    test(`${role} pages support both themes at ${width}px`, async ({ page }, testInfo) => {
      test.setTimeout(120000);
      await page.setViewportSize({ width, height: 900 });
      await loadAdminSession(page, role);
      await seedThemeRecords(page);
      await page.addStyleTag({ content: '*, *::before, *::after { animation: none !important; transition: none !important; }' });
      const destinations = await page.locator('.nav-link:not([hidden])').evaluateAll(buttons => buttons.map(button => button.dataset.page));
      const issues = [];
      for (const mode of ['light', 'dark']) {
        await page.evaluate(mode => window.ESugidTheme.set(mode), mode);
        for (const destination of destinations) {
          await page.evaluate(destination => window.navigateTo(destination), destination);
          await expect(page.locator(`#pageOutlet > #page-${destination}`)).toBeVisible();
          const audit = await auditTheme(page);
          expect.soft(audit.overflow, `${mode} ${destination} overflow`).toBe(false);
          expect.soft(audit.brightSurfaces, `${mode} ${destination} bright sections`).toEqual([]);
          if (audit.contrast.length) issues.push({ mode, destination, contrast: audit.contrast });
          if (role === 'super_admin') await page.screenshot({ path: testInfo.outputPath(`${mode}-${destination}.png`), fullPage: true });
        }
      }
      await testInfo.attach('theme-contrast-audit', { body: JSON.stringify(issues, null, 2), contentType: 'application/json' });
      writeFileSync(testInfo.outputPath('audit.json'), JSON.stringify(issues, null, 2));
      expect(issues.flatMap(issue => issue.contrast.map(item => `${issue.mode} ${issue.destination}: ${item.element} (${item.ratio})`))).toEqual([]);
      if (role !== 'super_admin') await page.screenshot({ path: testInfo.outputPath('dark-profile.png'), fullPage: true });
    });
  }
}

for (const width of [390, 768, 1440]) {
  test(`generated dialogs and forms support both themes at ${width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 });
    await loadAdminSession(page, 'barangay_captain');
    await seedThemeRecords(page);
    await page.addStyleTag({ content: '*, *::before, *::after { animation: none !important; transition: none !important; }' });
    const issues = [];
    const dialogs = [
      ['openConcernStatusModal', 'theme-concern-0'], ['openAskInfoModal', 'theme-concern-0'],
      ['openResolveConcernModal', 'theme-concern-0'], ['openPriorityModal', 'theme-concern-0'],
      ['openFlagConcernModal', 'theme-concern-0'], ['openHandleConcernModal', 'theme-concern-0'],
      ['openComplaintCase', 'theme-complaint-0'], ['openIssueSummonsModal', 'theme-complaint-1'],
      ['openDocumentRequest', 'theme-request'], ['openAnnouncement', 'theme-post'],
      ['openStaffPasswordChange'], ['openStaffEmailChange'],
    ];
    for (const mode of ['light', 'dark']) {
      await page.evaluate(mode => window.ESugidTheme.set(mode), mode);
      for (const [name, id] of dialogs) {
        await page.evaluate(({ name, id }) => { window.closeModal(); window[name](id); }, { name, id });
        await expect(page.locator('#adminModal')).toBeVisible();
        const audit = await auditTheme(page);
        expect.soft(audit.brightSurfaces, `${mode} ${name} bright sections`).toEqual([]);
        expect.soft(audit.overflow, `${mode} ${name} overflow`).toBe(false);
        if (audit.contrast.length) issues.push({ mode, dialog: name, contrast: audit.contrast });
        if (width === 1440) await page.screenshot({ path: testInfo.outputPath(`${mode}-${name}.png`), fullPage: true });
      }
    }
    writeFileSync(testInfo.outputPath('audit.json'), JSON.stringify(issues, null, 2));
    expect(issues.flatMap(issue => issue.contrast.map(item => `${issue.mode} ${issue.dialog}: ${item.element} (${item.ratio})`))).toEqual([]);
  });
}

test('existing chart instances recolor without losing data or hidden series', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await seedThemeRecords(page);
  await page.evaluate(() => window.navigateTo('dashboard'));
  const before = await page.evaluate(() => {
    const chart = window.__adminSession.state.charts.barangayAnalyticsChart;
    chart.setDatasetVisibility(1, false);
    chart.update('none');
    return { data: JSON.stringify(chart.data.datasets.map(dataset => dataset.data)), ticks: chart.options.scales.x.ticks.color, series: chart.data.datasets[0].borderColor };
  });
  await page.evaluate(() => window.ESugidTheme.set('dark'));
  const after = await page.evaluate(() => {
    const chart = window.__adminSession.state.charts.barangayAnalyticsChart;
    return { data: JSON.stringify(chart.data.datasets.map(dataset => dataset.data)), ticks: chart.options.scales.x.ticks.color, hidden: !chart.isDatasetVisible(1), tooltip: chart.options.plugins.tooltip.bodyColor, series: chart.data.datasets[0].borderColor };
  });
  expect(after.data).toBe(before.data);
  expect(after.hidden).toBe(true);
  expect(after.ticks).toBe('#b3c8bc');
  expect(after.tooltip).toBe('#ecf5ef');
  expect(after.series).toBe('#6de0ad');
  await page.evaluate(() => window.ESugidTheme.set('light'));
  expect(await page.evaluate(() => window.__adminSession.state.charts.barangayAnalyticsChart.options.scales.x.ticks.color)).toBe(before.ticks);
  expect(await page.evaluate(() => window.__adminSession.state.charts.barangayAnalyticsChart.data.datasets[0].borderColor)).toBe(before.series);
});

for (const width of [390, 768, 1440]) {
  test(`authentication and registration screens support both themes at ${width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('/');
    await page.waitForFunction(() => Boolean(window.initAppearanceFeature));
    await page.addStyleTag({ content: '*, *::before, *::after { animation: none !important; transition: none !important; }' });
    const issues = [];
    for (const mode of ['light', 'dark']) {
      await page.evaluate(mode => window.ESugidTheme.set(mode), mode);
      for (const id of ['login-screen', 'setup-screen', 'registration-type-screen', 'organization-registration-screen', 'registration-success-screen']) {
        await page.evaluate(id => {
          for (const screen of document.querySelectorAll('body > main')) {
            screen.hidden = screen.id !== id;
            screen.style.display = screen.hidden ? 'none' : '';
          }
        }, id);
        const audit = await auditTheme(page);
        expect.soft(audit.brightSurfaces, `${mode} ${id}`).toEqual([]);
        expect.soft(audit.overflow, `${mode} ${id}`).toBe(false);
        if (audit.contrast.length) issues.push({ mode, screen: id, contrast: audit.contrast });
        if (width === 1440) await page.screenshot({ path: testInfo.outputPath(`${mode}-${id}.png`), fullPage: true });
      }
    }
    writeFileSync(testInfo.outputPath('audit.json'), JSON.stringify(issues, null, 2));
    expect(issues.flatMap(issue => issue.contrast.map(item => `${issue.mode} ${issue.screen}: ${item.element} (${item.ratio})`))).toEqual([]);
  });
}

for (const width of [390, 1440]) {
  test(`administrative dialogs and publishing steps support both themes at ${width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 });
    await loadAdminSession(page);
    await seedThemeRecords(page);
    // Exercise the retained recipient editor as well as current staff dialogs.
    await page.evaluate(() => window.__adminSession.state.capabilities.add('routing:manage'));
    await page.addStyleTag({ content: '*, *::before, *::after { animation: none !important; transition: none !important; }' });
    const issues = [];
    const check = async (mode, view) => {
      const audit = await auditTheme(page);
      expect.soft(audit.brightSurfaces, `${mode} ${view}`).toEqual([]);
      expect.soft(audit.overflow, `${mode} ${view}`).toBe(false);
      if (audit.contrast.length) issues.push({ mode, view, contrast: audit.contrast });
    };
    for (const mode of ['light', 'dark']) {
      await page.evaluate(mode => window.ESugidTheme.set(mode), mode);
      for (const [name, ...args] of [['openHotlineEditor'], ['openRecipientEditor'], ['openLguDepartmentEditor'], ['openEntityAccess', 'organization', 'layout-org'], ['openDocumentRequest', 'theme-request']]) {
        await page.evaluate(({ name, args }) => { window.closeModal(); window[name](...args); }, { name, args });
        await expect(page.locator('#adminModal'), name).toBeVisible();
        await check(mode, name);
      }
      await page.evaluate(() => { window.closeModal(); window.openAnnouncementComposer(); });
      for (const step of [1, 2, 3]) {
        await page.evaluate(step => window.setAnnouncementStep(step), step);
        await check(mode, `announcement step ${step}`);
      }
      await page.evaluate(() => window.openAlertComposer());
      await check(mode, 'alert composer');
    }
    writeFileSync(testInfo.outputPath('audit.json'), JSON.stringify(issues, null, 2));
    expect(issues.flatMap(issue => issue.contrast.map(item => `${issue.mode} ${issue.view}: ${item.element} (${item.ratio})`))).toEqual([]);
  });
}

for (const mode of ['light', 'dark']) {
  test(`${mode} buttons, table rows and keyboard focus remain distinguishable`, async ({ page }) => {
    await loadAdminSession(page, 'barangay_captain');
    await seedThemeRecords(page);
    await page.addStyleTag({ content: '@layer test-stability { *, *::before, *::after { animation: none !important; transition: none !important; } }' });
    await page.evaluate(mode => { window.ESugidTheme.set(mode); window.openDocumentRequest('theme-request'); }, mode);
    for (const type of ['primary', 'secondary']) {
      const button = page.locator(`#modalActions .button--${type}`).first();
      await page.mouse.move(0, 0);
      const background = await button.evaluate(element => getComputedStyle(element).background);
      await button.hover();
      expect(await button.evaluate(element => getComputedStyle(element).background)).not.toBe(background);
      expect((await auditTheme(page)).contrast).toEqual([]);
    }
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toHaveCSS('outline-style', 'solid');
    await expect(page.locator(':focus')).toHaveCSS('outline-width', '3px');
    await page.evaluate(() => { window.closeModal(); window.navigateTo('complaints'); });
    const row = page.locator('.complaint-reports-table tbody tr').first();
    await page.mouse.move(0, 0);
    const background = await row.evaluate(element => getComputedStyle(element).background);
    await row.hover();
    expect(await row.evaluate(element => getComputedStyle(element).background)).not.toBe(background);
    expect((await auditTheme(page)).contrast).toEqual([]);
  });
}
