const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require("./helpers/admin-session");
const { planTrackingUpdate } = require("../../functions/complaint_tracking");
const samples = [
  { id: "BC-2026-100001", kind: "complaint", complaintTrackingVersion: 1, workflowVersion: 0,
    residentName: "Maria Clara", type: "Noise", description: "Loud music every evening.", date: "2026-10-08T01:00:00Z", status: "filed", hearings: [],
    complaint: { respondentName: "Juan Dela Cruz", respondentAddress: "Sitio Riverside" } },
  { id: "BC-2026-100002", kind: "complaint", complaintTrackingVersion: 1, workflowVersion: 2,
    residentName: "Christian Perez", type: "Boundary", description: "Boundary dispute.", date: "2026-10-07T01:00:00Z", status: "hearing_scheduled",
    complaint: { respondentName: "Waels Santos" }, hearings: [{ id: "h1", number: 1, status: "scheduled", date: "2026-10-11", time: "09:00", venue: "Barangay Hall" }] },
  { id: "BC-2026-100003", kind: "complaint", complaintTrackingVersion: 1, workflowVersion: 6,
    residentName: "Pedro Santos", type: "Debt", description: "Debt remains unpaid.", date: "2026-10-06T01:00:00Z", status: "hearing_scheduled",
    complaint: { respondentName: "Ana Cruz" }, legacyCompletedHearings: 2,
    hearings: [{ id: "h3", number: 3, status: "scheduled", date: "2026-10-09", time: "09:00", venue: "Barangay Hall" }] },
  { id: "BC-2026-100004", kind: "complaint", complaintTrackingVersion: 1, workflowVersion: 7,
    residentName: "Carlo Reyes", type: "Noise", date: "2026-10-05T01:00:00Z", status: "closed", closureOutcome: "unsettled", resolutionSummary: "No agreement was reached.", hearings: [] },
];
async function openPage(page, records = samples) {
  await page.clock.setFixedTime(new Date("2026-10-10T04:00:00Z"));
  await loadAdminSession(page, "barangay_captain");
  await page.evaluate(records => { window.__adminSession.state.complaints = records; }, records);
  await page.locator('.nav-link[data-page="complaints"]').click();
  await page.locator('.complaint-header-actions').hover();
}
const tab = (page, stage) => page.locator('.complaint-summary-card[data-stage="' + stage + '"]');
const row = (page, id) => page.locator('.complaint-reports-table tbody tr').filter({ hasText: id });
test("table prioritizes action, separates pending and finished, and searches parties", async ({ page }) => {
  await openPage(page);
  await expect(page.locator('.complaint-reports-table thead th')).toHaveCount(6);
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(3);
  await expect(row(page, "100001")).toContainText("View");
  await tab(page, "scheduled").click();
  await expect(row(page, "100002")).toContainText("Hearing 1 of 3");
  await tab(page, "result_pending").click();
  await expect(row(page, "100003")).toContainText("View");
  await tab(page, "finished").click();
  await expect(row(page, "100004")).toContainText("Closed — Unsettled");
  await tab(page, "active").click();
  await expect(tab(page, "active")).toHaveCSS("color", "rgb(255, 255, 255)");
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(3);
  await page.locator('#complaintSearch').fill("Maria");
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(1);
  await page.locator('#complaintSearchClear').click();
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(3);
});
test("future schedules can be edited but same-day schedules are locked before start", async ({ page }) => {
  const today = structuredClone(samples[1]); today.hearings[0].date = "2026-10-10"; today.hearings[0].time = "14:00";
  await openPage(page, [samples[1], { ...today, id: "BC-2026-100005" }]);
  await tab(page, "scheduled").click();
  await row(page, "100002").locator('button').first().click();
  await expect(page.locator('[data-tracking-action="edit_schedule"]')).toBeVisible();
  await expect(page.locator('[data-tracking-action="record_result"]')).toHaveCount(0);
  await page.locator('#trackingClose').click();
  await row(page, "100005").locator('button').first().click();
  await expect(page.locator('[data-tracking-action="edit_schedule"]')).toHaveCount(0);
  await expect(page.locator('[data-tracking-action="record_result"]')).toHaveCount(0);
  await expect(page.locator('[data-tracking-action="hearing_not_held"]')).toBeVisible();
});
test("failed saves retain the original record and show a retryable error", async ({ page }) => {
  await openPage(page);
  let posted;
  await page.route('**/advanceComplaintWorkflow', async route => {
    posted = route.request().postDataJSON().data;
    await route.fulfill({ status: 403, contentType: "application/json", body: JSON.stringify({ error: { status: "PERMISSION_DENIED", message: "Update rejected by the server." } }) });
  });
  await row(page, "100001").locator('button').last().click();
  await page.locator('[data-tracking-action="review"]').click();
  await page.locator('#trackingSave').click();
  await expect(page.locator('#trackingError')).toContainText("Update rejected");
  await expect(page.locator('#trackingSave')).toBeEnabled();
  expect(posted.action).toBe("review"); expect(posted.expectedVersion).toBe(0);
  expect(posted.operationId).toMatch(/^[a-z0-9-]{36}$/);
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].status)).toBe("filed");
});
test("third hearing records a conclusion and displays closed-unsettled without documents", async ({ page }) => {
  await openPage(page);
  let posted;
  await page.route('**/advanceComplaintWorkflow', async route => {
    posted = route.request().postDataJSON().data;
    const update = { status: "closed", closureOutcome: "unsettled", workflowVersion: 7, resolutionSummary: posted.summary,
      hearings: [{ ...samples[2].hearings[0], status: "completed", outcome: "no_agreement", summary: posted.summary }] };
    const event = { action: "record_result", label: "Closed — Unsettled", status: "closed", note: posted.summary, date: "2026-10-10T04:00:00Z" };
    await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: { success: true, workflowVersion: 7, update, event } }) });
  });
  await tab(page, "result_pending").click();
  await row(page, "100003").locator('button').last().click();
  await page.locator('[data-tracking-action="record_result"]').click();
  await expect(page.locator('#trackingForm')).toContainText("No agreement closes the tracking record as unsettled");
  await page.locator('[name="outcome"][value="no_agreement"]').check();
  await page.locator('[name="complainantAttendance"]').check();
  await page.locator('[name="respondentAttendance"]').check();
  await page.locator('[name="summary"]').fill("Both parties attended. No agreement was reached about repayment.");
  await page.locator('#trackingSave').click();
  await expect(page.locator('#modalBody')).toContainText("Closed — Unsettled");
  await expect(page.locator('[data-tracking-action="schedule_hearing"]')).toHaveCount(0);
  await expect(page.locator('.tracking-other-actions')).toHaveCount(0);
  await expect(page.locator('#officialSummonsModalOverlay')).toBeHidden();
  expect(posted.summary).toContain("Both parties attended");
  expect(posted.action).toBe("record_result");
});
test("legacy records require confirmation instead of inferring hearings from summons", async ({ page }) => {
  const old = { ...samples[1], complaintTrackingVersion: 0, status: "being_handled", hearings: [], summons: { summonsCount: 3, appearanceDate: "October 11, 2026" } };
  await openPage(page, [old]);
  await expect(row(page, "100002").locator('button').last()).toHaveText("View");
  await row(page, "100002").locator('button').first().click();
  await expect(page.locator('[data-tracking-action="confirm_tracking"]')).toBeVisible();
  await expect(page.locator('[data-tracking-action="schedule_hearing"]')).toHaveCount(0);
  await expect(page.locator('#modalBody')).toContainText("Previous schedules cannot establish");
  await page.locator('[data-tracking-action="confirm_tracking"]').click();
  await expect(page.locator('[name="completedHearings"]')).toHaveValue("");
});

