const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');
const { instrumentAdminBundle } = require('./helpers/admin-bundle');

test('registration mobile input keeps only eleven digits for typing and paste', async ({ page }) => {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle('window.__mobileAuth = auth; window.__mobilePhoneValid = validPhilippineContact;') });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__mobileAuth));
  await page.evaluate(() => window.__mobileAuth.authStateReady());
  expect(await page.evaluate(() => window.__mobilePhoneValid('9123456789'))).toBe(false);
  await page.evaluate(() => {
    for (const screen of document.querySelectorAll('body > main')) {
      screen.hidden = screen.id !== 'organization-registration-screen';
      screen.style.display = screen.hidden ? 'none' : '';
    }
  });
  const input = page.locator('#registrationContactNumber');
  await input.evaluate(element => {
    // Display this registration step without submitting any staff information.
    for (let parent = element.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
      parent.hidden = false;
      if (parent instanceof HTMLFieldSetElement) parent.disabled = false;
      parent.style.setProperty('display', 'block', 'important');
    }
  });
  await expect(input).toHaveAttribute('maxlength', '11');
  await input.fill('08123456789');
  expect(await input.evaluate(element => element.checkValidity())).toBe(false);
  await input.fill('0912345678');
  expect(await input.evaluate(element => element.checkValidity())).toBe(false);
  await input.fill('');
  await input.click();
  await input.pressSequentially('0912345678912345abc');
  await expect(input).toHaveValue('09123456789');
  await input.evaluate((element) => {
    const transfer = new DataTransfer();
    transfer.setData('text/plain', '0912 345 6789 letters');
    element.value = '';
    element.dispatchEvent(new ClipboardEvent('paste', { clipboardData: transfer, bubbles: true, cancelable: true }));
  });
  await expect(input).toHaveValue('09123456789');
  await expect(input).toHaveAttribute('maxlength', '11');
});

for (const role of ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary']) {
  test(`${role} has verification access without a legacy account flag`, async ({ page }) => {
    await loadAdminSession(page, role);
    await page.evaluate(role => {
      window.configureRoleAccess({ role, name: 'Cabcaban Official', status: 'approved',
        barangay: 'Cabcaban', barangayId: 'barili_cabcaban' });
    }, role);
    await expect(page.locator('#residentVerificationNavButton')).toBeVisible();
    await page.locator('#residentVerificationNavButton').click();
    await expect(page.locator('#admin-dashboard')).toBeVisible();
    await expect(page.locator('#login-screen')).toBeHidden();
  });
}

test('all 42 barangays enforce role defaults, own-barangay scope, and explicit revocation', async ({ page }) => {
  await page.route('**/app.bundle.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await instrumentAdminBundle(
      'window.__allBarangayAccess = { state, auth, roleCapabilities, canViewResidentVerification, BARANGAYS, barangayIdFor };'
    ) });
  });
  await page.goto('/');
  await page.waitForFunction(() => Boolean(window.__allBarangayAccess));
  await page.evaluate(() => window.__allBarangayAccess.auth.authStateReady());
  const result = await page.evaluate(() => {
    const { state, roleCapabilities, canViewResidentVerification, BARANGAYS, barangayIdFor } = window.__allBarangayAccess;
    const failures = [];
    let checked = 0;
    for (const [index, barangay] of BARANGAYS.entries()) {
      const ownId = barangayIdFor(barangay);
      const otherId = barangayIdFor(BARANGAYS[(index + 1) % BARANGAYS.length]);
      for (const role of ['barangay_captain', 'barangay_vice_captain', 'barangay_secretary']) {
        for (const flag of [undefined, false]) {
          state.currentProfile = { role, barangay, barangayId: ownId, canVerifyResidents: flag };
          state.currentAccessPolicy = {};
          state.capabilities = roleCapabilities(role);
          if (!canViewResidentVerification({ role: 'resident', barangayId: ownId })) failures.push(`${barangay}: ${role} blocked`);
          if (canViewResidentVerification({ role: 'resident', barangayId: otherId })) failures.push(`${barangay}: cross-barangay access`);
          state.currentAccessPolicy = { denied: ['verifications:local'] };
          state.capabilities = roleCapabilities(role);
          if (canViewResidentVerification({ role: 'resident', barangayId: ownId })) failures.push(`${barangay}: ignored denial`);
          checked++;
        }
      }
    }
    return { barangays: BARANGAYS.length, checked, failures };
  });
  expect(result.barangays).toBe(42);
  expect(result.checked).toBe(252);
  expect(result.failures).toEqual([]);
});

test('reviewer settings show leader defaults and reserve delegation switches for other officials', async ({ page }) => {
  await loadAdminSession(page, 'barangay_captain');
  await page.evaluate(() => {
    window.__adminSession.state.verificationReviewers = [
      { id: 'captain', role: 'barangay_captain', name: 'Test Captain', canVerifyResidents: false },
      { id: 'vice', role: 'barangay_vice_captain', name: 'Test Vice Captain' },
      { id: 'secretary', role: 'barangay_secretary', name: 'Test Secretary' },
      { id: 'councilor', role: 'barangay_councilor', name: 'Test Councilor', canVerifyResidents: false },
    ];
    window.openVerificationReviewerManager();
  });
  for (const name of ['Test Captain', 'Test Vice Captain', 'Test Secretary']) {
    const checkbox = page.getByRole('checkbox', { name: `Allow ${name} to verify residents`, exact: true });
    await expect(checkbox).toBeChecked();
    await expect(checkbox).toBeDisabled();
  }
  const delegated = page.getByRole('checkbox', { name: 'Allow Test Councilor to verify residents', exact: true });
  await expect(delegated).not.toBeChecked();
  await expect(delegated).toBeEnabled();
});
