const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require('./helpers/admin-session');

test.describe("Announcement Publishing Scope & Audience Controls", () => {
  test("Publishing scope button is removed from organization cards and department management", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto("/");
    await page.waitForLoadState("domcontentloaded");

    // Ensure no button with "Publishing scope" exists in the document
    const publishingScopeButtons = page.locator("button:has-text('Publishing scope')");
    await expect(publishingScopeButtons).toHaveCount(0);
    const managePublishingScopeButtons = page.locator("button:has-text('Manage publishing scope')");
    await expect(managePublishingScopeButtons).toHaveCount(0);
  });

  test("Barangay dashboard locks announcement audience to intended barangay only", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await loadAdminSession(page, 'barangay_captain');
    await page.waitForLoadState("domcontentloaded");

    // Open the single-page composer with the barangay audience locked.
    await page.evaluate(() => {
      document.getElementById("admin-dashboard").hidden = false;
      document.getElementById("login-screen").hidden = true;
      const profile = {
        role: "barangay_captain",
        barangay: "Poblacion",
        barangayId: "poblacion"
      };
      if (typeof window.configureRoleAccess === "function") {
        window.configureRoleAccess(profile);
      }
      if (typeof window.openAnnouncementComposer === "function") {
        window.openAnnouncementComposer();
      }
      if (typeof window.setAnnouncementStep === "function") {
        window.setAnnouncementStep(2);
      }
    });

    // Check audience choices are hidden and locked notice is displayed
    const audienceChoices = page.locator("#announcementAudienceChoices");
    await expect(audienceChoices).toBeHidden();

    const lockedNotice = page.locator("#barangayAudienceNotice");
    await expect(lockedNotice).toBeVisible();
    await expect(lockedNotice).toContainText("Barangay Poblacion");
    await expect(lockedNotice).toContainText("Only residents in your registered barangay will receive this announcement");

    // Check barangay picker is hidden
    const picker = page.locator("#barangayPicker");
    await expect(picker).toBeHidden();
  });

  test("Authorized users (LGU/Mayor/SuperAdmin/Org) can choose audience residents", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await loadAdminSession(page, 'lgu');
    await page.waitForLoadState("domcontentloaded");

    // Open the single-page composer with a municipal department profile.
    await page.evaluate(() => {
      document.getElementById("admin-dashboard").hidden = false;
      document.getElementById("login-screen").hidden = true;
      const profile = {
        role: "lgu",
        departmentId: "dept_pio",
        departmentName: "Public Information Office"
      };
      if (typeof window.configureRoleAccess === "function") {
        window.configureRoleAccess(profile);
      }
      if (typeof window.openAnnouncementComposer === "function") {
        window.openAnnouncementComposer();
      }
      if (typeof window.setAnnouncementStep === "function") {
        window.setAnnouncementStep(2);
      }
    });

    // Audience choices are visible and unlocked
    const audienceChoices = page.locator("#announcementAudienceChoices");
    await expect(audienceChoices).toBeVisible();

    const audienceAll = page.locator("#audienceAll");
    const audienceTargeted = page.locator("#audienceTargeted");
    await expect(audienceAll).toBeVisible();
    await expect(audienceTargeted).toBeVisible();
    await expect(audienceTargeted).toBeEnabled();

    // Clicking targeted opens the barangay picker
    await audienceTargeted.click();
    const picker = page.locator("#barangayPicker");
    await expect(picker).toBeVisible();

    // Clicking all hides the barangay picker
    await audienceAll.click();
    await expect(picker).toBeHidden();
  });

  test("When to publish date/time picker is available in all dashboards including Barangay", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await loadAdminSession(page, 'barangay_secretary');
    await page.waitForLoadState("domcontentloaded");

    // Scheduling remains available in the single-page composer.
    await page.evaluate(() => {
      document.getElementById("admin-dashboard").hidden = false;
      document.getElementById("login-screen").hidden = true;
      const profile = {
        role: "barangay_secretary",
        barangay: "Campangga",
        barangayId: "campangga"
      };
      if (typeof window.configureRoleAccess === "function") {
        window.configureRoleAccess(profile);
      }
      if (typeof window.openAnnouncementComposer === "function") {
        window.openAnnouncementComposer();
      }
      if (typeof window.setAnnouncementStep === "function") {
        window.setAnnouncementStep(3);
      }
    });

    // Schedule announcement button must be visible for Barangay
    const scheduleButton = page.locator("#scheduleAnnouncement");
    await expect(scheduleButton).toBeVisible();

    // Clicking schedule announcement displays the date/time picker container
    await scheduleButton.scrollIntoViewIfNeeded();
    await scheduleButton.click();
    const publishAtContainer = page.locator("#announcementPublishAtBtn");
    await expect(publishAtContainer).toBeVisible();

    // Verify date/time input is present
    const dateInput = page.locator("#announcementPublishAt");
    await expect(dateInput).toBeAttached();

    // Now test with Organization user role
    await page.evaluate(() => {
      document.getElementById("admin-dashboard").hidden = false;
      document.getElementById("login-screen").hidden = true;
      const profile = {
        role: "organization",
        organizationId: "org_cebeco",
        organizationName: "CEBECO"
      };
      if (typeof window.configureRoleAccess === "function") {
        window.configureRoleAccess(profile);
      }
      if (typeof window.openAnnouncementComposer === "function") {
        window.openAnnouncementComposer();
      }
      if (typeof window.setAnnouncementStep === "function") {
        window.setAnnouncementStep();
      }
    });

    await expect(scheduleButton).toBeVisible();
    await scheduleButton.scrollIntoViewIfNeeded();
    await scheduleButton.click();
    await expect(publishAtContainer).toBeVisible();
  });
});
