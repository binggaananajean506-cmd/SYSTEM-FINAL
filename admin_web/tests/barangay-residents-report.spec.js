const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test('admin report lists all barangays, including zero counts, and searches locally', async ({ page }) => {
  await loadAdminSession(page, 'super_admin');
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    const report = state.barangayResidentReport;
    report.open = true;
    report.counts = new Map([['barili_vito', 2], ['barili_cagay', 0]]);
    report.countsLoading = false;
    report.total = 2;
    window.navigateTo('reports');
  });

  const rows = page.locator('#barangayResidentsBarangayRows tr');
  await expect(rows).toHaveCount(42);
  await expect(page.locator('#barangayResidentsTotal')).toContainText('2 total registered residents');
  await expect(page.locator('#barangayResidentsTableTotal')).toHaveText('2');
  await expect(rows.filter({ hasText: 'Barangay Vito' })).toContainText('2');
  await expect(rows.filter({ hasText: 'Barangay Cagay' })).toContainText('0');
  await page.locator('#barangayResidentsSearch').fill('Vito');
  await expect(rows).toHaveCount(1);
  await expect(rows.first()).toContainText('Barangay Vito');
  await expect(page.locator('#barangayResidentsTableTotal')).toHaveText('2');
});

test('barangay table breaks residents down by login and verification status', async ({ page }) => {
  await loadAdminSession(page, 'super_admin');
  await page.evaluate(() => {
    const { state, BARANGAYS, barangayIdFor } = window.__adminSession;
    const report = state.barangayResidentReport;
    report.open = true;
    const ids = BARANGAYS.map(barangayIdFor);
    report.counts = new Map(ids.map((id) => [id, 0]));
    report.statusCounts = new Map(ids.map((id) => [id, { verified: 0, pending: 0 }]));
    report.counts.set('barili_vito', 10);
    report.statusCounts.set('barili_vito', { verified: 5, pending: 3 });
    report.counts.set('barili_cagay', 4);
    report.statusCounts.set('barili_cagay', { verified: 1, pending: 0 });
    report.loggedIn = new Map([['barili_vito', 2], ['barili_cagay', 1]]);
    report.countsLoading = false;
    report.total = 14;
    window.navigateTo('reports');
  });

  const headers = page.locator('#barangayResidentsBarangays thead th');
  await expect(headers).toHaveText(['Barangay', 'Logged In', 'Not Verified', 'Pending Verification', 'Verified', 'Total Registered', 'Action']);
  const vito = page.locator('#barangayResidentsBarangayRows tr', { hasText: 'Barangay Vito' }).locator('td');
  await expect(vito.nth(0)).toHaveText('2');
  await expect(vito.nth(1)).toHaveText('2');
  await expect(vito.nth(2)).toHaveText('3');
  await expect(vito.nth(3)).toHaveText('5');
  await expect(vito.nth(4)).toHaveText('10');
  await expect(page.locator('#barangayResidentsTotalLoggedIn')).toHaveText('3');
  await expect(page.locator('#barangayResidentsTotalNotVerified')).toHaveText('5');
  await expect(page.locator('#barangayResidentsTotalPending')).toHaveText('3');
  await expect(page.locator('#barangayResidentsTotalVerified')).toHaveText('6');
  await expect(page.locator('#barangayResidentsTableTotal')).toHaveText('14');
});

test('resident drill-down displays every verification state without sensitive fields', async ({ page }) => {
  await loadAdminSession(page, 'super_admin');
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    const report = state.barangayResidentReport;
    report.open = true;
    report.barangayId = 'barili_vito';
    report.counts = new Map([['barili_vito', 4]]);
    report.residents = [
      { id: 'verified', role: 'resident', barangayId: 'barili_vito', name: 'Verified User', verificationStatus: 'verified', accountStatus: 'active' },
      { id: 'pending', role: 'resident', barangayId: 'barili_vito', name: 'Pending User', verificationStatus: 'submitted', accountStatus: 'active' },
      { id: 'unverified', role: 'resident', barangayId: 'barili_vito', name: 'Unverified User', verificationStatus: 'not_submitted', accountStatus: 'suspended' },
      { id: 'attention', role: 'resident', barangayId: 'barili_vito', name: 'Attention User', verificationStatus: 'additional_document_required', restrictionStatus: 'active', passwordHash: 'secret-value' },
    ];
    window.navigateTo('reports');
  });

  const table = page.locator('#barangayResidentsResidents');
  await expect(page.locator('#barangayResidentsSubtitle')).toHaveText('4 Registered Residents');
  await expect(table.locator('tbody tr')).toHaveCount(4);
  await expect(table).toContainText('Verified');
  await expect(table).toContainText('Pending');
  await expect(table).toContainText('Not Verified');
  await expect(table).toContainText('Needs Attention');
  await expect(table).toContainText('Restricted');
  await expect(table).not.toContainText('secret-value');

  await page.evaluate(() => {
    const report = window.__adminSession.state.barangayResidentReport;
    report.residents = [];
    report.counts.set('barili_vito', 0);
    window.navigateTo('reports');
  });
  await expect(table).toContainText('No registered residents found for this barangay.');
});

test('other Reports roles cannot open the resident registry', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(() => window.navigateTo('reports'));
  await expect(page.locator('#openBarangayResidentReport')).toBeHidden();
  await expect(page.locator('#barangayResidentReport')).toBeHidden();
  await page.evaluate(() => window.openBarangayResidentList('barili_vito'));
  await expect(page.locator('#barangayResidentReport')).toBeHidden();
});

test('barangay and resident tables stay within a narrow Reports viewport', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 800 });
  await loadAdminSession(page, 'super_admin');
  await page.evaluate(() => {
    const report = window.__adminSession.state.barangayResidentReport;
    report.open = true;
    report.counts = new Map([['barili_vito', 1]]);
    report.total = 1;
    window.navigateTo('reports');
  });
  await expect(page.locator('#barangayResidentReport')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
  await page.evaluate(() => {
    const report = window.__adminSession.state.barangayResidentReport;
    report.barangayId = 'barili_vito';
    report.residents = [{ id: 'one', role: 'resident', barangayId: 'barili_vito', name: 'One Resident' }];
    window.navigateTo('reports');
  });
  await expect(page.locator('#barangayResidentsResidentRows')).toContainText('One Resident');
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
});
