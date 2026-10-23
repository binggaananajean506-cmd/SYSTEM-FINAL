const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test.describe('Barangay Analytics Chart Visibility', () => {
  test('renders 3D Wave chart and toggles to 3D Pillars without errors', async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));

    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay');

    const canvas = page.locator('#barangayAnalyticsChart');
    await expect(canvas).toBeVisible();

    const chartState = await page.evaluate(() => {
      const chart = window.__adminSession?.state?.charts?.barangayAnalyticsChart;
      return {
        exists: !!chart,
        type: chart?.config?.type,
        datasetsCount: chart?.data?.datasets?.length || 0,
        labelsCount: chart?.data?.labels?.length || 0
      };
    });

    expect(chartState.exists).toBe(true);
    expect(chartState.type).toBe('line');
    expect(chartState.datasetsCount).toBeGreaterThan(0);
    expect(chartState.labelsCount).toBeGreaterThan(0);

    // Toggle to Pillars
    const pillarsBtn = page.locator('[data-barangay-chart-type="pillars"]');
    await expect(pillarsBtn).toBeVisible();
    await pillarsBtn.click();
    await page.waitForTimeout(300);

    const pillarsState = await page.evaluate(() => {
      const chart = window.__adminSession?.state?.charts?.barangayAnalyticsChart;
      return {
        exists: !!chart,
        type: chart?.config?.type,
        datasetsCount: chart?.data?.datasets?.length || 0
      };
    });

    expect(pillarsState.exists).toBe(true);
    expect(pillarsState.type).toBe('bar');
    expect(pillarsState.datasetsCount).toBeGreaterThan(0);

    // Toggle back to Wave
    const waveBtn = page.locator('[data-barangay-chart-type="wave"]');
    await expect(waveBtn).toBeVisible();
    await waveBtn.click();
    await page.waitForTimeout(300);

    const waveState = await page.evaluate(() => {
      const chart = window.__adminSession?.state?.charts?.barangayAnalyticsChart;
      return {
        exists: !!chart,
        type: chart?.config?.type,
        datasetsCount: chart?.data?.datasets?.length || 0
      };
    });

    expect(waveState.exists).toBe(true);
    expect(waveState.type).toBe('line');
    expect(waveState.datasetsCount).toBeGreaterThan(0);

    // Ensure zero page errors
    expect(pageErrors).toEqual([]);
  });

  test('Barangay analytics supports functional Complaints tab with Received and Resolved datasets', async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));

    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay');

    // Verify Complaints tab button exists in the barangay analytics tabs
    const complaintsTab = page.locator('[data-barangay-analytics-tab="complaints"]');
    await expect(complaintsTab).toBeVisible();
    await expect(complaintsTab).toContainText('Complaints');
    await expect(complaintsTab.locator('.material-symbols-rounded')).toHaveText('gavel');

    // Populate mock complaints in state
    await page.evaluate(() => {
      const now = new Date();
      const yesterday = new Date(Date.now() - 86400000);
      window.__adminSession.state.complaints = [
        {
          id: 'CMP-001',
          barangayId: 'vito',
          barangay: 'Vito',
          kind: 'complaint',
          status: 'filed',
          date: now.toISOString(),
          createdAt: now.toISOString()
        },
        {
          id: 'CMP-002',
          barangayId: 'vito',
          barangay: 'Vito',
          kind: 'complaint',
          status: 'resolved',
          closureOutcome: 'settled',
          date: yesterday.toISOString(),
          createdAt: yesterday.toISOString(),
          resolvedAt: now.toISOString()
        }
      ];
    });

    // Click the Complaints tab
    await complaintsTab.click();
    await expect(complaintsTab).toHaveClass(/active/);
    await expect(complaintsTab).toHaveAttribute('aria-selected', 'true');

    // Check chart datasets
    const chartInfo = await page.evaluate(() => {
      const chart = window.__adminSession?.state?.charts?.barangayAnalyticsChart;
      return {
        exists: !!chart,
        currentTab: window.__adminSession?.state?.barangayAnalyticsTab,
        datasets: chart?.data?.datasets?.map(ds => ({
          label: ds.label,
          borderColor: ds.borderColor,
          dataCount: ds.data?.length || 0,
          sum: ds.data?.reduce((a, b) => a + b, 0) || 0
        }))
      };
    });

    expect(chartInfo.exists).toBe(true);
    expect(chartInfo.currentTab).toBe('complaints');
    expect(chartInfo.datasets?.length).toBe(2);
    expect(chartInfo.datasets[0].label).toBe('Received');
    expect(chartInfo.datasets[0].sum).toBe(2); // 2 total received
    expect(chartInfo.datasets[1].label).toBe('Resolved');
    expect(chartInfo.datasets[1].sum).toBe(1); // 1 resolved

    // Check legend items
    const legendItems = page.locator('#barangayAnalyticsLegend button');
    await expect(legendItems).toHaveCount(2);
    await expect(legendItems.nth(0)).toContainText('Received');
    await expect(legendItems.nth(1)).toContainText('Resolved');

    // Toggle chart type to pillars while on Complaints tab
    const pillarsBtn = page.locator('[data-barangay-chart-type="pillars"]');
    await pillarsBtn.click();
    const pillarType = await page.evaluate(() => window.__adminSession?.state?.charts?.barangayAnalyticsChart?.config?.type);
    expect(pillarType).toBe('bar');

    expect(pageErrors).toEqual([]);
  });

  test('Notification bell shows a single proper badge without duplicate inner dot', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'barangay');

    // Inject a pending concern notice so notification count = 1
    await page.evaluate(() => {
      window.__adminSession.state.concernFlagNotices = [
        { id: 'flag-1', read: false, createdAt: new Date().toISOString(), residentId: 'r-1', reason: 'Review required' }
      ];
      window.__adminSession.state.residentVerifications = [
        { id: 'r-1', name: 'Maria Santos', barangayId: 'vito', barangay: 'Vito' }
      ];
      window.__adminSession.renderDashboard();
    });

    const workQueueButton = page.locator('#workQueueButton');
    await expect(workQueueButton).toBeVisible();

    const badge = page.locator('#notificationBadge');
    await expect(badge).toBeVisible();
    await expect(badge).toHaveText('1');

    // Verify dot is NOT displayed
    const dotVisible = await page.evaluate(() => {
      const dot = document.getElementById('notificationDot');
      if (!dot) return false;
      const style = window.getComputedStyle(dot);
      return style.display !== 'none' && style.visibility !== 'hidden' && !dot.hidden;
    });
    expect(dotVisible).toBe(false);

    // Verify that inside #workQueueButton there is only exactly 1 visible badge element
    const visibleBadgesCount = await page.evaluate(() => {
      const btn = document.getElementById('workQueueButton');
      if (!btn) return 0;
      const elements = btn.querySelectorAll('.notification-badge, i');
      let visible = 0;
      elements.forEach(el => {
        const style = window.getComputedStyle(el);
        if (style.display !== 'none' && style.visibility !== 'hidden' && !el.hidden) {
          visible++;
        }
      });
      return visible;
    });
    expect(visibleBadgesCount).toBe(1);
  });

  test('Admin dashboard analytics does NOT have Complaints tab', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'super_admin');

    const adminTabs = page.locator('#adminAnalyticsTabs');
    await expect(adminTabs).toBeVisible();

    const complaintTabInAdmin = page.locator('#adminAnalyticsTabs [data-admin-analytics-tab="complaints"]');
    await expect(complaintTabInAdmin).toHaveCount(0);
  });

  test('Admin concerns page provides view-only municipal registry without action buttons', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'super_admin');

    // Populate a test concern in state
    await page.evaluate(() => {
      window.__adminSession.state.concerns = [
        {
          id: 'CON-TEST-001',
          title: 'Streetlight maintenance requested',
          category: 'Streetlight',
          description: 'Streetlight on Purok 3 is not functioning.',
          status: 'new',
          barangay: 'Vito',
          barangayId: 'vito',
          barangayName: 'Vito',
          createdAt: new Date().toISOString()
        }
      ];
    });

    await page.locator('.nav-link[data-page="concerns"]').click();
    await expect(page.locator('#pageOutlet > #page-concerns')).toBeVisible();

    // Check header/browser title
    const browserTitle = page.locator('.concern-browser-title');
    await expect(browserTitle).toBeVisible();
    await expect(browserTitle).toHaveText('Barangay Concern Records');

    // Open concern
    await page.evaluate(() => {
      window.openConcern('CON-TEST-001');
    });

    // Check oversight card
    const oversightCard = page.locator('.action-card--admin-oversight');
    await expect(oversightCard).toBeVisible();
    await expect(oversightCard).toContainText('Barangay Vito Jurisdiction · View-Only Record');
    await expect(oversightCard).toContainText('Municipal administration retains read-only access');

    // Ensure no direct status modification buttons exist inside oversight card
    const actionButtons = oversightCard.locator('button');
    await expect(actionButtons).toHaveCount(0);

    // Verify subpage switcher shows Record Status
    const subnavActions = page.locator('#subnavBtnActions');
    await expect(subnavActions).toContainText('Record Status');

    // Attempting openConcernStatusModal should trigger view-only notice
    await page.evaluate(() => {
      window.openConcernStatusModal('CON-TEST-001');
    });
    const toast = page.locator('#toastRegion .toast');
    await expect(toast).toBeVisible();
    await expect(toast).toContainText('Municipal administration has view-only access');
  });
});


