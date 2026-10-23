const { instrumentAdminBundle } = require('./admin-bundle');
async function loadAdminSession(page, role = 'super_admin') {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle('window.__adminSession = { state, auth, byId, clearRealtimeListeners, renderDashboard, renderBarangayAnalyticsChart, renderOverviewAnalyticsChart, renderAlerts, renderEmergencyHotlines, renderUsersAndVerifications, BARANGAYS, barangayIdFor };') });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__adminSession));
  await page.evaluate(() => window.__adminSession.auth.authStateReady());
  await page.evaluate(role => {
    const { state, byId } = window.__adminSession;
    const profile = {
      role, email: 'layout@example.test', name: 'Layout Test', status: 'approved',
      barangay: 'Vito', barangayId: 'vito', canVerifyResidents: true,
      departmentId: 'it-department', departmentName: 'IT Department',
      organizationId: 'layout-org', organizationName: 'Layout Organization', organizationSector: 'private',
    };
    state.organizations = [{ id: 'layout-org', name: 'Layout Organization', sector: 'private', status: 'approved' }];
    state.lguDepartments = [{ id: 'it-department', name: 'IT Department', status: 'active' }];
    byId('login-screen').hidden = true;
    byId('login-screen').style.display = 'none';
    byId('admin-dashboard').hidden = false;
    byId('admin-dashboard').style.display = '';
    window.configureRoleAccess(profile);
  }, role);
}

module.exports = { loadAdminSession };
