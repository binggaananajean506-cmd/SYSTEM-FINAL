const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { seedThemeRecords } = require('./helpers/theme-records');

test('municipal staff retain the barangay filter when their profile has a home barangay', async ({ page }) => {
  await loadAdminSession(page);
  await seedThemeRecords(page);
  await page.evaluate(() => window.navigateTo('concerns'));
  await page.locator('#concernFilterToggle').click();
  await expect(page.locator('#concernBarangayFilter')).toBeVisible();
  await expect(page.locator('#concernBarangayFilter')).toBeEnabled();
});

const source = readFileSync(path.join(__dirname, '..', 'app.js'), 'utf8');
function between(start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first);
  if (first < 0 || last < 0) throw new Error(`Missing handler: ${start}`);
  return source.slice(first, last);
}

test('opening a concern category preserves status, period, type and barangay filters', () => {
  const controls = {
    concernBarangayFilter: { value: 'Vito' }, concernTypeFilter: { value: 'Roads' },
    concernReportYear: { value: '2026' }, concernReportMonth: { value: '10' },
  };
  const context = {
    state: { currentProfile: { role: 'super_admin', barangay: 'Vito' }, concernStatus: 'new', concernReportCategory: null,
      concerns: [
        { id: 'included', category: 'Roads', status: 'new', date: '2026-10-10', barangay: 'Vito' },
        { id: 'resolved', category: 'Roads', status: 'resolved', date: '2026-10-10', barangay: 'Vito' },
        { id: 'old-year', category: 'Roads', status: 'new', date: '2025-10-10', barangay: 'Vito' },
        { id: 'old-month', category: 'Roads', status: 'new', date: '2026-09-10', barangay: 'Vito' },
        { id: 'other-type', category: 'Health', status: 'new', date: '2026-10-10', barangay: 'Vito' },
        { id: 'other-barangay', category: 'Roads', status: 'new', date: '2026-10-10', barangay: 'Dakit' },
      ] },
    globalSearch: { value: '' }, normalize: value => String(value || '').toLowerCase(),
    isBarangayRole: () => false, canonicalRole: value => value, usesConcernReportTable: () => true,
    byId: id => controls[id], concernStatus: item => item.status,
    concernBarangay: item => item.barangay, concernReportDate: item => new Date(item.date),
  };
  vm.runInNewContext(between('function getFilteredConcerns() {', '\nfunction updateConcernFilterIndicator'), context);
  vm.runInNewContext(between('function matchesConcernReportPeriod(item) {', '\nfunction concernReportItems'), context);
  expect(context.getFilteredConcerns().map(item => item.id)).toEqual(['included']);
  context.state.concernReportCategory = 'roads';
  expect(context.getFilteredConcerns().map(item => item.id)).toEqual(['included']);
  expect(context.matchesConcernReportPeriod(context.state.concerns[2])).toBe(false);
  expect(context.matchesConcernReportPeriod(context.state.concerns[3])).toBe(false);
});

function workspace() {
  let finishTimeline;
  let html = '';
  const nodes = {
    'page-concerns': { classList: { add() {} } },
    concernDocumentGrid: { querySelectorAll: () => [] },
    printableConcernRecord: { hidden: true }, concernActionsHistoryContainer: { hidden: false },
    subpageActionsView: { hidden: false }, subpageHistoryView: { hidden: true },
    subnavBtnActions: { classList: { add() {}, remove() {} } },
    subnavBtnHistory: { classList: { add() {}, remove() {} } },
    concernDetailPane: { dataset: {} },
  };
  Object.defineProperty(nodes.concernDetailPane, 'innerHTML', {
    get: () => html,
    set(value) {
      html = value;
      nodes.printableConcernRecord.hidden = value !== 'report';
      nodes.concernActionsHistoryContainer.hidden = value === 'report';
      nodes.subpageActionsView.hidden = false;
      nodes.subpageHistoryView.hidden = true;
    },
  });
  const context = {
    window: {}, state: { selectedConcernId: null }, concernDetailRequest: 0,
    findCase: id => ({ id }), byId: id => nodes[id],
    document: { querySelector: () => null }, loadGroupedConcernSubmissions() {},
    caseWorkspaceMarkup: (_item, _entries, view) => view,
    concernTimelineEntries: () => new Promise(resolve => { finishTimeline = resolve; }),
  };
  vm.runInNewContext(between('window.openConcern = async', '\nwindow.openConcernManagement'), context);
  return { context, nodes, finish: () => finishTimeline([]) };
}

test('late concern timeline response keeps the report the user selected', async () => {
  const { context, nodes, finish } = workspace();
  const loading = context.window.openConcern('C-1');
  context.window.setConcernWorkspaceView('report');
  expect(nodes.printableConcernRecord.hidden).toBe(false);
  finish();
  await loading;
  expect(nodes.printableConcernRecord.hidden).toBe(false);
});

test('late concern timeline response keeps the history subpage the user selected', async () => {
  const { context, nodes, finish } = workspace();
  const loading = context.window.openConcern('C-1');
  context.window.setActionHistorySubpage('history');
  finish();
  await loading;
  expect(nodes.subpageHistoryView.hidden).toBe(false);
  expect(nodes.subpageActionsView.hidden).toBe(true);
});
