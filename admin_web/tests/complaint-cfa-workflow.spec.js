const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require("./helpers/admin-session");

test.describe("Complaint Non-attendance, 3-Hearing Limit, and CFA Workflow", () => {
  test("shows Schedule Another Hearing for resident non-attendance up to 3 hearings, then issues terminal CFA", async ({ page }) => {
    const record = {
      id: "BC-2026-100099",
      kind: "complaint",
      complaintTrackingVersion: 1,
      workflowVersion: 3,
      residentName: "Elena Ramos",
      type: "Property Dispute",
      description: "Boundary disagreement with neighbor.",
      date: "2026-10-01T01:00:00Z",
      status: "hearing_scheduled",
      complaint: { respondentName: "Roberto Gomez", respondentAddress: "Sitio Riverside" },
      hearings: [{ id: "h1", number: 1, status: "scheduled", date: "2026-10-15", time: "09:00", venue: "Barangay Hall" }],
      summons: {
        id: "summons-1",
        hearingId: "h1",
        status: "issued",
        deliveryStatus: "handed_to_tanod",
        appearanceDate: "2026-10-15",
        appearanceTime: "09:00",
        appearanceVenue: "Barangay Hall",
        assignedTanod: "Tanod Juan"
      }
    };

    await page.setViewportSize({ width: 1280, height: 900 });
    await page.clock.setFixedTime(new Date("2026-10-10T04:00:00Z"));
    await loadAdminSession(page, "barangay_captain");
    await page.evaluate(records => { window.__adminSession.state.complaints = records; }, [record]);
    await page.locator('.nav-link[data-page="complaints"]').click();
    await page.locator('.complaint-header-actions').hover();

    // 1. Open the complaint case
    await page.locator('.complaint-reports-table tbody tr').filter({ hasText: "100099" }).locator('button').first().click();

    // Complainant was notified -> primary action is Record Result, secondary is Schedule Another Hearing
    await expect(page.locator('[data-tracking-action="record_result"]')).toBeVisible();
    await expect(page.locator('[data-tracking-action="schedule_another_hearing"]')).toBeVisible();
    await expect(page.locator('[data-tracking-action="schedule_another_hearing"]')).toHaveText("Schedule Another Hearing");

    // Unnecessary buttons should be absent
    await expect(page.locator('[data-tracking-action="resolve_outside_hearing"]')).toHaveCount(0);
    await expect(page.locator('[data-tracking-action="withdraw"]')).toHaveCount(0);
    await expect(page.locator('[data-tracking-action="record_external_update"]')).toHaveCount(0);

    // 2. Click "Schedule Another Hearing"
    let posted;
    await page.route('**/advanceComplaintWorkflow', async route => {
      posted = route.request().postDataJSON().data;
      if (posted.action === "schedule_another_hearing") {
        const update = {
          workflowVersion: 4,
          status: "hearing_scheduled",
          schedule: { id: "h2", number: 2, status: "scheduled", date: posted.date, time: posted.time, venue: posted.venue },
          hearings: [
            { id: "h1", number: 1, status: "completed", outcome: "no_agreement", summary: posted.reason, respondentAttendance: "absent", complainantAttendance: "present" },
            { id: "h2", number: 2, status: "scheduled", date: posted.date, time: posted.time, venue: posted.venue }
          ]
        };
        const event = { action: "schedule_another_hearing", label: "Hearing 2 Scheduled", date: "2026-10-10T04:00:00Z" };
        await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: { success: true, workflowVersion: 4, update, event } }) });
      } else if (posted.action === "issue_cfa") {
        const update = {
          workflowVersion: 6,
          status: "cfa_issued",
          closureOutcome: "cfa_issued",
          cfaReason: posted.reason,
          resolutionSummary: posted.reason,
          schedule: null
        };
        const event = { action: "issue_cfa", label: "Certificate to File Action Issued", date: "2026-10-10T04:00:00Z" };
        await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: { success: true, workflowVersion: 6, update, event } }) });
      }
    });

    await page.locator('[data-tracking-action="schedule_another_hearing"]').click();
    await expect(page.locator('#modalTitle')).toContainText("Schedule Another Hearing (Non-Attendance)");
    await page.locator('[name="reason"]').fill("Resident did not attend Hearing 1.");
    await page.locator('#trackingSave').click();

    // After scheduling Hearing 2, modal re-opens showing Hearing 2 of 3
    await expect(page.locator('.tracking-hearing-count')).toContainText("1 of 3 completed");
    await expect(page.locator('[data-tracking-action="issue_summons"]')).toBeVisible();

    // 3. Now simulate reaching Hearing 3 with summons and notifications complete
    await page.evaluate(() => {
      const item = window.__adminSession.state.complaints[0];
      item.hearings = [
        { id: "h1", number: 1, status: "completed", outcome: "no_agreement", summary: "Resident absent", respondentAttendance: "absent", complainantAttendance: "present" },
        { id: "h2", number: 2, status: "completed", outcome: "no_agreement", summary: "Resident absent again", respondentAttendance: "absent", complainantAttendance: "present" },
        { id: "h3", number: 3, status: "scheduled", date: "2026-10-25", time: "09:00", venue: "Barangay Hall" }
      ];
      item.schedule = item.hearings[2];
      item.summons = {
        id: "summons-3",
        hearingId: "h3",
        status: "issued",
        deliveryStatus: "handed_to_tanod",
        appearanceDate: "2026-10-25",
        appearanceTime: "09:00",
        appearanceVenue: "Barangay Hall"
      };
      window.openComplaintCase("BC-2026-100099");
    });

    // In Hearing 3 of 3: option is now directly Issue Certificate to File Action (CFA)
    await expect(page.locator('[data-tracking-action="issue_cfa"]')).toBeVisible();
    await expect(page.locator('[data-tracking-action="issue_cfa"]')).toHaveText("Issue Certificate to File Action (CFA)");
    await expect(page.locator('[data-tracking-action="schedule_another_hearing"]')).toHaveCount(0); // cannot schedule past 3

    // 4. Issue the CFA
    await page.locator('[data-tracking-action="issue_cfa"]').click();
    await expect(page.locator('#modalTitle')).toContainText("Issue Certificate to File Action");
    await page.locator('[name="reason"]').fill("Resident failed to appear for 3 scheduled mediation hearings.");
    await page.locator('#trackingSave').click();

    // 5. System ends — CFA Issued terminal state
    await expect(page.locator('.tracking-panel--cfa')).toBeVisible();
    await expect(page.locator('.tracking-panel--cfa')).toContainText("Certificate to File Action Issued — Case Officially Closed");
    await expect(page.locator('[data-tracking-action="view_cfa"]')).toBeVisible();
    await expect(page.locator('[data-tracking-action="record_result"]')).toHaveCount(0);
    await expect(page.locator('[data-tracking-action="schedule_another_hearing"]')).toHaveCount(0);
    await expect(page.locator('[data-tracking-action="issue_summons"]')).toHaveCount(0);

    // 6. Click "View / Print Certificate to File Action (CFA)" and verify official KP Form 20 opens
    await page.locator('[data-tracking-action="view_cfa"]').click();
    await expect(page.locator('#officialSummonsModalOverlay')).toBeVisible();
    await expect(page.locator('#officialSummonsModalTitle')).toHaveText("Certificate to File Action (KP Form 20)");
    await expect(page.locator('#officialSummonsModalContent')).toContainText("CERTIFICATE TO FILE ACTION");
    await expect(page.locator('#officialSummonsModalContent')).toContainText("KP FORM NO. 20");
    await expect(page.locator('#officialSummonsModalContent')).toContainText("ELENA RAMOS");
    await expect(page.locator('#officialSummonsModalContent')).toContainText("ROBERTO GOMEZ");
    await expect(page.locator('#officialSummonsModalContent')).toContainText("Resident failed to appear for 3 scheduled mediation hearings");
  });
});
