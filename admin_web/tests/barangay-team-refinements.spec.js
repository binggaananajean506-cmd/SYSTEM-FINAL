const { test, expect } = require("@playwright/test");
const { loadAdminSession } = require("./helpers/admin-session");

test.describe("Barangay Team Filter Button and Table Refinements", () => {
  test("Unified filter button toggles popover with Position and Sort controls for Barangay Team", async ({ page }) => {
    await loadAdminSession(page, "barangay_captain");

    const result = await page.evaluate(() => {
      window.navigateTo("directory");
      const toggle = document.getElementById("peopleFilterToggle");
      const popover = document.getElementById("peopleFilterPopover");
      const posWrap = document.getElementById("barangayPositionFilterWrap");
      const sortWrap = document.getElementById("peopleSortWrap");
      const statusWrap = document.getElementById("userStatusFilterWrap");

      const initiallyHidden = popover?.hidden;

      // Click to open
      toggle?.click();
      const openedHidden = popover?.hidden;

      return {
        hasToggle: Boolean(toggle),
        hasPopover: Boolean(popover),
        initiallyHidden,
        openedHidden,
        posVisible: Boolean(posWrap && !posWrap.hidden),
        sortVisible: Boolean(sortWrap && !sortWrap.hidden),
        statusHidden: Boolean(statusWrap && statusWrap.hidden),
      };
    });

    expect(result.hasToggle).toBe(true);
    expect(result.hasPopover).toBe(true);
    expect(result.initiallyHidden).toBe(true);
    expect(result.openedHidden).toBe(false);
    expect(result.posVisible).toBe(true);
    expect(result.sortVisible).toBe(true);
    expect(result.statusHidden).toBe(true);
  });

  test("Selecting filters updates badge and clear button resets them", async ({ page }) => {
    await loadAdminSession(page, "barangay_captain");

    const badgeInfo = await page.evaluate(() => {
      window.navigateTo("directory");
      const toggle = document.getElementById("peopleFilterToggle");
      const badge = document.getElementById("peopleFilterCount");
      const posSelect = document.getElementById("userPositionFilter");
      const clearBtn = document.getElementById("peopleFilterClear");

      // Initial count should be hidden / 0
      const initialBadgeHidden = badge?.hidden;

      // Select a position
      posSelect.value = "barangay_secretary";
      posSelect.dispatchEvent(new Event("change", { bubbles: true }));

      const countAfterChange = badge?.textContent;
      const badgeVisibleAfterChange = !badge?.hidden;
      const hasFilterClass = toggle?.classList.contains("has-filters");

      // Click clear all
      clearBtn?.click();

      const posAfterClear = posSelect.value;
      const badgeAfterClear = badge?.hidden;

      return {
        initialBadgeHidden,
        countAfterChange,
        badgeVisibleAfterChange,
        hasFilterClass,
        posAfterClear,
        badgeAfterClear,
      };
    });

    expect(badgeInfo.initialBadgeHidden).toBe(true);
    expect(badgeInfo.countAfterChange).toBe("1");
    expect(badgeInfo.badgeVisibleAfterChange).toBe(true);
    expect(badgeInfo.hasFilterClass).toBe(true);
    expect(badgeInfo.posAfterClear).toBe("all");
    expect(badgeInfo.badgeAfterClear).toBe(true);
  });

  test("Barangay Team table has natural, clean proportions without horizontal scrolling", async ({ page }) => {
    await page.setViewportSize({ width: 1200, height: 800 });
    await loadAdminSession(page, "barangay_captain");

    const tableLayout = await page.evaluate(() => {
      const { state, renderUsersAndVerifications } = window.__adminSession;

      // Mock an official in Barangay Vito
      state.users = [
        {
          id: "official-1",
          name: "Ana Jean Binggaan",
          username: "binggaananajean506@gmail.com",
          email: "binggaananajean506@gmail.com",
          role: "barangay_captain",
          positionTitle: "Barangay Captain",
          barangay: "Vito",
          barangayId: "vito",
          accountStatus: "active",
          status: "active",
          lastActiveAt: new Date().toISOString(),
        },
      ];

      window.navigateTo("directory");
      renderUsersAndVerifications();

      const tableWrap = document.getElementById("peopleAccountsTableWrap");
      const table = document.getElementById("peopleAccountsTable");
      const headers = [...table.querySelectorAll("thead th")].map((th) => th.textContent.trim());
      const firstRowCells = [...table.querySelectorAll("tbody tr:first-child td")];

      const wrapWidth = tableWrap.clientWidth;
      const tableWidth = table.offsetWidth;
      const scrollWidth = tableWrap.scrollWidth;

      // Check column widths of cells
      const cellWidths = firstRowCells.map((td) => td.getBoundingClientRect().width);
      const lastCellAlign = getComputedStyle(firstRowCells.at(-1)).textAlign;

      return {
        headers,
        wrapWidth,
        tableWidth,
        scrollWidth,
        cellCount: firstRowCells.length,
        cellWidths,
        lastCellAlign,
      };
    });

    expect(tableLayout.headers).toEqual(["OFFICIAL", "POSITION", "STATUS", "LAST ACTIVE"]);
    expect(tableLayout.cellCount).toBe(4);
    // Table should naturally fit within wrap with NO horizontal scrollbar
    expect(tableLayout.scrollWidth).toBeLessThanOrEqual(tableLayout.wrapWidth + 2);
    // Last column should NOT be squished to 76px and should be left-aligned
    expect(tableLayout.cellWidths[3]).toBeGreaterThan(120);
    expect(tableLayout.lastCellAlign).toBe("left");
  });

  test("Official details modal has simple title 'Official Details', no duplicate name in header, clean layout, and no horizontal scrollbar", async ({ page }) => {
    await page.setViewportSize({ width: 1200, height: 800 });
    await loadAdminSession(page, "barangay_captain");

    const modalData = await page.evaluate(() => {
      const { state, renderUsersAndVerifications } = window.__adminSession;

      const mockOfficial = {
        id: "official-123",
        name: "Ana Jean Binggaan",
        username: "binggaananajean506@gmail.com",
        email: "binggaananajean506@gmail.com",
        contactNumber: "0968 302 2242",
        role: "barangay_captain",
        positionTitle: "Barangay Captain",
        barangay: "Vito",
        barangayId: "vito",
        accountStatus: "active",
        status: "active",
        createdAt: "2026-09-23T06:02:00.000Z",
        lastActiveAt: new Date(Date.now() - 13 * 60000).toISOString(),
      };

      state.users = [mockOfficial];
      window.navigateTo("directory");
      renderUsersAndVerifications();

      // Open user modal
      window.openUser("official-123");

      const modalEl = document.getElementById("adminModal");
      const modalEyebrow = document.getElementById("modalEyebrow");
      const modalTitle = document.getElementById("modalTitle");
      const modalBody = document.getElementById("modalBody");
      const heroName = modalBody.querySelector(".user-detail-hero-3d__name");
      const heroPosition = modalBody.querySelector(".user-detail-hero-3d__position");

      const cards = [...modalBody.querySelectorAll(".user-detail-card")];
      const cardLabels = cards.map((c) => c.querySelector("small")?.textContent.trim());

      const bodyScrollWidth = modalBody.scrollWidth;
      const bodyClientWidth = modalBody.clientWidth;

      return {
        modalVisible: !modalEl?.hidden,
        eyebrowHidden: modalEyebrow?.classList.contains("sr-only"),
        eyebrowText: modalEyebrow?.textContent.trim(),
        modalTitleText: modalTitle?.textContent.trim(),
        heroNameText: heroName?.textContent.trim(),
        heroPositionText: heroPosition?.textContent.trim(),
        cardCount: cards.length,
        cardLabels,
        bodyScrollWidth,
        bodyClientWidth,
      };
    });

    expect(modalData.modalVisible).toBe(true);
    // Eyebrow should be hidden (no "Account Dossier")
    expect(modalData.eyebrowHidden).toBe(true);
    expect(modalData.eyebrowText).toBe("");
    // Title should be "Official Details", NOT "Ana Jean Binggaan" and NOT "Account Dossier"
    expect(modalData.modalTitleText).toBe("Official Details");
    // Hero inside modal displays official name and role cleanly
    expect(modalData.heroNameText).toBe("Ana Jean Binggaan");
    expect(modalData.heroPositionText).toContain("Barangay Captain");
    // All cards are clean siblings (no nested broken cards)
    expect(modalData.cardLabels).toContain("Login Email / Username");
    expect(modalData.cardLabels).toContain("Assigned Location");
    expect(modalData.cardLabels).toContain("Contact Number");
    expect(modalData.cardLabels).toContain("Date Registered");
    expect(modalData.cardLabels).toContain("Last Active");
    // Absolutely NO horizontal scrollbar in modal body
    expect(modalData.bodyScrollWidth).toBeLessThanOrEqual(modalData.bodyClientWidth);
  });
});
