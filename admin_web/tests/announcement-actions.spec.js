const { instrumentAdminBundle } = require('./helpers/admin-bundle');
const { test, expect } = require("@playwright/test");

test("barangay announcement actions open beside the selected row", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 700 });
  await page.goto("/");
  await page.waitForFunction(() => typeof window.toggleBarangayAnnouncementMenu === "function");
  await page.evaluate(() => {
    window.__selectedAnnouncementAction = "";
    const row = document.createElement("div");
    row.style.cssText = "position:fixed;right:16px;bottom:40px";
    row.innerHTML = `<button type="button" aria-label="Actions for Barangay post" onclick="toggleBarangayAnnouncementMenu(event,this)">•••</button>
      <template><button type="button" onclick="window.__selectedAnnouncementAction='edit'">Edit</button>
      <button type="button" onclick="window.__selectedAnnouncementAction='delete'">Delete</button>
      <button type="button" onclick="window.__selectedAnnouncementAction='archive'">Archive</button></template>`;
    document.body.append(row);
  });

  await page.getByRole("button", { name: "Actions for Barangay post" }).click();
  const menu = page.locator(".announcement-floating-menu");
  await expect(menu.getByRole("button")).toHaveCount(3);
  const box = await menu.boundingBox();
  expect(box.x).toBeGreaterThanOrEqual(0);
  expect(box.y).toBeGreaterThanOrEqual(0);
  expect(box.x + box.width).toBeLessThanOrEqual(390);
  expect(box.y + box.height).toBeLessThanOrEqual(700);
  await menu.getByRole("button", { name: "Edit" }).click();
  expect(await page.evaluate(() => window.__selectedAnnouncementAction)).toBe("edit");
  await expect(menu).toHaveCount(0);
});

test("announcement row actions invoke edit, delete, and archive", async ({ page }) => {
  await page.route("**/app.bundle.js*", async (route) => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle('window.__announcementTest = { state, auth, renderAnnouncements };') });
  });
  await page.goto("/");
  await page.waitForFunction(() => Boolean(window.__announcementTest));
  await page.evaluate(() => {
    const { state, auth, renderAnnouncements } = window.__announcementTest;
    Object.defineProperty(auth, "currentUser", {
      configurable: true, value: { uid: "post-author", email: "author@example.com" },
    });
    state.currentProfile = { role: "lgu", departmentId: "it-department" };
    state.capabilities = new Set(["announcements"]);
    state.announcementTab = "draft";
    state.posts = [{
      id: "action-post", title: "Action test", content: "Message", status: "draft",
      authorId: "post-author", authorRole: "lgu", departmentId: "it-department",
      announcementType: "general", priority: "regular", visibility: "public",
      targetBarangay: "All Barangays", targetBarangays: [],
    }];
    document.getElementById("admin-dashboard").hidden = false;
    document.getElementById("admin-dashboard").style.display = "";
    document.getElementById("login-screen").hidden = true;
    window.navigateTo("announcements");
    renderAnnouncements();
    window.archiveAnnouncement = (id) => { window.__archiveActionId = id; };
  });

  const actions = page.getByRole("button", { name: "Actions for Action test" });
  await actions.click();
  await page.locator(".announcement-floating-menu").getByRole("button", { name: "Delete" }).click();
  await expect(page.getByText("Delete this post permanently?")).toBeVisible();
  await page.getByRole("button", { name: "Keep post" }).click();

  await actions.click();
  await page.locator(".announcement-floating-menu").getByRole("button", { name: "Archive" }).click();
  expect(await page.evaluate(() => window.__archiveActionId)).toBe("action-post");

  await actions.click();
  await page.locator(".announcement-floating-menu").getByRole("button", { name: "Edit" }).click();
  await expect(page.locator("#announcementComposerPanel")).toBeVisible();
  await expect(page.locator("#announcementTitle")).toHaveValue("Action test");
});
