const { test, expect } = require("@playwright/test");

for (const width of [320, 390, 1280]) {
  test(`active emergency banner fits at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 760 });
    await page.goto("/");
    const source = await (await page.request.get("/")).text();
    const layout = await page.evaluate((html) => {
      const banner = new DOMParser().parseFromString(html, "text/html")
        .getElementById("dashboardActiveEmergencyBanner");
      document.body.replaceChildren(document.importNode(banner, true));
      const mounted = document.getElementById("dashboardActiveEmergencyBanner");
      mounted.hidden = false;
      mounted.classList.add("is-critical");
      mounted.querySelector("#dashboardEmergencyTitle").textContent =
        "Severe weather advisory for coastal barangays";
      mounted.querySelector("#dashboardEmergencyBarangays").textContent =
        "Affected Barangays: Poblacion, Santa Ana, San Rafael";
      mounted.querySelector("#dashboardEmergencyIssued").textContent = "Issued: 2:44 PM";
      const card = mounted.getBoundingClientRect();
      const action = mounted.querySelector("button").getBoundingClientRect();
      return {
        scrollWidth: document.documentElement.scrollWidth,
        viewport: innerWidth,
        actionFits: action.left >= card.left && action.right <= card.right,
        actionVisible: action.width > 0 && action.height > 0,
      };
    }, source);

    expect(layout.scrollWidth).toBeLessThanOrEqual(layout.viewport);
    expect(layout.actionFits).toBe(true);
    expect(layout.actionVisible).toBe(true);
  });
}
