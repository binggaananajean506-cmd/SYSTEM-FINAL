const { readFileSync } = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test, expect } = require("@playwright/test");

const source = readFileSync(path.join(__dirname, "..", "app.js"), "utf8");
const start = source.indexOf("function concernReportCategoryRows(groups, total) {");
const end = source.indexOf("\nwindow.openConcernReportCategory", start);
if (start < 0 || end < 0) throw new Error("Concern report renderer was not found.");
const reportRenderer = source.slice(start, end);

function renderReport(items) {
  const target = { innerHTML: "" };
  const context = {
    window: {},
    state: { concernReportSort: { key: "latest", direction: "desc" }, concernReportCategory: null, concernStatus: "new" },
    concernReportItems: () => items,
    concernReportDate: (item) => new Date(item.date),
    normalize: (value) => String(value).toLowerCase(),
    escapeHtml: (value) => String(value),
    escapeAttribute: (value) => String(value),
    formatNumber: (value) => String(value),
    formatShortDate: (value) => new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(value),
    statusLabel: () => "Active",
    renderConcerns: () => {},
  };
  vm.runInNewContext(reportRenderer, context);
  context.renderConcernReport(target);
  return { html: target.innerHTML, sort: context.window.setConcernReportSort, context };
}

const records = [
  { id: "CON-1", category: "Roads", date: "2026-09-27" },
  { id: "CON-2", category: "Public Safety", date: "2026-09-28" },
  { id: "CON-3", category: "Roads", date: "2026-09-26" },
];

test("shared concern report groups categories and keeps controls compact", async ({ page }) => {
  const { html } = renderReport(records);
  await page.setViewportSize({ width: 390, height: 800 });
  await page.goto("/");
  const sourceHtml = await (await page.request.get("/")).text();
  await page.evaluate(({ sourceHtml, html }) => {
    const section = new DOMParser().parseFromString(sourceHtml, "text/html").getElementById("page-concerns");
    document.body.replaceChildren(document.importNode(section, true));
    const mounted = document.getElementById("page-concerns");
    mounted.style.display = "block";
    mounted.classList.add("concern-table-report");
    document.getElementById("concernDocumentGrid").innerHTML = html;
  }, { sourceHtml, html });

  const table = page.locator(".concern-report-table");
  await expect(table.locator("thead th")).toHaveCount(5);
  await expect(table.locator("thead th").nth(1)).toContainText("Category");
  await expect(table.locator("thead th").nth(3)).toContainText("% of Reports");
  await expect(table.locator("tbody tr")).toHaveCount(2);
  await expect(table.locator("tbody tr").first()).toContainText("Public Safety");
  await expect(table.locator("tbody tr").nth(1)).toContainText("Roads");
  await expect(table.locator("tbody tr").nth(1)).toContainText("66.7%");
  await expect(table.locator("tfoot")).toContainText("100%");
  expect(await page.locator(".concern-browser-header #concernReportYear").count()).toBe(1);
  expect(await page.locator(".concern-browser-header #concernReportMonth").count()).toBe(1);
  const dimensions = await page.evaluate(() => ({
    pageWidth: document.documentElement.scrollWidth,
    tableViewportWidth: document.querySelector(".concern-report-table-wrap").clientWidth,
    tableScrollWidth: document.querySelector(".concern-report-table-wrap").scrollWidth,
  }));
  expect(dimensions.pageWidth).toBeLessThanOrEqual(390);
  expect(dimensions.tableScrollWidth).toBeGreaterThan(dimensions.tableViewportWidth);

  await page.setViewportSize({ width: 1280, height: 800 });
  const desktop = await page.evaluate(() => ({
    headingTop: document.querySelector(".concern-browser-heading").getBoundingClientRect().top,
    filterTop: document.querySelector("#concernFilterToggle").getBoundingClientRect().top,
    pageWidth: document.documentElement.scrollWidth,
  }));
  expect(Math.abs(desktop.headingTop - desktop.filterTop)).toBeLessThan(10);
  expect(desktop.pageWidth).toBeLessThanOrEqual(1280);
});

test("category sorting changes the report order", () => {
  const { sort, context } = renderReport(records);
  sort("category");
  expect(context.state.concernReportSort).toEqual({ key: "category", direction: "asc" });
});
