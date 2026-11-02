const { test, expect } = require("@playwright/test");
const { readFileSync } = require("node:fs");
const { loadAdminSession } = require("./helpers/admin-session");
const { planTrackingUpdate } = require("../../functions/complaint_tracking");

test("three barangay and three lupon rounds precede CFA issuance, download and print", async ({ page }) => {
  let record = { id: "BC-2026-100099", kind: "complaint", barangay: "Vito", barangayId: "barili_vito",
    complaintTrackingVersion: 1, workflowVersion: 0, residentName: "Elena Ramos", type: "Property Dispute",
    description: "Boundary disagreement.", date: "2026-10-01T01:00:00Z", status: "hearing_scheduled",
    complaint: { respondentName: "Roberto Gomez", respondentAddress: "Sitio Riverside" },
    hearings: [{ id: "h1", number: 1, status: "scheduled", date: "2026-10-01", time: "09:00", venue: "Barangay Hall" }] };
  const actor = { id: "official", name: "Captain Cruz", role: "barangay_captain" };
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.clock.setFixedTime(new Date("2026-10-02T04:00:00Z"));
  await loadAdminSession(page, "barangay_captain");
  await page.route('**/advanceComplaintWorkflow', async route => {
    const input = route.request().postDataJSON().data;
    const now = new Date(await page.evaluate(() => new Date().toISOString()));
    const plan = planTrackingUpdate(record, input, now, actor);
    record = { ...record, ...plan.update, statusHistory: [...(record.statusHistory || []), plan.event] };
    await route.fulfill({ contentType: "application/json", body: JSON.stringify({ result: {
      success: true, workflowVersion: record.workflowVersion, update: plan.update, event: plan.event } }) });
  });
  await page.evaluate(records => { window.__adminSession.state.complaints = records; }, [record]);
  await page.locator('.nav-link[data-page="complaints"]').click();
  await page.evaluate(() => window.openComplaintCase("BC-2026-100099"));
  for (let n = 1; n <= 6; n++) {
    const label = `${n <= 3 ? "Barangay" : "Lupon"} Hearing ${(n - 1) % 3 + 1} of 3`;
    await expect(page.locator('.tracking-schedule-panel')).toContainText(label);
    await expect(page.locator('[data-tracking-action="issue_cfa"]')).toHaveCount(0);
    await page.getByRole('button',{name:'Record result',exact:true}).click();
    await page.locator('[name="outcome"][value="no_agreement"]').check();
    await page.locator('[name="respondentAttendance"]').uncheck();
    await page.locator('[name="summary"]').fill(`Respondent absent at round ${n}.`);
    await page.locator('#trackingSave').click();
    if (n < 6) {
      await page.getByRole('button',{name:'Schedule next hearing',exact:true}).click();
      await page.locator('[name="date"]').fill(`2026-11-0${n + 1}`);
      await page.locator('[name="time"]').fill('09:00');
      await page.locator('#trackingSave').click();
      await page.getByRole('button', { name: 'View case', exact: true }).click();
      await expect(page.locator('.tracking-hearing-count')).toContainText(`${n} of 6 recorded`);
      if (n === 3) {
        await expect(page.locator('.tracking-schedule-panel')).toContainText("Lupon Hearing 1 of 3");
        await page.locator('[data-tracking-action="issue_summons"]').click();
        await expect(page.locator('#summonsCountSelect')).toHaveValue("4");
        await expect(page.locator('#summonsCountSelect')).toBeDisabled();
        await page.locator('#modalActions button').filter({ hasText: "Generate a Summon" }).click();
        await expect(page.locator('#officialSummonsModalContent')).toContainText("OFFICE OF THE LUPONG TAGAPAMAYAPA");
        await page.evaluate(() => window.closeOfficialSummonsModal());
      }
      await page.clock.setFixedTime(new Date(`2026-11-0${n + 1}T02:00:00Z`));
      await page.evaluate(() => window.openComplaintCase("BC-2026-100099"));
    } else {
      await page.getByRole('button',{name:'Review CFA',exact:true}).click();
      await expect(page.locator('[name="date"]')).toHaveCount(0);
    }
  }
  expect(record.hearings.filter(h=>h.status==='completed')).toHaveLength(6);
  await page.locator('[name="cfaForm"]').selectOption('20-B');
  await page.locator('[name="confirmUnjustifiedAbsence"]').check();
  await page.locator('[name="reason"]').fill("No settlement after three barangay and three lupon rounds.");
  await page.locator('[name="confirmEligibility"]').check();
  await page.locator('#trackingSave').click();
      await page.getByRole('button', { name: 'View case', exact: true }).click();
  await expect(page.locator('.tracking-panel--cfa')).toBeVisible();
  await expect(page.locator('[data-tracking-action="issue_summons"]')).toHaveCount(0);
  await page.locator('[data-tracking-action="view_cfa"]').click();
  await expect(page.locator('#officialSummonsModalContent')).toContainText("CERTIFICATE TO FILE ACTION");
  await expect(page.locator('#officialSummonsModalContent')).toContainText('20-B');
  await expect(page.locator('#officialSummonsModalContent')).toContainText("ELENA RAMOS");
  await expect(page.locator('#officialSummonsModalContent')).toContainText("ROBERTO GOMEZ");
  const issuedDate = new Date(record.cfaIssuedAt).toLocaleDateString("en-US", { timeZone: "Asia/Manila", month: "long", day: "numeric", year: "numeric" });
  await page.clock.setFixedTime(new Date("2027-01-01T04:00:00Z"));
  await page.evaluate(() => window.openOfficialCfaModal("BC-2026-100099"));
  await expect(page.locator('#officialSummonsModalContent')).toContainText(issuedDate);
  await page.evaluate(() => { window.print = () => { window.__cfaPrinted = true; }; });
  await page.locator('#officialSummonsPrintBtn').click();
  expect(await page.evaluate(() => window.__cfaPrinted)).toBe(true);
  await expect(page.locator('#printableSummonsSheet')).toContainText("CERTIFICATE TO FILE ACTION");
  const downloadPromise = page.waitForEvent("download");
  await page.locator('#officialSummonsDownloadPdfBtn').click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe("CFA_BC-2026-100099.pdf");
  const pdf = readFileSync(await download.path(), "latin1");
  expect(pdf.startsWith("%PDF-")).toBe(true);
  expect(pdf).toContain("Elena Ramos");
  expect(pdf).toContain("Roberto Gomez");
  expect(pdf).toContain("No settlement after three barangay and three lupon rounds.");
  expect(pdf).toContain('20-B');
});
