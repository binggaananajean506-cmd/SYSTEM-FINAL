const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test, expect } = require("@playwright/test");

const source = readFileSync(path.join(__dirname, "..", "app.js"), "utf8");
const start = source.indexOf("window.openConcernStatusModal = (id) => {");
const end = source.indexOf("\nwindow.chooseConcernStatus", start);
if (start < 0 || end < 0) throw new Error("Concern status menu handler was not found.");
const menuHandler = source.slice(start, end);
const choiceEnd = source.indexOf("\nwindow.startHandlingConcern", end);
if (choiceEnd < 0) throw new Error("Concern status choice handler was not found.");
const choiceHandler = source.slice(end, choiceEnd);

function statusMenu(status, role = "barangay", leadOrganizationId = "") {
  let body = "";
  const context = {
    window: {},
    state: {
      concerns: [{ id: "CON-1", status, schemaVersion: 4, leadOrganizationId }],
      currentProfile: { role },
    },
    findCase: (id) => context.state.concerns.find((item) => item.id === id),
    concernStatus: (item) => item.status,
    canonicalRole: (value) => value,
    safeId: (value) => value,
    statusLabel: (value) => value,
    escapeHtml: (value) => value,
    openModal: (_eyebrow, _title, markup) => { body = markup; },
  };
  vm.runInNewContext(menuHandler, context);
  context.window.openConcernStatusModal("CON-1");
  return body;
}

test("status menu keeps the three tracking choices and valid transitions", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await page.goto("/");
  await page.evaluate((markup) => {
    const modal = document.querySelector("#adminModal");
    modal.hidden = false;
    document.querySelector("#modalBody").innerHTML = markup;
  }, statusMenu("new"));

  const choices = page.locator("#modalBody .concern-status-choice");
  await expect(choices.locator("span:last-child")).toHaveText(["In Progress", "Awaiting Information", "Resolved"]);
  for (const choice of await choices.all()) await expect(choice).toBeEnabled();
  const right = await choices.last().evaluate((button) => button.getBoundingClientRect().right);
  expect(right).toBeLessThanOrEqual(320);

  await page.locator("#modalBody").evaluate((body, markup) => { body.innerHTML = markup; }, statusMenu("needs_information"));
  await expect(choices.nth(0)).toBeEnabled();
  await expect(choices.nth(1)).toBeDisabled();
  await expect(choices.nth(2)).toBeEnabled();

  await page.locator("#modalBody").evaluate((body, markup) => { body.innerHTML = markup; }, statusMenu("new", "organization"));
  await expect(choices.nth(0)).toBeEnabled();
  await expect(choices.nth(1)).toBeDisabled();
  await expect(choices.nth(2)).toBeDisabled();
});

test("each status choice opens the matching update path", () => {
  const calls = [];
  const context = {
    window: {
      startHandlingConcern: (id) => calls.push(["handle", id]),
      openAskInfoModal: (id) => calls.push(["request_information", id]),
      openResolveConcernModal: (id) => calls.push(["resolve", id]),
    },
    closeModal: () => calls.push(["close"]),
  };
  vm.runInNewContext(choiceHandler, context);
  for (const action of ["handle", "request_information", "resolve"]) {
    context.window.chooseConcernStatus("CON-1", action);
  }
  expect(calls).toEqual([
    ["handle", "CON-1"],
    ["close"], ["request_information", "CON-1"],
    ["close"], ["resolve", "CON-1"],
  ]);
});
