const { test, expect } = require("@playwright/test");

for (const width of [320, 360, 390, 768, 1024, 1440]) {
  test(`login has no horizontal overflow or overlapping feedback at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await page.goto("/");
    await expect(page.locator("#loginForm")).toBeVisible();
    await page.locator("#authMessage").evaluate((message) => {
      message.textContent = "The email address or password is incorrect.";
      message.classList.add("error");
    });

    const layout = await page.evaluate(() => {
      const rect = (selector) => document.querySelector(selector).getBoundingClientRect();
      const message = rect("#authMessage");
      const submit = rect("#loginForm button[type='submit']");
      const helper = rect("#openOrganizationRegistration");
      return {
        pageWidth: document.documentElement.scrollWidth,
        viewportWidth: window.innerWidth,
        messageBottom: message.bottom,
        submitTop: submit.top,
        submitBottom: submit.bottom,
        helperTop: helper.top,
      };
    });

    expect(layout.pageWidth).toBeLessThanOrEqual(layout.viewportWidth);
    expect(layout.messageBottom).toBeLessThanOrEqual(layout.submitTop);
    expect(layout.submitBottom).toBeLessThanOrEqual(layout.helperTop);
  });
}

for (const width of [320, 390, 740]) {
  test(`confirmation actions fit at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 700 });
    await page.goto("/");
    await page.locator("#confirmDialog").evaluate((dialog) => {
      dialog.hidden = false;
      dialog.querySelector("#confirmDialogTitle").textContent = "Deactivate organization?";
      dialog.querySelector("#confirmDialogMessage").textContent = "Existing records will be retained, but new assignments will stop.";
      dialog.querySelector("#confirmDialogConfirm").textContent = "Deactivate organization";
    });
    const layout = await page.evaluate(() => {
      const card = document.querySelector(".confirmation-card").getBoundingClientRect();
      const actions = [...document.querySelectorAll(".confirmation-card__actions .button")]
        .map((button) => button.getBoundingClientRect());
      return { cardLeft: card.left, cardRight: card.right, buttonsFit: actions.every((rect) => rect.left >= card.left && rect.right <= card.right) };
    });
    expect(layout.cardLeft).toBeGreaterThanOrEqual(0);
    expect(layout.cardRight).toBeLessThanOrEqual(width);
    expect(layout.buttonsFit).toBe(true);
  });
}

test("account approvals switch to cards before mobile table styles apply", async ({ page }) => {
  await page.setViewportSize({ width: 740, height: 800 });
  await page.goto("/");
  const source = await (await page.request.get("/")).text();
  await page.evaluate((html) => {
    const section = new DOMParser().parseFromString(html, "text/html").getElementById("page-accountRequests");
    document.body.appendChild(document.importNode(section, true));
  }, source);
  const display = await page.evaluate(() => ({
    table: getComputedStyle(document.querySelector(".account-approval-table-wrap")).display,
    cards: getComputedStyle(document.querySelector("#accountApprovalCards")).display,
  }));
  expect(display).toEqual({ table: "none", cards: "grid" });
});

