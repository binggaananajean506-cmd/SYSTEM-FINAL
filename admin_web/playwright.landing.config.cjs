const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: './tests', testMatch: 'landing-page.spec.js', timeout: 60000, reporter: 'list',
  webServer: process.env.ESUGID_LANDING_URL ? undefined : {
    command: 'node ../scripts/serve-deploy.mjs', cwd: __dirname, url: 'http://127.0.0.1:4174', reuseExistingServer: !process.env.CI,
  },
  use: { baseURL: process.env.ESUGID_LANDING_URL || 'http://127.0.0.1:4174', browserName: 'chromium', channel: 'msedge' },
});
