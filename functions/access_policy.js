// Entity-wide overrides are intentionally limited to operational permissions.
// IT administration and account approval are never delegable.
const DELEGABLE_PERMISSIONS = Object.freeze([
  'concerns',
  'announcements',
  'staff:request',
  'alerts:publish',
  'verifications:local',
  'emergencies:direct:send',
  'emergencies:direct:receive',
]);

function accessPolicyId(type, id) {
  if (!['department', 'organization', 'barangay'].includes(type)
      || !/^[a-zA-Z0-9_-]{1,100}$/.test(String(id || ''))) return '';
  return `${type}_${id}`;
}

function policyAllows(policy, permission, defaultAllowed) {
  if (!DELEGABLE_PERMISSIONS.includes(permission)) return defaultAllowed;
  if (Array.isArray(policy?.denied) && policy.denied.includes(permission)) return false;
  if (Array.isArray(policy?.granted) && policy.granted.includes(permission)) return true;
  return defaultAllowed;
}

function policyScopeForVerification(policy, ownBarangayId = '') {
  if (ownBarangayId) return [ownBarangayId];
  return Array.isArray(policy?.verificationBarangayIds)
    ? [...new Set(policy.verificationBarangayIds.filter((id) => typeof id === 'string'))]
    : [];
}

module.exports = { DELEGABLE_PERMISSIONS, accessPolicyId, policyAllows, policyScopeForVerification };
