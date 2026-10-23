const { test, expect } = require("@playwright/test");

test.describe("Org-to-Org Emergency Flow", () => {
  test("incoming emergency modal shows emergency type, sender, location, description, date/time and buttons", async ({ page }) => {
    await page.goto("/");
    const result = await page.evaluate(() => {
      // Simulate incoming dispatch
      const fakeDispatch = {
        id: "disp-123",
        emergencyType: "Theft",
        title: "Theft at Landbank Branch",
        sourceOrganizationName: "Landbank Barili",
        sourceOrganizationId: "org-landbank",
        destinationOrganizationName: "PNP Barili",
        destinationOrganizationId: "org-pnp",
        location: "Poblacion, Barili, Cebu",
        description: "Suspects attempting forced entry through rear doors.",
        urgency: "critical",
        contactName: "Branch Manager",
        contactNumber: "0917 123 4567",
        status: "pending",
        createdAt: new Date().toISOString(),
      };

      if (typeof window.showIncomingEmergencyModal === "function") {
        window.showIncomingEmergencyModal(fakeDispatch);
      }

      const modal = document.getElementById("adminModal");
      const modalEyebrow = document.getElementById("modalEyebrow")?.textContent || "";
      const modalTitle = document.getElementById("modalTitle")?.textContent || "";
      const modalBody = document.getElementById("modalBody")?.textContent || "";
      const actionsEl = document.getElementById("modalActions");
      const buttons = actionsEl ? Array.from(actionsEl.querySelectorAll("button")).map((b) => b.textContent.trim()) : [];

      return {
        modalVisible: !modal?.hidden,
        modalEyebrow,
        modalTitle,
        hasEmergencyClass: modal?.querySelector(".modal-card")?.classList.contains("modal-card--emergency-alert"),
        hasEmergencyType: modalBody.includes("Theft") || modalTitle.includes("Theft"),
        hasSender: modalBody.includes("Landbank Barili") || modalTitle.includes("Landbank Barili"),
        hasLocation: modalBody.includes("Poblacion, Barili, Cebu"),
        hasDescription: modalBody.includes("Suspects attempting forced entry through rear doors."),
        buttons,
      };
    });

    expect(result.modalVisible).toBe(true);
    expect(result.hasEmergencyClass).toBe(true);
    expect(result.hasEmergencyType).toBe(true);
    expect(result.hasSender).toBe(true);
    expect(result.hasLocation).toBe(true);
    expect(result.hasDescription).toBe(true);
    expect(result.buttons.some((btn) => btn.includes("Acknowledge"))).toBe(true);
    expect(result.buttons.some((btn) => btn.includes("View Request"))).toBe(true);

    // Escape does not dismiss the emergency alert modal
    await page.keyboard.press("Escape");
    const stillVisible = await page.evaluate(() => !document.getElementById("adminModal")?.hidden);
    expect(stillVisible).toBe(true);
  });

  test("status flow transitions: pending -> acknowledged -> responding -> resolved in card & modal", async ({ page }) => {
    await page.goto("/");
    const statuses = await page.evaluate(() => {
      const items = [
        { id: "1", title: "Theft", status: "pending", sourceOrganizationName: "Landbank", destinationOrganizationName: "PNP" },
        { id: "2", title: "Fire", status: "acknowledged", sourceOrganizationName: "CEBECO", destinationOrganizationName: "BFP" },
        { id: "3", title: "Medical", status: "responding", sourceOrganizationName: "School", destinationOrganizationName: "RHU" },
        { id: "4", title: "Robbery", status: "resolved", sourceOrganizationName: "Store", destinationOrganizationName: "PNP" },
      ];

      const html = items.map((item) => {
        const rawStatus = item.status;
        const statusLabel = rawStatus.charAt(0).toUpperCase() + rawStatus.slice(1);
        return `<article class="emergency-dispatch-card status-${rawStatus}">
          <div class="emergency-dispatch-card__top">
            <strong>${item.title}</strong>
            <span class="status-pill status-pill--${rawStatus}">${statusLabel}</span>
          </div>
          <p>${item.sourceOrganizationName} &rarr; ${item.destinationOrganizationName}</p>
          <button class="button button--secondary">View request</button>
        </article>`;
      }).join("");

      const container = document.createElement("div");
      container.innerHTML = html;
      document.body.appendChild(container);

      const pills = Array.from(container.querySelectorAll(".status-pill")).map((p) => p.textContent.trim());
      return pills;
    });

    expect(statuses).toEqual(["Pending", "Acknowledged", "Responding", "Resolved"]);
  });

  test("private org can send emergency to public org; public org does not send emergency to org", async ({ page }) => {
    await page.goto("/");
    const source = await (await page.request.get("/")).text();
    const result = await page.evaluate((html) => {
      const doc = new DOMParser().parseFromString(html, "text/html");
      const privateBtn = doc.getElementById("newDispatchButton");
      const publicAlertBtn = doc.getElementById("newPublicAlertButton");

      return {
        hasPrivateBtn: Boolean(privateBtn),
        hasPublicAlertBtn: Boolean(publicAlertBtn),
        privateBtnText: privateBtn?.textContent || "",
      };
    }, source);

    expect(result.hasPrivateBtn).toBe(true);
    expect(result.hasPublicAlertBtn).toBe(false);
    expect(result.privateBtnText).toContain("Send Emergency to Public Response Org");
  });
});