test("existing official summons form prints and sends a confirmed tanod handoff notice", async ({ page }) => {
  let record = structuredClone({ ...samples[1], barangay: "Vito", barangayId: "vito" });
  const posted = [];
  await openPage(page, [record]);
  await page.route('**/advanceComplaintWorkflow', async route => {
    const input = route.request().postDataJSON().data;
    posted.push(input);
    const plan = planTrackingUpdate(record, input, new Date("2026-10-10T04:00:00Z"), { id: "official", name: "Captain Cruz", role: "barangay_captain" });
    record = { ...record, ...plan.update };
    await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: { success: true, workflowVersion: record.workflowVersion, update: plan.update, event: plan.event } }) });
  });
  await tab(page, "scheduled").click();
  await expect(row(page, "100002").locator('button').last()).toHaveText("View");
  await row(page, "100002").locator('button').last().click();
  await page.locator('[data-tracking-action="issue_summons"]').click();
  await expect(page.locator('#issueSummonsForm')).toBeVisible();
  await expect(page.locator('#summonsAppearanceDate')).toHaveValue("2026-10-11");
  await page.locator('#summonsTanodName').fill("Pedro Reyes");
  await page.locator('#summonsRespondentAddress').fill("Sitio Riverside");
  await page.locator('#modalActions button').filter({ hasText: "Generate a Summon" }).click();
  await expect(page.locator('#officialSummonsModalOverlay')).toBeVisible();
  await expect(page.locator('#confirmDialog')).toBeHidden();
  await expect(page.locator('#officialSummonsModalContent')).toContainText(/WAELS SANTOS/i);
  await expect(page.locator('#officialSummonsDownloadPdfBtn')).toBeVisible();
  await page.evaluate(() => { window.print = () => { window.__summonsPrinted = true; }; });
  await page.locator('#officialSummonsPrintBtn').click();
  expect(await page.evaluate(() => window.__summonsPrinted)).toBe(true);
  await expect(page.locator('#printableSummonsSheet')).toContainText(/WAELS SANTOS/i);
  await page.locator('#officialSummonsNotifyBtn').click();
  await expect(page.locator('#reporterHearingMessage')).toContainText("delivered to the resident");
  await page.locator('#modalActions button').filter({ hasText: "Notify Complainants" }).click();
  expect(posted).toHaveLength(1);
  await page.locator('#complaintConfirmHandoff').check();
  await page.locator('#modalActions button').filter({ hasText: "Notify Complainants" }).click();
  await expect(page.locator('#modalBody')).toContainText("Summons Handed to Barangay Tanod");
  expect(posted).toHaveLength(2);
  expect(posted[1].handoff).toBe(true);
  expect(posted[1].expectedVersion).toBe(3);
  expect(record.status).toBe("hearing_scheduled");
  expect(record.hearings[0].status).toBe("scheduled");
});

