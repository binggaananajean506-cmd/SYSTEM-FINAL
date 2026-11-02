import tracking from "../functions/complaint_tracking.js";
import cfaForms from "../functions/cfa_forms.js";

const { TERMINAL, MAX_HEARINGS, trackingStatus, activeHearing, completedHearings, requiresTrackingConfirmation, manilaDate, startTime } = tracking;
function hearingLabel(number) {
  const n = Number(number) || 1;
  return `${n > 3 ? "Lupon" : "Barangay"} Hearing ${(n - 1) % 3 + 1} of 3`;
}
const outcomes = { settled: "Resolved", unsettled: "Closed — Unsettled", cfa_issued: "Closed — CFA Issued", invalid: "Invalid", withdrawn: "Withdrawn", dismissed: "Dismissed (previous record)", referred: "Closed — External referral recorded" };
const labels = { filed: "New", under_review: "In review", needs_information: "Waiting for resident", awaiting_next_schedule: "Needs a hearing date", awaiting_cfa: "CFA review", hearing_scheduled: "Hearing scheduled", resolved: "Resolved", settled: "Resolved", cfa_issued: "Closed — CFA Issued", unsettled: "Closed — Unsettled", closed: "Closed" };
export function complaintText(item) {
  const details = item.complaint || {};
  let narrative = String(item.description || "");
  const metadata = {};
  let match;
  while ((match = narrative.match(/^\s*\[(Problem|Location):\s*([^\]]*)\]\s*/i))) {
    metadata[match[1].toLowerCase()] = match[2].trim();
    narrative = narrative.slice(match[0].length);
  }
  const category = details.complaintType || item.type || "Complaint";
  return {
    narrative: narrative.trim(),
    location: String(details.location || item.location || metadata.location || details.respondentAddress || "").trim(),
    category: category.toLowerCase() === "other" && metadata.problem ? metadata.problem : category,
    respondent: String(details.respondentName || item.respondentName || details.respondentDescription || "Not specified"),
  };
}

