"use strict";
const { before, after, test } = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");

// This suite must run against a disposable local Firestore emulator.
if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "")) {
  throw new Error("Run this suite with firebase emulators:exec --only firestore.");
}
process.env.GCLOUD_PROJECT = "e-sugid";
const { getFirestore } = require("firebase-admin/firestore");
const { getApps, deleteApp } = require("firebase-admin/app");
const callables = require("./index");
const db = getFirestore();
const { barangayIdFor } = require("./verification_helpers");
const barangayId = barangayIdFor("Vito");
const actor = (uid, data) => ({ auth: { uid, token: { name: uid } }, data });
let nextReference = 700000;
async function seed(fields = {}) {
  const id = `BC-2026-${++nextReference}`;
  await db.collection("submissions").doc(id).set({ id, kind: "complaint", status: "filed",
    userId: "tracking-resident", createdBy: "tracking-resident", reporterIds: ["tracking-resident"],
    barangay: "Vito", barangayId, recipientType: "barangay", complaintTrackingVersion: 1,
    workflowVersion: 0, hearings: [], ...fields });
  return id;
}
function advance(id, fields = {}, uid = "tracking-official") {
  return callables.advanceComplaintWorkflow.run(actor(uid, {
    submissionId: id, action: "review", operationId: randomUUID(), expectedVersion: 0, ...fields,
  }));
}
before(async () => {
  const profiles = {
    "tracking-official": { role: "barangay_captain", barangay: "Vito", barangayId },
    "tracking-other": { role: "barangay_secretary", barangay: "Poblacion", barangayId: barangayIdFor("Poblacion") },
    "tracking-resident": { role: "resident", barangay: "Vito", barangayId, verificationStatus: "verified" },
    "tracking-pending": { role: "barangay_secretary", barangay: "Vito", barangayId, accountStatus: "pending_approval" },
    "tracking-mayor": { role: "mayor" },
    "tracking-secretary": { role: "barangay_secretary", barangay: "Vito", barangayId },
    "tracking-it": { role: "super_admin", departmentId: "it-department" },
    "tracking-neighbor": { role: "resident", barangay: "Vito", barangayId,
      verifiedBarangayId: barangayId, verificationStatus: "verified" },
    "tracking-other-resident": { role: "resident", barangay: "Poblacion", barangayId: barangayIdFor("Poblacion"),
      verificationStatus: "verified" },
    "tracking-unverified-resident": { role: "resident", barangay: "Vito", barangayId, verificationStatus: "not_submitted" },
  };
  for (const [uid, fields] of Object.entries(profiles)) await db.collection("users").doc(uid).set({
    name: uid, status: "approved", accountStatus: "active", ...fields,
  });
});
after(async () => { await Promise.all(getApps().map(deleteApp)); });

