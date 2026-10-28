import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import verificationHelpers from '../functions/verification_helpers.js';

let env;
before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085').split(':');
  env = await initializeTestEnvironment({ projectId: 'e-sugid',
    firestore: { host, port: Number(port), rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') } });
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

async function seed(role, { flag, granted = [], denied = [] } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'cabcaban-official'), {
      role, accountStatus: 'active', status: 'approved', setupRequired: false,
      barangay: 'Cabcaban', barangayId: 'barili_cabcaban',
      ...(flag === undefined ? {} : { canVerifyResidents: flag }),
    });
    await setDoc(doc(db, 'access_policies', 'barangay_barili_cabcaban'), {
      type: 'barangay', entityId: 'barili_cabcaban', granted, denied,
    });
    await setDoc(doc(db, 'verification_queue_versions', 'barili_cabcaban'), { version: 1 });
    await setDoc(doc(db, 'verification_queue_versions', 'barili_vito'), { version: 1 });
  });
  return env.authenticatedContext('cabcaban-official').firestore();
}

for (const role of ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary']) {
  for (const flag of [undefined, false]) test(`${role} verifies its barangay with legacy flag ${flag}`, async () => {
    const db = await seed(role, { flag });
    await assertSucceeds(getDoc(doc(db, 'access_policies', 'barangay_barili_cabcaban')));
    await assertSucceeds(getDoc(doc(db, 'verification_queue_versions', 'barili_cabcaban')));
    await assertFails(getDoc(doc(db, 'verification_queue_versions', 'barili_vito')));
  });
}

test('Cabcaban office grant works when the old per-account flag is missing', async () => {
  const db = await seed('barangay_councilor', { granted: ['verifications:local'] });
  await assertSucceeds(getDoc(doc(db, 'verification_queue_versions', 'barili_cabcaban')));
  await assertFails(getDoc(doc(db, 'verification_queue_versions', 'barili_vito')));
});

test('office denial still takes precedence over role defaults and explicit delegation', async () => {
  const db = await seed('barangay_captain', { flag: true, denied: ['verifications:local'] });
  await assertFails(getDoc(doc(db, 'verification_queue_versions', 'barili_cabcaban')));
});

test('an undelegated councilor cannot read verification queues or other office policies', async () => {
  const db = await seed('barangay_councilor');
  await assertFails(getDoc(doc(db, 'verification_queue_versions', 'barili_cabcaban')));
  await assertFails(getDoc(doc(db, 'access_policies', 'barangay_barili_vito')));
});

for (const [index, barangay] of verificationHelpers.BARILI_BARANGAYS.entries()) {
  test(`all barangays: ${barangay} leaders stay within their own verification queue`, async () => {
    const ownId = verificationHelpers.barangayIdFor(barangay);
    const otherId = verificationHelpers.barangayIdFor(verificationHelpers.BARILI_BARANGAYS[(index + 1) % 42]);
    const roles = ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary'];
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await Promise.all(roles.flatMap(role => [undefined, false].map(flag => setDoc(doc(db, 'users', `${role}-${flag}`), {
        role, barangay, barangayId: ownId, accountStatus: 'active', status: 'approved',
        ...(flag === undefined ? {} : { canVerifyResidents: false }),
      }))));
      await setDoc(doc(db, 'verification_queue_versions', ownId), { version: 1 });
      await setDoc(doc(db, 'verification_queue_versions', otherId), { version: 1 });
    });
    for (const role of roles) {
      for (const flag of [undefined, false]) {
        const db = env.authenticatedContext(`${role}-${flag}`).firestore();
        await assertSucceeds(getDoc(doc(db, 'verification_queue_versions', ownId)));
        await assertFails(getDoc(doc(db, 'verification_queue_versions', otherId)));
      }
    }
  });
}