test("failed summons generation stays open without a local issued record", async ({ page }) => {
  await openPage(page, [samples[1]]);
  await page.route('**/advanceComplaintWorkflow', async route => route.fulfill({ status: 403, contentType: "application/json",
    body: JSON.stringify({ error: { status: "PERMISSION_DENIED", message: "Summons rejected by server." } }) }));
  await tab(page, "scheduled").click();
  await row(page, "100002").locator('button').first().click();
  await page.locator('[data-tracking-action="issue_summons"]').click();
  await page.locator('#summonsRespondentAddress').fill("Sitio Riverside");
  await page.locator('#modalActions button').filter({ hasText: "Generate a Summon" }).click();
  await expect(page.locator('#toastRegion')).toContainText("Summons was not issued: Access permission denied. Please contact system support or your LGU administrator.");
  await expect(page.locator('#issueSummonsForm')).toBeVisible();
  await expect(page.locator('#modalActions button').filter({ hasText: "Generate a Summon" })).toBeEnabled();
  await expect(page.locator('#officialSummonsModalOverlay')).toBeHidden();
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].summons)).toBeUndefined();
});

test("failed handoff notice retains pending delivery and retries the same operation", async ({ page }) => {
  const record = structuredClone(samples[1]);
  record.summons = { id: "summons-1", hearingId: "h1", status: "issued", deliveryStatus: "pending",
    assignedTanod: "Pedro Reyes", appearanceDate: "2026-10-11", appearanceTime: "09:00",
    appearanceVenue: "Barangay Hall", respondentName: "Waels Santos" };
  await openPage(page, [record]);
  const posted = [];
  await page.route('**/advanceComplaintWorkflow', async route => {
    const input = route.request().postDataJSON().data; posted.push(input);
    if (posted.length === 1) {
      await route.fulfill({ status: 503, contentType: "application/json", body: JSON.stringify({ error: { status: "UNAVAILABLE", message: "Notice not saved. Retry." } }) }); return;
    }
    const plan = planTrackingUpdate(record, input, new Date("2026-10-10T04:00:00Z"), { id: "official", name: "Captain Cruz", role: "barangay_captain" });
    await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: { success: true, workflowVersion: plan.update.workflowVersion, update: plan.update, event: plan.event } }) });
  });
  await tab(page, "scheduled").click();
  await row(page, "100002").locator('button').first().click();
  await page.locator('[data-tracking-action="notify_summons"]').click();
  await expect(page.locator('.hearing-summary-item').filter({ hasText: 'Delivery Status' })).toContainText('Awaiting delivery confirmation');
  await page.locator('#complaintConfirmHandoff').check();
  const send = page.locator('#modalActions button').filter({ hasText: "Notify Complainants" });
  await send.click();
  await expect(page.locator('#toastRegion')).toContainText("Notice was not sent: Connection to the service is unavailable. Please try again.");
  await expect(send).toBeEnabled();
  expect(await page.evaluate(() => window.__adminSession.state.complaints[0].summons.deliveryStatus)).toBe("pending");
  await send.click();
  await expect(page.locator('#modalBody')).toContainText("Summons Handed to Barangay Tanod");
  expect(posted[0].operationId).toBe(posted[1].operationId);
  await page.evaluate(() => window.openNotifyReporterModal('BC-2026-100002'));
  await expect(page.locator('.hearing-summary-item').filter({ hasText: 'Delivery Status' })).toContainText('Delivery confirmed');
  await expect(page.locator('#complaintHandoffField')).toBeHidden();
});

