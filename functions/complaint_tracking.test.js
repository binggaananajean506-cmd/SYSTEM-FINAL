"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { planTrackingUpdate, completedHearings, activeHearing, requiresTrackingConfirmation,
  checkTrackingOperation, validDate, manilaDate } = require("./complaint_tracking");
const actor = { id: "official", name: "Captain Cruz", role: "barangay_captain" };
const before = new Date("2026-10-09T15:59:59Z"); // 11:59:59 PM in Manila
const hearingDay = new Date("2026-10-09T16:00:00Z");
const start = new Date("2026-10-10T01:00:00Z");
const filed = () => ({ kind: "complaint", status: "filed", complaintTrackingVersion: 1, workflowVersion: 0, hearings: [] });
let sequence = 0;
function step(data, action, fields = {}, now = before) {
  const plan = planTrackingUpdate(data, { action, operationId: `operation-${++sequence}`, ...fields }, now, actor);
  return { ...data, ...plan.update, statusHistory: [...(data.statusHistory || []), plan.event] };
}
function scheduled() {
  return step(step(filed(), "review"), "schedule_hearing", { date: "2026-10-10", time: "09:00", venue: "Barangay Hall" });
}
const result = (outcome = "no_agreement") => ({ outcome, summary: "Both parties discussed the boundary but did not agree.", complainantAttendance: "present", respondentAttendance: "present" });
const summonsFields = () => ({ appearanceDate: "2026-10-10", appearanceTime: "09:00", appearanceVenue: "Barangay Hall",
  respondentName: "Juan Dela Cruz", respondentAddress: "Sitio Riverside", hearingPurpose: "Noise complaint mediation",
  summonsCount: 1, assignedTanod: "Pedro Reyes" });

test("official summons uses the scheduled hearing without advancing its count", () => {
  const direct = step(filed(), "issue_summons", summonsFields());
  assert.equal(direct.status, "hearing_scheduled");
  assert.equal(completedHearings(direct), 0);
  assert.equal(direct.summons.deliveryStatus, "pending");
  assert.equal(direct.summonsHistory.length, 1);

  const data = step(scheduled(), "issue_summons", summonsFields());
  assert.equal(data.status, "hearing_scheduled");
  assert.equal(completedHearings(data), 0);
  assert.equal(data.summons.hearingId, data.hearings[0].id);
  assert.equal(data.summons.deliveryStatus, "pending");
  assert.equal(data.summonsHistory.length, 1);
});

test("handoff requires confirmation and does not claim service or complete a hearing", () => {
  const data = step(scheduled(), "issue_summons", summonsFields());
  const notice = { handoff: true, confirmHandoff: true, message: "Please attend the scheduled hearing." };
  assert.throws(() => step(data, "notify_summons", { ...notice, confirmHandoff: false }), /Confirm the summons/);
  const sent = step(data, "notify_summons", notice);
  assert.equal(sent.summons.deliveryStatus, "handed_to_tanod");
  assert.equal(sent.summonsHistory[0].deliveryStatus, "handed_to_tanod");
  assert.equal(sent.status, "hearing_scheduled"); assert.equal(completedHearings(sent), 0);
  assert.match(sent.statusHistory.at(-1).note, /Pedro Reyes.*for delivery to the respondent/);
  assert.throws(() => step(sent, "notify_summons", notice), /already recorded/);
  assert.equal(step(sent, "notify_summons", { message: "Please attend on time.", handoff: false }).summons.deliveryStatus, "handed_to_tanod");
});

test("schedule changes and replacement hearings require a new matching summons", () => {
  const data = step(scheduled(), "issue_summons", summonsFields());
  const changed = step(data, "edit_schedule", { date: "2026-10-11", time: "10:00", venue: "New Hall", reason: "Venue unavailable." });
  assert.equal(changed.summons.status, "superseded");
  assert.throws(() => step(changed, "notify_summons", { message: "Old notice", handoff: true, confirmHandoff: true }), /current hearing/);
  const held = step(data, "record_result", result(), start);
  assert.throws(() => step(held, "notify_summons", { message: "Old notice" }, start), /current hearing/);
  const closed = step(data, "withdraw", { reason: "Resident confirmed withdrawal." });
  assert.throws(() => step(closed, "issue_summons", summonsFields()), /finished/);
});

