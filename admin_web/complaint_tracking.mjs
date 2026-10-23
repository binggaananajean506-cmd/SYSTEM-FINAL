import tracking from "../functions/complaint_tracking.js";

const { TERMINAL, trackingStatus, activeHearing, completedHearings, requiresTrackingConfirmation, manilaDate, startTime } = tracking;
const outcomes = { settled: "Resolved", unsettled: "Closed — Unsettled", cfa_issued: "Closed — CFA Issued", invalid: "Invalid", withdrawn: "Withdrawn", dismissed: "Dismissed (previous record)", referred: "Closed — External referral recorded" };
const labels = { filed: "Filed", under_review: "Under Review", needs_information: "Needs Information", awaiting_next_schedule: "Awaiting Next Schedule", hearing_scheduled: "Hearing Scheduled", resolved: "Resolved", settled: "Resolved", cfa_issued: "Closed — CFA Issued", unsettled: "Closed — Unsettled", closed: "Closed" };
export function complaintLabel(item, now = new Date()) {
  const status = trackingStatus(item);
  if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") return "CFA Issued (Closed)";
  if (TERMINAL.has(status)) return outcomes[item.closureOutcome] || outcomes[status] || labels[status] || (status === "rejected" ? "Invalid (previous record)" : "Closed");
  if (requiresTrackingConfirmation(item)) return "Previous Record — Confirm Position";
  if (status === "needs_information" || status === "awaiting_resident") return "Needs Information";
  const hearing = activeHearing(item);
  if (hearing && now >= startTime(hearing)) return "Result Pending";
  return labels[status] || status.replaceAll("_", " ");
}
export function complaintBucket(item, now = new Date()) {
  const status = trackingStatus(item);
  if (TERMINAL.has(status)) return "finished";
  if (status === "needs_information" || status === "awaiting_resident") return "needs_information";
  const hearing = activeHearing(item);
  if (hearing) return now >= startTime(hearing) ? "result_pending" : "scheduled";
  return "active";
}
export function complaintNextStep(item, now = new Date()) {
  const status = trackingStatus(item);
  if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") return { action: "view_cfa", label: "View / Print CFA", title: "Certificate to File Action Issued", help: "This complaint is officially closed. A Certificate to File Action (KP Form 20) was issued. The system will no longer record updates." };
  if (TERMINAL.has(status)) return { action: "view_record", label: "View Record", title: "Complaint Closed", help: "This complaint is completed and closed." };
  if (requiresTrackingConfirmation(item)) return { action: "confirm_tracking", label: "Check Previous Hearings", title: "Confirm Previous Hearings", help: "Confirm number of hearings from records before proceeding.", step: 0 };
  if (status === "needs_information" || status === "awaiting_resident") return { action: "view_record", label: "View Missing Info", title: "Needs Information", help: "Waiting for resident to provide requested info or evidence.", step: 0 };
  if (status === "filed") return { action: "review", label: "Review Complaint", title: "Review Complaint", help: "Check details below to proceed.", step: 0 };
  const hearing = activeHearing(item);
  if (hearing) {
    const hearingTitle = `Hearing ${hearing.number} of 3`;
    if (now >= startTime(hearing)) return { action: "record_result", label: "Record Result", title: `${hearingTitle}: Record Result`, help: "The hearing schedule has arrived. Record the outcome below based on party attendance.", step: 4 };
    const summons = tracking.currentSummons(item);
    if (!summons) return { action: "issue_summons", label: "Issue Summon", title: `${hearingTitle}: Issue Summon`, help: "Generate and issue summons for this scheduled hearing.", step: 2 };
    if (summons.deliveryStatus !== "handed_to_tanod") return { action: "notify_summons", label: "Notify Complainants", title: `${hearingTitle}: Notify Complainants`, help: "Confirm delivery and notify complainants of the hearing schedule.", step: 3 };
    return { action: "record_result", label: "Record Result", title: `${hearingTitle}: Ready for Hearing`, help: "Summons delivered. When the hearing is conducted, record the outcome below based on party attendance.", step: 4 };
  }
  const count = completedHearings(item);
  if (count >= 3) return { action: "issue_cfa", label: "Issue CFA", title: "3 Hearings Reached — Issue CFA", help: "Maximum of 3 hearings completed. Issue Certificate to File Action (KP Form 20) to close this case.", step: 4 };
  if (count > 0) return { action: "schedule_another_hearing", label: "Schedule Another Hearing", title: `Awaiting Hearing ${count + 1} of 3`, help: "Resident did not attend or previous hearing had no agreement. Schedule the next hearing.", step: 1 };
  return { action: "issue_summons", label: "Issue Summon", title: "Issue Official Summon", help: "Type schedule of hearing and venue to generate summons.", step: 1 };
}
export function complaintNeedsAction(item) {
  return ["review", "schedule_hearing", "schedule_another_hearing", "issue_summons", "notify_summons", "record_result", "issue_cfa", "confirm_tracking"].includes(complaintNextStep(item).action);
}
export function createComplaintTracking(deps) {
  const { items, find, byId, escape: esc, openModal, closeModal, toast, call, saved, residentName, formatDate, protectEdits, issueSummons, viewSummons, notifySummons, openCfa, openKasunduan } = deps;
  let filter = "active";
  let pending = false;
  function statusClass(item, now = new Date()) {
    const status = trackingStatus(item);
    if (requiresTrackingConfirmation(item)) return "needs-confirmation";
    if (status === "filed") return "filed";
    if (status === "under_review") return "under-review";
    if (status === "needs_information" || status === "awaiting_resident") return "needs-information";
    const hearing = activeHearing(item);
    if (hearing) return now >= startTime(hearing) ? "result-pending" : "scheduled";
    if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") return "cfa-issued";
    if (status === "settled" || status === "resolved") return "resolved";
    if (status === "unsettled") return "unsettled";
    if (status === "invalid" || status === "rejected") return "invalid";
    if (TERMINAL.has(status)) return "finished";
    return "active";
  }
  function pill(item) {
    const cls = statusClass(item);
    return `<span class="complaint-stage-pill tracking-status tracking-status--${cls} tracking-status--${complaintBucket(item)}">${esc(complaintLabel(item))}</span>`;
  }
  function hearingScheduleCell(item, hearing) {
    if (hearing) {
      return `<strong>Hearing ${hearing.number} of 3</strong><small>${esc(formatDate(startTime(hearing)))}</small><small>${esc(hearing.venue)}</small>`;
    }
    const status = trackingStatus(item);
    if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") {
      return `<span class="tracking-schedule-none">CFA Issued</span>`;
    }
    if (status === "settled" || status === "resolved") {
      return `<span class="tracking-schedule-none">Resolved</span>`;
    }
    if (TERMINAL.has(status)) {
      return `<span class="tracking-schedule-none">Case closed</span>`;
    }
    const count = completedHearings(item);
    if (count > 0) {
      return `<strong>Awaiting Schedule</strong><small>${count} of 3 completed</small>`;
    }
    return `<span class="tracking-schedule-none"><span class="material-symbols-rounded">event_busy</span> Not scheduled</span>`;
  }
  function button(action, title, primary = false) { return `<button type="button" class="button ${primary ? "button--primary" : "button--secondary"}" data-tracking-action="${action}">${esc(title)}</button>`; }
  function matches(item, category) {
    if (category === "all") return true;
    const status = trackingStatus(item);
    if (category === "active") {
      return !TERMINAL.has(status) && status !== "needs_information" && status !== "awaiting_resident";
    }
    if (category === "needs_information") {
      return status === "needs_information" || status === "awaiting_resident";
    }
    return complaintBucket(item) === category;
  }
  function progress(item, next) {
    if (TERMINAL.has(trackingStatus(item)) || requiresTrackingConfirmation(item) || next.step == null) return "";
    const hearing = activeHearing(item);
    const summons = tracking.currentSummons(item);
    const done = [!["filed", "needs_information"].includes(trackingStatus(item)), !!hearing, !!summons, summons?.deliveryStatus === "handed_to_tanod", false];
    const hearingLabel = hearing ? `Hearing ${hearing.number} of 3` : (completedHearings(item) >= 3 ? "Case conclusion" : "Hearing session");
    const steps = ["Review", "Set hearing", "Prepare summons", "Notify resident", hearingLabel];
    return `<ol class="tracking-steps" aria-label="Complaint steps">${steps.map((label, index) => `<li class="${index === next.step ? "is-current" : done[index] ? "is-done" : ""}" ${index === next.step ? 'aria-current="step"' : ""}><span aria-hidden="true">${done[index] ? "✓" : index + 1}</span><strong>${esc(label)}</strong>${done[index] ? '<small class="sr-only">Recorded</small>' : ""}</li>`).join("")}</ol>`;
  }
  function render() {
    const board = byId("complaintBoard");
    if (!board) return;
    const search = byId("complaintSearch");
    const clear = byId("complaintSearchClear");
    search.oninput = () => { clear.hidden = !search.value; render(); };
    clear.onclick = () => { search.value = ""; clear.hidden = true; render(); search.focus(); };
    document.querySelectorAll(".complaint-summary-card").forEach((tab) => {
      const category = tab.dataset.stage;
      tab.classList.toggle("active", category === filter);
      tab.classList.toggle("is-selected", category === filter);
      tab.setAttribute("aria-pressed", String(category === filter));
      tab.querySelector("b").textContent = items().filter((item) => matches(item, category)).length;
      tab.onclick = () => { filter = category; render(); };
    });
    const query = search.value.trim().toLowerCase();
    const rows = items().filter((item) => matches(item, filter)
      && [item.id, residentName(item), item.respondentName, item.complaint?.respondentName, item.type, item.location, item.description].some((value) => String(value || "").toLowerCase().includes(query)))
      .sort((a, b) => Number(complaintBucket(b) === "result_pending") - Number(complaintBucket(a) === "result_pending")
        || String(b.date?.toDate?.().toISOString() || b.date || "").localeCompare(String(a.date?.toDate?.().toISOString() || a.date || "")));
    board.classList.add("is-table-view");
    board.innerHTML = `<div class="tracking-table-scroll"><table class="complaint-reports-table"><thead><tr><th>Case No.</th><th>Complainant</th><th>Complaint</th><th>Status</th><th>Hearing / Next Schedule</th><th>Action</th></tr></thead><tbody>${rows.length ? rows.map((item, index) => {
      const hearing = activeHearing(item);
      return `<tr><td><button type="button" class="tracking-reference" data-case-id="${esc(item.id)}">${index + 1}</button><span class="sr-only">${esc(item.id)}</span></td>
        <td><strong>${esc(residentName(item))}</strong></td>
        <td>${esc(item.complaint?.complaintType || item.type || "Complaint")}</td><td>${pill(item)}</td>
        <td>${hearingScheduleCell(item, hearing)}</td>
        <td><button type="button" class="button button--primary" data-case-id="${esc(item.id)}">View</button></td></tr>`;
    }).join("") : '<tr><td colspan="6" class="tracking-empty">No complaints match this view.</td></tr>'}</tbody></table></div>`;
    board.querySelectorAll("[data-case-id]").forEach((node) => {
      node.onclick = () => {
        open(node.dataset.caseId);
      };
    });
  }
  function open(id) {
    const item = find(id);
    if (!item) return;
    const now = new Date();
    const status = trackingStatus(item);
    const finished = TERMINAL.has(status);
    const legacy = requiresTrackingConfirmation(item);
    const hearing = activeHearing(item);
    const summons = tracking.currentSummons(item);
    const details = item.complaint || {};
    const next = complaintNextStep(item);
    const actions = [];
    const add = (action, label, primary = false) => {
      actions.push(`<button type="button" class="button ${primary ? "button--primary" : "button--secondary"}" data-tracking-action="${action}">${esc(label)}</button>`);
    };

    if (finished) {
      if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") {
        add("view_cfa", "View / Print Certificate to File Action (CFA)", true);
      } else if (status === "settled" || status === "resolved") {
        add("view_kasunduan", "View / Print Kasunduan (KP Form 16)", true);
      }
      if (item.summons) add("view_summons", "View / Print Official Summons", false);
    } else if (legacy) {
      add("confirm_tracking", "Confirm Previous Hearings", true);
    } else {
      if (status === "filed") {
        add("review", "Start Review", true);
        add("issue_summons", "Issue Summon", false);
        add("request_information", "Need Information", false);
        add("invalid", "Mark as Invalid", false);
      } else if (status === "needs_information") {
        add("request_information", "Need Information", false);
        add("invalid", "Mark as Invalid", false);
      } else if (!hearing) {
        const count = completedHearings(item);
        if (count >= 3) {
          add("issue_cfa", "Issue Certificate to File Action (CFA)", true);
        } else if (count > 0) {
          add("schedule_another_hearing", "Schedule Another Hearing", true);
          add("issue_cfa", "Issue Certificate to File Action (CFA)", false);
        } else {
          add("issue_summons", "Issue Summon", true);
          add("request_information", "Need Information", false);
          add("invalid", "Mark as Invalid", false);
        }
        if (item.summons) add("view_summons", "View / Print Official Summons", false);
      } else {
        const currentNumber = hearing.number || (completedHearings(item) + 1);
        if (now >= startTime(hearing)) {
          add("record_result", "Record Result", true);
          if (currentNumber < 3) {
            add("schedule_another_hearing", "Schedule Another Hearing", false);
          } else {
            add("issue_cfa", "Issue Certificate to File Action (CFA)", false);
          }
          if (item.summons) add("view_summons", "View / Print Official Summons", false);
        } else if (!summons) {
          add("issue_summons", "Issue Summon", true);
          if (manilaDate(new Date()) < hearing.date) add("edit_schedule", "Edit Schedule", false);
          else add("hearing_not_held", "Hearing Not Held", false);
        } else if (summons.deliveryStatus !== "handed_to_tanod") {
          add("notify_summons", "Notify Complainants", true);
          if (manilaDate(new Date()) < hearing.date) add("edit_schedule", "Edit Schedule", false);
          else add("hearing_not_held", "Hearing Not Held", false);
          add("view_summons", "View / Print Official Summons", false);
        } else {
          add("record_result", "Record Result", true);
          if (currentNumber < 3) {
            add("schedule_another_hearing", "Schedule Another Hearing", false);
          } else {
            add("issue_cfa", "Issue Certificate to File Action (CFA)", false);
          }
          if (manilaDate(new Date()) < hearing.date) add("edit_schedule", "Edit Schedule", false);
          add("view_summons", "View / Print Official Summons", false);
        }
      }
    }

    const isHearingDecisionStage = !finished && !legacy && !!hearing && (now >= startTime(hearing) || summons?.deliveryStatus === "handed_to_tanod");
    const currentNumber = hearing ? (hearing.number || (completedHearings(item) + 1)) : 1;

    let actionsSectionHtml = "";
    if (isHearingDecisionStage) {
      actionsSectionHtml = `
        <div class="tracking-decision-grid">
          <div class="tracking-decision-card tracking-decision-card--attended">
            <div class="tracking-decision-info">
              <span class="tracking-decision-tag tracking-decision-tag--green">Both Parties Attended</span>
              <h4>Mediation Conducted</h4>
              <p>Record settlement agreement (Kasunduan) or conciliation notes.</p>
            </div>
            <button type="button" class="button button--primary" data-tracking-action="record_result">Record Result</button>
          </div>
          <div class="tracking-decision-card tracking-decision-card--absent">
            <div class="tracking-decision-info">
              <span class="tracking-decision-tag tracking-decision-tag--amber">Resident Did Not Attend</span>
              <h4>Resident / Respondent Absent</h4>
              <p>${currentNumber < 3 ? `Set Hearing ${currentNumber + 1} of 3 (maximum 3 hearings before CFA).` : "3 hearings reached. Conclude case and issue KP Form 20."}</p>
            </div>
            ${currentNumber < 3 
              ? `<button type="button" class="button button--secondary" data-tracking-action="schedule_another_hearing">Schedule Another Hearing</button>`
              : `<button type="button" class="button button--secondary" data-tracking-action="issue_cfa">Issue Certificate to File Action (CFA)</button>`
            }
          </div>
        </div>
        <div class="tracking-utility-bar">
          <span class="tracking-utility-title">Hearing Tools:</span>
          <div class="tracking-utility-buttons">
            ${manilaDate(new Date()) < hearing.date ? `<button type="button" class="button button--secondary button--sm" data-tracking-action="edit_schedule">Edit Schedule</button>` : ""}
            ${item.summons ? `<button type="button" class="button button--secondary button--sm" data-tracking-action="view_summons">View / Print Official Summons</button>` : ""}
          </div>
        </div>
      `;
    } else {
      actionsSectionHtml = `<div class="tracking-actions">${actions.join("")}</div>`;
    }

    const history = (item.statusHistory || []).filter((event) => event.visibility !== "internal");
    const scheduleHtml = hearing ? `<section class="tracking-panel tracking-schedule-panel">
      <div class="tracking-panel-header">
        <span class="tracking-schedule-badge">Scheduled Hearing</span>
        <h3>Hearing ${hearing.number} of 3</h3>
      </div>
      <div class="tracking-schedule-card">
        <div class="tracking-schedule-item">
          <span class="material-symbols-rounded">calendar_today</span>
          <div>
            <strong>${esc(formatDate(startTime(hearing)))}</strong>
            <small>${esc(hearing.venue)}</small>
          </div>
        </div>
        ${hearing.officerName ? `<div class="tracking-schedule-item"><span class="material-symbols-rounded">badge</span><div><small>Assigned Official</small><strong>${esc(hearing.officerName)}</strong></div></div>` : ""}
      </div>
      ${hearing.notes ? `<p class="tracking-schedule-notes">${esc(hearing.notes)}</p>` : ""}
      <p class="tracking-hint">${tracking.currentSummons(item)?.deliveryStatus === "handed_to_tanod" ? "Summons delivered. If the resident is not attending, click 'Schedule Another Hearing' (up to 3 hearings) or issue CFA." : "Summons not yet notified. Use 'Notify Complainants' to inform the resident."}</p>
    </section>` : "";

    const rawDescription = item.description || "";
    const locMatch = rawDescription.match(/^\[Location:\s*([^\]]+)\]/i);
    const locationVal = (details.location || item.location || locMatch?.[1] || details.respondentAddress || "").trim();
    const narrativeVal = rawDescription.replace(/^\[Location:\s*[^\]]+\]\s*/i, "").trim();

    const complaintDetailsHtml = `
      <section class="tracking-official-form">
        <div class="official-form-header">
          <div class="official-form-title">
            <span class="material-symbols-rounded">assignment</span>
            <span>Official Complaint Record</span>
          </div>
          <span class="official-form-badge">KP Case File</span>
        </div>
        <div class="official-form-body">
          <div class="official-form-row">
            <div class="official-form-cell">
              <span class="official-form-label">Complainant</span>
              <span class="official-form-value official-form-value--complainant">${esc(residentName(item))}</span>
            </div>
            <div class="official-form-cell">
              <span class="official-form-label">Respondent</span>
              <span class="official-form-value">${esc(details.respondentName || item.respondentName || details.respondentDescription || "Not specified")}</span>
            </div>
          </div>
          <div class="official-form-row">
            <div class="official-form-cell">
              <span class="official-form-label">Complaint Type</span>
              <span class="official-form-value">${esc(details.complaintType || item.type || "Complaint")}</span>
            </div>
            <div class="official-form-cell">
              <span class="official-form-label">Incident Date</span>
              <span class="official-form-value">${esc(item.incidentDate || "Not specified")}</span>
            </div>
          </div>
          ${locationVal ? `
            <div class="official-form-row official-form-row--full">
              <div class="official-form-cell">
                <span class="official-form-label">Incident Location</span>
                <span class="official-form-value"><span class="material-symbols-rounded official-loc-icon">location_on</span> ${esc(locationVal)}</span>
              </div>
            </div>
          ` : ""}
          ${narrativeVal ? `
            <div class="official-form-row official-form-row--full">
              <div class="official-form-cell">
                <span class="official-form-label">Statement of Complaint / What Happened</span>
                <div class="official-form-narrative">${esc(narrativeVal)}</div>
              </div>
            </div>
          ` : ""}
          ${details.desiredOutcome || item.requestedAction ? `
            <div class="official-form-row official-form-row--full">
              <div class="official-form-cell">
                <span class="official-form-label">Desired Outcome</span>
                <span class="official-form-value">${esc(details.desiredOutcome || item.requestedAction)}</span>
              </div>
            </div>
          ` : ""}
          ${details.witnesses ? `
            <div class="official-form-row official-form-row--full">
              <div class="official-form-cell">
                <span class="official-form-label">Witnesses</span>
                <span class="official-form-value">${esc(details.witnesses)}</span>
              </div>
            </div>
          ` : ""}
          ${evidence(item.attachmentUrl || details.attachmentUrl)}
        </div>
      </section>
    `;

    openModal("Complaint Tracking", id, `<div class="complaint-tracking-detail">
      <div class="tracking-overview">
        <div class="tracking-overview-badges">
          ${pill(item)}
          <span class="tracking-hearing-count"><span class="material-symbols-rounded">event_repeat</span> Hearings: <strong>${completedHearings(item)} of 3 completed</strong></span>
        </div>
      </div>
      ${progress(item, next)}
      ${complaintDetailsHtml}
      <section class="tracking-next-step" aria-labelledby="trackingNextTitle">
        <div class="tracking-next-header">
          ${hearing ? `
            <div class="tracking-next-header-row">
              <span class="tracking-next-caption">NEXT STEP · HEARING ${hearing.number} OF 3</span>
              <span class="tracking-schedule-pill"><span class="material-symbols-rounded">calendar_today</span> ${esc(formatDate(startTime(hearing)))}</span>
            </div>
          ` : `<span class="tracking-next-caption">NEXT STEP</span>`}
          <h3 id="trackingNextTitle">${esc(next.title)}</h3>
          <p>${esc(next.help)}</p>
        </div>
        ${actionsSectionHtml}
      </section>
      ${status === "cfa_issued" || item.closureOutcome === "cfa_issued" ? `
        <section class="tracking-panel tracking-panel--cfa" style="background: light-dark(#fef2f2, var(--errorSurface)); border: 1.5px solid light-dark(#f87171, var(--errorBorder)); border-radius: 10px; padding: 14px 16px; margin-bottom: 16px;">
          <div style="display: flex; align-items: flex-start; gap: 12px;">
            <span class="material-symbols-rounded" style="color: light-dark(#b52d38, var(--error)); font-size: 26px;">gavel</span>
            <div>
              <strong style="color: light-dark(#991b1b, var(--error)); display: block; font-size: 14.5px; margin-bottom: 4px;">Certificate to File Action Issued — Case Officially Closed</strong>
              <p style="color: light-dark(#7f1d1d, var(--error)); margin: 0 0 6px 0; font-size: 13px; line-height: 1.5;">
                Mediation in the barangay has concluded. A Certificate to File Action (KP Form 20) was issued for court or police proceedings. The system has ended tracking and will no longer record further updates.
              </p>
              ${item.cfaReason ? `<div style="background: light-dark(#fff, var(--surface)); border-radius: 6px; padding: 6px 10px; border: 1px solid light-dark(#fecaca, var(--errorBorder)); font-size: 12.5px; color: light-dark(#450a0a, var(--error));"><strong>Grounds for CFA:</strong> ${esc(item.cfaReason)}</div>` : ""}
            </div>
          </div>
        </section>
      ` : ""}
      ${legacy ? '<p class="tracking-warning">Previous schedules cannot establish the number of completed hearings. Check the barangay records and confirm the position before continuing.</p>' : ""}
      ${status === "needs_information" ? `<section class="tracking-panel tracking-panel--info-needed"><h3>Awaiting Resident Information</h3><p>${esc(item.requestedInfoMessage || "See the latest information request below.")}</p></section>` : ""}
      ${scheduleHtml}
      ${finished ? `<section class="tracking-panel"><h3>${esc(complaintLabel(item))}</h3><p class="tracking-text">${esc(item.resolutionSummary || item.settlement?.agreementTerms || item.unsettledRecord?.remarks || item.handlingNote || "See the recorded history for the conclusion.")}</p></section>` : ""}
      ${(item.hearings || []).length ? `<details class="tracking-panel"><summary>Hearing History (${item.hearings.length})</summary>${item.hearings.map((h) => `<article class="tracking-event"><strong>Hearing ${h.number} · ${esc(h.status.replaceAll("_", " "))}</strong><p>${esc(h.date)} · ${esc(h.time)} · ${esc(h.venue)}</p><p class="tracking-text">${esc(h.summary || h.reason || h.cancellationReason || h.notes || "")}</p>${h.complainantAttendance ? `<small>Attendance: complainant ${esc(h.complainantAttendance)}, respondent ${esc(h.respondentAttendance)}</small>` : ""}${(h.scheduleChanges || []).map((change) => `<small>Previous schedule: ${esc(change.previous.date)} ${esc(change.previous.time)} · ${esc(change.reason)}</small>`).join("")}</article>`).join("")}</details>` : ""}
      ${item.originalSubmission ? `<details class="tracking-panel"><summary>Original Submission and Revisions (${(item.submissionRevisions || []).length})</summary><p class="tracking-text">${esc(item.originalSubmission.description || "")}</p>${(item.submissionRevisions || []).map((revision) => `<article class="tracking-event"><small>Revised ${esc(formatDate(revision.revisedAt))}</small><p class="tracking-text">${esc(revision.description)}</p></article>`).join("")}</details>` : ""}
      <details class="tracking-panel"><summary>Activity History (${history.length})</summary><ol class="tracking-timeline">${history.map((event) => `<li><strong>${esc(event.label || labels[event.newStatus || event.status] || event.action?.replaceAll("_", " ") || "Update")}</strong><small>${esc(formatDate(event.date || event.performedAt || event.updatedAt))}${event.actorName ? ` · ${esc(event.actorName)}` : ""}</small><p class="tracking-text">${esc(event.note || event.remarks || event.reason || "")}</p>${event.action === "record_external_update" ? `<small>${esc(event.details?.type || "External event")} · ${esc(event.details?.date || "")} · ${esc(event.details?.reference || "No reference")}</small>` : ""}</li>`).join("") || "<li>No history recorded.</li>"}</ol></details>
    </div>`, '<button type="button" class="button button--secondary" id="trackingClose">Back to Complaints</button>', 'modal-card--complaint-tracking');
    byId("trackingClose").onclick = closeModal;
    byId("modalBody").querySelectorAll("[data-tracking-action]").forEach((node) => { node.onclick = () => run(id, node.dataset.trackingAction); });
  }
  function run(id, action) {
    if (action === "issue_summons") { issueSummons(id); return; }
    if (action === "view_summons") { closeModal(); viewSummons(id); return; }
    if (action === "notify_summons") { notifySummons(id); return; }
    if (action === "view_cfa") { closeModal(); if (openCfa) openCfa(id); else window.openOfficialCfaModal(id); return; }
    if (action === "view_kasunduan") { closeModal(); if (openKasunduan) openKasunduan(id); else window.openOfficialKasunduanModal(id); return; }
    form(id, action);
  }
  function evidence(url) {
    if (!url) return "";
    try { const parsed = new URL(url); if (parsed.protocol !== "https:") return "";
      return `<div class="official-form-row official-form-row--full">
        <div class="official-form-cell">
          <span class="official-form-label">Supporting Attachment</span>
          <a href="${esc(parsed.href)}" target="_blank" rel="noopener noreferrer" class="official-form-link">
            <span class="material-symbols-rounded">attachment</span> View supporting attachment
          </a>
        </div>
      </div>`;
    } catch { return ""; }
  }
  function field(name, label, type = "text", value = "", required = true) {
    return `<label class="tracking-field">${esc(label)}<input name="${name}" type="${type}" value="${esc(value)}" ${required ? "required" : ""} maxlength="160"></label>`;
  }
  function reason(label, name = "reason") { return `<label class="tracking-field">${esc(label)}<textarea name="${name}" required minlength="3" maxlength="1000" rows="4"></textarea></label>`; }
  function attendance(name, title, presentOnly = false) {
    if (presentOnly) return `<label class="tracking-choice"><input type="checkbox" required name="${name}" value="present"><span>${title} — I confirm this person attended.</span></label>`;
    return `<label class="tracking-field">${title}<select required name="${name}"><option value="">Choose attendance</option><option value="present">Present</option>${presentOnly ? "" : '<option value="absent">Absent</option><option value="unknown">Unknown</option>'}</select></label>`;
  }
  function form(id, action) {
    const item = find(id);
    if (!item || pending) return;
    const hearing = activeHearing(item);
    const details = item.complaint || {};
    let content = "";
    const titles = {
      schedule_another_hearing: "Schedule Another Hearing (Non-Attendance)",
      issue_cfa: "Issue Certificate to File Action (KP Form 20)",
      record_result: "Record Hearing Result",
      review: "Start Review",
      confirm_tracking: "Confirm Previous Hearings",
      request_information: "Ask for More Information",
      invalid: "Mark Complaint Invalid"
    };
    let title = titles[action] || tracking.ACTION_LABELS[action] || "Update Complaint";
    const d = new Date();
    d.setDate(d.getDate() + 3);
    const defDate = d.toISOString().slice(0, 10);
    const scheduleFields = (optional = false) => `<div class="tracking-form-grid">${field("date", optional ? "Current hearing date (optional)" : "Hearing date", "date", action === "edit_schedule" ? hearing?.date || "" : defDate, !optional)}${field("time", "Time (Philippine time)", "time", action === "edit_schedule" ? hearing?.time || "" : "09:00", !optional)}${field("venue", "Venue", "text", hearing?.venue || "Barangay Hall", !optional)}${field("officerName", "Assigned official (optional)", "text", hearing?.officerName || "", false)}</div><label class="tracking-field">Schedule notes (optional)<textarea name="notes" maxlength="1000">${esc(hearing?.notes || "")}</textarea></label>`;
    if (action === "schedule_another_hearing") {
      const nextNum = (hearing?.number || completedHearings(item)) + 1;
      content = `
        <div class="summons-simple-banner" style="border-left: 4px solid light-dark(#f59e0b, var(--warningBorder)); background: light-dark(#fffbeb, var(--warningSurface)); border-radius: 8px; padding: 12px 14px; margin-bottom: 16px;">
          <strong style="color: light-dark(#b45309, var(--warning)); display: block; margin-bottom: 4px; font-size: 14px;">Resident Not Attending Hearing</strong>
          <p style="margin: 0; font-size: 13px; color: light-dark(#78350f, var(--warning)); line-height: 1.5;">
            Use this option when the resident or respondent did not attend the scheduled hearing. You are setting Hearing ${nextNum} of 3. (Hearings are strictly limited to 3 before issuing a CFA).
          </p>
        </div>
        <input type="hidden" name="respondentAttendance" value="absent">
        <input type="hidden" name="complainantAttendance" value="present">
        ${reason("Note regarding resident non-attendance", "reason")}
        <hr style="border: 0; border-top: 1px solid light-dark(#e2e8f0, var(--border)); margin: 16px 0;">
        <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 700; color: light-dark(#0f172a, var(--textPrimary));">New Schedule for Hearing ${nextNum} of 3</h4>
        ${scheduleFields()}
      `;
    } else if (action === "issue_cfa") {
      content = `
        <div class="summons-simple-banner" style="border-left: 4px solid light-dark(#b52d38, var(--error)); background: light-dark(#fef2f2, var(--errorSurface)); border-radius: 8px; padding: 12px 14px; margin-bottom: 16px;">
          <strong style="color: light-dark(#991b1b, var(--error)); display: block; margin-bottom: 4px; font-size: 14px;">Issuing Certificate to File Action (KP Form 20)</strong>
          <p style="margin: 0; font-size: 13px; color: light-dark(#7f1d1d, var(--error)); line-height: 1.5;">
            3 hearings have been reached or conciliation was unsuccessful. Issuing a CFA permanently concludes barangay proceedings. Once issued, the system will end tracking and will no longer record updates for this case.
          </p>
        </div>
        <input type="hidden" name="respondentAttendance" value="absent">
        <input type="hidden" name="complainantAttendance" value="present">
        ${reason("Grounds / Reason for Certificate to File Action (e.g. Respondent failed to appear after 3 hearings)", "reason")}
      `;
    } else if (["schedule_hearing", "edit_schedule"].includes(action)) {
      content = `<p>Hearing ${hearing?.number || completedHearings(item) + 1} of 3. After scheduling, use Generate Official Summons to prepare the existing form.</p>${scheduleFields()}${action === "edit_schedule" ? reason("Reason for change") : ""}`;
    } else if (action === "record_result") {
      content = `
        <div class="hearing-result-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span class="hearing-result-badge">Hearing ${hearing.number} of 3</span>
            <span class="hearing-result-case">${esc(id)} · ${esc(residentName(item))}</span>
          </div>
          ${hearing.number === 3 ? `<span class="hearing-result-note">Final Hearing · No agreement closes the tracking record as unsettled</span>` : ""}
        </div>
        <div class="hearing-result-section">
          <label class="hearing-result-section-label">Hearing Result</label>
          <div class="hearing-outcome-options">
            <label class="hearing-outcome-card hearing-outcome-card--settled">
              <input type="radio" required name="outcome" value="settled">
              <div class="hearing-outcome-content">
                <span class="material-symbols-rounded">check_circle</span>
                <div>
                  <strong>Settled</strong>
                  <small>Both parties agreed</small>
                </div>
              </div>
            </label>
            <label class="hearing-outcome-card hearing-outcome-card--unsettled">
              <input type="radio" required name="outcome" value="no_agreement">
              <div class="hearing-outcome-content">
                <span class="material-symbols-rounded">cancel</span>
                <div>
                  <strong>Not Settled</strong>
                  <small>No agreement</small>
                </div>
              </div>
            </label>
          </div>
        </div>
        <div class="hearing-result-section">
          <label class="hearing-result-section-label">Attendance Confirmation</label>
          <div class="hearing-attendance-grid">
            <label class="hearing-attendance-chip">
              <input type="checkbox" required name="complainantAttendance" value="present" checked>
              <span class="material-symbols-rounded">person_check</span>
              <span>Complainant Attended</span>
            </label>
            <label class="hearing-attendance-chip">
              <input type="checkbox" required name="respondentAttendance" value="present" checked>
              <span class="material-symbols-rounded">person_check</span>
              <span>Respondent Attended</span>
            </label>
          </div>
        </div>
        <div class="hearing-result-section" style="margin-bottom: 0;">
          <label class="hearing-result-section-label" for="hearingSummaryInput">Hearing Summary / Notes</label>
          <textarea id="hearingSummaryInput" name="summary" required minlength="3" maxlength="1000" rows="3" class="hearing-result-textarea" placeholder="Enter key agreements, settlement terms, or minutes of the hearing..."></textarea>
        </div>
      `;
    } else if (action === "hearing_not_held") {
      content = `<p>The original appointment stays in history. A replacement uses hearing ${hearing.number} again.</p>${attendance("complainantAttendance", "Complainant attendance")}${attendance("respondentAttendance", "Respondent attendance")}${reason("Reason the hearing was not held")}`;
    } else if (action === "confirm_tracking") {
      content = `<p>Check the offline records. Do not infer hearing count from summons count. Enter the current appointment only if it is confirmed.</p><label class="tracking-field">Completed hearings<select required name="completedHearings"><option value="">Choose confirmed count</option><option value="0">0</option><option value="1">1</option><option value="2">2</option><option value="3">3 — Record final conclusion</option></select></label><label class="tracking-field">Final outcome (only for 3 completed hearings)<select name="outcome"><option value="">Not applicable</option><option value="settled">Resolved</option><option value="unsettled">Closed — Unsettled</option></select></label><label class="tracking-field">Final conclusion (required for 3 completed hearings)<textarea name="summary" maxlength="1000"></textarea></label>${reason("Basis for confirmation")}${scheduleFields(true)}`;
    } else if (action === "record_external_update") {
      content = `<p>Record an event that already occurred outside the app. This does not create or issue any document.</p>${field("type", "Event (for example, CFA issued outside the app)")}${field("date", "Actual event date", "date")}${field("reference", "Document reference (optional)", "text", "", false)}${reason("External update notes")}`;
    } else if (action === "review") {
      const revRaw = item.description || "";
      const revLocMatch = revRaw.match(/^\[Location:\s*([^\]]+)\]/i);
      const revLoc = (details.location || item.location || revLocMatch?.[1] || details.respondentAddress || "").trim();
      const revNarr = revRaw.replace(/^\[Location:\s*[^\]]+\]\s*/i, "").trim();
      content = `
        <div style="background: light-dark(#f8fafc, var(--surfaceAlt)); border: 1px solid light-dark(#e2e8f0, var(--border)); border-radius: 12px; padding: 14px 16px; margin-bottom: 14px;">
          <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px 14px; margin-bottom: 8px;">
            <div><small style="color: light-dark(#64748b, var(--textSecondary)); font-weight: 700; text-transform: uppercase; font-size: 11px;">Complainant</small><div style="font-weight: 600; color: light-dark(#0f172a, var(--textPrimary));">${esc(residentName(item))}</div></div>
            <div><small style="color: light-dark(#64748b, var(--textSecondary)); font-weight: 700; text-transform: uppercase; font-size: 11px;">Respondent</small><div style="font-weight: 600; color: light-dark(#0f172a, var(--textPrimary));">${esc(details.respondentName || item.respondentName || "Not specified")}</div></div>
            <div><small style="color: light-dark(#64748b, var(--textSecondary)); font-weight: 700; text-transform: uppercase; font-size: 11px;">Complaint Type</small><div style="color: light-dark(#0f172a, var(--textPrimary));">${esc(details.complaintType || item.type || "Complaint")}</div></div>
            ${revLoc ? `<div><small style="color: light-dark(#64748b, var(--textSecondary)); font-weight: 700; text-transform: uppercase; font-size: 11px;">Location</small><div style="color: light-dark(#0f172a, var(--textPrimary));">${esc(revLoc)}</div></div>` : ""}
          </div>
          ${revNarr ? `<div style="border-top: 1px solid light-dark(#e2e8f0, var(--border)); padding-top: 8px;"><small style="color: light-dark(#64748b, var(--textSecondary)); font-weight: 700; text-transform: uppercase; font-size: 11px;">What Happened</small><div style="color: light-dark(#334155, var(--textPrimary)); font-size: 13.5px; line-height: 1.5; white-space: pre-wrap;">${esc(revNarr)}</div></div>` : ""}
        </div>
        <p style="margin: 0; font-size: 14px; font-weight: 600; color: light-dark(#047857, var(--primaryGreen));">Start barangay review of this complaint and proceed to hearing scheduling?</p>
      `;
    }
    else {
      const prompts = { request_information: "Specific information the resident should provide", invalid: "Reason this complaint is invalid (prank, duplicate or unsupported filing)", resolve_outside_hearing: "Agreement summary confirmed outside a hearing", withdraw: "Reason for the resident’s confirmed withdrawal" };
      content = `${hearing && ["withdraw", "resolve_outside_hearing"].includes(action) ? '<p class="tracking-warning">This finishes the complaint and cancels the active appointment. The appointment remains in history.</p>' : ""}${reason(prompts[action] || "Reason")}`;
    }
    const saveLabels = {
      review: "Continue to Scheduling",
      schedule_hearing: "Save Hearing Schedule",
      schedule_another_hearing: "Save & Schedule Next Hearing",
      issue_cfa: "Issue Official CFA (KP Form 20)",
      edit_schedule: "Save Schedule Changes",
      record_result: "Save Hearing Result",
      hearing_not_held: "Save Why Hearing Was Not Held",
      request_information: "Send Information Request",
      invalid: "Mark Complaint Invalid",
      resolve_outside_hearing: "Save Agreement & Resolve",
      withdraw: "Confirm Withdrawal",
      confirm_tracking: "Save Confirmed Hearing Count",
      record_external_update: "Save Outside Update"
    };
    openModal("Complaint Tracking", title, `<form id="trackingForm" class="complaint-tracking-detail">${action === "record_result" ? "" : `<p class="tracking-form-context">Complaint ${esc(id)} · ${esc(residentName(item))}</p>`}${content}<p id="trackingError" class="tracking-error" role="alert" hidden></p></form>`, `<button type="button" class="button button--secondary" id="trackingCancel">Back to Complaint</button><button type="submit" form="trackingForm" class="button button--primary" id="trackingSave">${saveLabels[action] || "Save Update"}</button>`, 'modal-card--complaint-tracking');
    protectEdits?.();
    byId("trackingCancel").onclick = () => open(id);
    // Keep one operation ID for retries of this exact form submission.
    let operationId = crypto.randomUUID();
    let previousPayload = null;
    const expectedVersion = item.workflowVersion || 0;
    byId("trackingForm").onsubmit = async (event) => {
      event.preventDefault();
      if (pending || !event.currentTarget.reportValidity()) return;
      const payload = Object.fromEntries(new FormData(event.currentTarget));
      if (action === "confirm_tracking") payload.completedHearings = Number(payload.completedHearings);
      const signature = JSON.stringify(payload);
      if (previousPayload && signature !== previousPayload) operationId = crypto.randomUUID();
      previousPayload = signature;
      pending = true;
      byId("trackingSave").disabled = true;
      byId("trackingCancel").disabled = true;
      byId("trackingError").hidden = true;
      try {
        const response = await call({ submissionId: id, action, ...payload, expectedVersion, operationId });
        if (!response.data?.success) throw new Error("The update was not confirmed. Please retry.");
        saved(id, response.data);
        pending = false;
        open(id);
        render();
        toast("Complaint record saved.");
      } catch (error) {
        pending = false;
        if (!byId("trackingError")) { toast(`Update was not saved: ${error.message}`, true); return; }
        byId("trackingError").textContent = error.message || "Unable to save. Please retry.";
        byId("trackingError").hidden = false;
        byId("trackingSave").disabled = false;
        byId("trackingCancel").disabled = false;
      }
    };
  }
  return { render, open, pill };
}
