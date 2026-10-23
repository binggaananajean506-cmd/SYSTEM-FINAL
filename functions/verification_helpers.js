const BARILI_BARANGAYS = Object.freeze([
  "Azucena", "Bagakay", "Balao", "Bolocboloc", "Budbud", "Bugtong Kawayan",
  "Cabcaban", "Campangga", "Dakit", "Giloctog", "Guibuangan", "Giwanon",
  "Gunting", "Hilasgasan", "Japitan", "Cagay", "Kalubihan", "Kangdampas",
  "Candugay", "Luhod", "Lupo", "Luyo", "Maghanoy", "Maigang", "Malolos",
  "Mantalongon", "Mantayupan", "Mayana", "Minolos", "Nabunturan", "Nasipit",
  "Pancil", "Pangpang", "Paril", "Patupat", "Poblacion", "San Rafael",
  "Santa Ana", "Sayaw", "Tal-ot", "Tubod", "Vito",
]);

const VERIFICATION_ATTENTION_REASONS = new Set([
  "Document unreadable",
  "Wrong document uploaded",
  "Address not visible",
  "Document does not sufficiently prove residency",
  "Information needs clarification",
  "Other",
]);

const VERIFICATION_REJECTION_REASONS = new Set([
  "Not a resident of this barangay",
  "Fraudulent or invalid document",
  "Identity mismatch",
  "Duplicate account registration",
  "Unable to verify residency",
  "Other",
]);

const INITIAL_RESIDENCY_DOCUMENT_TYPES = new Set([
  "National ID",
  "Driver's License",
  "Postal ID",
  "Barangay Certificate",
  "Other Proof of Address",
  "Other Proof",
]);

const RESIDENT_VERIFICATION_REVIEWER_ROLES = new Set([
  "barangay_captain",
  "barangay_vice_captain",
  "barangay_secretary",
  "barangay_councilor",
]);

function canonicalBarangayName(value) {
  const cleaned = String(value || "")
    .trim()
    .replace(/^barangay\s+/i, "")
    .trim()
    .toLowerCase();
  return BARILI_BARANGAYS.find((item) => item.toLowerCase() === cleaned) || null;
}

function barangayIdFor(value) {
  const barangay = canonicalBarangayName(value);
  if (!barangay) return null;
  const slug = barangay
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
  return `barili_${slug}`;
}

function effectiveBarangayId(profile) {
  const stored = String(profile?.barangayId || "").trim().toLowerCase();
  return stored || barangayIdFor(profile?.barangay);
}

function canonicalVerificationStatus(value) {
  const status = String(value || "").trim().toLowerCase().replace(/[ -]+/g, "_");
  return ({
    pending: "under_review",
    pending_review: "under_review",
    approved: "verified",
    needs_correction: "additional_document_required",
    needs_attention: "additional_document_required",
    needsattention: "additional_document_required",
    needs_resubmission: "additional_document_required",
  })[status] || status || "not_submitted";
}

function isReviewableVerification(value) {
  return ["submitted", "under_review"].includes(canonicalVerificationStatus(value));
}

function isValidVerificationAttentionReason(value) {
  return VERIFICATION_ATTENTION_REASONS.has(String(value || "").trim());
}

function isValidVerificationRejectionReason(value) {
  return VERIFICATION_REJECTION_REASONS.has(String(value || "").trim());
}

function isValidResidentVerificationDocumentType(value, stage) {
  const documentType = String(value || "").trim();
  return ["initial_document", "additional_document"].includes(stage)
    && INITIAL_RESIDENCY_DOCUMENT_TYPES.has(documentType);
}

function canReviewResidentVerification(reviewer, resident) {
  const reviewerRole = String(reviewer?.role || "").trim().toLowerCase();
  const reviewerBarangayId = effectiveBarangayId(reviewer);
  const residentBarangayId = effectiveBarangayId(resident);
  return RESIDENT_VERIFICATION_REVIEWER_ROLES.has(reviewerRole)
    && reviewer?.canVerifyResidents === true
    && Boolean(reviewerBarangayId)
    && reviewerBarangayId === residentBarangayId;
}

function canManageResidentAccount(actor, resident) {
  const role = String(actor?.role || "").trim().toLowerCase();
  if (String(resident?.role || "").trim().toLowerCase() !== "resident") return false;
  if (role === "super_admin") return true;
  const actorBarangay = canonicalBarangayName(actor?.barangay);
  const residentBarangay = canonicalBarangayName(resident?.barangay);
  const actorBarangayId = barangayIdFor(actorBarangay);
  return RESIDENT_VERIFICATION_REVIEWER_ROLES.has(role)
    && actor?.canVerifyResidents === true
    && Boolean(actorBarangayId)
    && actorBarangayId === effectiveBarangayId(actor)
    && actorBarangayId === effectiveBarangayId(resident)
    && actorBarangayId === barangayIdFor(residentBarangay);
}

function canRestrictResidentAccount(actor, resident) {
  if (!canManageResidentAccount(actor, resident)) return false;
  if (String(actor?.role || "").trim().toLowerCase() === "super_admin") return true;
  const verifiedBarangayId = String(resident?.verifiedBarangayId || effectiveBarangayId(resident)).trim();
  return Boolean(verifiedBarangayId) && verifiedBarangayId === effectiveBarangayId(actor);
}

module.exports = {
  BARILI_BARANGAYS,
  barangayIdFor,
  canManageResidentAccount,
  canRestrictResidentAccount,
  canReviewResidentVerification,
  canonicalBarangayName,
  canonicalVerificationStatus,
  effectiveBarangayId,
  isReviewableVerification,
  isValidVerificationAttentionReason,
  isValidVerificationRejectionReason,
  isValidResidentVerificationDocumentType,
  VERIFICATION_ATTENTION_REASONS,
  VERIFICATION_REJECTION_REASONS,
};