test("review and intake information requests preserve the waiting state", () => {
  const waiting = step(step(filed(), "review"), "request_information", { reason: "Please identify the respondent's address." });
  assert.equal(waiting.status, "needs_information");
  assert.equal(waiting.requestedInfoMessage, waiting.statusHistory.at(-1).note);
  assert.throws(() => step(waiting, "schedule_hearing", { date: "2026-10-10", time: "09:00", venue: "Hall" }), /not ready/);
  assert.throws(() => step(scheduled(), "request_information", { reason: "More details" }), /intake/);
  assert.throws(() => step(filed(), "schedule_hearing"), /not ready/);
});
test("invalid and withdrawal need a reason and remain distinct from resolved", () => {
  assert.throws(() => step(filed(), "invalid", { reason: " " }), /Reason/);
  const invalid = step(filed(), "invalid", { reason: "Duplicate prank filing confirmed on review." });
  assert.equal(invalid.status, "closed");
  assert.equal(invalid.closureOutcome, "invalid");
  assert.throws(() => step(invalid, "review"), /finished/);
  assert.throws(() => step(scheduled(), "invalid", { reason: "Prank" }), /intake/);
  const withdrawn = step(scheduled(), "withdraw", { reason: "Resident confirmed withdrawal at the office." });
  assert.equal(withdrawn.closureOutcome, "withdrawn");
  assert.equal(withdrawn.hearings[0].status, "cancelled");
  assert.equal(completedHearings(withdrawn), 0);
});
test("schedule edits keep the old schedule and lock exactly at Manila midnight", () => {
  const data = scheduled();
  const changed = step(data, "edit_schedule", { date: "2026-10-11", time: "10:30", venue: "Barangay Hall", reason: "Both parties requested an earlier notice." }, before);
  assert.equal(changed.hearings.length, 1);
  assert.equal(changed.hearings[0].number, 1);
  assert.equal(changed.hearings[0].scheduleChanges[0].previous.date, "2026-10-10");
  assert.equal(data.hearings[0].date, "2026-10-10");
  assert.throws(() => step(data, "edit_schedule", { date: "2026-10-11", time: "10:30", venue: "Hall", reason: "Late change" }, hearingDay), /locked/);
  assert.equal(manilaDate(hearingDay), "2026-10-10");
});
test("dates reject impossible days, invalid times and schedules in the past", () => {
  assert.equal(validDate("2026-02-30"), false);
  assert.equal(validDate("2028-02-29"), true);
  assert.equal(validDate("Oct 10, 2026"), false);
  for (const [date, time] of [["2026-02-30", "09:00"], ["2026-10-10", "24:00"], ["2026-10-09", "09:00"]]) {
    assert.throws(() => step(step(filed(), "review"), "schedule_hearing", { date, time, venue: "Hall" }));
  }
});
test("results require the scheduled start, attendance, outcome and conclusion", () => {
  const data = scheduled();
  assert.throws(() => step(data, "record_result", result(), new Date(start.getTime() - 1)), /scheduled start/);
  assert.throws(() => step(data, "record_result", { ...result(), summary: " " }, start), /Conclusion/);
  assert.throws(() => step(data, "record_result", { ...result(), respondentAttendance: "absent" }, start), /Both parties/);
  assert.throws(() => step(data, "record_result", { ...result(), outcome: "referred" }, start), /Choose/);
  const next = step(data, "record_result", result(), start);
  assert.equal(next.status, "awaiting_next_schedule");
  assert.equal(next.hearings[0].status, "completed");
  assert.equal(next.schedule, null);
  assert.equal(completedHearings(next), 1);
});
test("three barangay rounds advance to three lupon rounds, then require separate CFA issuance", () => {
  let data = scheduled();
  for (let number = 1; number <= 6; number++) {
    assert.equal(activeHearing(data).number, number);
    assert.equal(activeHearing(data).phase, number <= 3 ? "barangay" : "lupon");
    assert.equal(activeHearing(data).phaseNumber, ((number - 1) % 3) + 1);
    assert.throws(() => step(data, "issue_cfa", { reason: "Unresolved case", confirmEligibility: true }), /six|6/i);
    data = step(data, "record_result", result(), new Date(`2026-10-${9 + number}T01:00:00Z`));
    if (number === 3) assert.equal(data.status, "awaiting_next_schedule");
    if (number < 6) data = step(data, "schedule_hearing", { date: `2026-10-${10 + number}`, time: "09:00", venue: "Hall" }, new Date(`2026-10-${9 + number}T02:00:00Z`));
  }
  assert.equal(data.status, "awaiting_cfa");
  assert.equal(completedHearings(data), 6);
  assert.equal(data.issuedCfa, undefined);
  assert.throws(() => step(data, "schedule_hearing", { date: "2026-10-17", time: "09:00", venue: "Hall" }), /not ready/);
  assert.throws(() => step(data, "issue_cfa", { reason: "No agreement after all six rounds." }), /confirm/i);
  const issued = step(data, "issue_cfa", { cfaForm: "20-A", reason: "No agreement after all six rounds.", confirmEligibility: true });
  assert.equal(issued.status, "closed");
  assert.equal(issued.closureOutcome, "cfa_issued");
  assert.ok(issued.cfaIssuedAt);
  assert.throws(() => step(issued, "issue_cfa", { reason: "Duplicate", confirmEligibility: true }), /finished/);
});
test("agreement at any hearing leaves its completed hearing intact", () => {
  for (let number = 1; number <= 6; number++) {
    const data = { ...scheduled(), legacyCompletedHearings: number - 1 };
    data.hearings[0].number = number;
    const finished = step(data, "record_result", result("settled"), start);
    assert.equal(finished.status, "resolved");
    assert.equal(finished.closureOutcome, "settled");
    assert.equal(finished.hearings[0].status, "completed");
    assert.equal(completedHearings(finished), number);
  }
});
test("not-held appointments retain attendance and replace the same hearing number", () => {
  let data = scheduled();
  assert.throws(() => step(data, "hearing_not_held", { reason: "Storm" }, before), /ordinary/);
  data = step(data, "hearing_not_held", { reason: "Respondent did not attend.", complainantAttendance: "present", respondentAttendance: "absent" }, start);
  assert.equal(data.hearings[0].status, "not_held");
  data = step(data, "schedule_hearing", { date: "2026-10-11", time: "09:00", venue: "Hall" }, start);
  assert.equal(data.hearings.length, 2);
  assert.equal(data.hearings[1].number, 1);
  assert.equal(completedHearings(data), 0);
});
test("agreement outside a hearing cancels the appointment without fabricating attendance", () => {
  const data = step(scheduled(), "resolve_outside_hearing", { reason: "The parties confirmed an agreement at the office." });
  assert.equal(data.status, "resolved");
  assert.equal(data.hearings[0].status, "cancelled");
  assert.equal(completedHearings(data), 0);
  assert.equal(data.hearings[0].complainantAttendance, undefined);
});
test("external events can follow closure, require an actual date, and do not reopen the case", () => {
  const closed = step(filed(), "invalid", { reason: "Prank confirmed." });
  const event = { type: "CFA issued outside the app", date: "2026-10-09", reference: "Office-123", reason: "Recorded from the barangay's offline register." };
  const updated = step(closed, "record_external_update", event);
  assert.equal(updated.status, "closed");
  assert.equal(updated.closureOutcome, "invalid");
  assert.equal(updated.externalUpdates[0].reference, "Office-123");
  assert.throws(() => step(closed, "record_external_update", { ...event, date: "2026-10-11" }), /actually occurred/);
});
test("ambiguous legacy schedules require confirmation; summons count is never hearing count", () => {
  const old = { kind: "complaint", status: "being_handled", summons: { summonsCount: 3 } };
  assert.equal(requiresTrackingConfirmation(old), true);
  assert.equal(completedHearings(old), 0);
  assert.throws(() => step(old, "review"), /Confirm/);
  const confirmed = step(old, "confirm_tracking", { completedHearings: 1, reason: "One completed hearing found in the logbook." });
  assert.equal(completedHearings(confirmed), 1);
  assert.equal(confirmed.status, "awaiting_next_schedule");
  assert.equal(requiresTrackingConfirmation(confirmed), false);
  assert.equal(confirmed.legacyTrackingSnapshot.summons.summonsCount, 3);
  const third = step(old, "confirm_tracking", { completedHearings: 3, reason: "Confirmed three barangay hearings in the logbook." });
  assert.equal(third.status, "awaiting_next_schedule");
  const sixth = step(old, "confirm_tracking", { completedHearings: 6, outcome: "unsettled", summary: "All six rounds ended without agreement.", reason: "Confirmed three barangay and three lupon hearings in the logbook." });
  assert.equal(sixth.status, "awaiting_cfa");
  assert.equal(completedHearings(sixth), 6);
});