test("callable permits its barangay and oversight but rejects other barangays, residents and pending staff", async () => {
  for (const uid of ["tracking-other", "tracking-resident", "tracking-pending"]) {
    await assert.rejects(advance(await seed(), {}, uid), { code: "permission-denied" });
  }
  assert.equal((await advance(await seed())).newStatus, "under_review");
  assert.equal((await advance(await seed(), {}, "tracking-mayor")).newStatus, "under_review");
  await assert.rejects(advance(await seed({ kind: "concern" })), /only to complaints/);
});
test("identical callable retries save one transition, notification and audit event", async () => {
  const id = await seed();
  const operationId = randomUUID();
  const first = await advance(id, { operationId });
  const retry = await advance(id, { operationId });
  assert.deepEqual(retry, first);
  const data = (await db.collection("submissions").doc(id).get()).data();
  assert.equal(data.workflowVersion, 1);
  assert.equal(data.statusHistory.length, 1);
  assert.equal((await db.collection("notifications").where("referenceId", "==", id).get()).size, 1);
  assert.equal((await db.collection("audit_logs").where("targetId", "==", id).get()).size, 1);
  await assert.rejects(advance(id, { operationId, action: "invalid", reason: "Different action" }), { code: "already-exists" });
});
test("concurrent decisions from the same version cannot overwrite each other", async () => {
  const id = await seed();
  const results = await Promise.allSettled([
    advance(id), advance(id, { action: "invalid", reason: "Confirmed prank filing." }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.find((r) => r.status === "rejected").reason.code, "aborted");
  assert.equal((await db.collection("submissions").doc(id).get()).data().statusHistory.length, 1);
});
test("generic concern actions cannot change complaint tracking", async () => {
  const id = await seed();
  await assert.rejects(callables.reviewConcern.run(actor("tracking-official", { submissionId: id, action: "handle" })), /complaint tracking/);
  await assert.rejects(callables.issueConcernSummons.run(actor("tracking-official", {
    submissionId: id, appearanceDate: "2026-11-01", appearanceTime: "09:00",
  })), /complaint tracking/);
});
test("resident revisions preserve the ID and original account, reject stale versions and retry once", async () => {
  const id = await seed({ status: "needs_information", workflowVersion: 2, draftId: "original-draft",
    title: "Original complaint", description: "Original description from the resident.",
    complaint: { respondentName: "Juan", attachmentUrl: "https://example.test/original.jpg" },
    attachmentUrl: "https://example.test/original.jpg", attachmentStoragePath: "previous-evidence",
    receiverAccountId: "tracking-official" });
  const input = { id, draftId: "revision-unique", expectedVersion: 1, barangay: "Vito", barangayId,
    respondentName: "Juan Dela Cruz", respondentAddress: "Sitio Riverside", complaintType: "Noise",
    incidentDate: "October 1, 2026", description: "Updated description with the requested details." };
  await assert.rejects(callables.submitComplaint.run(actor("tracking-resident", input)), { code: "aborted" });
  input.expectedVersion = 2;
  const first = await callables.submitComplaint.run(actor("tracking-resident", input));
  const retry = await callables.submitComplaint.run(actor("tracking-resident", input));
  assert.equal(first.id, id); assert.equal(retry.id, id);
  await assert.rejects(callables.submitComplaint.run(actor("tracking-resident", { ...input, description: "Different revised details after the save." })), { code: "already-exists" });
  const data = (await db.collection("submissions").doc(id).get()).data();
  assert.equal(data.status, "under_review"); assert.equal(data.workflowVersion, 3);
  assert.equal(data.originalSubmission.description, "Original description from the resident.");
  assert.equal(data.attachmentUrl, "https://example.test/original.jpg");
  assert.equal(data.complaint.attachmentUrl, data.attachmentUrl);
  assert.equal(data.submissionRevisions.length, 1);
  assert.equal((await db.collection("notifications").where("referenceId", "==", id).get()).size, 1);
});

test("summons and confirmed tanod handoff notify the resident once and preserve the hearing", async () => {
  const id = await seed({ status: "hearing_scheduled", hearings: [{ id: "current-hearing", number: 1,
    status: "scheduled", date: "2026-11-01", time: "09:00", venue: "Barangay Hall" }] });
  const issue = { action: "issue_summons", operationId: randomUUID(), respondentName: "Juan Dela Cruz",
    respondentAddress: "Sitio Riverside", appearanceDate: "2026-11-01", appearanceTime: "09:00",
    appearanceVenue: "Barangay Hall", hearingPurpose: "Noise complaint mediation", summonsCount: 1, assignedTanod: "Pedro Reyes" };
  await assert.rejects(advance(id, issue, "tracking-other"), { code: "permission-denied" });
  const generated = await advance(id, issue);
  assert.deepEqual(await advance(id, issue), generated);
  assert.equal(generated.update.summons.deliveryStatus, "pending");
  const notice = { action: "notify_summons", operationId: randomUUID(), expectedVersion: 1,
    handoff: true, confirmHandoff: true, message: "Please attend the scheduled hearing." };
  await assert.rejects(advance(id, { ...notice, operationId: randomUUID(), confirmHandoff: false }), { code: "invalid-argument" });
  const sent = await advance(id, notice);
  assert.deepEqual(await advance(id, notice), sent);
  const data = (await db.collection("submissions").doc(id).get()).data();
  assert.equal(data.workflowVersion, 2); assert.equal(data.status, "hearing_scheduled");
  assert.equal(data.hearings[0].status, "scheduled");
  assert.equal(data.summons.deliveryStatus, "handed_to_tanod");
  const notifications = await db.collection("notifications").where("referenceId", "==", id).get();
  assert.equal(notifications.size, 2);
  const handoff = notifications.docs.map((doc) => doc.data()).find((item) => item.title === "Summons Handed to Barangay Tanod");
  assert.equal(handoff.userId, "tracking-resident");
  assert.match(handoff.message, /Pedro Reyes.*for delivery to the respondent/);
  assert.equal(handoff.navigation.id, id);
});

test("summons loads the receiving office captain and secretary and leaves tanod blank", async () => {
  const id = await seed({ receivingBarangayId: barangayId, barangayId: barangayIdFor("Poblacion"),
    barangay: "Poblacion", status: "hearing_scheduled", hearings: [{ id: "office-hearing", number: 1,
      status: "scheduled", date: "2026-11-01", time: "09:00", venue: "Vito Barangay Hall" }] });
  const expected = { barangayId, barangay: "Vito", captainName: "tracking-official", secretaryName: "tracking-secretary" };
  // Official names are intentionally separate from their account identifiers.
  await db.collection("users").doc("tracking-official").update({ name: "Vito Captain" });
  await db.collection("users").doc("tracking-secretary").update({ name: "Vito Secretary" });
  expected.captainName = "Vito Captain"; expected.secretaryName = "Vito Secretary";
  assert.deepEqual(await callables.getSummonsOfficials.run(actor("tracking-resident", { submissionId: id })), expected);
  assert.deepEqual(await callables.getSummonsOfficials.run(actor("tracking-it", { submissionId: id })), expected);
  await assert.rejects(callables.getSummonsOfficials.run(actor("tracking-other", { submissionId: id })), { code: "permission-denied" });
  const issued = await advance(id, { action: "issue_summons", respondentName: "Juan Dela Cruz",
    respondentAddress: "Vito", appearanceDate: "2026-11-01", appearanceTime: "09:00",
    appearanceVenue: "Vito Barangay Hall", hearingPurpose: "Boundary dispute mediation", assignedTanod: "" });
  assert.deepEqual(issued.update.summons.officials, expected);
  assert.equal(issued.update.summons.assignedTanod, "");
  assert.equal(issued.update.summons.barangay, "Vito");
});

test("callable requires all six rounds before CFA, preserves retries and derives lupon summons stage", async () => {
  const id = await seed({ status: "awaiting_next_schedule", legacyCompletedHearings: 3 });
  await assert.rejects(advance(id, { action: "issue_cfa", reason: "No settlement", confirmEligibility: true }), /6 rounds/);
  const scheduled = await advance(id, { action: "schedule_another_hearing", date: "2099-11-01", time: "09:00", venue: "Vito Barangay Hall" });
  assert.equal(scheduled.update.schedule.number, 4);
  assert.equal(scheduled.update.schedule.phase, "lupon");
  const issued = await advance(id, { action: "issue_summons", expectedVersion: 1, respondentName: "Juan Dela Cruz",
    respondentAddress: "Vito", appearanceDate: "2099-11-01", appearanceTime: "09:00", appearanceVenue: "Vito Barangay Hall",
    hearingPurpose: "Lupon conciliation", summonsCount: 1 });
  assert.equal(issued.update.summons.summonsCount, 4);
  assert.equal(issued.update.summons.phaseNumber, 1);
  await assert.rejects(advance(id, { action: "issue_cfa", expectedVersion: 2, reason: "Still scheduled", confirmEligibility: true }), /6 rounds/);
  const ready = await seed({ status: "awaiting_cfa", legacyCompletedHearings: 6 });
  await assert.rejects(advance(ready, { action: "issue_cfa", reason: "No agreement after six rounds." }), /Confirm/);
  const input = { action: "issue_cfa", operationId: randomUUID(), cfaForm: "20-A", confirmOfficeRecords: true, reason: "No agreement after six rounds.", confirmEligibility: true };
  const cfa = await advance(ready, input);
  assert.equal(cfa.update.closureOutcome, "cfa_issued");
  assert.deepEqual(await advance(ready, input), cfa);
  assert.equal((await db.collection("notifications").where("referenceId", "==", ready).get()).size, 1);
  await assert.rejects(advance(ready, { action: "schedule_hearing", expectedVersion: 1 }), /finished/);
});

test("handler lookup returns only the actual official's name and role to authorized viewers", async () => {
  await db.collection("users").doc("tracking-official").update({ name: "Vito Captain" });
  const id = await seed({ kind: "concern", status: "being_handled", handledBy: "tracking-official",
    visibility: "private", statusHistory: [{ action: "handle", actorId: "tracking-official" }] });
  const result = await callables.getConcernHandler.run(actor("tracking-resident", { submissionId: id }));
  assert.deepEqual(result, { name: "Vito Captain", role: "barangay_captain" });
  await assert.rejects(callables.getConcernHandler.run(actor("tracking-other", { submissionId: id })), { code: "permission-denied" });
  await assert.rejects(callables.getConcernHandler.run(actor("tracking-pending", { submissionId: id })), { code: "permission-denied" });
  const missing = await seed({ kind: "concern", handledBy: "unknown-official" });
  assert.deepEqual(await callables.getConcernHandler.run(actor("tracking-resident", { submissionId: missing })), { name: "", role: "" });
  const publicId = await seed({ kind: "concern", visibility: "public", handledBy: "tracking-official" });
  assert.deepEqual(await callables.getConcernHandler.run(actor("tracking-neighbor", { submissionId: publicId })), result);
  for (const uid of ["tracking-other-resident", "tracking-unverified-resident"]) {
    await assert.rejects(callables.getConcernHandler.run(actor(uid, { submissionId: publicId })), { code: "permission-denied" });
  }
  await assert.rejects(callables.getConcernHandler.run(actor("tracking-neighbor", { submissionId: id })), { code: "permission-denied" });
  const complaintId = await seed({ visibility: "public", handledBy: "tracking-official" });
  await assert.rejects(callables.getConcernHandler.run(actor("tracking-neighbor", { submissionId: complaintId })), { code: "permission-denied" });
});
