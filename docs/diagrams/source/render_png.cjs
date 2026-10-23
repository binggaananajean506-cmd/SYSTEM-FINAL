// Render the diagram <svg> of each HTML file to a PNG next to it.
const path = require("path");
const fs = require("fs");
const { chromium } = require(path.resolve("E:/programs/esugid/admin_web/node_modules/playwright"));

(async () => {
  const dir = process.argv[2];
  const scale = Number(process.argv[3] || 2);
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".html"));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 }, deviceScaleFactor: scale });
  for (const f of files) {
    await page.goto("file:///" + path.join(dir, f).replace(/\\/g, "/"), { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    const out = path.join(dir, f.replace(/\.html$/, ".png"));
    await page.locator(".diagram-container svg").screenshot({ path: out });
    console.log(out);
  }
  await browser.close();
})();
