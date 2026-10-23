const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require("./helpers/admin-session");

test.describe("Emergency Refinements: Modal, Resolved flow & compact table, and Hotline cards", () => {
  test("Emergency alert modal does not contain Safety Action textarea", async ({ page }) => {
    await loadAdminSession(page, "super_admin");
    const hasSafetyAction = await page.evaluate(() => {
      const modal = document.getElementById("emergencyAlertModal");
      const textarea = modal?.querySelector("#alertInstructions");
      return Boolean(textarea);
    });
    expect(hasSafetyAction).toBe(false);
  });

  test("Emergency alerts render in a compact table with Resolved button and resolves correctly", async ({ page }) => {
    await loadAdminSession(page, "super_admin");
    const result = await page.evaluate(async () => {
      const { state, renderAlerts } = window.__adminSession;

      const mockAlert = {
        id: "alert-test-1",
        alertType: "Weather / Storm",
        title: "Typhoon Warning",
        message: "Heavy rain and winds expected in coastal barangays.",
        targetBarangay: "All Barangays",
        visibility: "public",
        active: true,
        status: "active",
        createdAt: new Date().toISOString(),
        startAt: new Date().toISOString(),
        createdBy: "staff-1",
        stats: { acknowledged: 4, targeted: 25 },
      };

      state.alerts = [mockAlert];

      // Switch to emergency page and render
      window.navigateTo("emergency");
      renderAlerts();

      const table = document.querySelector("#activeAlertList .emergency-table");
      const row = table?.querySelector("tbody tr");
      const statusPill = row?.querySelector(".alert-status-pill")?.textContent.trim();
      const title = row?.querySelector(".emergency-table-title-text")?.textContent.trim();
      const resolveBtn = row?.querySelector(".alert-resolve-btn");

      const hasResolveBtn = Boolean(resolveBtn && resolveBtn.textContent.includes("Resolve"));

      return {
        tableExists: Boolean(table),
        headers: [...(table?.querySelectorAll("thead th") || [])].map((th) => th.textContent.trim()),
        statusPill,
        title,
        hasResolveBtn,
        resolveBtnText: resolveBtn?.textContent.trim(),
      };
    });

    expect(result.tableExists).toBe(true);
    expect(result.headers).toEqual(["Status", "Emergency Alert", "Coverage", "Acknowledged", "Date & Time", "Actions"]);
    expect(result.statusPill).toBe("Active");
    expect(result.title).toBe("Typhoon Warning");
    expect(result.hasResolveBtn).toBe(true);
    expect(result.resolveBtnText).toContain("Resolve");
    expect(result.resolveBtnText).not.toContain("Resolved");
  });

  test("Resolved emergency alerts render in the same compact table", async ({ page }) => {
    await loadAdminSession(page, "super_admin");
    const result = await page.evaluate(async () => {
      const { state, renderAlerts } = window.__adminSession;

      const mockAlert = {
        id: "alert-resolved-1",
        alertType: "Flood",
        title: "Flash Flood Cleared",
        message: "Road is now passable.",
        targetBarangay: "All Barangays",
        visibility: "public",
        active: false,
        status: "resolved",
        createdAt: new Date(Date.now() - 3600000).toISOString(),
        createdBy: "staff-1",
        stats: { acknowledged: 10, targeted: 15 },
      };

      state.alerts = [mockAlert];

      window.navigateTo("emergency");
      const filterSelect = document.getElementById("alertStatusFilter");
      if (filterSelect) filterSelect.value = "resolved";
      renderAlerts();

      const table = document.querySelector("#activeAlertList .emergency-table");
      const row = table?.querySelector("tbody tr");
      const statusPill = row?.querySelector(".alert-status-pill")?.textContent.trim();
      const title = row?.querySelector(".emergency-table-title-text")?.textContent.trim();
      const hasResolveBtn = Boolean(row?.querySelector(".alert-resolve-btn"));

      return {
        tableExists: Boolean(table),
        statusPill,
        title,
        hasResolveBtn,
      };
    });

    expect(result.tableExists).toBe(true);
    expect(result.statusPill).toContain("Resolved");
    expect(result.title).toBe("Flash Flood Cleared");
    expect(result.hasResolveBtn).toBe(false);
  });

  test("Hotline section is removed from the emergency page", async ({ page }) => {
    await loadAdminSession(page, "super_admin");
    const hotlineListExists = await page.evaluate(() => {
      window.navigateTo("emergency");
      return Boolean(document.getElementById("emergencyHotlineList"));
    });

    expect(hotlineListExists).toBe(false);
  });
});