test("recorded non-attendance advances rounds only after their start and never creates an early CFA", () => {
  let data = scheduled();
  const fields = { reason: "Respondent absent despite the summons.", complainantAttendance: "present", respondentAttendance: "absent" };
  assert.throws(() => step(data, "record_nonattendance", fields, before), /scheduled start/);
  assert.throws(() => step(data, "schedule_another_hearing", { ...fields, date: "2026-10-11", time: "09:00", venue: "Hall" }, before), /scheduled start/);
  for (let number = 1; number <= 6; number++) {
    data = step(data, "record_nonattendance", fields, new Date(`2026-10-${9 + number}T01:00:00Z`));
    if (number < 6) data = step(data, "schedule_another_hearing", { date: `2026-10-${10 + number}`, time: "09:00", venue: "Hall" }, new Date(`2026-10-${9 + number}T02:00:00Z`));
  }
  assert.equal(data.status, "awaiting_cfa");
  assert.equal(completedHearings(data), 6);
  assert.equal(data.cfaIssuedAt, undefined);
  assert.throws(() => step(data, "schedule_another_hearing", {}), /6/);
});

test("lupon summons numbers are derived from the hearing, not client input or regenerated copies", () => {
  const data = { ...scheduled(), legacyCompletedHearings: 3 };
  data.hearings[0].number = 4;
  const issued = step(data, "issue_summons", { ...summonsFields(), summonsCount: 6 });
  assert.equal(issued.summons.summonsCount, 4);
  assert.equal(issued.summons.phase, "lupon");
  assert.equal(issued.summons.phaseNumber, 1);
  const reissued = step(issued, "issue_summons", summonsFields());
  assert.equal(reissued.summons.summonsCount, 4);
  assert.equal(completedHearings(reissued), 3);
});
test("external notes cannot accidentally confirm a legacy position", () => {
  const old = { kind: "complaint", status: "mediation", schedule: { date: "old date" } };
  const updated = step(old, "record_external_update", { type: "Office update", date: "2026-10-09", reason: "Called parties to verify previous appointment." });
  assert.equal(requiresTrackingConfirmation(updated), true);
});
test("stale versions fail while a matching saved retry returns the original receipt", () => {
  const data = { workflowVersion: 2 };
  assert.throws(() => checkTrackingOperation(data, { expectedVersion: 1 }, "official", "a", null), { code: "aborted" });
  assert.equal(checkTrackingOperation(data, { expectedVersion: 2 }, "official", "a", null), null);
  const receipt = { actorId: "official", fingerprint: "a", result: { success: true, workflowVersion: 1 } };
  assert.deepEqual(checkTrackingOperation(data, { expectedVersion: 0 }, "official", "a", receipt), receipt.result);
  assert.throws(() => checkTrackingOperation(data, {}, "other", "a", receipt), { code: "already-exists" });
  assert.throws(() => checkTrackingOperation(data, {}, "official", "b", receipt), { code: "already-exists" });
});
test("non-complaints and inherited object keys cannot enter the workflow", () => {
  assert.throws(() => step({ kind: "concern" }, "review"), /only to complaints/);
  assert.throws(() => step(filed(), "toString"), /valid tracking action/);
});
