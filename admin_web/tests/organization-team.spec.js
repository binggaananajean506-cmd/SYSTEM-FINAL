const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test('People account badges and account details use each organization saved sector', async ({ page }) => {
  await loadAdminSession(page, 'super_admin');
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    state.organizations = [
      { id: 'public-org', name: 'Public Office', organizationSector: 'public' },
      { id: 'private-org', name: 'Private Group', organizationSector: 'private' },
      { id: 'legacy-org', name: 'Legacy Office', sector: 'public' },
    ];
    const member = (id, name, organizationId, extra = {}) => ({
      id, name, organizationId, role: 'organization', email: `${id}@example.test`,
      status: 'active', accountStatus: 'active', positionTitle: 'Organization Staff', ...extra,
    });
    state.users = [
      member('public-member', 'Public Member', 'public-org', { organizationSector: 'private' }),
      member('private-member', 'Private Member', 'private-org', { organizationSector: 'public' }),
      member('legacy-member', 'Legacy Member', 'legacy-org'),
      member('cached-member', 'Cached Member', 'missing-org', { organizationSector: 'private' }),
      member('unknown-member', 'Unknown Member', ''),
    ];
    state.peopleTab = 'organization';
    window.navigateTo('directory');
  });
  for (const [name, label] of [
    ['Public Member', 'Public Organization'], ['Private Member', 'Private Organization'],
    ['Legacy Member', 'Public Organization'], ['Cached Member', 'Private Organization'],
    ['Unknown Member', 'Organization'],
  ]) {
    await expect(page.locator('#userTable tr').filter({ hasText: name }).locator('.account-type-chip')).toContainText(label);
  }
  await expect(page.locator('#userTable')).not.toContainText('Partner Organization');
  await page.evaluate(() => window.openUser('public-member'));
  await expect(page.locator('#modalBody .account-type-chip')).toContainText('Public Organization');
});

async function loadMixedTeam(page) {
  await loadAdminSession(page, 'organization');
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    const now = new Date().toISOString();
    state.currentProfile.organizationName = 'CTU';
    state.organizations[0].name = 'CTU';
    const member = (id, name, role, organizationId, extra = {}) => ({
      id, name, role, organizationId, email: `${id}@example.test`,
      status: 'active', accountStatus: 'active', positionTitle: name, lastLoginAt: now, ...extra,
    });
    state.users = [
      member('own', 'CTU Member', 'organization', 'layout-org'),
      member('alias', 'CTU Representative', 'partner_organization', 'layout-org'),
      member('other', 'Other Organization Member', 'organization', 'other-org'),
      member('brgy', 'Barangay Official', 'barangay_secretary', 'layout-org'),
      member('lgu', 'LGU Staff', 'lgu', 'layout-org'),
      member('resident', 'Resident', 'resident', 'layout-org'),
      member('missing', 'Unassigned Member', 'organization', ''),
      member('archived', 'Former CTU Member', 'organization', 'layout-org', {
        accountStatus: 'disabled', approvedAt: '2026-09-01',
      }),
      member('other-archived', 'Former Other Member', 'organization', 'other-org', {
        accountStatus: 'disabled', approvedAt: '2026-09-01',
      }),
    ];
    state.accountRequests = [
      member('request', 'CTU Applicant', 'organization', 'layout-org', { status: 'pending', accountStatus: 'pending' }),
      member('other-request', 'Other Applicant', 'organization', 'other-org', { status: 'pending', accountStatus: 'pending' }),
      member('brgy-request', 'Barangay Applicant', 'barangay_secretary', 'layout-org', { status: 'pending', accountStatus: 'pending' }),
    ];
    window.navigateTo('directory');
  });
}

test('organization members and counts exclude other teams and non-organization roles', async ({ page }) => {
  await loadMixedTeam(page);
  await expect(page.locator('#page-title')).toHaveText('Organization Team');
  await expect(page.locator('#userTable .cell-title')).toHaveText(['CTU Member', 'CTU Representative']);
  await expect(page.locator('#barangayActiveOfficialsCount')).toHaveText('2');
  await expect(page.locator('#barangayArchivedOfficialsCount')).toHaveText('1');
  await expect(page.locator('#barangayPendingRequestsCount')).toHaveText('1');
  await expect(page.locator('#userPositionFilter')).not.toContainText('LGU Staff');
  await page.locator('#userSearch').fill('Other Organization');
  await expect(page.locator('#userTable')).toContainText('No active organization members found');
  await expect(page.locator('#userTable .cell-title')).toHaveCount(0);
});

test('organization archives and requests remain scoped to the same team', async ({ page }) => {
  await loadMixedTeam(page);
  await page.locator('[data-barangay-tab="archived"]').click();
  await expect(page.locator('#userTable .cell-title')).toHaveText(['Former CTU Member']);
  await page.locator('[data-barangay-tab="requests"]').click();
  await expect(page.locator('#barangayPendingRequestTable .cell-title')).toHaveText(['CTU Applicant']);
});

