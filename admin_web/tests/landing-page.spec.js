const { test, expect } = require('@playwright/test');
const { readFileSync, mkdirSync } = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const review = path.resolve(__dirname, '../../output/landing-review');
mkdirSync(review, { recursive: true });

for (const width of [320, 390, 1440]) {
  test(`landing night mode preserves content and phone screenshots at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
    await page.emulateMedia({ colorScheme: 'light' });
    await page.goto('/');
    const toggle = page.locator('.landing-theme-toggle');
    await expect(toggle).toBeVisible();
    await page.evaluate(() => document.fonts.ready);
    await page.locator('.entrance').evaluateAll(elements => Promise.all(elements.flatMap(element => element.getAnimations().map(animation => animation.finished.catch(() => {})))));
    const before = await page.locator('h1').boundingBox();
    await toggle.focus();
    await page.keyboard.press('Enter');
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'dark');
    await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(16, 31, 27)');
    expect(await page.locator('h1').boundingBox()).toEqual(before);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    expect((await toggle.boundingBox()).height).toBeGreaterThanOrEqual(44);
    await page.screenshot({ path: path.join(review, `night-hero-${width}.png`), animations: 'disabled' });
    await page.evaluate(() => document.querySelectorAll('.reveal').forEach(el => el.classList.add('is-visible')));
    await page.screenshot({ path: path.join(review, `night-full-${width}.png`), fullPage: true, animations: 'disabled' });
    for (const id of ['app-preview', 'download', 'faqs']) {
      await page.locator('#' + id).screenshot({ path: path.join(review, `night-${id}-${width}.png`), animations: 'disabled' });
    }
    await page.locator('[data-preview-link]').first().click();
    await expect(page.getByRole('dialog')).toHaveCSS('background-color', 'rgb(16, 31, 27)');
    await page.keyboard.press('Escape');
    await page.reload();
    await expect(page.getByRole('button', { name: 'Switch to light mode' })).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('.phone .app-screen-capture')).toHaveAttribute('src', '/landing-assets/screenshots/home-dashboard.jpg');
    await expect(page.locator('.phone .app-screen-capture')).toHaveCSS('filter', 'none');
    await page.getByRole('button', { name: 'Switch to light mode' }).click();
    await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'light');
  });
}

test('landing theme follows the system until chosen, then stays independent from admin', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'dark');
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'light');
  await page.getByRole('button', { name: 'Switch to dark mode' }).click();
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'dark');
  const keys = await page.evaluate(() => Object.keys(localStorage));
  expect(keys.filter(key => /theme/i.test(key))).toEqual(['esugid-landing-theme']);
  await page.getByRole('link', { name: 'Admin Login' }).first().click();
  await expect(page.locator('#login-screen')).toBeVisible();
  await expect(page.locator('html')).not.toHaveAttribute('data-landing-theme');
  await expect(page.locator('.landing-theme-toggle')).toHaveCount(0);
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
});

test('theme motion reverses cleanly and is disabled for reduced motion and blocked storage', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light', reducedMotion: 'no-preference' });
  await page.goto('/');
  await expect(page.locator('html')).toHaveClass(/landing-theme-ready/);
  await expect(page.locator('.theme-sun')).toHaveCSS('transition-duration', '0.65s, 0.65s');
  await page.locator('.landing-theme-toggle').evaluate(button => { for (let i = 0; i < 5; i++) button.click(); });
  await expect(page.locator('.theme-moon')).toHaveCSS('opacity', '1');
  await expect(page.locator('.theme-sun')).toHaveCSS('opacity', '0');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.theme-moon')).toHaveCSS('transition-duration', '0s');
  await page.getByRole('button', { name: 'Switch to light mode' }).click();
  await expect(page.locator('.theme-sun')).toHaveCSS('opacity', '1');
  await page.addInitScript(() => { Object.defineProperty(window, 'localStorage', { get() { throw new Error('Storage disabled'); } }); });
  await page.reload();
  await page.getByRole('button', { name: 'Switch to dark mode' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-landing-theme', 'dark');
});

for (const width of [320, 390, 1440]) {
  test(`public landing page is responsive and accessible at ${width}px`, async ({ page }) => {
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
    const response = await page.goto('/');
    expect(response.status()).toBe(200);
    await expect(page).toHaveTitle(/E-SUGID/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('A closer community.');
    await expect(page.getByRole('link', { name: 'Admin Login' }).first()).toBeVisible();
    await expect(page.getByRole('link', { name: 'Admin Login' }).first()).toHaveAttribute('href', '/admin');
    await expect(page.getByRole('link', { name: 'Download for Android' })).toHaveAttribute('href', '/downloads/app-release.apk');
    await expect(page.locator('.phone .app-screen-capture')).toHaveAttribute('src', '/landing-assets/screenshots/home-dashboard.jpg');
    await expect(page.locator('[data-release-version]').first()).toHaveText('v1.0.5');
    const fit = await page.evaluate(async () => {
      await document.fonts.ready;
      return { overflow: document.documentElement.scrollWidth > innerWidth, missing: [...document.images].filter(image => !image.complete || !image.naturalWidth).map(image => image.src) };
    });
    expect(fit.overflow).toBe(false);
    // Scroll each section into view to validate loaded images and reveal content.
    for (const section of ['#app-preview', '#features', '#how-it-works', '#download', '#faqs']) {
      await page.locator(section).scrollIntoViewIfNeeded();
      await expect(page.locator(section)).toBeVisible();
    }
    for (const [group, id] of [['app', 'app-screenshots']]) {
      const rail = page.locator(`#${id}`);
      await expect(rail.locator('figure')).toHaveCount(11);
      await expect(rail.locator('.device-frame .device-screen img')).toHaveCount(11);
      await rail.scrollIntoViewIfNeeded();
      const previous = page.getByRole('button', { name: 'Previous app screenshots' });
      const next = page.getByRole('button', { name: 'Next app screenshots' });
      await expect(previous).toBeDisabled();
      await next.click();
      await expect.poll(() => rail.evaluate(element => element.scrollLeft)).toBeGreaterThan(100);
      await expect(previous).toBeEnabled();
      await previous.click();
      await expect(previous).toBeDisabled();
      await rail.evaluate(element => element.scrollTo({ left: element.scrollWidth, behavior: 'instant' }));
      await expect(next).toBeDisabled();
      await rail.scrollIntoViewIfNeeded();
      await expect(rail.locator('figure').last()).toBeInViewport();
      await rail.locator('img').evaluateAll(images => Promise.all(images.map(image => { image.loading = 'eager'; return image.decode(); })));
      await expect(rail.locator('img').last()).toHaveCSS('object-fit', 'contain');
      await rail.evaluate(element => element.scrollTo({ left: 0, behavior: 'instant' }));
      await expect(previous).toBeDisabled();
      await rail.locator('..').screenshot({ path: path.join(review, `showcase-${group}-${width}.png`), animations: 'disabled' });
    }
    await page.getByRole('link', { name: 'Emergency alerts', exact: true }).click();
    const emergency = page.locator('#preview-alerts .showcase-image-link');
    await expect(emergency).toBeInViewport();
    await emergency.click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await expect(dialog.locator('h2')).toHaveText('Emergency alerts');
    await dialog.locator('img').evaluate(image => image.decode());
    await dialog.getByRole('button', { name: 'Zoom in' }).click();
    await expect(dialog.getByRole('button', { name: 'Fit to screen' })).toHaveAttribute('aria-pressed', 'true');
    await dialog.screenshot({ path: path.join(review, `emergency-zoom-${width}.png`), animations: 'disabled' });
    await dialog.getByRole('button', { name: 'Fit to screen' }).click();
    await dialog.screenshot({ path: path.join(review, `emergency-preview-${width}.png`), animations: 'disabled' });
    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
    await expect(emergency).toBeFocused();
    await page.locator('#app-preview').screenshot({ path: path.join(review, `showcase-${width}.png`), animations: 'disabled' });
    const faq = page.locator('.faq-list details').first();
    await faq.locator('summary').click();
    await expect(faq).toHaveAttribute('open', '');
    await expect(faq.locator('p')).toContainText('app-release.apk');
    await page.evaluate(() => {
      document.querySelectorAll('.reveal').forEach(element => element.classList.add('is-visible'));
      document.activeElement?.blur();
      document.documentElement.style.scrollBehavior = 'auto';
      window.scrollTo(0, 0);
    });
    await page.screenshot({ path: path.join(review, `landing-${width}.png`), fullPage: true, animations: 'disabled' });
    expect(await page.evaluate(() => [...document.querySelectorAll('img[src]')].filter(image => !image.complete || !image.naturalWidth).map(image => image.src))).toEqual([]);
    expect(errors).toEqual([]);
  });
}
test('download delivers the signed APK described by release metadata and admin remains separate', async ({ page, request }) => {
  const metadata = await (await request.get('/release.json')).json();
  expect(metadata.version).toBe('1.0.5'); expect(metadata.build).toBe(6);
  await page.goto('/');
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Download for Android' }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('app-release.apk');
  const content = readFileSync(await download.path());
  expect(content.length).toBe(metadata.bytes);
  expect(content.subarray(0, 2).toString()).toBe('PK');
  expect(createHash('sha256').update(content).digest('hex')).toBe(metadata.sha256);
  const head = await request.head(metadata.url);
  expect(head.headers()['content-type']).toContain('application/vnd.android.package-archive');
  await page.getByRole('link', { name: 'Admin Login' }).first().click();
  await expect(page).toHaveURL(/\/admin$/);
  await expect(page.locator('#login-screen')).toBeVisible();
  await page.getByRole('link', { name: 'Back to home', exact: true }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole('heading', { level: 1 })).toContainText('A closer community.');
});
test('reduced motion, keyboard navigation, no-JavaScript content and download failure feedback', async ({ page, browser }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to content' })).toBeFocused();
  expect(await page.locator('.phone').evaluate(element => getComputedStyle(element).animationName)).toBe('none');
  await page.locator('#app-screenshots').focus();
  await expect(page.locator('#app-screenshots')).toBeFocused();
  await page.keyboard.press('ArrowRight');
  await expect.poll(() => page.locator('#app-screenshots').evaluate(element => element.scrollLeft)).toBeGreaterThan(0);
  await expect(page.locator('#features')).toHaveCSS('opacity', '1');
  await page.route('**/downloads/app-release.apk', route => route.fulfill({ status: 503, body: 'Unavailable' }));
  await page.getByRole('link', { name: 'Download for Android' }).click();
  await expect(page.locator('#download-status')).toContainText('temporarily unavailable');
  const context = await browser.newContext({ javaScriptEnabled: false });
  const plainPage = await context.newPage();
  await plainPage.goto(new URL('/', page.url()).href);
  await expect(plainPage.getByRole('heading', { level: 1 })).toBeVisible();
  await expect(plainPage.getByRole('link', { name: 'Download for Android' })).toBeVisible();
  for (const control of await plainPage.locator('.showcase-controls').all()) await expect(control).toBeHidden();
  await expect(plainPage.locator('.showcase-sheet')).toHaveCount(11);
  await plainPage.locator('.showcase-sheet').last().scrollIntoViewIfNeeded();
  await expect(plainPage.locator('.showcase-sheet').last()).toBeInViewport();
  const original = plainPage.waitForEvent('popup');
  await plainPage.locator('.showcase-sheet').last().getByRole('link').click();
  const originalPage = await original;
  await expect(originalPage).toHaveURL(/\/screenshots\/resident-profile\.jpg$/);
  await originalPage.close();
  await plainPage.locator('.faq-list summary').first().click();
  await expect(plainPage.locator('.faq-list details').first()).toHaveAttribute('open', '');
  await context.close();
});

