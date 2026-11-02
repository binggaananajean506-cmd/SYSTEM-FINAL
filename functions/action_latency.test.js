const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require.resolve('./index.js'), 'utf8');
test('complaint response waits for atomic save and durable notification, not phone delivery', async () => {
  const writes = []; let releaseCommit; let committed = false;
  const gate = new Promise(resolve => { releaseCommit = resolve; });
  const data = { status: 'filed', userId: 'resident', workflowVersion: 0 };
  function reference(path) {
    return { path, collection: name => ({ doc: id => reference(`${path}/${name}/${id || 'new'}`) }) };
  }
  const transaction = {
    get: async ref => ({ exists: !ref.path.includes('tracking_operations'), data: () => data }),
    set: (ref, value) => writes.push({ path: ref.path, value }), update: (ref, value) => writes.push({ path: ref.path, value }),
  };
  const scope = {
    console, Date,
    exports: {}, REGION: 'asia-southeast1', onCall: (_, fn) => fn,
    approvedCaller: async () => ({ id: 'official', role: 'super_admin' }), canonicalRole: role => role,
    validComplaintReference: value => value, isComplaint: () => true, summonsBarangay: () => ({ barangayId: 'barili_vito' }),
    createHash: require('node:crypto').createHash, checkTrackingOperation: () => null,
    Timestamp: { now: () => ({ toDate: () => new Date() }) }, FieldValue: { arrayUnion: event => [event], serverTimestamp: () => 'server' },
    planTrackingUpdate: () => ({ update: { workflowVersion: 1, status: 'under_review' }, event: { action: 'review' }, title: 'Reviewed', message: 'Reviewed' }),
    sendNormalPushToUsers: () => assert.fail('phone delivery must not run in the request'),
    db: { collection: name => ({ doc: id => reference(`${name}/${id || 'new'}`) }), runTransaction: async fn => { const result = await fn(transaction); await gate; committed = true; return result; } },
  };
  const queue = source.match(/^function queueWebNotification\([^]*?^}/m)[0];
  vm.runInNewContext(queue + '\n' + source.slice(source.indexOf('exports.advanceComplaintWorkflow =')), scope);
  let returned = false;
  const response = scope.exports.advanceComplaintWorkflow({ data: { submissionId: 'BC-2026-123456', action: 'review', expectedVersion: 0, operationId: 'valid-operation-123456' } }).then(result => { returned = true; return result; });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(returned, false); assert.equal(committed, false);
  assert.ok(writes.some(write => write.path.startsWith('web_notification_outbox/')));
  assert.ok(writes.some(write => write.path.startsWith('audit_logs/')));
  releaseCommit();
  assert.equal((await response).success, true); assert.equal(committed, true);
});
