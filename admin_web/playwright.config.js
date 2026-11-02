const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./tests",
  testIgnore: "landing-page.spec.js",
  timeout: 60000,
  reporter: "list",
  webServer: process.env.ESUGID_ADMIN_URL ? undefined : {
    command: "node scripts/serve-admin.mjs",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: !process.env.CI,
  },
  use: {
    baseURL: process.env.ESUGID_ADMIN_URL || "http://127.0.0.1:4173",
    browserName: "chromium",
    channel: process.env.PLAYWRIGHT_CHANNEL || "msedge",
  },
});
