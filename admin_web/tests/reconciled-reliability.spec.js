const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

test.beforeEach(async ({ page }) => {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__reconciled = { setButtonBusy, callableErrorMessage, ensureConcernCategories };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__reconciled));
});

test('busy buttons restore markup and original disabled state after repeated requests', async ({ page }) => {
  const result = await page.evaluate(() => {
    const { setButtonBusy } = window.__reconciled;
    return [false, true].map(disabled => {
      const button = document.createElement('button');
      button.innerHTML = '<span>Save</span>';
      button.disabled = disabled;
      setButtonBusy(button, true, 'Saving…');
      setButtonBusy(button, true, 'Again');
      const busy = { label: button.textContent, disabled: button.disabled, aria: button.getAttribute('aria-busy') };
      setButtonBusy(button, false);
      setButtonBusy(button, false);
      return { busy, html: button.innerHTML, disabled: button.disabled, aria: button.getAttribute('aria-busy'), data: Object.keys(button.dataset) };
    });
  });
  for (const [index, item] of result.entries()) {
    expect(item.busy).toEqual({ label: 'Saving…', disabled: true, aria: 'true' });
    expect(item.html).toBe('<span>Save</span>');
    expect(item.disabled).toBe(Boolean(index));
    expect(item.aria).toBeNull();
    expect(item.data).toEqual([]);
  }
});

test('service errors hide internal details while retaining actionable domain validation', async ({ page }) => {
  const errors = [
    { code: 'functions/unavailable', message: 'backend-private-host:8080' },
    { code: 'functions/unauthenticated', message: 'token private details' },
    { code: 'functions/resource-exhausted', message: 'quota private details' },
    { code: 'functions/internal', message: 'database password private details' },
    { code: 'functions/invalid-argument', message: 'Please enter an appearance date.' },
    { message: 'TypeError: undefined at private.js:20' },
    { message: 'Concern categories are unavailable. Try again.' },
    { name: 'TypeError', message: 'Cannot read properties of undefined (reading privateField)' },
  ];
  const messages = await page.evaluate(errors => errors.map(window.__reconciled.callableErrorMessage), errors);
  expect(messages[0]).toMatch(/connection|unavailable/i);
  expect(messages[1]).toMatch(/session.*expired/i);
  expect(messages[2]).toMatch(/busy/i);
  expect(messages[3]).not.toContain('private');
  expect(messages[4]).toBe('Please enter an appearance date.');
  expect(messages[5]).not.toContain('private.js');
  expect(messages[6]).toBe('Concern categories are unavailable. Try again.');
  expect(messages[7]).not.toContain('privateField');
});

test('concurrent category requests share work and a failed request can be retried', async ({ page }) => {
  let requests = 0;
  let fail = true;
  await page.route('**/getConcernCategories', async route => {
    requests++;
    await new Promise(resolve => setTimeout(resolve, 100));
    await route.fulfill(fail
      ? { status: 503, json: { error: { status: 'UNAVAILABLE', message: 'Try later' } } }
      : { json: { result: { categories: [{ id: 'roads', name: 'Roads' }] } } });
  });
  const outcomes = await page.evaluate(() => Promise.allSettled([
    window.__reconciled.ensureConcernCategories(), window.__reconciled.ensureConcernCategories(),
  ]).then(results => results.map(result => result.status)));
  expect(outcomes).toEqual(['rejected', 'rejected']);
  expect(requests).toBe(1);
  fail = false;
  expect(await page.evaluate(() => window.__reconciled.ensureConcernCategories())).toEqual([{ id: 'roads', name: 'Roads' }]);
  expect(await page.evaluate(() => window.__reconciled.ensureConcernCategories())).toEqual([{ id: 'roads', name: 'Roads' }]);
  expect(requests).toBe(2);
});
