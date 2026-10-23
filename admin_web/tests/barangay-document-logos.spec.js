const { readFileSync } = require("node:fs");
const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require("./helpers/admin-session");

test("case recipient ID selects the seal and unknown seals use the municipal fallback", async () => {
  const { barangayLogoForCase, MUNICIPALITY_SEAL } = await import("../barangay_logos.mjs");
  expect(barangayLogoForCase({
    kind: "concern", recipientType: "barangay", recipientId: "barangay-barili_vito",
    barangayId: "barili_pangpang", barangay: "Pangpang"
  })).toBe("assets/barangays/vito.png");
  expect(barangayLogoForCase({
    kind: "complaint", barangayId: "barili_santa_ana", barangay: "Santa Ana"
  })).toBe("assets/barangays/santa_ana.jpg");
  expect(barangayLogoForCase({
    kind: "concern", recipientType: "barangay", receivingBarangayId: "barili_cagay",
    barangayId: "barili_vito", barangay: "Vito"
  })).toBe("assets/barangays/cagay.png");
  expect(barangayLogoForCase({
    kind: "complaint", barangayId: "barili_azucena", barangay: "Vito"
  })).toBe(MUNICIPALITY_SEAL);
  expect(barangayLogoForCase({
    kind: "concern", recipientType: "municipalOffice", barangayId: "barili_vito"
  })).toBeNull();
});

test("Cagay seal is available to document previews and PDF downloads", async ({ request }) => {
  const response = await request.get("/assets/barangays/cagay.png");
  expect(response.ok()).toBe(true);
  expect(response.headers()["content-type"]).toBe("image/png");
  expect((await response.body()).subarray(0, 8)).toEqual(
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
  );
});

test("Cagay report and summons previews display the receiving seal", async ({ page }) => {
  await loadAdminSession(page, "barangay_admin");
  await page.evaluate(() => {
    window.__adminSession.state.concerns = [{
      id: "CON-CAGAY-SEAL", kind: "concern", title: "Road repair",
      recipientType: "barangay", receivingBarangayId: "barili_cagay",
      barangayId: "barili_vito", barangay: "Vito", date: "2026-10-13"
    }];
    window.__adminSession.state.complaints = [{
      id: "KP-CAGAY-SEAL", kind: "complaint", title: "Boundary",
      barangayId: "barili_cagay", barangay: "Cagay",
      summons: { barangay: "Cagay", respondentName: "Test Respondent",
        appearanceDate: "2026-11-12", appearanceTime: "09:00 AM" }
    }];
    window.openIndividualOfficialReport("CON-CAGAY-SEAL", 0);
  });
  const reportSeal = page.locator("#individualOfficialRecord .doc-sheet-seal-right img");
  await expect(reportSeal).toHaveAttribute("src", "assets/barangays/cagay.png");
  await expect.poll(() => reportSeal.evaluate(img => img.naturalWidth)).toBeGreaterThan(0);

  await page.evaluate(() => window.openOfficialSummonsModal("KP-CAGAY-SEAL"));
  const summonsSeal = page.locator("#officialSummonsModalContent .kp-header-seal--barangay");
  await expect(summonsSeal).toHaveAttribute("src", "assets/barangays/cagay.png");
  await expect.poll(() => summonsSeal.evaluate(img => img.naturalWidth)).toBeGreaterThan(0);

  const width = await summonsSeal.evaluate(img => img.naturalWidth);
  const download = page.waitForEvent("download");
  await page.evaluate(() => window.downloadSummonsPdf("KP-CAGAY-SEAL"));
  const pdf = readFileSync(await (await download).path()).toString("latin1");
  expect((pdf.match(/\/Subtype \/Image/g) || []).length).toBeGreaterThanOrEqual(2);
  expect(pdf).toMatch(new RegExp(`/Width\\s+${width}\\b`));
});

