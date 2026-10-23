const { test, expect } = require('@playwright/test');
const { resolve } = require('node:path');
const { auditTheme } = require('./helpers/theme-audit');

for (const mode of ['light', 'dark']) {
  for (const width of [320, 360, 390, 768, 860, 861, 1024, 1440]) {
    test(`responsive web login: ${mode} at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 });
      await page.emulateMedia({ colorScheme: mode });
      await page.goto('/');
      await expect(page.locator('#loginForm')).toBeVisible();
      await expect(page.locator('#login-screen .auth-eyebrow')).toBeVisible();
      await page.evaluate(() => document.fonts.ready);

      const layout = await page.evaluate(() => {
        const rect = selector => document.querySelector(selector).getBoundingClientRect();
        const brand = rect('#login-screen .auth-brand-panel');
        const form = rect('#loginForm');
        const fields = [...document.querySelectorAll('#loginForm input, #loginForm button')];
        const photo = document.querySelector('.auth-cover-photo');
        const overlay = getComputedStyle(document.querySelector('.auth-brand-panel'), '::before');
        return {
          pageWidth: document.documentElement.scrollWidth,
          pageHeight: document.documentElement.scrollHeight,
          brand: { right: brand.right, bottom: brand.bottom, height: brand.height },
          form: { left: form.left, top: form.top, right: form.right, bottom: form.bottom },
          fieldsFit: fields.every(field => {
            const box = field.getBoundingClientRect();
            return box.left >= form.left && box.right <= form.right && box.height >= 44;
          }),
          photoLoaded: photo.complete && photo.naturalWidth > 0,
          photoFit: getComputedStyle(photo).objectFit,
          overlayWidth: parseFloat(overlay.width),
          overlayHeight: parseFloat(overlay.height),
          brandWidth: brand.width,
        };
      });
      expect(layout.pageWidth).toBeLessThanOrEqual(width);
      expect(layout.pageHeight).toBeLessThanOrEqual(800);
      expect(layout.fieldsFit).toBe(true);
      expect(layout.photoLoaded).toBe(true);
      expect(layout.photoFit).toBe('cover');
      expect(layout.overlayWidth).toBeCloseTo(layout.brandWidth, 0);
      expect(layout.overlayHeight).toBeCloseTo(layout.brand.height, 0);
      if (width <= 860) {
        expect(layout.brand.height).toBeLessThan(300);
        expect(layout.form.top).toBeGreaterThanOrEqual(layout.brand.bottom);
      } else {
        expect(layout.form.left).toBeGreaterThanOrEqual(layout.brand.right);
      }
      expect(layout.form.right).toBeLessThanOrEqual(width);
      expect(layout.form.bottom).toBeLessThanOrEqual(800);
      const audit = await auditTheme(page);
      expect(audit.brightSurfaces).toEqual([]);
      expect(audit.contrast).toEqual([]);

      await page.locator('#email').focus();
      await expect(page.locator('#email')).toBeFocused();
      await expect(page.locator('#email')).toHaveCSS('outline-style', 'solid');
      await page.locator('#email').blur();

      if ([390, 1440].includes(width)) {
        await page.screenshot({
          path: resolve(__dirname, '../../build/web-login-work/previews', `login-${width}-${mode}.png`),
          fullPage: true,
        });
      }
    });
  }
}

for (const size of [{ width: 320, height: 568 }, { width: 844, height: 390 }, { width: 1024, height: 600 }]) {
  test(`short viewport remains scrollable with feedback: ${size.width}x${size.height}`, async ({ page }) => {
    await page.setViewportSize(size);
    await page.goto('/');
    await page.locator('#authMessage').evaluate(message => {
      message.classList.add('error');
      message.textContent = 'The email address or password is incorrect. Check your details and try again.';
    });
    await page.locator('#openOrganizationRegistration').scrollIntoViewIfNeeded();
    await expect(page.locator('#openOrganizationRegistration')).toBeInViewport();
    const layout = await page.evaluate(() => {
      const message = document.querySelector('#authMessage').getBoundingClientRect();
      const submit = document.querySelector('#loginForm button[type="submit"]').getBoundingClientRect();
      return {
        pageWidth: document.documentElement.scrollWidth,
        overflowY: getComputedStyle(document.body).overflowY,
        overlaps: message.bottom > submit.top,
      };
    });
    expect(layout.pageWidth).toBeLessThanOrEqual(size.width);
    expect(layout.overflowY).not.toBe('hidden');
    expect(layout.overlaps).toBe(false);
  });
}

test('existing login controls and registration navigation work on phone browsers', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await expect(page.getByRole('link', { name: 'Back to landing page' })).toHaveCount(0);
  await page.locator('#rememberMe').check();
  await expect(page.locator('#rememberMe')).toBeChecked();
  await page.locator('#rememberMe').uncheck();
  await expect(page.locator('#rememberMe')).not.toBeChecked();
  const password = page.locator('#password');
  await password.fill('visibility-test');
  await page.getByRole('button', { name: 'Show password', exact: true }).click();
  await expect(password).toHaveAttribute('type', 'text');
  await page.getByRole('button', { name: 'Hide password', exact: true }).click();
  await expect(password).toHaveAttribute('type', 'password');
  await expect(password).toHaveValue('visibility-test');
  await page.locator('#loginForm button[type="submit"]').click();
  await expect(page.locator('#email')).toBeFocused();
  expect(await page.locator('#email').evaluate(input => input.validity.valueMissing)).toBe(true);

  await page.locator('#forgotPasswordBtn').click();
  await expect(page.locator('#toastRegion')).toContainText('Enter your email address or username first.');
  await page.locator('#email').fill('login-layout@example.test');
  await page.locator('#forgotPasswordBtn').click();
  await expect(page.locator('#confirmResetBtn')).toBeVisible();
  await page.getByRole('button', { name: 'Cancel', exact: true }).click();
  await page.locator('#openOrganizationRegistration').click();
  await expect(page.locator('#registration-type-screen')).toBeVisible();
  await expect(page.locator('#login-screen')).toBeHidden();
  await page.locator('#registrationTypeBackToLogin').click();
  await expect(page.locator('#loginForm')).toBeVisible();
});
