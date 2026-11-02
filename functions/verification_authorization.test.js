const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const helpers = require('./verification_helpers');
const { policyAllows, policyScopeForVerification } = require('./access_policy');
const { HttpsError } = require('firebase-functions/v2/https');
const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const roles = ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary'];
const canonicalRole = role => role === 'barangay' ? 'barangay_captain' : role;

function officialCaller(actor, policy = {}) {
  const start = source.indexOf('async function verificationOfficialCaller(');
  const end = source.indexOf('async function profilesForBarangay(', start);
  return vm.runInNewContext(`${source.slice(start, end)}; verificationOfficialCaller`, {
    activeUserCaller: async () => actor,
    actorPolicy: async () => policy,
    profileCanVerifyResidents: helpers.defaultResidentVerificationPermission,
    BARANGAY_ROLES: new Set([...roles, 'barangay_councilor']),
    canonicalBarangayName: helpers.canonicalBarangayName,
    barangayIdFor: helpers.barangayIdFor,
    policyAllows, policyScopeForVerification, HttpsError,
    db: { collection: () => { throw new Error('Assigned staff need no profile mutation'); } },
  });
}

test('the actual verification callable authorizer accepts leaders in every one of the 42 barangays', async () => {
  for (const barangay of helpers.BARILI_BARANGAYS) {
    const barangayId = helpers.barangayIdFor(barangay);
    for (const role of roles) {
      const actor = { id: 'official', role, barangay, barangayId };
      const result = await officialCaller(actor)({});
      assert.deepEqual(Array.from(result.verificationBarangayIds), [barangayId], `${barangay}: ${role}`);
      await assert.rejects(officialCaller(actor, { denied: ['verifications:local'] })({}), { code: 'permission-denied' });
    }
  }
});

test('an office grant cannot expand a barangay official to another barangay', async () => {
  const actor = { id: 'official', role: 'barangay_secretary', barangay: 'Cabcaban', barangayId: 'barili_cabcaban' };
  const result = await officialCaller(actor, {
    granted: ['verifications:local'], verificationBarangayIds: ['barili_vito'],
  })({});
  assert.deepEqual(Array.from(result.verificationBarangayIds), ['barili_cabcaban']);
});

test('a mismatched name and barangay ID cannot be used to cross barangay boundaries', async () => {
  const actor = { id: 'official', role: 'barangay_captain', barangay: 'Vito', barangayId: 'barili_cabcaban' };
  await assert.rejects(officialCaller(actor)({}), { code: 'permission-denied' });
});

test('councilors continue to require an explicit account or office delegation', async () => {
  const actor = { id: 'official', role: 'barangay_councilor', barangay: 'Cabcaban', barangayId: 'barili_cabcaban' };
  await assert.rejects(officialCaller(actor)({}), { code: 'permission-denied' });
  const result = await officialCaller(actor, { granted: ['verifications:local'] })({});
  assert.deepEqual(Array.from(result.verificationBarangayIds), ['barili_cabcaban']);
});

for (const role of roles) test(`${role} role default cannot be silently disabled by the delegation endpoint`, async () => {
  const start = source.indexOf('exports.setResidentVerificationPermission =');
  const end = source.indexOf('function requestedRolesFor(', start);
  const scope = {
    exports: {}, REGION: 'test', onCall: (_, handler) => handler, HttpsError, canonicalRole,
    approvedCaller: async () => ({ id: 'admin', role: 'super_admin' }),
    requiredText: value => String(value), isItAdministrator: role => role === 'super_admin',
    BARANGAY_ROLES: new Set(roles), effectiveBarangayId: helpers.effectiveBarangayId,
    defaultResidentVerificationPermission: helpers.defaultResidentVerificationPermission,
    db: { collection: () => ({ doc: () => ({ get: async () => ({ exists: true,
      data: () => ({ role, barangay: 'Cabcaban', barangayId: 'barili_cabcaban' }),
    }) }) }) },
  };
  const endpoint = vm.runInNewContext(`${source.slice(start, end)}; exports.setResidentVerificationPermission`, scope);
  await assert.rejects(endpoint({ data: { userId: 'leader', canVerifyResidents: false } }), { code: 'failed-precondition' });
});
