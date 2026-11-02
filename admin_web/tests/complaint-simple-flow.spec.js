const { test, expect } = require('@playwright/test');
const { mkdirSync } = require('node:fs');
const path = require('node:path');
const { loadAdminSession } = require('./helpers/admin-session');
const { planTrackingUpdate } = require('../../functions/complaint_tracking');
const review = path.resolve(__dirname, '../../output/complaint-review');
mkdirSync(review, { recursive: true });
const base = { kind: 'complaint', barangay: 'Vito', barangayId: 'barili_vito', complaintTrackingVersion: 1, workflowVersion: 0,
  residentName: 'Maria Clara Santos', date: '2026-10-28T01:00:00Z', type: 'Other',
  description: '[Problem: Gossip or rumors]\n\n[Location: Sitio Riverside, Barangay Vito]\n\nA neighbor has been spreading false stories about our family.',
  complaint: { respondentName: 'Juan Dela Cruz' }, hearings: [] };
const scheduled = { id: 'h1', number: 1, status: 'scheduled', date: '2026-10-31', time: '09:00', venue: 'Vito Barangay Hall' };
const records = [
  { ...base, id: 'BC-2026-200001', status: 'filed', attachmentUrl: 'https://example.test/evidence.jpg' },
  { ...base, id: 'BC-2026-200002', status: 'under_review' },
  { ...base, id: 'BC-2026-200003', status: 'needs_information', requestedInfoMessage: 'Please confirm the incident date.' },
  { ...base, id: 'BC-2026-200004', status: 'hearing_scheduled', hearings: [scheduled] },
  { ...base, id: 'BC-2026-200005', status: 'hearing_scheduled', hearings: [{ ...scheduled, date: '2026-10-29' }] },
  { ...base, id: 'BC-2026-200006', complaintTrackingVersion: 0, status: 'being_handled', summons: { summonsCount: 3 } },
  { ...base, id: 'BC-2026-200007', status: 'awaiting_next_schedule', legacyCompletedHearings: 6 },
  { ...base, id: 'BC-2026-200008', status: 'closed', closureOutcome: 'unsettled', resolutionSummary: 'Case closed with an external referral.' },
  { ...base, id: 'BC-2026-200009', status: 'hearing_scheduled', hearings: [scheduled], summons: { id: 'summons-ready', hearingId: 'h1', status: 'issued', deliveryStatus: 'handed_to_tanod', appearanceDate: scheduled.date, appearanceTime: scheduled.time, appearanceVenue: scheduled.venue } },
];
async function setup(page, data = records) {
  await page.clock.setFixedTime(new Date('2026-10-30T04:00:00Z'));
  await page.route('**/getSummonsOfficials', route => route.fulfill({ contentType: 'application/json', body: JSON.stringify({ result: {
    barangayId: 'barili_vito', barangay: 'Vito', captainName: 'Captain Cruz', secretaryName: 'Secretary Ramos' } }) }));
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(data => { window.__adminSession.state.complaints = data; }, data);
  if (await page.locator('#menuButton').isVisible()) await page.locator('#menuButton').click();
  await page.locator('.nav-link[data-page="complaints"]').click();
  await page.locator('.complaint-header-actions').hover();
}
const tab = (page, stage) => page.locator('.complaint-summary-card[data-stage="' + stage + '"]');
const open = (page, id) => page.evaluate(id => window.openComplaintCase(id), id);

test('five exclusive queues separate new complaints from cases needing further action', async ({ page }) => {
  await setup(page);
  await expect(page.locator('.complaint-summary-card')).toHaveCount(5);
  const counts = { new: 1, active: 4, scheduled: 2, needs_information: 1, finished: 1 };
  const seen = [];
  for (const [queue, count] of Object.entries(counts)) {
    await expect(tab(page, queue).locator('b')).toHaveText(String(count));
    await tab(page, queue).click();
    const rows = page.locator('.complaint-reports-table tbody tr');
    await expect(rows).toHaveCount(count);
    seen.push(...await rows.locator('.tracking-reference').allTextContents());
    await expect(rows.first()).toContainText('Maria Clara Santos');
    await expect(rows.first()).toContainText('Juan Dela Cruz');
  }
  expect(seen.length).toBe(9); expect(new Set(seen).size).toBe(9);
  await tab(page, 'active').click();
  await page.getByRole('searchbox', { name: 'Search complaints in this queue' }).fill('not-a-case');
  await expect(page.locator('#complaintBoard')).toContainText('No cases found.');
  await page.getByRole('button', { name: 'Clear search' }).click();
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(4);
});

test('case view removes metadata clutter, keeps evidence and original records accessible', async ({ page }) => {
  await setup(page);
  await open(page, 'BC-2026-200001');
  await expect(page.locator('.case-statement')).toHaveText('A neighbor has been spreading false stories about our family.');
  await expect(page.locator('.case-location')).toContainText('Sitio Riverside');
  await expect(page.locator('.case-status-line')).toContainText('Gossip or rumors');
  await expect(page.locator('.tracking-steps, .tracking-official-form')).toHaveCount(0);
  await expect(page.locator('.tracking-next-step .button--primary')).toHaveCount(1);
  await expect(page.locator('[data-tracking-action="invalid"]')).toBeHidden();
  await page.getByText('Case details & attachment', { exact: true }).click();
  await expect(page.getByRole('link', { name: 'View supporting attachment' })).toHaveAttribute('href', 'https://example.test/evidence.jpg');
  await page.getByText('Original submission', { exact: true }).click();
  await expect(page.locator('.case-record-section').last()).toContainText('[Problem: Gossip or rumors]');
});

