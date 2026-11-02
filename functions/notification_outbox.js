// Durable delivery: a saved action never depends on an FCM network request.
// Firestore events may repeat; leases prevent concurrent workers and completed
// receipts suppress normal redelivery. A crash after FCM accepts a message can
// still produce a duplicate push (FCM has no exactly-once send API).
async function processNotificationJob(ref, deliver, { now = Date.now, leaseMs = 180000, maxAttempts = 8 } = {}) {
  const job = await ref.firestore.runTransaction(async transaction => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    if (!data || ['completed', 'failed'].includes(data.status)) return null;
    if (data.leaseUntil > now()) throw new Error('notification-lease-active');
    if ((data.attempts || 0) >= maxAttempts) {
      transaction.update(ref, { status: 'failed', leaseUntil: 0, updatedAt: new Date(now()) });
      return null;
    }
    const attempts = (data.attempts || 0) + 1;
    transaction.update(ref, { status: 'processing', attempts, leaseUntil: now() + leaseMs, updatedAt: new Date(now()) });
    return { ...data, attempts };
  });
  if (!job) return { skipped: true };
  try {
    await deliver(job, ref.id);
    await ref.update({ status: 'completed', leaseUntil: 0, completedAt: new Date(now()) });
    return { completed: true, attempts: job.attempts };
  } catch (error) {
    const exhausted = job.attempts >= maxAttempts;
    await ref.update({ status: exhausted ? 'failed' : 'pending', leaseUntil: 0,
      lastErrorCode: String(error.code || 'delivery-failed').slice(0, 80), updatedAt: new Date(now()) });
    if (!exhausted) throw error;
    return { failed: true, attempts: job.attempts };
  }
}
module.exports = { processNotificationJob };
