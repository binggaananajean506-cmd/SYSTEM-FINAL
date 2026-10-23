"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canClaimAccountRequest,
  canDirectlyCreateRole,
  canReviewAccountRequest,
  isAllowedAccountRequest,
  isValidAccountRejectionReason,
  requiresUniqueBarangayPosition,
  secondaryBarangayPositionLabel,
} = require("./account_approval_helpers");

test("only the IT administrator reviews institutional account requests", () => {
  assert.equal(canReviewAccountRequest("super_admin", "barangay_secretary"), true);
  assert.equal(canReviewAccountRequest("super_admin", "organization"), true);
  assert.equal(canReviewAccountRequest("super_admin", "lgu"), true);
  assert.equal(canReviewAccountRequest("lgu", "barangay_secretary"), false);
  assert.equal(canReviewAccountRequest("lgu", "organization"), false);
  assert.equal(canReviewAccountRequest("barangay_captain", "barangay_secretary"), false);
  assert.equal(canReviewAccountRequest("organization", "organization"), false);
});

test("only the IT administrator directly creates managed staff roles", () => {
  assert.equal(canDirectlyCreateRole("super_admin", "lgu"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "mayor"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "municipal_mayor"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "barangay_captain"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "barangay_vice_captain"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "barangay_secretary"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "organization"), true);
  assert.equal(canDirectlyCreateRole("super_admin", "barangay_councilor"), true);
  assert.equal(canDirectlyCreateRole("lgu", "lgu"), false);
  assert.equal(canDirectlyCreateRole("barangay_captain", "barangay_secretary"), false);
  assert.equal(canDirectlyCreateRole("super_admin", "super_admin"), false);
  assert.equal(canDirectlyCreateRole("mayor", "lgu"), false);
});

test("only the System Administrator reviews LGU account requests", () => {
  assert.equal(canReviewAccountRequest("super_admin", "lgu"), true);
  assert.equal(canReviewAccountRequest("lgu", "lgu"), false);
  assert.equal(canReviewAccountRequest("lgu", "super_admin"), false);
});

test("account rejection reasons use the controlled list", () => {
  assert.equal(isValidAccountRejectionReason("Requested role could not be confirmed"), true);
  assert.equal(isValidAccountRejectionReason("Person is not authorized for this position"), true);
  assert.equal(isValidAccountRejectionReason("Requested role could not be verified"), true);
  assert.equal(isValidAccountRejectionReason("User is not authorized for this position"), true);
  assert.equal(isValidAccountRejectionReason("Incorrect account information"), true);
  assert.equal(isValidAccountRejectionReason("Invalid role request"), true);
  assert.equal(isValidAccountRejectionReason("Incorrect barangay information"), true);
  assert.equal(isValidAccountRejectionReason("Incorrect requested role"), true);
  assert.equal(isValidAccountRejectionReason("Other"), true);
  assert.equal(isValidAccountRejectionReason("because I said so"), false);
});

test("only scoped staff requests enter IT account approvals", () => {
  assert.equal(isAllowedAccountRequest("lgu", ""), true);
  assert.equal(isAllowedAccountRequest("lgu", "barangay_treasurer"), false);
  assert.equal(isAllowedAccountRequest("barangay_councilor", "barangay_treasurer"), true);
  assert.equal(isAllowedAccountRequest("barangay_councilor", "barangay_tanod"), true);
  assert.equal(isAllowedAccountRequest("barangay_councilor", "barangay_kagawad"), true);
  assert.equal(isAllowedAccountRequest("barangay_councilor", "barangay_staff"), true);
  assert.equal(isAllowedAccountRequest("barangay_councilor", ""), false);
  assert.equal(isAllowedAccountRequest("barangay_vice_captain", ""), true);
  assert.equal(isAllowedAccountRequest("barangay_secretary", ""), true);
  assert.equal(isAllowedAccountRequest("organization", ""), true);
  assert.equal(isAllowedAccountRequest("organization", "barangay_tanod"), false);
  assert.equal(isAllowedAccountRequest("barangay_councilor", "barangay_captain"), false);
  assert.equal(isAllowedAccountRequest("barangay_captain", ""), true);
  assert.equal(isAllowedAccountRequest("resident", ""), false);
});

test("only single-occupancy secondary roles require a uniqueness check", () => {
  assert.equal(requiresUniqueBarangayPosition("barangay_treasurer"), true);
  assert.equal(requiresUniqueBarangayPosition("barangay_kagawad"), false);
  assert.equal(requiresUniqueBarangayPosition("barangay_staff"), false);
});

test("secondary barangay positions are controlled and exclude direct roles", () => {
  assert.equal(secondaryBarangayPositionLabel("barangay_treasurer"), "Barangay Treasurer");
  assert.equal(secondaryBarangayPositionLabel("barangay_kagawad"), "Barangay Kagawad");
  assert.equal(secondaryBarangayPositionLabel("barangay_captain"), "");
  assert.equal(secondaryBarangayPositionLabel("barangay_secretary"), "");
  assert.equal(secondaryBarangayPositionLabel("made_up_role"), "");
});

test("review claims prevent conflicting approval decisions", () => {
  const now = 1_000_000;
  assert.equal(canClaimAccountRequest("pending", 0, now), true);
  assert.equal(canClaimAccountRequest("reviewing", now - 30_000, now), false);
  assert.equal(canClaimAccountRequest("reviewing", now - 180_000, now), true);
  assert.equal(canClaimAccountRequest("approved", 0, now), false);
  assert.equal(canClaimAccountRequest("rejected", 0, now), false);
});
