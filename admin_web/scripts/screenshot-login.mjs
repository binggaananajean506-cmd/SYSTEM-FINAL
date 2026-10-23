import { chromium } from "playwright";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");

async function capture() {
  const browser = await chromium.launch({ channel: "msedge" });
  
  // Desktop
  const desktopContext = await browser.newContext({
    viewport: { width: 1440, height: 900 }
  });
  const desktopPage = await desktopContext.newPage();
  await desktopPage.screenshot({ path: path.join(projectRoot, "login-desktop.png") });
  
  // Click "Register an account"
  await desktopPage.click("#openOrganizationRegistration");
  await desktopPage.waitForTimeout(500);
  await desktopPage.screenshot({ path: path.join(projectRoot, "registration-type.png") });
  
  // Click on "Organization" card
  await desktopPage.click(".registration-type-card-btn[data-account-type='organization']");
  await desktopPage.waitForTimeout(500);
  await desktopPage.screenshot({ path: path.join(projectRoot, "registration-form.png") });
  
  // Scroll down to see proof document dropzone and password fields
  await desktopPage.evaluate(() => window.scrollBy(0, 700));
  await desktopPage.waitForTimeout(300);
  await desktopPage.screenshot({ path: path.join(projectRoot, "registration-form-bottom.png") });

  // Test selecting an image file in the dropzone
  await desktopPage.setInputFiles("#registrationProofFile", path.join(projectRoot, "assets", "esugid-logo.png"));
  await desktopPage.waitForTimeout(400);
  await desktopPage.screenshot({ path: path.join(projectRoot, "registration-file-selected.png") });

  await desktopContext.close();

  // Mobile
  const mobileContext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true
  });
  const mobilePage = await mobileContext.newPage();
  await mobilePage.goto(`file://${path.join(projectRoot, "index.html")}`);
  await mobilePage.waitForTimeout(1000);
  await mobilePage.screenshot({ path: path.join(projectRoot, "login-mobile.png") });
  await mobileContext.close();

  await browser.close();
  console.log("Screenshots captured successfully!");
}

capture().catch(err => {
  console.error(err);
  process.exit(1);
});
