const { test, expect } = require('@playwright/test');
const { readFileSync } = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function harness({ policyId = 'department_roads' } = {}) {
  const source = readFileSync(path.join(__dirname, '../app.js'), 'utf8');
  const start = source.indexOf('async function finishAdministratorAuthorization(user) {');
  const end = source.indexOf('window.toggleSetupPasswordVisibility =', start);
  if (start < 0 || end < 0) throw new Error('Authorization entry point not found');
  const events = [];
  const user = { uid: 'staff-a', email: 'staff@example.test' };
  let resolvePolicy;
  let rejectPolicy;
  const policy = new Promise((resolve, reject) => { resolvePolicy = resolve; rejectPolicy = reject; });
  const state = {
    sessionGeneration: 1,
    currentProfile: { id: user.uid, email: user.email, role: 'lgu' },
    currentAccessPolicy: { denied: ['announcements'] },
  };
  const auth = { currentUser: user };
  const scope = {
    state, auth, console: { error() {}, warn() {} },
    db: {}, doc: (...args) => args, getDoc: () => policy,
    accessPolicyIdForProfile: () => policyId,
    showDashboard: () => events.push({ action: 'show' }),
    configureRoleAccess: () => events.push({ action: 'configure', policy: state.currentAccessPolicy }),
    attachRealtimeListeners: () => events.push({ action: 'listen' }),
    signOut: async () => { events.push({ action: 'signOut' }); auth.currentUser = null; },
    setAuthMessage: message => events.push({ action: 'message', message }),
    showToast: message => events.push({ action: 'toast', message }),
    normalize: value => String(value || '').toLowerCase(),
    syncStaffEmailCall: async () => ({ data: { email: user.email } }),
    updateDoc: async () => {}, serverTimestamp: () => 0, arrayUnion: value => value,
  };
  const finish = vm.runInNewContext(`${source.slice(start, end)}; finishAdministratorAuthorization`, scope);
  return { finish, user, state, auth, events, resolvePolicy, rejectPolicy, scope };
}

test('office policy is loaded before dashboard permissions and listeners initialize', async () => {
  const h = harness();
  const pending = h.finish(h.user);
  expect(h.events).toEqual([]);
  h.resolvePolicy({ exists: () => true, data: () => ({ denied: ['concerns'] }) });
  await pending;
  expect(h.events.find(event => event.action === 'configure').policy).toEqual({ denied: ['concerns'] });
  expect(h.events.map(event => event.action)).toEqual(['show', 'configure', 'listen']);
});

test('an account without an office policy never inherits another session policy', async () => {
  const h = harness({ policyId: '' });
  await h.finish(h.user);
  expect(h.events.find(event => event.action === 'configure').policy).toEqual({});
});

test('a stale policy response cannot initialize or overwrite the next session', async () => {
  const h = harness();
  const pending = h.finish(h.user);
  h.state.sessionGeneration++;
  h.auth.currentUser = { uid: 'staff-b' };
  h.state.currentProfile = { id: 'staff-b' };
  h.state.currentAccessPolicy = { granted: ['announcements'] };
  h.resolvePolicy({ exists: () => true, data: () => ({ denied: ['concerns'] }) });
  await pending;
  expect(h.events).toEqual([]);
  expect(h.state.currentAccessPolicy).toEqual({ granted: ['announcements'] });
});

test('unavailable policy gives retry guidance without enabling default office controls', async () => {
  const h = harness();
  const pending = h.finish(h.user);
  h.rejectPolicy(new Error('offline'));
  await pending;
  expect(h.events.some(event => ['show', 'configure', 'listen'].includes(event.action))).toBe(false);
  expect(h.events.find(event => event.action === 'message').message).toMatch(/access settings.*connection.*again/i);
  expect(h.events.some(event => event.action === 'signOut')).toBe(true);
});

test('a failed stale policy request cannot sign out the next user', async () => {
  const h = harness();
  const pending = h.finish(h.user);
  h.state.sessionGeneration++;
  h.auth.currentUser = { uid: 'staff-b' };
  h.rejectPolicy(new Error('offline'));
  await pending;
  expect(h.events).toEqual([]);
  expect(h.auth.currentUser.uid).toBe('staff-b');
});

for (const fails of [false, true]) {
  test(`an outdated staff-profile ${fails ? 'failure' : 'response'} cannot affect a later login`, async () => {
    const h = harness();
    const source = readFileSync(path.join(__dirname, '../app.js'), 'utf8');
    const start = source.indexOf('async function authorizeAdministrator(user) {');
    const end = source.indexOf('async function finishAdministratorAuthorization(user)', start);
    const authorize = vm.runInNewContext(`${source.slice(start, end)}; authorizeAdministrator`, h.scope);
    const pending = authorize(h.user);
    h.state.sessionGeneration++;
    h.auth.currentUser = { uid: 'staff-b' };
    const currentProfile = { id: 'staff-b' };
    h.state.currentProfile = currentProfile;
    if (fails) h.rejectPolicy(new Error('offline'));
    else h.resolvePolicy({ exists: () => true, data: () => ({ id: 'staff-a', role: 'lgu' }) });
    await pending;
    expect(h.events).toEqual([]);
    expect(h.state.currentProfile).toBe(currentProfile);
    expect(h.auth.currentUser.uid).toBe('staff-b');
  });
}