export function complaintLabel(item, now = new Date()) {
  const status = trackingStatus(item);
  if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") return "CFA Issued (Closed)";
  if (TERMINAL.has(status)) return outcomes[item.closureOutcome] || outcomes[status] || labels[status] || (status === "rejected" ? "Invalid (previous record)" : "Closed");
  if (requiresTrackingConfirmation(item)) return "Check hearing record";
  if (status === "needs_information" || status === "awaiting_resident") return "Waiting for resident";
  const hearing = activeHearing(item);
  if (!hearing && completedHearings(item) >= MAX_HEARINGS) return "CFA review";
  if (hearing && now >= startTime(hearing)) return "Result needed";
  return labels[status] || status.replaceAll("_", " ");
}
export function complaintBucket(item, now = new Date()) {
  const status = trackingStatus(item);
  if (TERMINAL.has(status)) return "finished";
  if (status === "needs_information" || status === "awaiting_resident") return "needs_information";
  if (status === "filed" && !requiresTrackingConfirmation(item) && !activeHearing(item) && completedHearings(item) === 0) return "new";
  const hearing = activeHearing(item);
  if (hearing) return now >= startTime(hearing) ? "result_pending" : "scheduled";
  return "active";
}
export function complaintNextStep(item, now = new Date()) {
  const status = trackingStatus(item);
  if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") return { action: "view_cfa", label: "View / Print CFA", title: "Certificate to File Action Issued", help: "This complaint is officially closed. A Certificate to File Action (KP Form 20) was issued. The system will no longer record updates." };
  if (TERMINAL.has(status)) return { action: "view_record", label: "View Record", title: "Complaint Closed", help: "This complaint is completed and closed." };
  if (requiresTrackingConfirmation(item)) return { action: "confirm_tracking", label: "Check past hearings", title: "Check the previous hearing record", help: "Confirm which hearings were completed before continuing this older case.", step: 0 };
  if (status === "needs_information" || status === "awaiting_resident") return { action: "view_record", label: "Waiting for resident", title: "Waiting for resident", help: "The resident needs to reply to the information request below.", step: 0 };
  if (status === "filed") return { action: "review", label: "Review complaint", title: "Review this complaint", help: "Read the statement and evidence, then continue to the first hearing.", step: 0 };
  const hearing = activeHearing(item);
  if (hearing) {
    const hearingTitle = hearingLabel(hearing.number);
    if (now >= startTime(hearing)) return { action: "record_result", label: "Record Result", title: `${hearingTitle}: Record Result`, help: "The hearing schedule has arrived. Record the outcome below based on party attendance.", step: 4 };
    const summons = tracking.currentSummons(item);
    if (!summons) return { action: "issue_summons", label: "Prepare summons", title: "Prepare the summons", help: "Generate the official summons for this hearing.", step: 2 };
    if (summons.deliveryStatus !== "handed_to_tanod") return { action: "notify_summons", label: "Confirm given to tanod", title: "Give the summons to a tanod", help: "Print the summons and give it to a tanod. Then confirm below. The resident will get an update.", step: 3 };
    return { action: "view_record", label: "Wait for hearing", title: "Ready for the hearing", help: "The summons was given to a tanod. Add the hearing result after the scheduled hearing starts.", step: 4 };
  }
  const count = completedHearings(item);
  if (count >= MAX_HEARINGS) return { action: "issue_cfa", label: "Review CFA", title: "Review for CFA issuance", help: "All six rounds are recorded. Check the grounds and office records before issuing the certificate.", step: 4 };
  if (count > 0) return { action: "schedule_another_hearing", label: "Schedule next hearing", title: `Set ${hearingLabel(count + 1)}`, help: count === 3 ? "The three barangay rounds are complete. Continue to lupon conciliation." : "The previous round ended without settlement. Schedule the next hearing.", step: 1 };
  return { action: "issue_summons", label: "Set first hearing", title: "Set the first hearing", help: "Choose the hearing date, time and venue, then prepare the summons.", step: 1 };
}
export function complaintNeedsAction(item) {
  return ["review", "schedule_hearing", "schedule_another_hearing", "issue_summons", "notify_summons", "record_result", "issue_cfa", "confirm_tracking"].includes(complaintNextStep(item).action);
}
export function createComplaintTracking(deps) {
  const { items, find, byId, escape: esc, openModal, closeModal, toast, call, saved, residentName, formatDate, protectEdits, issueSummons, viewSummons, notifySummons, openCfa, openKasunduan, backgroundActions, canDelete = () => false, deleteComplaint } = deps;
  let filter = "active";
  let pending = false;
  let activeMenu = null;
  const closeRowMenu = () => {
    if (activeMenu?.matches(":popover-open")) activeMenu.hidePopover();
    activeMenu = null;
  };
  window.addEventListener("resize", closeRowMenu);
  window.addEventListener("scroll", event => {
    if (activeMenu && !activeMenu.contains(event.target)) closeRowMenu();
  }, true);
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
  function button(action, title, primary = false) {
    return '<button type="button" class="button ' + (primary ? 'button--primary' : 'button--secondary') + '" data-tracking-action="' + action + '">' + esc(title) + '</button>';
  }
  function matches(item, category) {
    if (category === "all") return true;
    const status = trackingStatus(item);
    const bucket = TERMINAL.has(status) ? "finished"
      : ["needs_information", "awaiting_resident"].includes(status) ? "needs_information"
      : requiresTrackingConfirmation(item) ? "active" : complaintBucket(item);
    return category === "active" ? ["active", "result_pending"].includes(bucket) : bucket === category;
  }
  function render() {
    const board = byId("complaintBoard");
    if (!board) return;
    closeRowMenu();
    const search = byId("complaintSearch");
    const clear = byId("complaintSearchClear");
    search.oninput = () => { clear.hidden = !search.value; render(); };
    clear.onclick = () => { search.value = ""; clear.hidden = true; render(); search.focus(); };
    document.querySelectorAll(".complaint-summary-card").forEach(tab => {
      tab.classList.toggle("active", tab.dataset.stage === filter);
      tab.classList.toggle("is-selected", tab.dataset.stage === filter);
      tab.setAttribute("aria-pressed", String(tab.dataset.stage === filter));
      tab.querySelector("b").textContent = items().filter(item => matches(item, tab.dataset.stage)).length;
      tab.onclick = () => { filter = tab.dataset.stage; render(); };
    });
    const query = search.value.trim().toLowerCase();
    const rows = items().filter(item => matches(item, filter)
      && [item.id, residentName(item), complaintText(item).respondent, complaintText(item).category, item.location, item.description].some(value => String(value || "").toLowerCase().includes(query)))
      .sort((a, b) => Number(complaintBucket(b) === "result_pending") - Number(complaintBucket(a) === "result_pending")
        || String(b.date?.toDate?.().toISOString() || b.date || "").localeCompare(String(a.date?.toDate?.().toISOString() || a.date || "")));
    const descriptions = {
      new: "Newly filed complaints waiting for their first review.",
      active: "Reviewed cases, hearing results and next steps that need your action.",
      scheduled: "Upcoming hearings. Open a case to prepare or print its summons.",
      needs_information: "Cases waiting for a reply from the resident.",
      finished: "Completed cases and their final documents.",
    };
    const summary = byId("complaintViewSummary");
    if (summary) summary.textContent = rows.length + (rows.length === 1 ? " case. " : " cases. ") + (query ? "Search results in this queue." : descriptions[filter] || "");
    board.classList.add("is-table-view");
    board.innerHTML = '<div class="tracking-table-scroll"><table class="complaint-reports-table"><thead><tr><th>Case</th><th>People</th><th>Complaint</th><th>Status</th><th>Next step</th><th></th></tr></thead><tbody>' +
      (rows.length ? rows.map(item => {
        const text = complaintText(item);
        const hearing = activeHearing(item);
        const task = complaintNextStep(item);
        return '<tr><td data-label="Case"><button type="button" class="tracking-reference" data-case-id="' + esc(item.id) + '">' + esc(item.id) + '</button><small class="case-filed-date">Filed ' + esc(formatDate(item.date)) + '</small></td>' +
          '<td data-label="People"><div class="case-party-cell"><span>From</span><strong>' + esc(residentName(item)) + '</strong></div><div class="case-party-cell"><span>Against</span><strong>' + esc(text.respondent) + '</strong></div></td>' +
          '<td data-label="Complaint">' + esc(text.category) + '</td><td data-label="Status">' + pill(item) + '</td>' +
          '<td data-label="Next step" class="case-next-cell"><strong>' + esc(task.label) + '</strong>' + (hearing ? '<small>' + esc(hearingLabel(hearing.number)) + '</small><small>' + esc(formatDate(startTime(hearing))) + '</small>' : '') + '</td>' +
          '<td data-label="Actions"><button type="button" class="complaint-menu-toggle" popovertarget="complaintActions_' + esc(item.id) + '" aria-label="Actions for complaint ' + esc(item.id) + '" aria-haspopup="menu" aria-expanded="false"><span class="material-symbols-rounded" aria-hidden="true">more_vert</span></button>' +
          '<div id="complaintActions_' + esc(item.id) + '" class="complaint-row-menu" popover="auto" role="menu" aria-label="Complaint ' + esc(item.id) + ' actions"><button type="button" role="menuitem" class="complaint-row-menu-item" data-case-id="' + esc(item.id) + '" aria-label="Open case ' + esc(item.id) + '"><span class="material-symbols-rounded" aria-hidden="true">folder_open</span>Open case</button>' +
          (canDelete(item) ? '<button type="button" role="menuitem" class="complaint-row-menu-item complaint-row-menu-item--delete" data-delete-case="' + esc(item.id) + '" aria-label="Delete complaint ' + esc(item.id) + '"><span class="material-symbols-rounded" aria-hidden="true">delete</span>Delete</button>' : '') + '</div></td></tr>';
      }).join("") : '<tr class="case-empty-row"><td colspan="6" class="tracking-empty"><strong>' + (query ? "No cases found." : filter === "active" ? "No cases need action." : "No cases in this queue.") + '</strong><p>' + (query ? "Try another name or case number, clear the search, or choose a different queue." : filter === "active" ? "Use Hearings to see upcoming appointments, or choose another queue." : "Choose another queue to see more cases.") + '</p></td></tr>') +
      '</tbody></table></div>';
    board.querySelectorAll("[data-case-id]").forEach(node => { node.onclick = () => open(node.dataset.caseId); });
    board.querySelectorAll("[data-delete-case]").forEach(node => { node.onclick = () => { closeRowMenu(); deleteComplaint(node.dataset.deleteCase); }; });
    board.querySelectorAll(".complaint-menu-toggle").forEach(toggle => {
      const menu = byId(toggle.getAttribute("popovertarget"));
      menu.addEventListener("toggle", event => {
        const expanded = event.newState === "open";
        toggle.setAttribute("aria-expanded", String(expanded));
        if (!expanded) { if (activeMenu === menu) activeMenu = null; return; }
        activeMenu = menu;
        const anchor = toggle.getBoundingClientRect();
        const bounds = menu.getBoundingClientRect();
        const top = anchor.bottom + 6 + bounds.height <= window.innerHeight - 8 ? anchor.bottom + 6 : anchor.top - bounds.height - 6;
        menu.style.left = Math.max(8, Math.min(anchor.right - bounds.width, window.innerWidth - bounds.width - 8)) + "px";
        menu.style.top = Math.max(8, Math.min(top, window.innerHeight - bounds.height - 8)) + "px";
        menu.querySelector("button")?.focus({ preventScroll: true });
      });
      menu.addEventListener("keydown", event => {
        const entries = [...menu.querySelectorAll("button")];
        const index = entries.indexOf(document.activeElement);
        const target = event.key === "ArrowDown" ? (index + 1) % entries.length : event.key === "ArrowUp" ? (index - 1 + entries.length) % entries.length : event.key === "Home" ? 0 : event.key === "End" ? entries.length - 1 : -1;
        if (target >= 0) { event.preventDefault(); entries[target].focus(); }
      });
      menu.addEventListener("focusout", event => {
        if (event.relatedTarget && !menu.contains(event.relatedTarget) && event.relatedTarget !== toggle) closeRowMenu();
      });
    });
  }
  function open(id) {
    closeRowMenu();
    const item = find(id);
    if (!item) return;
    const now = new Date();
    const status = trackingStatus(item);
    const finished = TERMINAL.has(status);
    const legacy = requiresTrackingConfirmation(item);
    const hearing = activeHearing(item);
    const summons = tracking.currentSummons(item);
    const details = item.complaint || {};
    const text = complaintText(item);
    const next = complaintNextStep(item, now);
    const due = !finished && !legacy && hearing && now >= startTime(hearing);
    const waiting = ["needs_information", "awaiting_resident"].includes(status);
    const utilities = [];
    const exceptions = [];
    const addUtility = (action, label) => utilities.push(button(action, label));
    let primary = "";
    if (finished) {
      if (status === "cfa_issued" || item.closureOutcome === "cfa_issued") primary = button("view_cfa", "View / print CFA", true);
      else if (["settled", "resolved"].includes(status)) primary = button("view_kasunduan", "View / print agreement", true);
    } else if (legacy) primary = button("confirm_tracking", "Check past hearings", true);
    else if (!waiting && !due && next.action !== "view_record") primary = button(next.action, next.action === "review" ? "Review complaint" : next.label, true);
    if (!finished && !legacy && !due && hearing) {
      if (manilaDate(now) < hearing.date) addUtility("edit_schedule", "Change schedule");
      else addUtility("hearing_not_held", "Hearing not held");
    }
    if (!legacy && item.summons) addUtility("view_summons", summons ? "View / print summons" : "View previous summons");
    if (!finished && !legacy && !hearing && completedHearings(item) === 0) {
      exceptions.push(button("request_information", waiting ? "Update information request" : "Ask resident for information"));
      exceptions.push(button("invalid", "Mark invalid"));
    }
    const attendanceButtons = due ? '<div class="tracking-actions case-main-action">' + button("record_result", "Record result", true) + '</div>' : "";
    const history = (item.statusHistory || []).filter(event => event.visibility !== "internal");
    const statement = text.narrative || "No statement provided.";
    const statementHtml = statement.length > 380
      ? '<details class="case-long-statement"><summary>' + esc(statement.slice(0, 240)) + '… <span>Read full statement</span></summary><p class="tracking-text">' + esc(statement) + '</p></details>'
      : '<p class="tracking-text case-statement">' + esc(statement) + '</p>';
    const hearingSummary = hearing ? '<div class="case-hearing-summary tracking-schedule-panel"><strong>' + esc(hearingLabel(hearing.number)) + '</strong><span>' + esc(formatDate(startTime(hearing))) + '</span><span>' + esc(hearing.venue || "Venue not recorded") + '</span>' +
      (hearing.officerName ? '<span>Official: ' + esc(hearing.officerName) + '</span>' : '') + '</div>' : "";
    const conclusion = finished ? '<section class="case-conclusion' + (status === "cfa_issued" || item.closureOutcome === "cfa_issued" ? ' tracking-panel--cfa' : '') + '"><h3>Case closed</h3><p class="tracking-text">' +
      esc(item.resolutionSummary || item.settlement?.agreementTerms || item.unsettledRecord?.remarks || item.handlingNote || "See the case history for the recorded conclusion.") + '</p>' +
      (item.cfaReason ? '<p><strong>CFA grounds:</strong> ' + esc(item.cfaReason) + '</p>' : '') + '</section>' : "";
    const body = '<div class="complaint-tracking-detail complaint-case-view">' +
      '<div class="case-status-line">' + pill(item) + '<span>' + esc(text.category) + '</span></div>' +
      '<dl class="case-parties"><div><dt>Complainant <small>Filed by</small></dt><dd>' + esc(residentName(item)) + '</dd></div><div><dt>Respondent <small>Complaint against</small></dt><dd>' + esc(text.respondent) + '</dd></div></dl>' +
      '<section class="case-statement-section"><h3>What happened</h3>' + statementHtml +
        (text.location ? '<p class="case-location"><span class="material-symbols-rounded" aria-hidden="true">location_on</span>' + esc(text.location) + '</p>' : '') + '</section>' +
      '<section class="tracking-next-step case-next-action" aria-labelledby="trackingNextTitle"><div class="tracking-next-header"><span class="tracking-next-caption">' + (finished ? "FINAL RECORD" : waiting ? "WAITING FOR A REPLY" : "NEXT STEP") + '</span><h3 id="trackingNextTitle">' + esc(due ? "Record what happened at the hearing" : next.title) + '</h3>' +
      '<p>' + esc(due ? (hearing.number < MAX_HEARINGS ? "Record whether the case was settled. If not, you can set the next hearing." : "Record whether the case was settled. If not, review the case for CFA.") : next.help) + '</p></div>' +
      hearingSummary + (waiting ? '<p class="case-request-message"><strong>Information requested:</strong> ' + esc(item.requestedInfoMessage || "See the latest request in the case history.") + '</p>' : '') +
      (legacy ? '<p class="case-record-note">Check the barangay records before confirming completed hearings.</p>' : '') +
      attendanceButtons + (primary ? '<div class="tracking-actions case-main-action">' + primary + '</div>' : '') +
      (utilities.length ? '<div class="case-utility-actions">' + utilities.join("") + '</div>' : '') + '</section>' +
      conclusion +
      (exceptions.length ? '<details class="case-secondary-actions"><summary>Other actions</summary><div class="tracking-actions">' + exceptions.join("") + '</div></details>' : '') +
      '<details class="case-record-section"><summary>Case details' + (item.attachmentUrl || details.attachmentUrl ? ' & attachment' : '') + '</summary><dl class="case-facts">' +
        '<div><dt>Case number</dt><dd>' + esc(item.id) + '</dd></div><div><dt>Filed</dt><dd>' + esc(formatDate(item.date)) + '</dd></div>' +
        '<div><dt>Incident date</dt><dd>' + esc(item.incidentDate || "Not specified") + '</dd></div><div><dt>Location</dt><dd>' + esc(text.location || "Not specified") + '</dd></div>' +
        (details.desiredOutcome || item.requestedAction ? '<div><dt>Requested outcome</dt><dd>' + esc(details.desiredOutcome || item.requestedAction) + '</dd></div>' : '') +
        (details.witnesses ? '<div><dt>Witnesses</dt><dd>' + esc(details.witnesses) + '</dd></div>' : '') + '</dl>' + evidence(item.attachmentUrl || details.attachmentUrl) + '</details>' +
      '<details class="case-record-section"><summary>Hearings & case history</summary><p class="tracking-hearing-count">' + completedHearings(item) + ' of ' + MAX_HEARINGS + ' recorded · 3 barangay rounds, then 3 lupon rounds if needed.</p>' +
      ((item.hearings || []).map(h => '<article class="tracking-event"><strong>' + esc(hearingLabel(h.number)) + ' · ' + esc(String(h.status || "recorded").replaceAll("_", " ")) + '</strong><p>' + esc(h.date) + ' · ' + esc(h.time) + ' · ' + esc(h.venue) + '</p><p class="tracking-text">' + esc(h.summary || h.reason || h.cancellationReason || h.notes || "") + '</p>' +
        (h.complainantAttendance ? '<small>Attendance: complainant ' + esc(h.complainantAttendance) + ', respondent ' + esc(h.respondentAttendance || "not recorded") + '</small>' : '') +
        (h.scheduleChanges || []).map(change => '<small>Previous schedule: ' + esc(change.previous?.date || "") + ' ' + esc(change.previous?.time || "") + ' · ' + esc(change.reason) + '</small>').join("") + '</article>').join("")) +
      '<h4>Activity</h4><ol class="tracking-timeline">' + (history.map(event => '<li><strong>' + esc(event.label || labels[event.newStatus || event.status] || event.action?.replaceAll("_", " ") || "Update") + '</strong><small>' + esc(formatDate(event.date || event.performedAt || event.updatedAt)) + (event.actorName ? ' · ' + esc(event.actorName) : '') + '</small><p class="tracking-text">' + esc(event.note || event.remarks || event.reason || "") + '</p>' +
        (event.action === "record_external_update" ? '<small>' + esc(event.details?.type || "External event") + ' · ' + esc(event.details?.date || "") + ' · ' + esc(event.details?.reference || "No reference") + '</small>' : '') + '</li>').join("") || '<li>No activity recorded yet.</li>') + '</ol></details>' +
      '<details class="case-record-section"><summary>Original submission' + ((item.submissionRevisions || []).length ? ' & revisions' : '') + '</summary><p class="tracking-text">' + esc(item.originalSubmission?.description || item.description || "No statement provided.") + '</p>' +
      (item.submissionRevisions || []).map(revision => '<article class="tracking-event"><small>Revised ' + esc(formatDate(revision.revisedAt)) + '</small><p class="tracking-text">' + esc(revision.description) + '</p></article>').join("") + '</details></div>';
    openModal("Complaint", id, body, (canDelete(item) ? '<button type="button" class="button button--danger" id="trackingDelete">Delete complaint</button>' : '') + '<button type="button" class="button button--secondary" id="trackingClose">Back to complaints</button>', 'modal-card--complaint-tracking');
    byId("trackingClose").onclick = closeModal;
    if (byId("trackingDelete")) byId("trackingDelete").onclick = () => deleteComplaint(id);
    byId("modalBody").querySelectorAll("[data-tracking-action]").forEach(node => { node.onclick = () => run(id, node.dataset.trackingAction); });
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
      schedule_another_hearing: hearing ? "Schedule Another Hearing (Non-Attendance)" : "Schedule Next Hearing",
      issue_cfa: "Issue Certificate to File Action",
      record_result: "Record result",
      review: "Review complaint",
      confirm_tracking: "Confirm Previous Hearings",
      request_information: "Ask for More Information",
      invalid: "Mark Complaint Invalid"
    };
    let title = titles[action] || tracking.ACTION_LABELS[action] || "Update Complaint";
    const d = new Date();
    d.setDate(d.getDate() + 3);
    const defDate = d.toISOString().slice(0, 10);
    const scheduleFields = (optional = false) => `<div class="tracking-form-grid">${field("date", optional ? "Current hearing date (optional)" : "Hearing date", "date", action === "edit_schedule" ? hearing?.date || "" : action === "schedule_another_hearing" ? "" : defDate, !optional)}${field("time", "Time (Philippine time)", "time", action === "edit_schedule" ? hearing?.time || "" : action === "schedule_another_hearing" ? "" : "09:00", !optional)}${field("venue", "Venue", "text", hearing?.venue || "Barangay Hall", !optional)}${field("officerName", "Assigned official (optional)", "text", hearing?.officerName || "", false)}</div><p class="tracking-form-context">Choose a future date and time in the Philippines (UTC+8). This is the new appointment, not the hearing being recorded.</p><label class="tracking-field">Schedule notes (optional)<textarea name="notes" maxlength="1000">${esc(hearing?.notes || "")}</textarea></label>`;
    if (action === "schedule_another_hearing") {
      const nextNum = (hearing?.number || completedHearings(item)) + 1;
      content = `
        <div class="summons-simple-banner" style="border-left: 4px solid light-dark(#f59e0b, var(--warningBorder)); background: light-dark(#fffbeb, var(--warningSurface)); border-radius: 8px; padding: 12px 14px; margin-bottom: 16px;">
          <strong style="color: light-dark(#b45309, var(--warning)); display: block; margin-bottom: 4px; font-size: 14px;">${nextNum === 4 ? "Continue to Lupon Conciliation" : "Next Hearing"}</strong>
          <p style="margin: 0; font-size: 13px; color: light-dark(#78350f, var(--warning)); line-height: 1.5;">
            ${hearing ? "Record who attended, then set the next hearing." : "The previous result is saved. Set the next hearing."} Next: ${hearingLabel(nextNum)}.
          </p>
        </div>
        ${hearing ? `${attendance("complainantAttendance", "Complainant attendance")}${attendance("respondentAttendance", "Respondent attendance")}${reason("Non-attendance notes", "reason")}` : ""}
        <hr style="border: 0; border-top: 1px solid light-dark(#e2e8f0, var(--border)); margin: 16px 0;">
        <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 700; color: light-dark(#0f172a, var(--textPrimary));">${hearingLabel(nextNum)}</h4>
        ${scheduleFields()}
      `;
    } else if (action === "issue_cfa") {
      const options = cfaForms.cfaOptions(item);
      const possible = options.filter(option => option.available);
      content = `
        <div class="summons-simple-banner" style="border-left: 4px solid light-dark(#b52d38, var(--error)); background: light-dark(#fef2f2, var(--errorSurface)); border-radius: 8px; padding: 12px 14px; margin-bottom: 16px;">
          <strong style="color: light-dark(#991b1b, var(--error)); display: block; margin-bottom: 4px; font-size: 14px;">Choose the correct Certificate to File Action</strong>
          <p style="margin: 0; font-size: 13px; color: light-dark(#7f1d1d, var(--error)); line-height: 1.5;">
            All six rounds are recorded. Check the case records, choose the correct form, and confirm the grounds. Issuing it closes the case.
          </p>
        </div>
        <label class="tracking-field">CFA form<select name="cfaForm" required><option value="">Choose a form</option>${options.map(option => `<option value="${option.form}" ${option.available ? "" : "disabled"}>KP Form ${option.form} — ${option.label}${option.available ? "" : " (check hearing records)"}</option>`).join("")}</select></label>
        ${!possible.length ? '<p class="tracking-error">The hearing records do not support either form yet. Check the attendance and results before issuing a certificate.</p>' : ''}
        <p id="cfaFormExplanation" class="tracking-form-context">20-A: both parties met but did not agree. 20-B: the respondent did not attend without a valid reason, after proper notice.</p>
        <label id="cfaOfficeRecordsField" class="tracking-choice" hidden><input type="checkbox" name="confirmOfficeRecords" value="true"><span>I checked the paper records for any missing attendance and results. They support the selected form.</span></label>
        <label id="cfaAbsenceField" class="tracking-choice" hidden><input type="checkbox" name="confirmUnjustifiedAbsence" value="true"><span>The office checked that the respondent had proper notice, the Pangkat proceedings were arranged, and the respondent willfully failed or refused to attend without a valid reason.</span></label>
        ${reason("Reason for this certificate", "reason")}
        <div class="tracking-form-grid">${field("pangkatSecretaryName", "Pangkat secretary name (optional)", "text", "", false)}${field("pangkatChairName", "Pangkat chairperson name (optional)", "text", "", false)}</div>
        <label class="tracking-choice"><input type="checkbox" required name="confirmEligibility" value="true"><span>The office checked the required steps, Pangkat records and grounds for this certificate.</span></label>
      `;
    } else if (["schedule_hearing", "edit_schedule"].includes(action)) {
      content = `<p>${hearingLabel(hearing?.number || completedHearings(item) + 1)}. After scheduling, generate the summons.</p>${scheduleFields()}${action === "edit_schedule" ? reason("Reason for change") : ""}`;
    } else if (action === "record_result") {
      content = `
        <div class="hearing-result-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span class="hearing-result-badge">${hearingLabel(hearing.number)}</span>
            <span class="hearing-result-case">${esc(id)} · ${esc(residentName(item))}</span>
          </div>
          ${hearing.number === 3 ? `<span class="hearing-result-note">Last barangay round · If unsettled, continue to Lupon Hearing 1 of 3</span>` : hearing.number === MAX_HEARINGS ? `<span class="hearing-result-note">Last lupon round · If unsettled, proceed to CFA review</span>` : ""}
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
                  <small>Both parties agreed. Close this case.</small>
                </div>
              </div>
            </label>
            <label class="hearing-outcome-card hearing-outcome-card--unsettled">
              <input type="radio" required name="outcome" value="no_agreement">
              <div class="hearing-outcome-content">
                <span class="material-symbols-rounded">cancel</span>
                <div>
                  <strong>Not settled</strong>
                  <small>${hearing.number < MAX_HEARINGS ? "Set another hearing after saving." : "Review for CFA after saving."}</small>
                </div>
              </div>
            </label>
          </div>
        </div>
        <div class="hearing-result-section">
          <label class="hearing-result-section-label">Who attended?</label>
          <p class="tracking-form-context">Uncheck anyone who did not attend. Both parties must have attended to mark the case settled.</p>
          <div class="hearing-attendance-grid">
            <label class="hearing-attendance-chip">
              <input type="checkbox" name="complainantAttendance" value="present" checked>
              <span class="material-symbols-rounded">person_check</span>
              <span>Complainant Attended</span>
            </label>
            <label class="hearing-attendance-chip">
              <input type="checkbox" name="respondentAttendance" value="present" checked>
              <span class="material-symbols-rounded">person_check</span>
              <span>Respondent Attended</span>
            </label>
          </div>
        </div>
        <div class="hearing-result-section" style="margin-bottom: 0;">
          <label class="hearing-result-section-label" for="hearingSummaryInput">Agreement or notes</label>
          <textarea id="hearingSummaryInput" name="summary" required minlength="3" maxlength="1000" rows="3" class="hearing-result-textarea" placeholder="Write the agreement, or why the case was not settled."></textarea>
        </div>
      `;
    } else if (action === "record_nonattendance") {
      content = `<p>${hearingLabel(hearing.number)}. Record actual attendance and the reason no settlement was reached. CFA issuance remains a separate step.</p>${attendance("complainantAttendance", "Complainant attendance")}${attendance("respondentAttendance", "Respondent attendance")}${reason("Non-attendance notes")}`;
    } else if (action === "hearing_not_held") {
      content = `<p>The original appointment stays in history. A replacement uses hearing ${hearing.number} again.</p>${attendance("complainantAttendance", "Complainant attendance")}${attendance("respondentAttendance", "Respondent attendance")}${reason("Reason the hearing was not held")}`;
    } else if (action === "confirm_tracking") {
      content = `<p>Check the offline records for the 3 barangay and 3 lupon rounds. Regenerated summons do not add rounds. Enter an appointment only if confirmed, and leave it blank after six rounds.</p><label class="tracking-field">Recorded rounds<select required name="completedHearings"><option value="">Choose confirmed count</option>${Array.from({ length: MAX_HEARINGS + 1 }, (_, n) => `<option value="${n}">${n}${n === 3 ? " — Continue to Lupon" : n === 6 ? " — Record final conclusion" : ""}</option>`).join("")}</select></label><label class="tracking-field">Final outcome (only for 6 recorded rounds)<select name="outcome"><option value="">Not applicable</option><option value="settled">Resolved</option><option value="unsettled">Unsettled — CFA pending</option></select></label><label class="tracking-field">Final conclusion (required for 6 recorded rounds)<textarea name="summary" maxlength="1000"></textarea></label>${reason("Basis for confirmation")}${scheduleFields(true)}`;
    } else if (action === "record_external_update") {
      content = `<p>Record an event that already occurred outside the app. This does not create or issue any document.</p>${field("type", "Event (for example, CFA issued outside the app)")}${field("date", "Actual event date", "date")}${field("reference", "Document reference (optional)", "text", "", false)}${reason("External update notes")}`;
    } else if (action === "review") {
      const reviewText = complaintText(item);
      content = '<section class="case-review-confirmation"><h3>Review the complaint</h3><p class="tracking-text">' + esc(reviewText.narrative || "No statement provided.") + '</p>' +
        '<p>Continue to accept this case for review and prepare its first hearing. Set the date, venue and summons on the next screen.</p></section>';
    }
    else {
      const prompts = { request_information: "Specific information the resident should provide", invalid: "Reason this complaint is invalid (prank, duplicate or unsupported filing)", resolve_outside_hearing: "Agreement summary confirmed outside a hearing", withdraw: "Reason for the resident’s confirmed withdrawal" };
      content = `${hearing && ["withdraw", "resolve_outside_hearing"].includes(action) ? '<p class="tracking-warning">This finishes the complaint and cancels the active appointment. The appointment remains in history.</p>' : ""}${reason(prompts[action] || "Reason")}`;
    }
    const saveLabels = {
      review: "Continue to hearing setup",
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
    openModal("Complaint update", title, `<form id="trackingForm" class="complaint-tracking-detail">${action === "record_result" ? "" : `<p class="tracking-form-context">${esc(id)} · ${esc(residentName(item))}</p>`}${content}<p id="trackingError" class="tracking-error" role="alert" hidden></p></form>`, `<button type="button" class="button button--secondary" id="trackingCancel">Back to case</button><button type="submit" form="trackingForm" class="button button--primary" id="trackingSave">${saveLabels[action] || "Save Update"}</button>`, 'modal-card--complaint-tracking');
    protectEdits?.();
    if (action === "record_result") {
      const syncResult = () => {
        const settled = byId("trackingForm").elements.namedItem("outcome").value === "settled";
        for (const name of ["complainantAttendance", "respondentAttendance"]) byId("trackingForm").elements.namedItem(name).required = settled;
        byId("trackingSave").textContent = settled ? "Save and close case" : "Save result";
      };
      byId("trackingForm").addEventListener("change", syncResult); syncResult();
    }
    if (action === "issue_cfa") {
      const select = byId("trackingForm").elements.namedItem("cfaForm");
      const syncCfa = () => {
        const option = cfaForms.cfaOptions(item).find(option => option.form === select.value);
        byId("cfaAbsenceField").hidden = select.value !== "20-B";
        byId("trackingForm").elements.namedItem("confirmUnjustifiedAbsence").required = select.value === "20-B";
        byId("cfaOfficeRecordsField").hidden = !option?.needsOfficeRecords;
        byId("trackingForm").elements.namedItem("confirmOfficeRecords").required = !!option?.needsOfficeRecords;
      };
      select.addEventListener("change", syncCfa); syncCfa();
    }
    byId("trackingCancel").onclick = () => open(id);
    const needsFutureSchedule = ["schedule_another_hearing", "schedule_hearing", "edit_schedule"].includes(action);
    if (needsFutureSchedule) {
      byId("trackingForm").elements.namedItem("date").min = manilaDate(new Date());
      byId("trackingForm").addEventListener("input", () => { byId("trackingError").hidden = true; });
    }
    // Keep one operation ID for retries of this exact form submission.
    let operationId = crypto.randomUUID();
    let previousPayload = null;
    const expectedVersion = item.workflowVersion || 0;
    byId("trackingForm").onsubmit = async (event) => {
      event.preventDefault();
      if (pending || !event.currentTarget.reportValidity()) return;
      if (backgroundActions.isActive(`complaint:${id}`)) { toast("This complaint already has an update in progress."); return; }
      const payload = Object.fromEntries(new FormData(event.currentTarget));
      let submissionAction = action;
      if (action === "record_result") {
        for (const name of ["complainantAttendance", "respondentAttendance"]) payload[name] = event.currentTarget.elements.namedItem(name).checked ? "present" : "absent";
        if (payload.outcome === "no_agreement" && [payload.complainantAttendance, payload.respondentAttendance].includes("absent")) {
          submissionAction = "record_nonattendance";
          payload.reason = payload.summary;
        }
      }
      if (needsFutureSchedule && (!tracking.validDate(payload.date) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.time || "") || startTime(payload) <= new Date())) {
        byId("trackingError").textContent = "Choose a future hearing date and time (Philippine time). Your attendance entries have been kept.";
        byId("trackingError").hidden = false;
        event.currentTarget.elements.namedItem("time").focus();
        return;
      }
      if (action === "confirm_tracking") payload.completedHearings = Number(payload.completedHearings);
      if (action === "issue_cfa") payload.confirmEligibility = payload.confirmEligibility === "true";
      if (action === "issue_cfa") {
        payload.confirmOfficeRecords = payload.confirmOfficeRecords === "true";
        payload.confirmUnjustifiedAbsence = payload.confirmUnjustifiedAbsence === "true";
      }
      const signature = JSON.stringify(payload);
      if (previousPayload && signature !== previousPayload) operationId = crypto.randomUUID();
      previousPayload = signature;
      const request = { submissionId: id, action: submissionAction, ...payload, expectedVersion, operationId };
      const nextHearing = action === "record_result" && payload.outcome === "no_agreement";
      const started = backgroundActions.start({
        key: `complaint:${id}`, title: "Saving complaint update", context: id, success: "Complaint update saved", retry: true,
        action: { label: action === "review" ? "Set hearing" : nextHearing ? (hearing.number < MAX_HEARINGS ? "Schedule next hearing" : "Review CFA") : "View case",
          run: () => action === "review" ? issueSummons(id) : nextHearing ? form(id, hearing.number < MAX_HEARINGS ? "schedule_another_hearing" : "issue_cfa") : open(id) },
        recover: () => {
          form(id, action);
          for (const [name, value] of Object.entries(payload)) {
            const field = byId("trackingForm").elements.namedItem(name);
            if (field?.type === "checkbox") field.checked = value === true || value === "true" || value === field.value;
            else if (field) field.value = value;
          }
          byId("trackingForm").elements.namedItem("cfaForm")?.dispatchEvent(new Event("change"));
          if (action === "record_result") byId("trackingForm").dispatchEvent(new Event("change"));
          return true;
        },
        run: async (progress, isCurrent) => {
          if (!isCurrent()) throw new Error("Sign in with the account that started this update.");
          progress("Saving complaint record…");
          const response = await call(request);
          if (!response.data?.success) throw new Error("The update was not confirmed. Please retry.");
          if (isCurrent()) { saved(id, response.data); render(); }
        },
      });
      if (started) closeModal(true);
    };
  }
  return { render, open, pill };
}