test("next task opens directly and waiting residents do not appear as work to do", async ({ page }) => {
  const pending = { ...structuredClone(samples[1]), id: "BC-2026-100006" };
  pending.summons = { id: "summons-1", hearingId: "h1", status: "issued", deliveryStatus: "pending",
    appearanceDate: "2026-10-11", appearanceTime: "09:00", appearanceVenue: "Barangay Hall", assignedTanod: "Pedro Reyes" };
  const ready = { ...structuredClone(pending), id: "BC-2026-100007", summons: { ...pending.summons, deliveryStatus: "handed_to_tanod" } };
  const waiting = { ...structuredClone(samples[0]), id: "BC-2026-100008", status: "needs_information", requestedInfoMessage: "Please provide the incident date." };
  await openPage(page, [samples[0], samples[2], pending, ready, waiting]);
  await expect(page.locator('.complaint-reports-table tbody tr')).toHaveCount(4);
  await expect(page.locator('.complaint-reports-table tbody tr').first()).toContainText("100003");
  await expect(row(page, "100008")).toHaveCount(0);
  await expect(row(page, "100006").locator('button').last()).toHaveText("View");
  await row(page, "100006").locator('button').last().click();
  await page.locator('[data-tracking-action="notify_summons"]').click();
  await expect(page.locator('#notifyReporterForm')).toBeVisible();
  await page.locator('#modalClose').click();
  await tab(page, "needs_information").click();
  await row(page, "100008").locator('button').last().click();
  await expect(page.locator('#trackingNextTitle')).toHaveText("Needs Information");
  await expect(page.locator('.tracking-next-step .button--primary')).toHaveCount(0);
});

test("guided complaint view keeps one main action and hides occasional actions", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await openPage(page, [samples[0], samples[1]]);
  await row(page, "100002").locator('button').first().click();
  await expect(page.locator('.tracking-next-step .button--primary')).toHaveCount(1);
  await expect(page.locator('.tracking-next-step .button--primary')).toHaveText("Issue Summon");
  await expect(page.locator('.tracking-steps [aria-current="step"]')).toContainText("Prepare summons");
  await expect(page.locator('[data-tracking-action="withdraw"]')).toBeHidden();
  await expect(page.locator('[data-tracking-action="edit_schedule"]')).toBeVisible();
  await expect(page.locator('.tracking-other-actions')).toHaveCount(0);
  await page.setViewportSize({ width: 560, height: 800 });
  expect(await page.locator('#modalBody').evaluate(node => node.scrollWidth <= node.clientWidth)).toBe(true);
  const buttonBox = await page.locator('.tracking-next-step .button--primary').boundingBox();
  expect(buttonBox.height).toBeGreaterThanOrEqual(44);
  await page.screenshot({ path: test.info().outputPath("guided-complaint-narrow.png") });
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.locator('#modalClose').click();
  await row(page, "100001").locator('button').first().click();
  await page.screenshot({ path: test.info().outputPath("guided-filed-complaint.png") });
});