test('only the 11 uploaded screenshots are published; document images are removed', async ({ page, request }) => {
  const uploads = JSON.parse(readFileSync(path.resolve(__dirname, '../../landing_web/showcase.json'), 'utf8'));
  expect(uploads).toHaveLength(11);
  expect(new Set(uploads.map(image => image.file)).size).toBe(11);
  expect(uploads.map(image => image.file).sort()).toEqual(['barili-services.jpg', 'bayanihan-works.jpg', 'carabao-runner.jpg', 'community-updates.jpg', 'emergency-alert.jpg', 'emergency-hotlines.jpg', 'esugid-assistant.jpg', 'home-dashboard.jpg', 'local-market.jpg', 'report-center.jpg', 'resident-profile.jpg']);
  const inventory = uploads;
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('[data-preview-link]')).toHaveCount(inventory.length);
  await expect(page.locator('#admin-screenshots, .showcase-related')).toHaveCount(0);
  expect(await page.content()).not.toMatch(/user-guide|DOCUMENT_SHOWCASE|image\d+\.(png|jpeg)/);
  for (const removed of ['/landing-assets/user-guide/image1.jpeg', '/landing-assets/user-guide/image14.png', '/landing-assets/user-guide/image30.png', '/landing-assets/app-services-guide.jpg']) {
    expect((await request.head(removed)).status()).toBe(404);
  }
  await page.locator('[data-preview-link]').first().click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('button', { name: 'Previous preview', exact: true })).toBeDisabled();
  for (const [index, item] of inventory.entries()) {
    const response = await request.get(`/landing-assets/screenshots/${item.file}`);
    expect(response.status()).toBe(200);
    const expected = readFileSync(path.resolve(__dirname, '../../landing_web/assets/screenshots', item.file));
    expect(createHash('sha256').update(await response.body()).digest('hex')).toBe(createHash('sha256').update(expected).digest('hex'));
    await expect(dialog.locator('h2')).toHaveText(item.title);
    await expect(dialog.locator('[data-preview-position]')).toHaveText(`${index + 1} of ${inventory.length}`);
    await expect(dialog.locator('img')).toHaveAttribute('src', new URL(`/landing-assets/screenshots/${item.file}`, page.url()).href);
    await dialog.locator('img').evaluate(image => image.decode());
    if (item.file === 'carabao-runner.jpg') await dialog.screenshot({ path: path.join(review, 'game-preview-390.png'), animations: 'disabled' });
    if (index < inventory.length - 1) await dialog.getByRole('button', { name: 'Next preview', exact: true }).click();
  }
  await expect(dialog.getByRole('button', { name: 'Next preview', exact: true })).toBeDisabled();
  await dialog.getByRole('button', { name: 'Previous preview', exact: true }).click();
  await expect(dialog.locator('h2')).toHaveText('Carabao Runner');
  await dialog.getByRole('button', { name: 'Close preview', exact: true }).click();
  await expect(dialog).toBeHidden();
});
