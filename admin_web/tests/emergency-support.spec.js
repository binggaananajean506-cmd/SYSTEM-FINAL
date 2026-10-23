const { test, expect } = require("@playwright/test");

for (const width of [320, 390, 1024]) {
  test(`private emergency and hotline cards fit at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 760 });
    await page.goto("/");
    const source = await (await page.request.get("/")).text();
    const layout = await page.evaluate((html) => {
      const section = new DOMParser().parseFromString(html, "text/html").getElementById("page-emergency");
      const support = section.querySelector("#emergencyDispatchSection");
      const hotlines = section.querySelector("#emergencyHotlineList")?.closest(".emergency-support-surface");
      if (hotlines) {
        section.replaceChildren(support, hotlines);
      } else {
        section.replaceChildren(support);
      }
      document.body.replaceChildren(document.importNode(section, true));
      const mounted = document.getElementById("page-emergency");
      mounted.style.display = "block";
      mounted.querySelector("#emergencyDispatchSection").hidden = false;
      mounted.querySelector("#incomingDispatchList").innerHTML = '<article class="emergency-dispatch-card"><div class="emergency-dispatch-card__top"><strong>Theft at Landbank Barili branch</strong><span class="status-pill">Acknowledged</span></div><p>Landbank → PNP</p><small>Barili branch · Today</small><button class="button button--secondary">View request</button></article>';
      const hotlineEl = mounted.querySelector("#emergencyHotlineList");
      if (hotlineEl) {
        hotlineEl.innerHTML = '<article class="emergency-hotline-card"><div><strong>Barili Police Station</strong><small>Police</small></div><div class="emergency-hotline-lines"><div><span>Station mobile: <b>09123456789</b></span><a class="button button--primary" href="tel:09123456789">Call</a><button class="button button--secondary">Copy</button></div></div></article>';
      }
      const cards = [...mounted.querySelectorAll(".emergency-dispatch-card, .emergency-hotline-card")]
        .map((card) => card.getBoundingClientRect());
      return { scrollWidth: document.documentElement.scrollWidth, viewport: innerWidth,
        cardsFit: cards.every((card) => card.left >= 0 && card.right <= innerWidth) };
    }, source);
    expect(layout.scrollWidth).toBeLessThanOrEqual(layout.viewport);
    expect(layout.cardsFit).toBe(true);
  });
}
