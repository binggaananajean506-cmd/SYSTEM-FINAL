const { test, expect } = require('@playwright/test');
const { readFileSync } = require('node:fs');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

async function setup(page) {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__summonsLayout = { state, officialSummonsDocumentMarkup };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => window.__summonsLayout);
  await page.evaluate(() => {
    const { state, officialSummonsDocumentMarkup } = window.__summonsLayout;
    const profile = (role, barangay, name) => ({ id: `${role}_${barangay}`, role, name,
      barangay, status: 'approved', accountStatus: 'active' });
    state.users = [profile('barangay_captain', 'Vito', 'Wrong Captain'),
      profile('barangay_captain', 'Pangpang', 'Pangpang Captain'),
      profile('barangay_secretary', 'Pangpang', 'Pangpang Secretary')];
    const item = { id: 'BC-2026-900001', kind: 'complaint', residentName: 'Test Complainant',
      title: 'Boundary dispute', category: 'Boundary', receivingBarangayId: 'barili_pangpang',
      barangayId: 'barili_vito', barangay: 'Vito', complaint: { respondentName: 'Test Respondent' }, summons: {
        issuedAt: '2026-10-20T01:00:00Z',
        appearanceDate: '2026-11-01', appearanceTime: '09:00', appearanceVenue: 'Barangay Hall',
        hearingPurpose: 'Boundary dispute mediation', summonsCount: 1,
        assignedTanod: 'Barangay Tanod on duty' } };
    state.complaints = [item];
    const preview = document.createElement('div'); preview.id = 'summons-layout-fixture';
    preview.innerHTML = officialSummonsDocumentMarkup(item);
    for (const child of document.body.children) child.hidden = true;
    document.body.append(preview);
  });
}

test('reference layout uses the case barangay officials and correct left/right logos', async ({ page }) => {
  await setup(page);
  const doc = page.locator('#summons-layout-fixture');
  await expect(doc).toContainText('BARANGAY PANGPANG');
  await expect(doc).toContainText('OFFICE OF THE BARANGAY CAPTAIN');
  await expect(doc.locator('.kp-body-paragraphs')).toContainText('Respondent summoned: Test Respondent');
  await expect(doc).toContainText('Pangpang Secretary');
  await expect(doc).toContainText('Pangpang Captain');
  await expect(doc).not.toContainText('Wrong Captain');
  await expect(doc.locator('.kp-signatory--tanod')).not.toContainText('on duty');
  await expect(doc.locator('.kp-signatory--tanod .kp-signatory-name')).toHaveText('________________________');
  const left = await doc.locator('.kp-header-seal--barangay').boundingBox();
  const right = await doc.locator('.kp-header-seal--municipal').boundingBox();
  expect(left.x).toBeLessThan(right.x);
  const preparer = await doc.locator('.kp-signatories-row .kp-signatory').first().boundingBox();
  const captain = await doc.locator('.kp-signatories-row .kp-signatory').last().boundingBox();
  expect(preparer.x).toBeLessThan(captain.x);
  await expect(doc).toContainText('20th day of October, 2026');
  await page.screenshot({ path: test.info().outputPath('summons-reference-layout.png'), fullPage: true });
});

test('missing official records stay blank and a manually entered tanod is retained', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => {
    const { state, officialSummonsDocumentMarkup } = window.__summonsLayout;
    state.users = [];
    state.complaints[0].summons.assignedTanod = 'Pedro Reyes';
    document.getElementById('summons-layout-fixture').innerHTML = officialSummonsDocumentMarkup(state.complaints[0]);
  });
  const names = page.locator('.kp-signatories-row .kp-signatory-name');
  await expect(names.first()).toHaveText('________________________');
  await expect(names.last()).toHaveText('________________________');
  await expect(page.locator('.kp-signatory--tanod')).toContainText('Pedro Reyes');
});

test('downloaded PDF contains the same official names, issue date and manual tanod line', async ({ page }) => {
  await setup(page);
  const download = page.waitForEvent('download');
  await page.evaluate(() => window.downloadSummonsPdf('BC-2026-900001'));
  const result = await download;
  expect(result.suggestedFilename()).toBe('Barangay_Summons_BC-2026-900001.pdf');
  const pdf = readFileSync(await result.path()).toString('latin1');
  for (const text of ['Pangpang Captain', 'Pangpang Secretary', 'Prepared by:', 'Noted by:', 'Serve by:']) {
    expect(pdf).toContain(text);
  }
  expect(pdf).not.toContain('Wrong Captain');
  expect(pdf).toContain('Respondent summoned: Test Respondent');
  expect(pdf).not.toContain('Barangay Tanod on duty');
  expect((pdf.match(/\/Subtype \/Image/g) || []).length).toBeGreaterThanOrEqual(2);
});

test('lupon summons preview and PDF use the lupon office and restart invitation numbering', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => {
    const { state, officialSummonsDocumentMarkup } = window.__summonsLayout;
    Object.assign(state.complaints[0].summons, { hearingNumber: 4, summonsCount: 4, phase: 'lupon', phaseNumber: 1 });
    document.getElementById('summons-layout-fixture').innerHTML = officialSummonsDocumentMarkup(state.complaints[0]);
  });
  const doc = page.locator('#summons-layout-fixture');
  await expect(doc).toContainText('OFFICE OF THE LUPONG TAGAPAMAYAPA');
  await expect(doc.locator('.kp-case-field').last()).toContainText('1 of 3');
  await expect(doc.locator('.kp-body-paragraphs')).toContainText('before the Office of the Lupong Tagapamayapa');
  const download = page.waitForEvent('download');
  await page.evaluate(() => window.downloadSummonsPdf('BC-2026-900001'));
  const pdf = readFileSync(await (await download).path(), 'latin1');
  expect(pdf).toContain('OFFICE OF THE LUPONG TAGAPAMAYAPA');
  expect(pdf).toContain('1 of 3');
});