test("the local server returns the JPEG seal media type", async ({ request }) => {
  const response = await request.get("/assets/barangays/bagakay.jpg");
  expect(response.ok()).toBe(true);
  expect(response.headers()["content-type"]).toBe("image/jpeg");
});

test("Vito concern report and summons use the receiving seal in preview and PDF", async ({ page }) => {
  await loadAdminSession(page, "barangay_admin");
  await page.evaluate(() => {
    const concern = {
      id: "CON-LOGO-TEST", kind: "concern", title: "Road repair", category: "Roads",
      description: "Road needs repair.", residentName: "Test Resident", status: "new",
      recipientType: "barangay", recipientId: "barangay-barili_vito",
      department: "Barangay Vito", barangayId: "barili_pangpang", barangay: "Pangpang",
      date: "2026-10-12"
    };
    const complaint = {
      id: "KP-LOGO-TEST", kind: "complaint", title: "Boundary", category: "Boundary",
      residentName: "Test Complainant", respondentName: "Test Respondent",
      recipientType: "barangay", recipientId: "barangay-barili_vito",
      barangayId: "barili_pangpang", barangay: "Pangpang",
      summons: { barangay: "Vito", respondentName: "Test Respondent",
        appearanceDate: "2026-11-12", appearanceTime: "09:00 AM" }
    };
    window.__adminSession.state.concerns = [concern];
    window.__adminSession.state.complaints = [complaint];
    window.openIndividualOfficialReport(concern.id, 0);
  });

  const reportSeal = page.locator("#individualOfficialRecord .doc-sheet-seal-right img");
  await expect(reportSeal).toHaveAttribute("src", "assets/barangays/vito.png");
  await expect.poll(() => reportSeal.evaluate((img) => img.naturalWidth)).toBeGreaterThan(0);
  await expect(page.locator("#individualOfficialRecord .doc-sheet-seal-left img"))
    .toHaveAttribute("src", "assets/barili-logoo.png");

  const reportDownload = page.waitForEvent("download");
  await page.evaluate(() => window.downloadIndividualOfficialPdf(window._activeIndividualReport));
  const reportPdf = readFileSync(await (await reportDownload).path()).toString("latin1");
  expect((reportPdf.match(/\/Subtype \/Image/g) || []).length).toBeGreaterThanOrEqual(2);
  const vitoWidth = await reportSeal.evaluate((img) => img.naturalWidth);
  expect(reportPdf).toMatch(new RegExp(`/Width\\s+${vitoWidth}\\b`));

  await page.evaluate(() => window.openOfficialSummonsModal("KP-LOGO-TEST"));
  const summonsSeal = page.locator("#officialSummonsModalContent .kp-header-seal--barangay");
  await expect(summonsSeal).toHaveAttribute("src", "assets/barangays/vito.png");
  await expect.poll(() => summonsSeal.evaluate((img) => img.naturalWidth)).toBeGreaterThan(0);
  await expect(page.locator("#officialSummonsModalContent .kp-header-seal--municipal"))
    .toHaveAttribute("src", "assets/barili-logoo.png");

  await page.evaluate(() => {
    window.print = () => {};
    window.printIndividualOfficialReport();
    window.printBarangaySummons("KP-LOGO-TEST");
  });
  await expect(page.locator("#individualOfficialRecord .doc-sheet-seal-right img"))
    .toHaveAttribute("src", "assets/barangays/vito.png");
  await expect(page.locator("#printableSummonsSheet .kp-header-seal--barangay"))
    .toHaveAttribute("src", "assets/barangays/vito.png");

  const summonsDownload = page.waitForEvent("download");
  await page.evaluate(() => window.downloadSummonsPdf("KP-LOGO-TEST"));
  const summonsPdf = readFileSync(await (await summonsDownload).path()).toString("latin1");
  expect((summonsPdf.match(/\/Subtype \/Image/g) || []).length).toBeGreaterThanOrEqual(2);
  expect(summonsPdf).toMatch(new RegExp(`/Width\\s+${vitoWidth}\\b`));
});
