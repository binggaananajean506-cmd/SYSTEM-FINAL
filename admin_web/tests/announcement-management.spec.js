const { instrumentAdminBundle } = require('./helpers/admin-bundle');
const { test, expect } = require("@playwright/test");

test("department peers can use announcement actions and editing saves the current status", async ({ page }) => {
  await page.route("**/app.bundle.js*", async (route) => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle('window.__announcementTest = { state, auth, renderAnnouncements, announcementFormValues };') });
  });
  await page.goto("/");
  await page.waitForFunction(() => Boolean(window.__announcementTest));

  const access = await page.evaluate(() => {
    const { state, auth, renderAnnouncements, announcementFormValues } = window.__announcementTest;
    Object.defineProperty(auth, "currentUser", {
      configurable: true, value: { uid: "tourism-peer", email: "peer@example.com" },
    });
    state.currentProfile = { role: "lgu", departmentId: "tourism-department" };
    state.capabilities = new Set(["announcements"]);
    document.getElementById("admin-dashboard").hidden = false;
    document.getElementById("admin-dashboard").style.display = "";
    document.getElementById("login-screen").hidden = true;
    const post = {
      id: "department-post", title: "Community update", content: "Original message",
      status: "approved", authorId: "tourism-author", authorRole: "lgu",
      departmentId: "tourism-department", category: "General Information",
      announcementType: "general", priority: "regular", visibility: "public",
      targetBarangay: "All Barangays", targetBarangays: [], notificationRequested: true,
    };
    state.posts = [post, { ...post, id: "other-post", departmentId: "engineering-department" }];
    window.navigateTo("announcements");
    renderAnnouncements();
    const ownRow = [...document.querySelectorAll("#announcementTable tr")]
      .find((row) => row.textContent.includes("Community update") && row.querySelector(".people-row-action"));
    const actionLabels = [...ownRow.querySelector("template").content.querySelectorAll(".action-label")]
      .map((label) => label.textContent.trim());
    const viewOnlyCount = document.querySelectorAll("#announcementTable .announcement-open-btn").length;
    window.editAnnouncement("department-post");
    const publishedEdit = {
      ownActionsVisible: Boolean(ownRow),
      actionLabels,
      viewOnlyCount,
      submitLabel: document.getElementById("publishAnnouncement").lastChild.textContent.trim(),
      draftHidden: document.getElementById("saveAnnouncementDraft").hidden,
      notificationChecked: document.getElementById("announcementNotify").checked,
      savedStatus: announcementFormValues().status,
    };
    post.status = "draft";
    window.editAnnouncement("department-post");
    const draftEdit = {
      savedStatus: announcementFormValues().status,
      publishActionVisible: !document.getElementById("saveAnnouncementDraft").hidden,
      publishActionLabel: document.getElementById("saveAnnouncementDraft").lastChild.textContent.trim(),
    };
    state.currentProfile = { role: "super_admin", departmentId: "it-department" };
    state.posts = [{ ...post, id: "barangay-post", status: "approved",
      authorRole: "barangay_captain", authorBarangay: "Cabcaban",
      barangayId: "barili_cabcaban", targetBarangay: "Cabcaban",
      targetBarangays: ["Cabcaban"], visibility: "targeted" }];
    window.editAnnouncement("barangay-post");
    const barangayAdminEdit = {
      audienceLocked: document.getElementById("announcementAudienceChoices").hidden,
      targets: announcementFormValues().targets,
    };
    state.currentProfile = { role: "organization", organizationId: "partner" };
    state.organizations = [{ id: "partner", serviceBarangays: ["Cabcaban"], municipalityWidePublishing: false }];
    window.openAnnouncementComposer();
    return {
      publishedEdit,
      draftEdit,
      barangayAdminEdit,
      organizationAudience: {
        municipalityHidden: document.getElementById("audienceAll").hidden,
        selectedMode: state.announcementAudience,
        availableBarangays: [...document.querySelectorAll("#barangayChecklist input")]
          .map((input) => input.value),
      },
    };
  });

  expect(access).toEqual({
    publishedEdit: {
      ownActionsVisible: true,
      actionLabels: ["Edit", "Duplicate / Repost", "Delete", "Archive"],
      viewOnlyCount: 1,
      submitLabel: "Save changes",
      draftHidden: true,
      notificationChecked: false,
      savedStatus: "approved",
    },
    draftEdit: {
      savedStatus: "draft",
      publishActionVisible: true,
      publishActionLabel: "Publish now",
    },
    barangayAdminEdit: { audienceLocked: true, targets: ["Cabcaban"] },
    organizationAudience: {
      municipalityHidden: true,
      selectedMode: "targeted",
      availableBarangays: ["Cabcaban"],
    },
  });
  await expect(page.locator("#announcementComposerPanel")).toBeVisible();
});
