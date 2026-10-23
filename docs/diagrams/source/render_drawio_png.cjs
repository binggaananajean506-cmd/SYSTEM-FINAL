// Render each .drawio file to PNG with the draw.io web viewer (only viewer code is fetched;
// the diagram XML stays local in the page).
const path = require("path");
const fs = require("fs");
const { chromium } = require(path.resolve("E:/programs/esugid/admin_web/node_modules/playwright"));

(async () => {
  const dir = process.argv[2];
  const scale = Number(process.argv[3] || 2);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".drawio"));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 1600 }, deviceScaleFactor: scale });
  for (const f of files) {
    const xml = fs.readFileSync(path.join(dir, f), "utf8");
    const cfg = JSON.stringify({ xml, highlight: "none", nav: false, toolbar: null, border: 0 });
    const attr = cfg.replace(/&/g, "&amp;").replace(/"/g, "&quot;");
    await page.setContent(
      `<!doctype html><html><body style="margin:24px;background:#fff">
       <div id="d" class="mxgraph" data-mxgraph="${attr}"></div>
       <script src="https://viewer.diagrams.net/js/viewer-static.min.js"></script></body></html>`,
      { waitUntil: "networkidle" });
    await page.waitForFunction(() => typeof GraphViewer !== "undefined", null, { timeout: 60000 });
    await page.evaluate(() => { if (!document.querySelector("#d svg")) GraphViewer.processElements(); });
    await page.waitForSelector("#d svg", { state: "attached", timeout: 60000 });
    await page.waitForTimeout(500);
    const out = path.join(dir, f.replace(/\.drawio$/, ".png"));
    const box = await page.locator("#d svg").first().boundingBox();
    await page.setViewportSize({ width: Math.ceil(box.x + box.width + 48), height: Math.ceil(box.y + box.height + 48) });
    await page.screenshot({ path: out, clip: { x: Math.max(box.x - 24, 0), y: Math.max(box.y - 24, 0), width: box.width + 48, height: box.height + 48 } });
    console.log(out);
  }
  await browser.close();
})();
