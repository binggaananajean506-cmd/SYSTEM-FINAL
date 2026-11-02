const CLEANUP_ROLES = new Set(['barangay_captain', 'barangay_vice_captain', 'barangay_secretary']);
function canDeleteConcernRecord({ role, actorBarangayId, concernBarangayId, kind }) {
  const localId = value => String(value || '').trim().toLowerCase().replace(/^barili_/, '');
  if (!['', 'concern'].includes(String(kind || '').toLowerCase())) return false;
  if (role === 'super_admin') return true;
  return CLEANUP_ROLES.has(role) && Boolean(actorBarangayId) && Boolean(concernBarangayId)
    && localId(actorBarangayId) === localId(concernBarangayId);
}
function canDeleteComplaintRecord({ kind, ...scope }) {
  return String(kind || '').toLowerCase() === 'complaint'
    && canDeleteConcernRecord({ ...scope, kind: 'concern' });
}
module.exports = { canDeleteConcernRecord, canDeleteComplaintRecord };