test('an organization without an assignment never falls back to showing all accounts', async ({ page }) => {
  await loadMixedTeam(page);
  await page.evaluate(() => {
    window.__adminSession.state.currentProfile.organizationId = '';
    window.__adminSession.renderUsersAndVerifications();
  });
  await expect(page.locator('#userTable .cell-title')).toHaveCount(0);
  await expect(page.locator('#barangayActiveOfficialsCount')).toHaveText('0');
  await expect(page.locator('#barangayPendingRequestsCount')).toHaveText('0');
});

test('organization accounts cannot open another team member from cached account data', async ({ page }) => {
  await loadMixedTeam(page);
  await page.evaluate(() => window.openUser('other'));
  await expect(page.locator('#adminModal')).toBeHidden();
  await page.evaluate(() => window.openUser('brgy'));
  await expect(page.locator('#adminModal')).toBeHidden();
  await page.evaluate(() => window.openUser('own'));
  await expect(page.locator('#adminModal')).toBeVisible();
  await expect(page.locator('#modalBody')).toContainText('CTU Member');
});

test('changing organizations scopes members to the newly assigned team', async ({ page }) => {
  await loadMixedTeam(page);
  await page.evaluate(() => {
    window.__adminSession.state.currentProfile.organizationId = 'other-org';
    window.__adminSession.renderUsersAndVerifications();
  });
  await expect(page.locator('#userTable .cell-title')).toHaveText(['Other Organization Member']);
  await expect(page.locator('#barangayActiveOfficialsCount')).toHaveText('1');
  await expect(page.locator('#barangayPendingRequestsCount')).toHaveText('1');
});

test('ending a session clears cached accounts and team requests', async ({ page }) => {
  await loadMixedTeam(page);
  const cached = await page.evaluate(() => {
    const { state, clearRealtimeListeners } = window.__adminSession;
    state.concerns = [{ id: 'private-concern' }];
    state.posts = [{ id: 'private-post' }];
    state.auditLogs = [{ id: 'private-log' }];
    state.organizations = [{ id: 'private-organization' }];
    state.emergencies = [{ id: 'private-emergency' }];
    state.documentRequests = [{ id: 'private-document' }];
    clearRealtimeListeners();
    return [state.users, state.accountRequests, state.concerns, state.posts,
      state.auditLogs, state.organizations, state.emergencies, state.documentRequests];
  });
  expect(cached).toEqual([[], [], [], [], [], [], [], []]);
});

test('organization login activity replaces stale rows and shows only its own members', async ({ page }, testInfo) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await loadMixedTeam(page);
  await page.evaluate(() => {
    window.navigateTo('systemLogs');
    document.getElementById('loginActivityTableBody').innerHTML = '<tr><td>Old Administrator Login</td></tr>';
    window.navigateTo('systemLogs');
  });
  await page.locator('#tabBtnLoginActivity').click();
  await expect(page.locator('#loginActivityHeading')).toHaveText('CTU Login Activity');
  await expect(page.locator('#loginActivityTableBody .cell-title')).toHaveText([
    'CTU Member', 'CTU Representative', 'Former CTU Member',
  ]);
  await expect(page.locator('#loginEventsCount')).toHaveText('3 accounts');
  await expect(page.locator('#loginActivityTableBody')).not.toContainText('Old Administrator');
  await page.screenshot({ path: testInfo.outputPath('organization-login-activity.png'), fullPage: true });
  await page.locator('#loginActivitySearch').fill('Other');
  await expect(page.locator('#loginActivityTableBody .cell-title')).toHaveCount(0);
  await expect(page.locator('#tabBadgeLoginActivity')).toHaveText('0');
  expect(errors).toEqual([]);
});

test('login activity switches team scope and fails closed without an organization assignment', async ({ page }) => {
  await loadMixedTeam(page);
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    state.currentProfile.organizationId = 'other-org';
    state.currentProfile.organizationName = 'Other Team';
    state.organizations.unshift({ id: 'unrelated-org', name: 'Unrelated Organization' });
    window.navigateTo('systemLogs');
  });
  await page.locator('#tabBtnLoginActivity').click();
  await expect(page.locator('#loginActivityHeading')).toHaveText('Other Team Login Activity');
  await expect(page.locator('#loginActivityTableBody .cell-title')).toHaveText([
    'Other Organization Member', 'Former Other Member',
  ]);
  await page.evaluate(() => {
    window.__adminSession.state.currentProfile.organizationId = '';
    window.navigateTo('systemLogs');
  });
  await expect(page.locator('#loginActivityTableBody .cell-title')).toHaveCount(0);
  await expect(page.locator('#loginEventsCount')).toHaveText('0 accounts');
});

