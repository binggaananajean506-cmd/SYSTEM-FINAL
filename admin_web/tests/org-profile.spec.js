const { test, expect } = require('@playwright/test');
const { loadAdminSession } = require('./helpers/admin-session');

test.describe('Organization Profile and Header Flow', () => {
  test('header account button shows Organization Staff, is clickable, and navigates to Organization Profile', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'organization');

    const accountButton = page.locator('#accountButton');
    await expect(accountButton).toBeVisible();
    await expect(accountButton.locator('small')).toHaveText('Organization Staff');

    // Verify cursor is pointer
    const cursor = await accountButton.evaluate((el) => getComputedStyle(el).cursor);
    expect(cursor).toBe('pointer');

    // Click account card and verify navigation to Organization Profile
    await accountButton.click();
    await expect(page.locator('#page-settings')).toBeVisible();
    await expect(page.locator('#page-title')).toHaveText('Organization Profile');
    await expect(page.locator('#organizationProfileHeading')).toHaveText('Layout Organization');
    await expect(page.locator('#organizationProfileStatus')).toHaveText('Active');
  });

  test('profile fields are read-only by default, toggle to editable on Edit Profile, and cancel restores values', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'organization');

    // Navigate to settings / organization profile
    await page.locator('#accountButton').click();
    await expect(page.locator('#organizationProfileForm')).toBeVisible();

    const contactPerson = page.locator('#organizationProfileContactPerson');
    const contactNumber = page.locator('#organizationProfileContactNumber');
    const email = page.locator('#organizationProfileEmail');
    const address = page.locator('#organizationProfileAddress');
    const editBtn = page.locator('#orgEditProfileBtn');
    const cancelBtn = page.locator('#orgCancelEditBtn');
    const saveBtn = page.locator('#saveOrganizationProfile');

    // By default, read-only
    await expect(contactPerson).toHaveAttribute('readonly', '');
    await expect(contactNumber).toHaveAttribute('readonly', '');
    await expect(email).toHaveAttribute('readonly', '');
    await expect(address).toHaveAttribute('readonly', '');
    await expect(editBtn).toBeVisible();
    await expect(cancelBtn).toBeHidden();
    await expect(saveBtn).toBeHidden();

    // Click Edit Profile
    await editBtn.click();

    // Fields become editable
    await expect(contactPerson).not.toHaveAttribute('readonly', '');
    await expect(contactNumber).not.toHaveAttribute('readonly', '');
    await expect(email).not.toHaveAttribute('readonly', '');
    await expect(address).not.toHaveAttribute('readonly', '');
    await expect(editBtn).toBeHidden();
    await expect(cancelBtn).toBeVisible();
    await expect(saveBtn).toBeVisible();

    // Verify organization name and type remain read-only
    await expect(page.locator('#organizationProfileName')).toHaveAttribute('readonly', '');
    await expect(page.locator('#organizationProfileType')).toHaveAttribute('readonly', '');

    // Type new temporary values
    const originalPerson = await contactPerson.inputValue();
    await contactPerson.fill('Temporary Edit Name');
    expect(await contactPerson.inputValue()).toBe('Temporary Edit Name');

    // Click Cancel
    await cancelBtn.click();

    // Reverts to original value and read-only
    await expect(contactPerson).toHaveValue(originalPerson);
    await expect(contactPerson).toHaveAttribute('readonly', '');
    await expect(editBtn).toBeVisible();
    await expect(cancelBtn).toBeHidden();
    await expect(saveBtn).toBeHidden();
  });

  test('validates required fields, email format, and Philippine contact number', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'organization');

    await page.locator('#accountButton').click();
    await page.locator('#orgEditProfileBtn').click();

    const contactPerson = page.locator('#organizationProfileContactPerson');
    const contactNumber = page.locator('#organizationProfileContactNumber');
    const email = page.locator('#organizationProfileEmail');
    const address = page.locator('#organizationProfileAddress');
    const form = page.locator('#organizationProfileForm');
    const toast = page.locator('#toastRegion');

    // Test empty contact person
    await contactPerson.fill('');
    await contactNumber.fill('09171234567');
    await email.fill('valid@example.com');
    await address.fill('Barili, Cebu');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('Contact Person is required');

    // Test invalid Philippine contact number
    await contactPerson.fill('Juana Dela Cruz');
    await contactNumber.fill('12345'); // invalid
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('Enter a valid 11-digit Philippine mobile number starting with 09');

    // Test invalid email
    await contactNumber.fill('09181234567'); // valid PH mobile
    await email.fill('notanemail');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('Please enter a valid email address');

    // Test empty address
    await email.fill('contact@org.test');
    await address.fill('');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('Address is required');
  });

  test('outlined photo actions wrap is hidden on page, photo updates directly without save changes, and full photo viewer modal handles remove photo', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'organization');

    await page.locator('#accountButton').click();

    const fallback = page.locator('#orgAvatarFallback');
    const preview = page.locator('#orgAvatarPreview');
    const actionsWrap = page.locator('.org-photo-actions-wrap');
    const saveBtn = page.locator('#saveOrganizationProfile');

    // 1. Verify outlined element (.org-photo-actions-wrap) is NOT visible on page
    await expect(actionsWrap).toBeHidden();

    // By default without custom photo, fallback avatar is shown
    await expect(fallback).toBeVisible();
    await expect(preview).toBeHidden();

    // Save changes should be hidden initially
    await expect(saveBtn).toBeHidden();

    // 2. Trigger file input with simulated file
    await page.locator('#orgProfilePhotoInput').setInputFiles({
      name: 'avatar.png',
      mimeType: 'image/png',
      buffer: Buffer.from('fake-image-bytes'),
    });

    // 3. Preview should update immediately without entering edit mode (Save Changes remains hidden!)
    await expect(preview).toBeVisible();
    await expect(fallback).toBeHidden();
    await expect(saveBtn).toBeHidden();

    // 4. Click profile picture avatar to view whole profile photo in modal
    await page.locator('#orgAvatarClickable').click();
    const modalOverlay = page.locator('#profilePhotoModalOverlay');
    await expect(modalOverlay).toBeVisible();

    // 5. In modal, Remove Photo button is visible
    const modalRemoveBtn = page.locator('#profilePhotoModalRemoveBtn');
    await expect(modalRemoveBtn).toBeVisible();

    // 6. Click Remove Photo in modal
    await modalRemoveBtn.click();
    await expect(modalOverlay).toBeHidden();
    await expect(preview).toBeHidden();
    await expect(fallback).toBeVisible();
  });

  test('authorized users can edit credentials and change password in edit mode with old password verification and eye icon toggle', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await loadAdminSession(page, 'organization');

    await page.locator('#accountButton').click();

    const currPw = page.locator('#orgCurrentPassword');
    const newPw = page.locator('#orgNewPassword');
    const confirmPw = page.locator('#orgConfirmPassword');
    const editBtn = page.locator('#orgEditProfileBtn');
    const cancelBtn = page.locator('#orgCancelEditBtn');
    const form = page.locator('#organizationProfileForm');
    const toast = page.locator('#toastRegion');

    // Verify outlined elements are completely hidden
    await expect(page.locator('.org-security-notice')).toBeHidden();
    await expect(page.locator('#orgFooterLockText')).toBeHidden();

    // By default, password fields are read-only
    await expect(currPw).toHaveAttribute('readonly', '');
    await expect(newPw).toHaveAttribute('readonly', '');
    await expect(confirmPw).toHaveAttribute('readonly', '');

    // Click Edit Profile
    await editBtn.click();
    await expect(currPw).not.toHaveAttribute('readonly', '');
    await expect(newPw).not.toHaveAttribute('readonly', '');
    await expect(confirmPw).not.toHaveAttribute('readonly', '');

    // Ensure contact fields are populated so password validation triggers on submit
    await page.locator('#organizationProfileContactPerson').fill('Layout Test');
    await page.locator('#organizationProfileContactNumber').fill('09171234567');
    await page.locator('#organizationProfileEmail').fill('layout@example.test');
    await page.locator('#organizationProfileAddress').fill('Barili, Cebu');

    // Test missing current/old password when new password is typed
    await newPw.fill('newSecret123');
    await confirmPw.fill('newSecret123');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('Please enter your current (old) password');

    // Test short new password validation (< 6 chars)
    await currPw.fill('oldPass123');
    await newPw.fill('123');
    await confirmPw.fill('123');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('New password must be at least 6 characters long');

    // Test new password matching old password
    await newPw.fill('oldPass123');
    await confirmPw.fill('oldPass123');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('New password must be different from your current (old) password');

    // Test password mismatch
    await newPw.fill('securePass123');
    await confirmPw.fill('differentPass456');
    await form.evaluate((f) => f.requestSubmit());
    await expect(toast).toContainText('New passwords do not match');

    // Test eye icon toggle
    const toggleBtn = page.locator('[data-toggle-password="orgNewPassword"]');
    await expect(newPw).toHaveAttribute('type', 'password');
    await toggleBtn.click();
    await expect(newPw).toHaveAttribute('type', 'text');
    await toggleBtn.click();
    await expect(newPw).toHaveAttribute('type', 'password');

    // Cancel edit reverts password fields to read-only
    await cancelBtn.click();
    await expect(currPw).toHaveAttribute('readonly', '');
    await expect(newPw).toHaveAttribute('readonly', '');
    await expect(confirmPw).toHaveAttribute('readonly', '');
  });
});
