const { test, expect } = require('@playwright/test');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

async function setup(page, role = 'super_admin') {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(`
      window.__itComplaints = { state, auth, byId, BARANGAYS, barangayIdFor,
        applyMunicipalCaseRecords: typeof applyMunicipalCaseRecords === 'function' ? applyMunicipalCaseRecords : null };
    `) });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__itComplaints));
  await page.evaluate(() => window.__itComplaints.auth.authStateReady());
  await page.evaluate(role => {
    const { state, auth, byId } = window.__itComplaints;
    Object.defineProperty(auth, 'currentUser', { configurable: true, value: { uid: 'it-admin' } });
    byId('login-screen').hidden = true;
    byId('login-screen').style.display = 'none';
    byId('admin-dashboard').hidden = false;
    byId('admin-dashboard').style.display = '';
    window.configureRoleAccess({ id: 'it-admin', role, name: 'IT Administrator',
      departmentId: role === 'lgu' ? 'tourism-department' : 'it-department',
      status: 'approved', accountStatus: 'active' });
  }, role);
}

test('IT super admins can open Complaints from the sidebar', async ({ page }) => {
  await setup(page);
  const nav = page.locator('.nav-link[data-page="complaints"]');
  await expect(nav).toBeVisible();
  await nav.click();
  await expect(page.locator('#page-title')).toHaveText('Complaints');
  await expect(page.locator('#page-complaints')).toBeVisible();
});

test('IT complaint records cover all 42 barangays and refresh the open page', async ({ page }) => {
  await setup(page);
  const loaded = await page.evaluate(() => {
    const { state, BARANGAYS, barangayIdFor, applyMunicipalCaseRecords } = window.__itComplaints;
    const cases = BARANGAYS.map((barangay, index) => ({
      id: `BC-2026-${900000 + index}`, kind: 'complaint', barangay, barangayId: barangayIdFor(barangay),
      residentName: `Resident ${barangay}`, type: 'Noise', status: 'filed',
      complaintTrackingVersion: 1, workflowVersion: 0, hearings: [],
      date: '2026-10-27T01:00:00Z', complaint: { respondentName: 'Respondent' },
    }));
    applyMunicipalCaseRecords([...cases, { id: 'concern', kind: 'concern', status: 'filed' }]);
    window.navigateTo('complaints');
    return { complaints: state.complaints.length, concerns: state.concerns.map(item => item.id) };
  });
  expect(loaded).toEqual({ complaints: 42, concerns: ['concern'] });
  await page.locator('.complaint-summary-card[data-stage="new"]').click();
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(42);
  await page.locator('.complaint-reports-table tbody tr button').first().click();
  await expect(page.locator('[data-tracking-action="review"]')).toBeVisible();
  await page.locator('#trackingClose').click();
  await page.evaluate(() => window.__itComplaints.applyMunicipalCaseRecords([]));
  await expect(page.locator('.complaint-reports-table')).not.toContainText('BC-2026-900000');
  expect(await page.evaluate(() => window.__itComplaints.state.complaints.length)).toBe(0);
});

for (const role of ['lgu', 'organization', 'mayor']) {
  test(`${role} does not gain the IT complaints page`, async ({ page }) => {
    await setup(page, role);
    await expect(page.locator('.nav-link[data-page="complaints"]')).toBeHidden();
    await page.evaluate(() => window.navigateTo('complaints'));
    expect(await page.evaluate(() => window.__itComplaints.state.page)).not.toBe('complaints');
  });
}

test('IT admins can save a complaint review through the existing workflow', async ({ page }) => {
  await setup(page);
  await page.route('**/getSummonsOfficials', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ result: {
    barangayId: 'barili_vito', barangay: 'Vito', captainName: 'Captain Cruz', secretaryName: 'Secretary Ramos' } }) }));
  await page.route('**/advanceComplaintWorkflow', async route => {
    const input = route.request().postDataJSON().data;
    expect(input.action).toBe('review');
    expect(input.expectedVersion).toBe(0);
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ result: {
      success: true, workflowVersion: 1,
      update: { status: 'under_review', workflowVersion: 1 },
      event: { action: 'review', label: 'Under Review', date: '2026-10-27T01:00:00Z' },
    } }) });
  });
  await page.evaluate(() => {
    window.__itComplaints.applyMunicipalCaseRecords([{ id: 'BC-2026-900001', kind: 'complaint',
      residentName: 'Test Resident', type: 'Noise', status: 'filed', hearings: [],
      complaintTrackingVersion: 1, workflowVersion: 0, date: '2026-10-27T01:00:00Z',
      complaint: { respondentName: 'Test Respondent' } }]);
    window.navigateTo('complaints');
  });
  await page.locator('.complaint-summary-card[data-stage="new"]').click();
  await page.locator('.complaint-reports-table tbody tr button').first().click();
  await page.locator('[data-tracking-action="review"]').click();
  await page.locator('#trackingSave').click();
  await page.getByRole('button', { name: 'Set hearing', exact: true }).click();
  await expect(page.locator('#issueSummonsForm')).toBeVisible();
  expect(await page.evaluate(() => window.__itComplaints.state.complaints[0].workflowVersion)).toBe(1);
});

test('the shared municipal loader keeps mayor data limited to concerns', async ({ page }) => {
  await setup(page, 'mayor');
  const result = await page.evaluate(() => {
    const { state, applyMunicipalCaseRecords } = window.__itComplaints;
    applyMunicipalCaseRecords([{ id: 'private-complaint', kind: 'complaint' }, { id: 'public-concern', kind: 'concern' }]);
    return { complaints: state.complaints.length, concerns: state.concerns.map(item => item.id) };
  });
  expect(result).toEqual({ complaints: 0, concerns: ['public-concern'] });
});