test('organization reports, operations and CSV exports exclude unrelated records', async ({ page }) => {
  await loadMixedTeam(page);
  await page.evaluate(() => {
    const { state } = window.__adminSession;
    const now = new Date().toISOString();
    state.concerns = [
      { id: 'ctu-concern', title: 'CTU concern', organizationId: 'layout-org', status: 'resolved', createdAt: now, resolvedAt: now },
      { id: 'routed-concern', title: 'Routed CTU concern', organizationIds: ['layout-org', 'another-org'], status: 'new', createdAt: now },
      { id: 'foreign-concern', title: 'Foreign concern', organizationId: 'other-org', status: 'new', createdAt: now },
    ];
    state.posts = [
      { id: 'ctu-post', title: 'CTU announcement', publisherEntityId: 'layout-org', status: 'approved', createdAt: now },
      { id: 'foreign-post', title: 'Foreign announcement', publisherEntityId: 'other-org', status: 'approved', createdAt: now },
    ];
    state.accountRequests.forEach(request => { request.createdAt = now; });
    state.auditLogs = [
      { id: 'ctu-log', organizationId: 'layout-org', action: 'ctu_update', targetId: 'ctu-record', createdAt: now },
      { id: 'foreign-log', organizationId: 'other-org', action: 'foreign_update', targetId: 'foreign-record', createdAt: now },
    ];
    window.navigateTo('reports');
  });
  await expect(page.locator('#organizationReportReceived')).toHaveText('2');
  await expect(page.locator('#organizationReportCompleted')).toHaveText('1');
  await expect(page.locator('#organizationReportActive')).toHaveText('1');
  await expect(page.locator('#organizationReportPosts')).toHaveText('1');
  const downloadPromise = page.waitForEvent('download');
  await page.locator('#exportReport').click();
  const download = await downloadPromise;
  const csv = await require('node:fs/promises').readFile(await download.path(), 'utf8');
  expect(csv).toContain('CTU announcement');
  expect(csv).toContain('CTU Applicant');
  expect(csv).not.toContain('Foreign');
  expect(csv).not.toContain('foreign-');
  expect(csv).not.toContain('Other Applicant');
  expect(csv).not.toContain('Barangay Applicant');
  await page.locator('.nav-link[data-page="systemLogs"]').click();
  await expect(page.locator('#activityTableBody')).toContainText('CTU announcement');
  await expect(page.locator('#activityTableBody')).not.toContainText('Foreign');
  await expect(page.locator('#activityTableBody')).not.toContainText('Other Applicant');
});

test('global search cannot surface another organization or unrelated official accounts', async ({ page }) => {
  await loadMixedTeam(page);
  const search = value => page.evaluate(value => {
    const input = document.getElementById('globalSearch');
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }, value);
  await search('Other');
  await expect(page.locator('#globalSearchResults')).toContainText('No matching records');
  await search('CTU Member');
  await expect(page.locator('#globalSearchResults')).toContainText('CTU Member');
});

test('all organization navigation pages render without runtime errors with recorded logins', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await loadMixedTeam(page);
  for (const name of ['dashboard', 'concerns', 'announcements', 'emergency', 'directory', 'reports', 'systemLogs', 'settings']) {
    await page.locator(`.nav-link[data-page="${name}"]`).click();
    await expect(page.locator(`#page-${name}`)).toBeVisible();
  }
  expect(errors).toEqual([]);
});

for (const action of ['acknowledgeIncomingEmergency', 'changeEmergencyDispatch']) {
  test(`${action} refreshes the organization's emergency list after a successful update`, async ({ page }) => {
    await page.route('**/updateEmergencyDispatch', route => route.fulfill({
      status: 200,
      headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*' },
      contentType: 'application/json', body: JSON.stringify({ data: { success: true } }),
    }));
    await loadMixedTeam(page);
    await page.evaluate(() => {
      const { state } = window.__adminSession;
      state.organizations[0].sector = 'public';
      state.currentProfile.organizationSector = 'public';
      state.emergencyDispatches = [{
        id: 'ctu-dispatch', title: 'Test emergency', status: 'pending',
        sourceOrganizationId: 'requesting-org', destinationOrganizationId: 'layout-org',
        createdAt: new Date().toISOString(),
      }];
      window.navigateTo('emergency');
    });
    await page.evaluate(async action => {
      if (action === 'acknowledgeIncomingEmergency') await window[action]('ctu-dispatch', null);
      else await window[action]('ctu-dispatch', 'acknowledged', null);
    }, action);
    await expect(page.locator('#toastRegion')).toContainText('Emergency request acknowledged and moved to History.');
    await expect(page.locator('#toastRegion')).not.toContainText('not defined');
    await expect(page.locator('#incomingDispatchList')).toContainText('Test emergency');
  });
}
