const { test, expect } = require('@playwright/test');
const { resolve } = require('node:path');

test('photo overlay remains stationary throughout an extended visit', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 800 });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await expect(page.locator('#loginForm')).toBeVisible();
  const samples = await page.evaluate(() => {
    const panel = document.querySelector('#login-screen .auth-brand-panel');
    return [0, 10000, 20000, 40000, 60000].map(time => {
      for (const animation of panel.getAnimations({ subtree: true })) {
        animation.pause();
        animation.currentTime = time;
      }
      const overlay = getComputedStyle(panel, '::before');
      return { time, animation: overlay.animationName, transform: overlay.transform, width: parseFloat(overlay.width), height: parseFloat(overlay.height), panelWidth: panel.clientWidth, panelHeight: panel.clientHeight };
    });
  });
  for (const sample of samples) {
    expect(sample.animation, `overlay at ${sample.time}ms`).toBe('none');
    expect(sample.transform).toBe('none');
    expect(sample.width).toBeCloseTo(sample.panelWidth, 0);
    expect(sample.height).toBeCloseTo(sample.panelHeight, 0);
  }
  await page.screenshot({ path: resolve(__dirname, '../../build/web-login-work/previews/motion-overlay-static.png'), fullPage: true });
});

test('logo floats gently, welcome settles once, and sign-in hover gives subtle feedback', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  const greeting = page.locator('#authHeadingGreeting');
  await expect(greeting).toHaveCSS('animation-name', 'civic-welcome-reveal');
  await expect(greeting).toHaveCSS('animation-iteration-count', '1');
  await expect(greeting).toHaveCSS('opacity', '1');
  await expect(greeting).toHaveCSS('transform', /^(none|matrix\(1, 0, 0, 1, 0, 0\))$/);
  const float = await page.locator('.brand-logo-medallion').evaluate(logo => {
    const animation = logo.getAnimations().find(item => item.animationName === 'civic-logo-float');
    if (!animation) return null;
    animation.pause();
    animation.currentTime = 0;
    const start = logo.getBoundingClientRect();
    animation.currentTime = 2500;
    const top = logo.getBoundingClientRect();
    animation.currentTime = 5000;
    const end = logo.getBoundingClientRect();
    return { rise: start.y - top.y, returnOffset: end.y - start.y, widthChange: top.width - start.width };
  });
  expect(float).not.toBeNull();
  expect(float.rise).toBeCloseTo(4, 1);
  expect(float.returnOffset).toBeCloseTo(0, 1);
  expect(float.widthChange).toBe(0);
  const submit = page.locator('#loginForm button[type="submit"]');
  await submit.hover();
  await expect(submit).toHaveCSS('transform', 'matrix(1, 0, 0, 1, 0, -2)');
  await expect(submit.locator('.auth-btn-icon')).toHaveCSS('transform', 'matrix(1, 0, 0, 1, 4, 0)');
  await page.mouse.move(0, 0);
  await expect(submit).toHaveCSS('transform', 'none');
});

test('reduced motion disables welcome animations and hover movement', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await expect(page.locator('#loginForm')).toBeVisible();
  const animations = await page.locator('#login-screen').evaluate(screen => screen.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length);
  expect(animations).toBe(0);
  const submit = page.locator('#loginForm button[type="submit"]');
  await submit.hover();
  await expect(submit).toHaveCSS('transform', 'none');
  await expect(submit.locator('.auth-btn-icon')).toHaveCSS('transform', 'none');
});
