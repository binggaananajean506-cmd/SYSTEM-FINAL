const { BARILI_BARANGAYS, barangayIdFor } = require('./verification_helpers');

function barangayName(value) {
  const key = String(value || '').trim().toLowerCase()
    .replace(/^(?:(?:barangay|brgy|bgy|barili)[\s_:.-]+)+/, '').replace(/[^a-z0-9]/g, '');
  return BARILI_BARANGAYS.find(name => name.toLowerCase().replace(/[^a-z0-9]/g, '') === key) || '';
}

function summonsBarangay(data = {}) {
  const values = [data.receivingBarangayId, data.recipientBarangayId,
    data.receivingBarangayName, data.summons?.barangayId, data.summons?.barangay,
    data.recipientType === 'barangay' ? data.recipientId : '',
    data.recipientType === 'barangay' ? data.department : '', data.barangayId, data.barangay];
  for (const value of values) {
    const barangay = barangayName(value);
    if (barangay) return { barangayId: barangayIdFor(barangay), barangay };
  }
  return { barangayId: '', barangay: '' };
}

function selectSummonsOfficials(profiles, data) {
  const identity = summonsBarangay(data);
  const eligible = (profiles || []).filter(profile => {
    const own = summonsBarangay({ barangayId: profile.barangayId, barangay: profile.barangay });
    const status = String(profile.status || 'approved').toLowerCase();
    const accountStatus = String(profile.accountStatus || 'active').toLowerCase();
    return identity.barangayId && own.barangayId === identity.barangayId
      && ['approved', 'active', 'verified'].includes(status)
      && ['approved', 'active'].includes(accountStatus)
      && profile.setupRequired !== true && profile.restrictionStatus !== 'active';
  });
  function nameFor(role) {
    const matches = eligible.filter(profile => profile.role === role
      || (role === 'barangay_captain' && profile.role === 'barangay'));
    if (matches.length !== 1) return '';
    const profile = matches[0];
    const name = String(profile.name || '').replace(/\s+/g, ' ').trim();
    return name && name !== profile.id && !name.includes('@') ? name.slice(0, 120) : '';
  }
  return { ...identity, captainName: nameFor('barangay_captain'), secretaryName: nameFor('barangay_secretary') };
}

function manualTanodName(value) {
  const name = String(value || '').trim();
  return /^(?:barangay )?tanod(?: on duty)?$/i.test(name) ? '' : name;
}

module.exports = { summonsBarangay, selectSummonsOfficials, manualTanodName };