test('future hearings wait; due hearings have one result button; old records require confirmation', async ({ page }) => {
  await setup(page);
  await open(page, 'BC-2026-200009');
  await expect(page.locator('#trackingNextTitle')).toHaveText('Ready for the hearing');
  await expect(page.locator('[data-tracking-action="record_result"]')).toHaveCount(0);
  await open(page, 'BC-2026-200005');
  await expect(page.locator('.case-main-action button')).toHaveCount(1);
  await expect(page.getByRole('button', { name: 'No — record attendance' })).toHaveCount(0);
  await page.getByRole('button', { name: 'Record result', exact: true }).click();
  await expect(page.locator('[name="complainantAttendance"]')).toBeVisible();
  await expect(page.locator('[name="respondentAttendance"]')).toBeVisible();
  await expect(page.locator('[name="date"]')).toHaveCount(0);
  await expect(page.locator('[name="outcome"]')).toHaveCount(2);
  await open(page, 'BC-2026-200006');
  await expect(page.locator('[data-tracking-action="confirm_tracking"]')).toBeVisible();
  await expect(page.locator('[data-tracking-action="issue_summons"]')).toHaveCount(0);
  await open(page, 'BC-2026-200007');
  await expect(page.locator('[data-tracking-action="issue_cfa"]')).toBeVisible();
  await expect(page.locator('[data-tracking-action="issue_summons"]')).toHaveCount(0);
});

test('successful background review offers hearing setup and opening a case never writes data', async ({ page }) => {
  let record = structuredClone(records[0]); const actions = [];
  await setup(page, [record]);
  await page.route('**/advanceComplaintWorkflow', async route => {
    const input = route.request().postDataJSON().data; actions.push(input.action);
    const plan = planTrackingUpdate(record, input, new Date('2026-10-30T04:00:00Z'), { id: 'official', name: 'Captain Cruz', role: 'barangay_captain' });
    record = { ...record, ...plan.update };
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify({ result: { success: true, workflowVersion: record.workflowVersion, update: plan.update, event: plan.event } }) });
  });
  await open(page, record.id); expect(actions).toEqual([]);
  await page.locator('[data-tracking-action="review"]').click();
  await page.locator('#trackingSave').click();
  await expect(page.locator('#adminModal')).toBeHidden();
  await expect(tab(page, 'new').locator('b')).toHaveText('0');
  await expect(tab(page, 'active').locator('b')).toHaveText('1');
  await page.getByRole('button', { name: 'Set hearing', exact: true }).click();
  await expect(page.locator('#issueSummonsForm')).toBeVisible();
  expect(actions).toEqual(['review']); expect(record.status).toBe('under_review');
});

test('long statements and incomplete old submissions stay readable without losing text', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const description = 'A detailed account of what happened. '.repeat(30) + '<script>original text</script>';
  await setup(page, [{ ...base, id: 'BC-2026-200010', status: 'filed', description, complaint: {} }]);
  await open(page, 'BC-2026-200010');
  await expect(page.locator('.case-parties')).toContainText('Not specified');
  await expect(page.locator('.case-long-statement')).not.toHaveAttribute('open', '');
  const primary = await page.locator('.case-next-action .button--primary').boundingBox();
  expect(primary.y + primary.height).toBeLessThanOrEqual(844);
  await page.getByText('Read full statement', { exact: true }).click();
  await expect(page.locator('.case-long-statement p')).toHaveText(description);
  await expect(page.locator('.case-long-statement script')).toHaveCount(0);
  expect(await page.locator('#modalBody').evaluate(node => node.scrollWidth <= node.clientWidth)).toBe(true);
});

for (const width of [390, 1440]) {
  test('complaint workspace is readable at ' + width + 'px with one visible next action', async ({ page }) => {
    await page.setViewportSize({ width, height: width === 1440 ? 900 : 844 });
    await setup(page);
    await page.screenshot({ path: path.join(review, 'queue-' + width + '.png'), fullPage: true });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    await open(page, 'BC-2026-200001');
    const primary = page.locator('.case-next-action .button--primary');
    await expect(primary).toBeVisible();
    const box = await primary.boundingBox();
    expect(box.height).toBeGreaterThanOrEqual(44);
    expect(box.y + box.height).toBeLessThanOrEqual(width === 1440 ? 900 : 844);
    expect(await page.locator('#modalBody').evaluate(node => node.scrollWidth <= node.clientWidth)).toBe(true);
    await page.screenshot({ path: path.join(review, 'case-' + width + '.png') });
    await page.evaluate(() => { document.documentElement.dataset.theme = 'dark'; document.documentElement.style.colorScheme = 'dark'; });
    await page.screenshot({ path: path.join(review, 'case-dark-' + width + '.png') });
    await open(page, 'BC-2026-200005');
    await page.screenshot({ path: path.join(review, 'hearing-dark-' + width + '.png') });
  });
}
