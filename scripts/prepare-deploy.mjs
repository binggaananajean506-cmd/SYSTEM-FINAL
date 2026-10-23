import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const adminDir = resolve(root, "admin_web");
const outDir = resolve(root, "deploy_web");
const outAdminDir = resolve(outDir, "admin");

console.log("Preparing deploy_web directory...");

// Clean output directory
if (existsSync(outDir)) {
  rmSync(outDir, { recursive: true, force: true });
}
mkdirSync(outDir, { recursive: true });
mkdirSync(outAdminDir, { recursive: true });

// The public landing page is hosted elsewhere; this site serves only the
// Admin Console at /admin (firebase.json redirects / there).

// Copy admin web runtime files
const adminFiles = [
  "app.bundle.js",
  "app.bundle.css",
  "style.css",
  "theme.css",
  "login.css",
  "theme.js",
  "barangay_logos.mjs",
  "emergency_hotlines.mjs",
  "complaint_tracking.mjs",
  "theme-charts.mjs"
];

for (const file of adminFiles) {
  const src = resolve(adminDir, file);
  if (existsSync(src)) {
    cpSync(src, resolve(outAdminDir, file));
  }
}

// Copy admin assets
cpSync(resolve(adminDir, "assets"), resolve(outAdminDir, "assets"), { recursive: true });

// Copy admin index.html with <base href="/admin/"> injected
let adminHtml = readFileSync(resolve(adminDir, "index.html"), "utf-8");
if (!adminHtml.includes('<base href="/admin/">')) {
  adminHtml = adminHtml.replace('<head>', '<head>\n  <base href="/admin/">');
}
writeFileSync(resolve(outAdminDir, "index.html"), adminHtml, "utf-8");

console.log("Successfully prepared deploy_web with Admin Console at /admin");
