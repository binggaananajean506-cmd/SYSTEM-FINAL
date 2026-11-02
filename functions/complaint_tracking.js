"use strict";

// Tracking and the existing summons form. Physical service and legal eligibility stay offline.
const { isComplaint } = require("./complaint_helpers");
const { manualTanodName } = require("./summons_officials");
const { cfaOptions } = require("./cfa_forms");
const HEARINGS_PER_PHASE = 3;
const MAX_HEARINGS = HEARINGS_PER_PHASE * 2;
function hearingPhase(number) {
  return { phase: number > HEARINGS_PER_PHASE ? "lupon" : "barangay",
    phaseNumber: ((number - 1) % HEARINGS_PER_PHASE) + 1 };
}
function hearingLabel(number) {
  const { phase, phaseNumber } = hearingPhase(number);
  return `${phase === "lupon" ? "Lupon" : "Barangay"} Hearing ${phaseNumber} of ${HEARINGS_PER_PHASE} · Round ${number} of ${MAX_HEARINGS}`;
}
const TERMINAL = new Set(["resolved", "closed", "settled", "unsettled", "invalid", "withdrawn", "dismissed", "rejected", "cfa_issued"]);
const ACTION_LABELS = Object.freeze({
  review: "Under Review", request_information: "More Information Requested",
  invalid: "Invalid", schedule_hearing: "Hearing Scheduled", edit_schedule: "Schedule Updated",
  record_result: "Hearing Result Recorded", hearing_not_held: "Hearing Not Held",
  resolve_outside_hearing: "Resolved Outside Hearing", withdraw: "Withdrawn",
  record_external_update: "External Update Recorded", confirm_tracking: "Previous Tracking Position Confirmed",
  issue_summons: "Official Summons Issued", notify_summons: "Summons Notice Sent",
  issue_cfa: "Certificate to File Action Issued", schedule_another_hearing: "Next Hearing Scheduled",
  record_nonattendance: "Non-attendance Recorded",
  notify_cfa: "CFA notice sent",
});
function fail(message, code = "failed-precondition") {
  const error = new Error(message);
  error.code = code;
  throw error;
}
function text(value, label, required = true, max = 1000) {
  if (value != null && typeof value !== "string") fail(`${label} must be text.`, "invalid-argument");
  const result = (value || "").trim();
  if ((required && result.length < 3) || result.length > max) {
    fail(`${label} must contain ${required ? "3" : "0"}–${max} characters.`, "invalid-argument");
  }
  return result;
}
function manilaDate(now) { return new Date(now.getTime() + 8 * 3600000).toISOString().slice(0, 10); }
function validDate(value) {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)
    && Number.isFinite(Date.parse(`${value}T00:00:00+08:00`))
    && manilaDate(new Date(`${value}T00:00:00+08:00`)) === value;
}
function startTime(hearing) { return new Date(`${hearing.date}T${hearing.time}:00+08:00`); }
function trackingStatus(data) {
  const status = String(data.status || "filed").toLowerCase();
  if (["new", "submitted"].includes(status)) return "filed";
  if (["being_handled", "in_review"].includes(status)) return "under_review";
  if (status === "awaiting_resident") return "needs_information";
  if (["next_hearing", "for_next_hearing"].includes(status)) return "awaiting_next_schedule";
  return status;
}
function requiresTrackingConfirmation(data) {
  return !data.complaintTrackingVersion && !TERMINAL.has(trackingStatus(data))
    && (!!data.summons || !!data.schedule || (data.schedules || []).length > 0
      || ["summons_issued", "hearing_scheduled", "mediation", "final_conciliation", "awaiting_next_schedule"].includes(trackingStatus(data)));
}
function completedHearings(data) {
  return (data.legacyCompletedHearings || 0) + (data.hearings || []).filter((h) => h.status === "completed").length;
}
function activeHearing(data) { return (data.hearings || []).find((h) => h.status === "scheduled") || null; }
function currentSummons(data, hearing = activeHearing(data)) {
  const summons = data.summons;
  return hearing && summons && summons.status !== "superseded" && summons.hearingId === hearing.id
    && summons.appearanceDate === hearing.date && summons.appearanceTime === hearing.time
    && summons.appearanceVenue === hearing.venue ? summons : null;
}
function checkTrackingOperation(data, input, actorId, fingerprint, receipt) {
  if (receipt) {
    if (receipt.actorId !== actorId || receipt.fingerprint !== fingerprint) fail("This operation ID has already been used.", "already-exists");
    return receipt.result;
  }
  if ((data.workflowVersion || 0) !== input.expectedVersion) fail("Another update was saved. Reload the complaint and review its latest state.", "aborted");
  return null;
}
function schedule(input, number, now, actor, operationId, allowPast = false) {
  const date = input.date;
  const time = input.time;
  if (!validDate(date) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time || "")) fail("Choose a valid date and time.", "invalid-argument");
  const result = {
    id: operationId, number, ...hearingPhase(number), date, time, venue: text(input.venue, "Venue", true, 160),
    officerName: text(input.officerName, "Assigned official", false, 160),
    notes: text(input.notes, "Schedule notes", false), status: "scheduled",
    scheduledAt: now.toISOString(), scheduledBy: actor.id, scheduledByName: actor.name,
    scheduleChanges: [],
  };
  if (!allowPast && startTime(result) <= now) fail("Schedule a hearing in the future.", "invalid-argument");
  return result;
}
function planTrackingUpdate(data, input, now, actor) {
  if (!isComplaint(data)) fail("This action applies only to complaints.");
  if (!Object.hasOwn(ACTION_LABELS, input.action)) fail("Choose a valid tracking action.", "invalid-argument");
  const current = trackingStatus(data);
  const action = input.action;
  const finished = TERMINAL.has(current);
  if (finished && !["record_external_update", "notify_cfa"].includes(action)) fail("This complaint is already finished.");
  if (requiresTrackingConfirmation(data) && !["confirm_tracking", "record_external_update"].includes(action)) {
    fail("Confirm the previous hearing position before updating this legacy complaint.");
  }
  const hearings = (data.hearings || []).map((h) => ({ ...h }));
  const active = hearings.find((h) => h.status === "scheduled");
  let count = completedHearings(data);
  const update = { complaintTrackingVersion: 1, workflowVersion: (data.workflowVersion || 0) + 1 };
  let note = "";
  let label = ACTION_LABELS[action];
  let details = {};
  const intake = ["filed", "under_review", "needs_information"].includes(current) && count === 0 && !active;
  const close = (outcome, summary) => {
    update.status = outcome === "settled" ? "resolved" : "closed";
    update.closureOutcome = outcome;
    update.resolutionSummary = summary;
    update.closedAt = now.toISOString();
    update.closedBy = actor.id;
    update.schedule = null;
    if (active?.status === "scheduled") {
      active.status = "cancelled";
      active.cancellationReason = summary;
      active.cancelledAt = now.toISOString();
    }
  };
  const requireStarted = () => {
    if (!active || now < startTime(active)) fail("Record an attempt only after its scheduled start.");
  };
  const recordAbsence = () => {
    requireStarted();
    const attendance = [input.complainantAttendance, input.respondentAttendance];
    if (!attendance.every((value) => ["present", "absent"].includes(value)) || !attendance.includes("absent")) {
      fail("Record actual attendance for both parties, including the absent party.", "invalid-argument");
    }
    const summary = text(input.reason || input.previousHearingNote, "Non-attendance notes");
    Object.assign(active, { status: "completed", ...hearingPhase(active.number), outcome: "no_agreement", summary,
      complainantAttendance: input.complainantAttendance, respondentAttendance: input.respondentAttendance,
      recordedAt: now.toISOString(), recordedBy: actor.id });
    return summary;
  };
  switch (action) {
    case "review":
      if (current !== "filed") fail("Only a filed complaint can start review.");
      update.status = "under_review";
      note = "The barangay is reviewing this complaint.";
      break;
    case "request_information":
      if (!intake || current === "needs_information") fail("Information requests are available during intake review.");
      note = text(input.reason, "Information needed");
      update.status = "needs_information";
      update.requestedInfoMessage = note;
      update.requestedInfoAt = now.toISOString();
      update.requestedInfoBy = actor.id;
      break;
    case "invalid":
      if (!intake) fail("Only an intake complaint can be marked invalid.");
      note = text(input.reason, "Reason for invalid complaint");
      close("invalid", note);
      break;
    case "confirm_tracking": {
      if (!requiresTrackingConfirmation(data)) fail("This complaint does not need legacy confirmation.");
      count = input.completedHearings;
      if (!Number.isInteger(count) || count < 0 || count > MAX_HEARINGS) fail("Confirm 0 to 6 completed hearing rounds.", "invalid-argument");
      note = text(input.reason, "Basis for confirmed hearing count");
      update.legacyCompletedHearings = count;
      update.legacyTrackingSnapshot = { status: data.status, schedule: data.schedule || null, summons: data.summons || null };
      update.status = count > 0 ? "awaiting_next_schedule" : "under_review";
      update.schedule = null;
      if (count === MAX_HEARINGS) {
        if (input.date || !["settled", "unsettled"].includes(input.outcome)) fail("After six completed rounds, record the confirmed resolved or unsettled conclusion without another schedule.", "invalid-argument");
        const summary = text(input.summary, "Confirmed final conclusion");
        if (input.outcome === "settled") close("settled", summary);
        else { update.status = "awaiting_cfa"; update.resolutionSummary = summary; }
      }
      if (input.date) {
        const hearing = schedule(input, count + 1, now, actor, input.operationId, true);
        hearings.push(hearing);
        update.schedule = hearing;
        update.status = "hearing_scheduled";
      }
      details = { confirmedCompletedHearings: count, schedule: update.schedule };
      break;
    }
    case "schedule_hearing": {
      if (active || !["under_review", "awaiting_next_schedule"].includes(current) || count >= MAX_HEARINGS) fail("This complaint is not ready for a new hearing schedule.");
      const hearing = schedule(input, count + 1, now, actor, input.operationId);
      hearings.push(hearing);
      update.schedule = hearing;
      update.status = "hearing_scheduled";
      note = `${hearingLabel(hearing.number)} scheduled for ${hearing.date} at ${hearing.time} (Philippine time), ${hearing.venue}. ${hearing.notes}`.trim();
      details = { hearingId: hearing.id, hearingNumber: hearing.number, schedule: hearing };
      break;
    }
    case "edit_schedule": {
      if (!active) fail("There is no active hearing schedule.");
      if (manilaDate(now) >= active.date) fail("Ordinary schedule edits are locked on the hearing date. Record a result or a hearing-not-held event.");
      note = text(input.reason, "Reason for changing the schedule");
      const replacement = schedule(input, active.number, now, actor, active.id);
      const previous = { date: active.date, time: active.time, venue: active.venue, officerName: active.officerName || "", notes: active.notes || "" };
      replacement.scheduleChanges = [...(active.scheduleChanges || []), { previous, reason: note, changedAt: now.toISOString(), changedBy: actor.id }];
      Object.assign(active, replacement);
      if (data.summons) update.summons = { ...data.summons, status: "superseded" };
      update.schedule = active;
      details = { hearingNumber: active.number, previous, schedule: replacement };
      note = `${note} New schedule: ${active.date} at ${active.time} (Philippine time), ${active.venue}.`;
      break;
    }
    case "issue_summons": {
      let hearing = active;
      if (!hearing) {
        if (count >= MAX_HEARINGS) fail("This complaint has already reached 6 hearing rounds.");
        hearing = schedule({
          date: input.appearanceDate,
          time: input.appearanceTime,
          venue: input.appearanceVenue,
          officerName: input.assignedOfficer || actor.name,
          notes: input.hearingPurpose || ""
        }, count + 1, now, actor, `${input.operationId}_hearing`);
        hearings.push(hearing);
        update.schedule = hearing;
        update.status = "hearing_scheduled";
      } else {
        if (input.appearanceDate !== hearing.date || input.appearanceTime !== hearing.time || input.appearanceVenue !== hearing.venue) {
          hearing.date = input.appearanceDate;
          hearing.time = input.appearanceTime;
          hearing.venue = text(input.appearanceVenue, "Venue", true, 160);
          update.schedule = hearing;
        }
      }
      const countVal = hearing.number;
      const summons = {
        id: input.operationId, hearingId: hearing.id, hearingNumber: hearing.number, ...hearingPhase(hearing.number),
        issuedAt: now.toISOString(), issuedBy: actor.id, issuedByName: actor.name,
        barangay: actor.summonsOfficials?.barangay || data.barangay || "",
        barangayId: actor.summonsOfficials?.barangayId || data.barangayId || "",
        officials: actor.summonsOfficials || null,
        respondentName: text(input.respondentName, "Respondent", true, 150),
        respondentAddress: text(input.respondentAddress, "Respondent address", true, 240),
        appearanceDate: hearing.date, appearanceTime: hearing.time, appearanceVenue: hearing.venue,
        hearingPurpose: text(input.hearingPurpose, "Reason / Subject", true, 400),
        summonsCount: countVal, assignedTanod: text(manualTanodName(input.assignedTanod), "Assigned tanod", false, 100),
        status: "issued", deliveryStatus: "pending", deliveryMethod: "Personal service via Barangay Tanod / Peace Officer",
      };
      update.summons = summons;
      update.summonsHistory = [...(data.summonsHistory || []), summons];
      note = `Official summons generated for ${hearingLabel(hearing.number)} on ${hearing.date} at ${hearing.time} (Philippine time), ${hearing.venue}. Awaiting handoff to ${summons.assignedTanod || "a Barangay Tanod"}.`;
      details = { summonsId: summons.id, hearingNumber: hearing.number };
      break;
    }
    case "notify_summons": {
      const summons = currentSummons(data, active);
      if (!summons) fail("Generate a summons for the current hearing before notifying the complainant.");
      note = text(input.message, "Resident notice", true, 1000);
      if (input.handoff === true) {
        if (input.confirmHandoff !== true) fail("Confirm the summons was handed to the assigned tanod.", "invalid-argument");
        if (summons.deliveryStatus === "handed_to_tanod") fail("The tanod handoff notice was already recorded. Use a hearing reminder for another notice.");
        update.summons = { ...summons, deliveryStatus: "handed_to_tanod", handedToTanodAt: now.toISOString(), handedToTanodBy: actor.id };
        update.summonsHistory = (data.summonsHistory || []).map((entry) => entry.id === summons.id ? update.summons : entry);
        label = "Summons Handed to Barangay Tanod";
        note = `The summons has been handed to ${summons.assignedTanod ? `${summons.assignedTanod} (Barangay Tanod)` : "a Barangay Tanod"} for delivery to the respondent. ${note}`;
      }
      details = { summonsId: summons.id, hearingNumber: active.number, handoff: input.handoff === true };
      break;
    }
    case "record_result":
      if (!active || now < startTime(active)) fail("Record a hearing result only after its scheduled start.");
      if (!["settled", "no_agreement"].includes(input.outcome)) fail("Choose resolved or no agreement.", "invalid-argument");
      if (input.complainantAttendance !== "present" || input.respondentAttendance !== "present") fail("Both parties must attend a completed hearing. Use Hearing Not Held for an absent party.", "invalid-argument");
      note = text(input.summary, input.outcome === "settled" ? "Agreement summary" : "Conclusion and reason no agreement was reached");
      Object.assign(active, { status: "completed", outcome: input.outcome, summary: note,
        complainantAttendance: "present", respondentAttendance: "present", recordedAt: now.toISOString(), recordedBy: actor.id });
      update.schedule = null;
      if (input.outcome === "settled") { close("settled", note); label = "Resolved"; }
      else if (active.number >= MAX_HEARINGS) { update.status = "awaiting_cfa"; update.resolutionSummary = note; }
      else update.status = "awaiting_next_schedule";
      details = { hearingNumber: active.number, outcome: input.outcome, summary: note };
      break;
    case "record_nonattendance":
      note = recordAbsence();
      update.schedule = null;
      update.status = active.number >= MAX_HEARINGS ? "awaiting_cfa" : "awaiting_next_schedule";
      if (update.status === "awaiting_cfa") update.resolutionSummary = note;
      details = { hearingNumber: active.number, ...hearingPhase(active.number), outcome: "no_agreement",
        complainantAttendance: active.complainantAttendance, respondentAttendance: active.respondentAttendance };
      break;
    case "hearing_not_held":
      if (!active || manilaDate(now) < active.date) fail("Use ordinary schedule editing before the hearing date.");
      if (!["present", "absent", "unknown"].includes(input.complainantAttendance)
        || !["present", "absent", "unknown"].includes(input.respondentAttendance)) fail("Record attendance for both parties.", "invalid-argument");
      note = text(input.reason, "Reason the hearing was not held");
      Object.assign(active, { status: "not_held", reason: note, complainantAttendance: input.complainantAttendance,
        respondentAttendance: input.respondentAttendance, recordedAt: now.toISOString(), recordedBy: actor.id });
      update.schedule = null;
      update.status = count > 0 ? "awaiting_next_schedule" : "under_review";
      details = { hearingNumber: active.number, complainantAttendance: input.complainantAttendance, respondentAttendance: input.respondentAttendance };
      break;
    case "resolve_outside_hearing":
    case "withdraw":
      note = text(input.reason, action === "withdraw" ? "Confirmed withdrawal reason" : "Agreement summary");
      close(action === "withdraw" ? "withdrawn" : "settled", note);
      details = { cancelledHearingId: active?.id || null };
      break;
    case "issue_cfa": {
      if (active || count < MAX_HEARINGS) fail("Record all 6 rounds (3 barangay and 3 lupon) before issuing a CFA.");
      if (input.confirmEligibility !== true) fail("Confirm the office has checked the grounds and requirements for issuing this CFA.", "invalid-argument");
      const chosenForm = cfaOptions(data).find(option => option.form === input.cfaForm);
      if (!chosenForm) fail("Choose KP Form 20-A or 20-B.", "invalid-argument");
      if (!chosenForm.available) fail("The recorded attendance and results do not support this CFA form. Review the hearing records first.");
      if (chosenForm.needsOfficeRecords && input.confirmOfficeRecords !== true) fail("Check and confirm the paper records for missing attendance and outcomes.", "invalid-argument");
      if (input.cfaForm === "20-B" && input.confirmUnjustifiedAbsence !== true) fail("Confirm proper notice, Pangkat proceedings and the respondent's absence without a valid reason.", "invalid-argument");
      note = text(input.reason, "Reason for CFA", true, 1000);
      close("cfa_issued", note);
      update.cfaIssuedAt = now.toISOString();
      update.cfaIssuedBy = actor.id;
      update.cfaReason = note;
      update.cfaForm = chosenForm.form;
      update.cfaGround = chosenForm.ground;
      update.cfaEligibility = { officeChecked: true, officeRecordsConfirmed: input.confirmOfficeRecords === true,
        unjustifiedAbsenceConfirmed: input.confirmUnjustifiedAbsence === true, checkedBy: actor.id, checkedAt: now.toISOString() };
      update.cfaOfficials = { secretaryName: text(input.pangkatSecretaryName, "Pangkat secretary name", false, 150),
        chairName: text(input.pangkatChairName, "Pangkat chairperson name", false, 150) };
      label = `KP Form ${chosenForm.form} Issued`;
      details = { cfaIssuedAt: now.toISOString(), reason: note, cfaForm: chosenForm.form, cfaGround: chosenForm.ground };
      break;
    }
    case "schedule_another_hearing": {
      if (count >= MAX_HEARINGS || (active && active.number >= MAX_HEARINGS)) {
        fail("Maximum of 6 hearing rounds reached. Record the last result before issuing a CFA.");
      }
      if (active) {
        recordAbsence();
      }
      const nextNumber = (active ? active.number : count) + 1;
      if (nextNumber > MAX_HEARINGS) {
        fail("Maximum of 6 hearing rounds reached. Please issue a Certificate to File Action (CFA).");
      }
      const newHearing = schedule(input, nextNumber, now, actor, input.operationId);
      hearings.push(newHearing);
      update.schedule = newHearing;
      update.status = "hearing_scheduled";
      update.summons = null;
      note = `${hearingLabel(newHearing.number)} scheduled for ${newHearing.date} at ${newHearing.time} (Philippine time), ${newHearing.venue}. ${newHearing.notes || ""}`.trim();
      label = `Hearing ${newHearing.number} Scheduled`;
      details = { hearingId: newHearing.id, hearingNumber: newHearing.number, schedule: newHearing };
      break;
    }
    case "notify_cfa": {
      if (!finished || !(current === "cfa_issued" || data.closureOutcome === "cfa_issued")) fail("Issue a CFA before notifying the complainant about it.");
      note = text(input.message, "CFA notice");
      update.cfaLastNotifiedAt = now.toISOString();
      update.cfaLastNotifiedBy = actor.id;
      update.complaintTrackingVersion = data.complaintTrackingVersion || 0;
      details = { cfaForm: ["20-A", "20-B"].includes(data.cfaForm) ? data.cfaForm : "20" };
      break;
    }
    case "record_external_update": {
      // This records an actual offline event; it never implies document issuance.
      if (!validDate(input.date) || input.date > manilaDate(now)) fail("Enter the date the external event actually occurred.", "invalid-argument");
      const type = text(input.type, "External update type", true, 160);
      note = text(input.reason, "External update notes");
      details = { type, date: input.date, reference: text(input.reference, "External reference", false, 160) };
      update.externalUpdates = [...(data.externalUpdates || []), { ...details, note, recordedAt: now.toISOString(), recordedBy: actor.id }];
      // Do not confirm or migrate an ambiguous legacy workflow through a note.
      update.complaintTrackingVersion = data.complaintTrackingVersion || 0;
      break;
    }
  }
  if (!["record_external_update", "notify_cfa"].includes(action)) update.hearings = hearings;
  update.stage = update.status || current;
  update.updatedAt = now.toISOString();
  update.updatedBy = actor.id;
  update.lastHandledByName = actor.name;
  const event = { action, label, previousStatus: current, status: update.status || current, newStatus: update.status || current,
    note, remarks: note, details, date: now.toISOString(), performedAt: now.toISOString(),
    actorId: actor.id, performedBy: actor.id, actorName: actor.name, actorRole: actor.role, visibility: "public" };
  return { update, event, title: action === "notify_cfa" ? "Certificate to File Action ready" : label, message: note };
}
module.exports = { MAX_HEARINGS, HEARINGS_PER_PHASE, hearingPhase, hearingLabel, ACTION_LABELS, TERMINAL, manilaDate, validDate, startTime, trackingStatus, checkTrackingOperation,
  requiresTrackingConfirmation, completedHearings, activeHearing, currentSummons, planTrackingUpdate };
