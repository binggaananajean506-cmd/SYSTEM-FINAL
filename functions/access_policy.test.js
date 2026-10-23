const test = require('node:test');
const assert = require('node:assert/strict');
const { accessPolicyId, policyAllows, policyScopeForVerification } = require('./access_policy');

test('entity IDs and nondelegable access are bounded', () => {
  assert.equal(accessPolicyId('organization', 'pnp'), 'organization_pnp');
  assert.equal(accessPolicyId('organization', '../users'), '');
  assert.equal(policyAllows({ granted: ['staff:approve'] }, 'staff:approve', false), false);
});

test('denial overrides grant and role default', () => {
  assert.equal(policyAllows({ denied: ['announcements'], granted: ['announcements'] }, 'announcements', true), false);
  assert.equal(policyAllows({ granted: ['verifications:local'] }, 'verifications:local', false), true);
  assert.equal(policyAllows({}, 'concerns', true), true);
});

test('verification scope never expands a barangay assignment', () => {
  const policy = { verificationBarangayIds: ['vito', 'vito', 'azucena'] };
  assert.deepEqual(policyScopeForVerification(policy, 'vito'), ['vito']);
  assert.deepEqual(policyScopeForVerification(policy), ['vito', 'azucena']);
});