for (const width of [390, 1100]) {
  test(`resident report detail remains readable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 720 });
    await page.goto("/");
    const source = await (await page.request.get("/")).text();
    await page.evaluate((html) => {
      const section = new DOMParser().parseFromString(html, "text/html").getElementById("page-concerns");
      document.body.replaceChildren(document.importNode(section, true));
      const report = document.getElementById("page-concerns");
      report.style.display = "block";
      report.classList.add("concern-table-report");
      report.querySelector('[data-status="new"]').classList.add("active");
      report.querySelector("#concernReportYear").innerHTML = '<option value="2026">2026</option>';
      report.querySelector("#concernDocumentGrid").innerHTML = `
        <div class="concern-report-heading concern-report-heading--detail">
          <button class="concern-report-back" type="button"><span class="material-symbols-rounded">arrow_back</span>Back to categories</button>
          <div class="concern-report-heading__main"><span class="concern-report-category-icon material-symbols-rounded">file_copy</span><div class="concern-report-heading__title"><small>Concern category</small><strong>School &amp; Education</strong></div><div class="concern-report-heading__meta"><strong>1 report</strong><small>Oldest submitted first</small></div></div>
        </div>
        <div class="concern-file-grid"><button class="concern-file-card" type="button"><span class="concern-file-card__preview"><span class="concern-file-card__paper"><span class="material-symbols-rounded">description</span><i></i><i></i></span></span><span class="concern-file-card__body"><span class="concern-file-card__queue">1 · First submitted</span><strong>Batiq inyong skwelahan</strong><span class="concern-file-card__meta">CON-2026-222507<span>·</span>Barangay Vito</span></span><time class="concern-file-card__date"><span class="material-symbols-rounded">schedule</span>Sep 28, 2026, 9:02 PM</time><span class="concern-file-card__arrow material-symbols-rounded">chevron_right</span></button></div>`;
    }, source);
    const layout = await page.evaluate(() => ({
      pageWidth: document.documentElement.scrollWidth,
      cardRight: document.querySelector(".concern-file-card").getBoundingClientRect().right,
      headingRight: document.querySelector(".concern-report-heading").getBoundingClientRect().right,
    }));
    expect(layout.pageWidth).toBeLessThanOrEqual(width);
    expect(layout.cardRight).toBeLessThanOrEqual(width);
    expect(layout.headingRight).toBeLessThanOrEqual(width);
  });
}

test('concern reports show the four shared tracking statuses', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await page.goto('/');
  const source = await (await page.request.get('/')).text();
  const statuses = await page.evaluate((html) => {
    const section = new DOMParser().parseFromString(html, 'text/html').getElementById('page-concerns');
    document.body.replaceChildren(document.importNode(section, true));
    const tabs = document.querySelector('#concernStatusTabs');
    tabs.querySelector('[data-status="all"]').hidden = true;
    return [...tabs.querySelectorAll('button:not([hidden])')].map((button) => ({
      status: button.dataset.status,
      label: button.textContent.replace(/\d+/g, '').trim(),
    }));
  }, source);
  expect(statuses).toEqual([
    { status: 'new', label: 'Active' },
    { status: 'being_handled', label: 'In Progress' },
    { status: 'needs_information', label: 'Awaiting Information' },
    { status: 'resolved', label: 'Resolved' },
  ]);
});

for (const width of [320, 390]) {
  test(`account approval filters fit at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await page.goto("/");
    const source = await (await page.request.get("/")).text();
    await page.evaluate((html) => {
      const section = new DOMParser().parseFromString(html, "text/html").getElementById("page-accountRequests");
      document.body.appendChild(document.importNode(section, true));
    }, source);
    const layout = await page.evaluate(() => {
      const section = document.querySelector("#page-accountRequests");
      const controls = [...section.querySelectorAll("#accountApprovalSearch, #accountApprovalType, #accountApprovalSort")];
      return {
        sectionWidth: section.scrollWidth,
        viewportWidth: window.innerWidth,
        controlsFit: controls.every((control) => {
          const rect = control.getBoundingClientRect();
          return rect.left >= 0 && rect.right <= window.innerWidth;
        }),
      };
    });
    expect(layout.sectionWidth).toBeLessThanOrEqual(layout.viewportWidth);
    expect(layout.controlsFit).toBe(true);
  });
}

for (const width of [320, 390, 768, 1440]) {
  test(`organization registration fits ${width}px without horizontal overflow`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await page.goto("/");
    await page.locator("#openOrganizationRegistration").click();
    await page.locator('[data-account-type="organization"]').click();
    await expect(page.locator("#organizationRegistrationForm")).toBeVisible();
    await expect(page.locator("#registrationOrganizationSector")).toBeVisible();
    await page.locator("#registrationOrganizationSector").selectOption("public");
    await expect(page.locator("#registrationOrganizationType")).toBeVisible();
    await expect(page.locator('#registrationOrganizationType option[value="public_safety"]')).toHaveText("Public Safety");
    await expect(page.locator('#registrationOrganizationType option[value="private_banking_finance"]')).toHaveCount(0);
    await page.locator("#registrationOrganizationSector").selectOption("private");
    await expect(page.locator('#registrationOrganizationType option[value="private_banking_finance"]')).toHaveText("Banking & Finance");
    await expect(page.locator('#registrationOrganizationType option[value="public_safety"]')).toHaveCount(0);
    await expect(page.locator("#registrationProofFile")).toBeVisible();
    const pageWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(pageWidth).toBeLessThanOrEqual(width);
  });
}

for (const width of [320, 390, 768]) {
  test(`organization registration confirmation is clear at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 700 });
    await page.goto("/");
    await page.locator("#login-screen").evaluate((screen) => { screen.hidden = true; });
    await page.locator("#registration-success-screen").evaluate((screen) => { screen.hidden = false; });
    await expect(page.locator("#registrationSuccessTitle")).toHaveText("Your registration was submitted");
    await expect(page.locator(".registration-success-steps li")).toHaveCount(2);
    const pageWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(pageWidth).toBeLessThanOrEqual(width);
  });
}
