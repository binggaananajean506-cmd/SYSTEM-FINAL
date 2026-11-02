import { cpSync, mkdirSync, readFileSync, readdirSync, statSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { loadLandingShowcase } from './landing-showcase.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const adminDir = resolve(root, "admin_web");
const outDir = resolve(root, "deploy_web");
const outAdminDir = resolve(outDir, "admin");
const landingDir = resolve(root, "landing_web");
const apk = resolve(root, "output/app-release.apk");
const showcase = loadLandingShowcase(root);

// Publish the actual signed release rather than a placeholder or a stale version label.
if (!existsSync(apk)) throw new Error("Build output/app-release.apk before staging the public download.");
const declaredVersion = readFileSync(resolve(root, "pubspec.yaml"), "utf8").match(/^version:\s*([\d.]+)\+(\d+)\s*$/m);
if (!declaredVersion) throw new Error("The app version could not be read from pubspec.yaml.");
const localProperties = readFileSync(resolve(root, "android/local.properties"), "utf8");
const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT || localProperties.match(/^sdk\.dir=(.+)$/m)?.[1].trim().replace(/\\\\/g, "\\").replace(/\\:/g, ":");
if (!sdk) throw new Error("Android SDK is required to verify the downloadable APK version.");
const aaptName = process.platform === "win32" ? "aapt.exe" : "aapt";
const aapt = readdirSync(resolve(sdk, "build-tools"), { withFileTypes: true }).filter(item => item.isDirectory())
  .map(item => item.name).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
  .map(version => resolve(sdk, "build-tools", version, aaptName)).find(existsSync);
if (!aapt) throw new Error("Android aapt is required to verify the APK before publication.");
const badging = execFileSync(aapt, ["dump", "badging", apk], { encoding: "utf8" });
const actualVersion = badging.match(/^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'/m);
if (!actualVersion || actualVersion[1] !== "com.esugid.barili" || actualVersion[2] !== declaredVersion[2] || actualVersion[3] !== declaredVersion[1]) {
  throw new Error("The downloadable APK does not match the current app version. Build and verify a release first.");
}
const release = { version: actualVersion[3], build: Number(actualVersion[2]), bytes: statSync(apk).size,
  sha256: createHash("sha256").update(readFileSync(apk)).digest("hex"), url: "/downloads/app-release.apk" };

console.log("Preparing deploy_web directory...");

// Clean output directory
if (existsSync(outDir)) {
  rmSync(outDir, { recursive: true, force: true });
}
mkdirSync(outDir, { recursive: true });
mkdirSync(outAdminDir, { recursive: true });

// Public resident landing page at /; the existing admin console stays at /admin.
for (const file of ["landing.css", "landing-theme.css", "landing.js"]) cpSync(resolve(landingDir, file), resolve(outDir, file));
const landingHtml = readFileSync(resolve(landingDir, 'index.html'), 'utf8');
if (!landingHtml.includes('<!-- APP_SHOWCASE -->')) throw new Error('Landing showcase placeholder is missing.');
writeFileSync(resolve(outDir, 'index.html'), landingHtml.replace('<!-- APP_SHOWCASE -->', showcase.html));
const landingAssets = {
  "esugid.png": "admin_web/assets/esugid-logoo.png",
  "municipal-hall.png": "admin_web/assets/barili-municipal-hall.png",
  "barili-landscape.jpg": "assets/images/resident_dashboard/barili_hills_church_footer.jpg",
  "Outfit-Bold.ttf": "assets/fonts/Outfit-Bold.ttf",
  "Manrope-Regular.ttf": "assets/fonts/Manrope-Regular.ttf",
  "Manrope-Bold.ttf": "assets/fonts/Manrope-Bold.ttf",
};
mkdirSync(resolve(outDir, "landing-assets"));
for (const [name, source] of Object.entries(landingAssets)) cpSync(resolve(root, source), resolve(outDir, "landing-assets", name));
mkdirSync(resolve(outDir, 'landing-assets/screenshots'));
for (const image of showcase.assets) cpSync(resolve(landingDir, 'assets/screenshots', image.file), resolve(outDir, 'landing-assets/screenshots', image.file));
mkdirSync(resolve(outDir, "downloads"));
cpSync(apk, resolve(outDir, "downloads/app-release.apk"));
writeFileSync(resolve(outDir, "release.json"), JSON.stringify(release, null, 2) + "\n", "utf8");

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
  "complaint-workspace.css",
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

console.log(`Prepared public landing page, Android v${release.version} (${release.build}), and Admin Console at /admin.`);
