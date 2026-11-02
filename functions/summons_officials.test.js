const test = require('node:test');
const assert = require('node:assert/strict');
const { BARILI_BARANGAYS, barangayIdFor } = require('./verification_helpers');
const { summonsBarangay, selectSummonsOfficials, manualTanodName } = require('./summons_officials');

const official = (role, barangay, name, extra = {}) => ({ id: `${role}_${barangay}`,
  role, barangay, barangayId: barangayIdFor(barangay), name, status: 'approved',
  accountStatus: 'active', ...extra });

test('captain and secretary come from the receiving barangay for all 42 offices', () => {
  for (const barangay of BARILI_BARANGAYS) {
    const result = selectSummonsOfficials([
      official('barangay_captain', barangay, `${barangay} Captain`),
      official('barangay_secretary', barangay, `${barangay} Secretary`),
      official('barangay_councilor', barangay, 'A Tanod', { positionCode: 'barangay_tanod' }),
    ], { receivingBarangayId: barangayIdFor(barangay), barangay: 'Vito' });
    assert.equal(result.barangayId, barangayIdFor(barangay));
    assert.equal(result.captainName, `${barangay} Captain`);
    assert.equal(result.secretaryName, `${barangay} Secretary`);
    assert.equal(result.tanodName, undefined);
  }
});

test('receiving office identity wins over the resident or viewing account barangay', () => {
  const data = { receivingBarangayId: 'barili_pangpang', barangayId: 'barili_vito', barangay: 'Vito' };
  assert.deepEqual(summonsBarangay(data), { barangayId: 'barili_pangpang', barangay: 'Pangpang' });
  const result = selectSummonsOfficials([
    official('barangay_captain', 'Vito', 'Wrong Captain'),
    official('barangay_captain', 'Pangpang', 'Correct Captain'),
    official('barangay_secretary', 'Pangpang', 'Correct Secretary'),
  ], data);
  assert.equal(result.captainName, 'Correct Captain');
  assert.equal(result.secretaryName, 'Correct Secretary');
});

test('inactive, pending, restricted, ambiguous and unnamed officials leave blank lines', () => {
  const data = { barangay: 'Vito' };
  for (const extra of [{ accountStatus: 'suspended' }, { status: 'pending_approval' },
    { setupRequired: true }, { restrictionStatus: 'active' }, { name: '' }]) {
    assert.equal(selectSummonsOfficials([official('barangay_captain', 'Vito', 'Captain', extra)], data).captainName, '');
  }
  assert.equal(selectSummonsOfficials([
    official('barangay_captain', 'Vito', 'First'), official('barangay_captain', 'Vito', 'Second'),
  ], data).captainName, '');
});

test('legacy name-only assignments work and tanod names are entered manually', () => {
  assert.equal(selectSummonsOfficials([official('barangay_captain', 'Vito', 'Captain',
    { barangayId: '' })], { publisher: 'unrelated', barangay: 'Vito' }).captainName, 'Captain');
  for (const placeholder of ['', 'Barangay Tanod', 'Barangay Tanod on duty']) assert.equal(manualTanodName(placeholder), '');
  assert.equal(manualTanodName(' Pedro Reyes '), 'Pedro Reyes');
});
