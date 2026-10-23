"use strict";

const INSTITUTIONAL_ACCOUNT_ROLES = new Set([
  "mayor",
  "lgu",
  "barangay_captain",
  "barangay_vice_captain",
  "barangay_secretary",
  "barangay_councilor",
  "organization",
]);

const ACCOUNT_REJECTION_REASONS = new Set([
  "Requested role could not be confirmed",
  "Person is not authorized for this position",
  "Requested role could not be verified",
  "User is not authorized for this position",
  "Incorrect account information",
  "Information could not be verified",
  "Invalid role request",
  "Incorrect requested role",
  "Incorrect barangay information",
  "Incorrect barangay/organization information",
  "Duplicate account",
  "Account not authorized",
  "Other",
  "Information is incomplete",
  "Document is unreadable",
  "Wrong proof document",
  "Information does not match the proof",
  "Unable to verify account",
  "Position already assigned",
]);

const SECONDARY_BARANGAY_POSITIONS = Object.freeze({
  barangay_treasurer: "Barangay Treasurer",
  barangay_kagawad: "Barangay Kagawad",
  barangay_staff: "Barangay Staff",
  barangay_tanod: "Barangay Tanod",
  sk_chairperson: "SK Chairperson",
  other_position: "Other Position",
});

function normalizeRole(value) {
  const role = String(value || "").trim().toLowerCase();
  if (role === "barangay") return "barangay_captain";
  if (role === "partner") return "organization";
  if (role === "municipal_mayor") return "mayor";
  return role;
}

function canReviewAccountRequest(reviewerRole, requestedRole) {
  const reviewer = normalizeRole(reviewerRole);
  const target = normalizeRole(requestedRole);
  return reviewer === "super_admin" && INSTITUTIONAL_ACCOUNT_ROLES.has(target);
}

function canDirectlyCreateRole(creatorRole, requestedRole) {
  const creator = normalizeRole(creatorRole);
  const target = normalizeRole(requestedRole);
  return creator === "super_admin"
    && ["mayor", "lgu", "barangay_captain", "barangay_vice_captain", "barangay_secretary", "barangay_councilor", "organization"].includes(target);
}

function isValidAccountRejectionReason(value) {
  return ACCOUNT_REJECTION_REASONS.has(String(value || "").trim());
}

function secondaryBarangayPositionLabel(value) {
  return SECONDARY_BARANGAY_POSITIONS[String(value || "").trim().toLowerCase()] || "";
}

function isAllowedAccountRequest(role, positionCode) {
  const target = normalizeRole(role);
  if (target === "lgu" || target === "organization") return !positionCode;
  if (["barangay_captain", "barangay_secretary", "barangay_vice_captain"].includes(target)) {
    return !positionCode || positionCode === target;
  }
  return target === "barangay_councilor" && Boolean(secondaryBarangayPositionLabel(positionCode));
}

function requiresUniqueBarangayPosition(positionCode) {
  return String(positionCode || "").trim().toLowerCase() === "barangay_treasurer";
}

function canClaimAccountRequest(status, reviewStartedAtMillis, nowMillis = Date.now()) {
  const normalizedStatus = String(status || "").trim().toLowerCase();
  if (normalizedStatus === "pending") return true;
  return normalizedStatus === "reviewing"
    && Number(reviewStartedAtMillis || 0) < nowMillis - 2 * 60 * 1000;
}

module.exports = {
  ACCOUNT_REJECTION_REASONS,
  INSTITUTIONAL_ACCOUNT_ROLES,
  SECONDARY_BARANGAY_POSITIONS,
  canClaimAccountRequest,
  canDirectlyCreateRole,
  canReviewAccountRequest,
  isAllowedAccountRequest,
  isValidAccountRejectionReason,
  requiresUniqueBarangayPosition,
  secondaryBarangayPositionLabel,
};
