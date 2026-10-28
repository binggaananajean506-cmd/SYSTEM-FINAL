const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { pathToFileURL } = require('node:url');
const path = require('node:path');

async function readState(storage) {
  const module = await import(pathToFileURL(path.join(__dirname, '../notification_read_state.mjs')).href);
  return module.createNotificationReadState(() => storage);
}

test('read markers survive storage reloads and distinguish item types and resubmissions', async () => {
  const saved = new Map();
  const storage = { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value) };
  const item = { type: 'verification', id: 'resident-1', timestamp: 1000 };
  const first = await readState(storage);
  first.markSeen('official-1', [item]);
  const reloaded = await readState(storage);
  expect(reloaded.unreadCount('official-1', [item])).toBe(0);
  expect(reloaded.unreadCount('official-2', [item])).toBe(1);
  expect(reloaded.unreadCount('official-1', [{ ...item, timestamp: 2000 }])).toBe(1);
  expect(reloaded.unreadCount('official-1', [{ ...item, type: 'concern' }])).toBe(1);
});

test('the badge still clears if browser storage is blocked or malformed', async () => {
  const blocked = { getItem() { throw new Error('blocked'); }, setItem() { throw new Error('blocked'); } };
  for (const storage of [blocked, { getItem: () => '{invalid', setItem() {} }]) {
    const state = await readState(storage);
    const items = [{ type: 'concernFlag', id: 'notice-1', timestamp: 1000 }];
    expect(state.unreadCount('official', items)).toBe(1);
    state.markSeen('official', items);
    expect(state.unreadCount('official', items)).toBe(0);
  }
});

test('opening a large inbox clears every current badge item after a reload', async () => {
  const saved = new Map();
  const storage = { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value) };
  const items = Array.from({ length: 2500 }, (_, i) => ({ type: 'concern', id: `record-${i}`, timestamp: i }));
  const state = await readState(storage);
  state.markSeen('official', items);
  expect((await readState(storage)).unreadCount('official', items)).toBe(0);
});

async function seedNotifications(page, userId = 'notification-reader') {
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(userId => {
    const { state, renderDashboard } = window.__adminSession;
    state.currentProfile.id = userId;
    state.concernFlagNotices = [1, 2, 3].map(number => ({
      id: `notice-${number}`, read: false, residentId: `resident-${number}`,
      reason: 'Review required', createdAt: '2026-10-27T01:00:00Z',
    }));
    renderDashboard();
  }, userId);
}

test('opening notifications clears the badge without resolving the pending work', async ({ page }) => {
  await seedNotifications(page);
  const badge = page.locator('#notificationBadge');
  await expect(badge).toHaveText('3');
  await expect(badge).toBeVisible();
  await page.locator('#workQueueButton').click();
  await expect(page.locator('.work-queue-item')).toHaveCount(3);
  await expect(badge).toBeHidden();
  await page.evaluate(() => { window.closeModal(); window.__adminSession.renderDashboard(); });
  await expect(badge).toBeHidden();
  expect(await page.evaluate(() => window.__adminSession.state.concernFlagNotices.every(item => item.read === false))).toBe(true);
});

test('seen notifications stay cleared after a reload and only new arrivals raise the badge', async ({ page }) => {
  await seedNotifications(page);
  await page.locator('#workQueueButton').click();
  await seedNotifications(page);
  const badge = page.locator('#notificationBadge');
  await expect(badge).toBeHidden();
  await page.evaluate(() => {
    const { state, renderDashboard } = window.__adminSession;
    state.concernFlagNotices.push({ id: 'new-notice', read: false,
      residentId: 'new-resident', createdAt: '2026-10-27T02:00:00Z' });
    renderDashboard();
  });
  await expect(badge).toBeVisible();
  await expect(badge).toHaveText('1');
  await page.locator('#workQueueButton').click();
  await expect(page.locator('.work-queue-item')).toHaveCount(4);
  await expect(badge).toBeHidden();
});

test('one account viewing notifications does not clear another account badge', async ({ page }) => {
  await seedNotifications(page, 'first-official');
  await page.locator('#workQueueButton').click();
  await seedNotifications(page, 'second-official');
  await expect(page.locator('#notificationBadge')).toHaveText('3');
  await expect(page.locator('#notificationBadge')).toBeVisible();
});
