const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { readFileSync } = require('node:fs');
const path = require('node:path');

test('large announcement cover uploads shrink while transparent pixels and small originals stay intact', async ({ page }) => {
  await page.route('**/upload-image.mjs', route => route.fulfill({ contentType: 'text/javascript', body: readFileSync(path.resolve(__dirname, '../upload-image.mjs'), 'utf8') }));
  await page.goto('/');
  const result = await page.evaluate(async () => {
    const { prepareAnnouncementImage } = await import('/upload-image.mjs');
    const canvas = document.createElement('canvas'); canvas.width = 2400; canvas.height = 1200;
    const context = canvas.getContext('2d'); const pixels = context.createImageData(canvas.width, canvas.height);
    let seed = 1234;
    for (let i = 0; i < pixels.data.length; i += 4) {
      seed = (seed * 1664525 + 1013904223) >>> 0;
      pixels.data[i] = seed & 255; pixels.data[i + 1] = seed >>> 8 & 255; pixels.data[i + 2] = seed >>> 16 & 255;
      pixels.data[i + 3] = i < canvas.width * 4 * 100 ? 0 : 255;
    }
    context.putImageData(pixels, 0, 0);
    const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
    const original = new File([blob], 'cover.png', { type: 'image/png' });
    const compressed = await prepareAnnouncementImage(original);
    const bitmap = await createImageBitmap(compressed);
    const width = bitmap.width; const height = bitmap.height;
    const check = document.createElement('canvas'); check.width = width; check.height = height;
    check.getContext('2d').drawImage(bitmap, 0, 0); bitmap.close();
    const alpha = check.getContext('2d').getImageData(0, 0, 1, 1).data[3];
    const small = new File(['small'], 'tiny.png', { type: 'image/png' });
    const broken = new File([new Uint8Array(400000)], 'broken.png', { type: 'image/png' });
    return { before: original.size, after: compressed.size, type: compressed.type, width, height, alpha,
      smallUnchanged: await prepareAnnouncementImage(small) === small,
      fallback: await prepareAnnouncementImage(broken) === broken };
  });
  expect(result.after).toBeLessThan(result.before * .9);
  expect(result.type).toBe('image/webp'); expect(result.width).toBe(2048); expect(result.height).toBe(1024);
  expect(result.alpha).toBe(0); expect(result.smallUnchanged).toBe(true); expect(result.fallback).toBe(true);
  console.log('Announcement image bytes:', JSON.stringify({ before: result.before, after: result.after }));
});

test('complaint submit closes immediately, suppresses duplicate requests and preserves failed work', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(() => {
    window.__adminSession.state.complaints = [{ id: 'BC-2026-123456', kind: 'complaint', complaintTrackingVersion: 1,
      workflowVersion: 0, status: 'filed', residentName: 'Test Resident', barangay: 'Vito', barangayId: 'barili_vito',
      description: 'A test complaint with enough information.', complaint: { respondentName: 'Test Respondent' }, hearings: [] }];
    window.openComplaintCase('BC-2026-123456');
  });
  await page.locator('[data-tracking-action="review"]').click();
  let requests = 0; let release;
  const gate = new Promise(resolve => { release = resolve; });
  await page.route('**/advanceComplaintWorkflow', async route => {
    requests++; await gate;
    await route.fulfill({ contentType: 'application/json', status: 503, body: JSON.stringify({ error: { status: 'UNAVAILABLE', message: 'Please retry.' } }) });
  });
  const elapsed = await page.locator('#trackingForm').evaluate(form => {
    const start = performance.now();
    form.requestSubmit(); form.requestSubmit();
    return { ms: performance.now() - start, floating: !!document.querySelector('.background-task--running'), closed: document.querySelector('#adminModal').hidden };
  });
  expect(elapsed.ms).toBeLessThan(200); expect(elapsed.floating).toBe(true); expect(elapsed.closed).toBe(true);
  await expect.poll(() => requests).toBe(1);
  await expect(page.locator('.background-task--running')).toBeVisible();
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].status)).toBe('filed');
  release();
  await expect(page.locator('.background-task--failed')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry', exact: true })).toBeEnabled();
  const timing = await page.evaluate(() => {
    const entry = performance.getEntriesByType('measure').find(entry => entry.name.startsWith('esugid:call:advanceComplaintWorkflow:'));
    return { duration: entry.duration, detail: entry.detail };
  });
  expect(timing.duration).toBeGreaterThan(0);
  expect(timing.detail.outcome).toBe('error');
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].status)).toBe('filed');
});
