const test = require('node:test');
const assert = require('node:assert/strict');
const { processNotificationJob } = require('./notification_outbox');
function storedJob(data = {}) {
  const record = { status: 'pending', attempts: 0, ...data };
  const ref = { id: 'job', update: async update => Object.assign(record, update) };
  ref.firestore = { runTransaction: async run => run({
    get: async () => ({ data: () => ({ ...record }) }),
    update: (_, update) => Object.assign(record, update),
  }) };
  return { record, ref };
}
test('a durable job completes once and repeated event delivery does not resend', async () => {
  const { record, ref } = storedJob(); let sends = 0;
  const send = async () => { sends++; };
  await processNotificationJob(ref, send);
  await processNotificationJob(ref, send);
  assert.equal(record.status, 'completed'); assert.equal(sends, 1);
});
test('failed delivery keeps the job for a later retry', async () => {
  const { record, ref } = storedJob();
  await assert.rejects(processNotificationJob(ref, async () => { throw Object.assign(new Error('Offline'), { code: 'unavailable' }); }));
  assert.equal(record.status, 'pending'); assert.equal(record.leaseUntil, 0);
  await processNotificationJob(ref, async () => {});
  assert.equal(record.attempts, 2); assert.equal(record.status, 'completed');
});
test('a live lease rejects concurrent delivery, while an expired lease is recoverable', async () => {
  const { record, ref } = storedJob({ status: 'processing', leaseUntil: 2000 });
  let sends = 0;
  await assert.rejects(processNotificationJob(ref, async () => { sends++; }, { now: () => 1000 }), /lease-active/);
  assert.equal(sends, 0);
  await processNotificationJob(ref, async () => { sends++; }, { now: () => 3000 });
  assert.equal(record.status, 'completed'); assert.equal(sends, 1);
});
test('persistent failure has bounded retries and remains inspectable', async () => {
  const { record, ref } = storedJob({ attempts: 7 });
  await processNotificationJob(ref, async () => { throw new Error('No service'); });
  assert.equal(record.status, 'failed'); assert.equal(record.attempts, 8);
  await processNotificationJob(ref, async () => assert.fail('failed jobs must not loop'));
});
