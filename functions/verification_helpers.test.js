const test = require("node:test");
const assert = require("node:assert/strict");

const {
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
} = require("./verification_helpers");

test("barangay display names resolve to stable IDs", () => {
  assert.equal(canonicalBarangayName(" Barangay Cabcaban "), "Cabcaban");
  assert.equal(barangayIdFor("Cabcaban"), "barili_cabcaban");
  assert.equal(barangayIdFor("Santa Ana"), "barili_santa_ana");
  assert.equal(barangayIdFor("Not a Barili barangay"), null);
});

test("stored barangay IDs take priority with a legacy-name fallback", () => {
  assert.equal(
    effectiveBarangayId({ barangayId: "barili_cabcaban", barangay: "Vito" }),
    "barili_cabcaban",
  );
  assert.equal(effectiveBarangayId({ barangay: "Vito" }), "barili_vito");
});

test("verification decisions only accept a waiting request", () => {
  assert.equal(canonicalVerificationStatus("pending_review"), "under_review");
  assert.equal(isReviewableVerification("submitted"), true);
  assert.equal(isReviewableVerification("under_review"), true);
  assert.equal(isReviewableVerification("verified"), false);
  assert.equal(isReviewableVerification("rejected"), false);
});

test("needs-attention aliases use the existing correction state", () => {
  assert.equal(canonicalVerificationStatus("NeedsAttention"), "additional_document_required");
  assert.equal(canonicalVerificationStatus("needs_attention"), "additional_document_required");
});

test("needs-attention reasons use the controlled resident list", () => {
  assert.equal(isValidVerificationAttentionReason("Document unreadable"), true);
  assert.equal(isValidVerificationAttentionReason("Wrong document uploaded"), true);
  assert.equal(isValidVerificationAttentionReason("Address not visible"), true);
  assert.equal(isValidVerificationAttentionReason("Document does not sufficiently prove residency"), true);
  assert.equal(isValidVerificationAttentionReason("Information needs clarification"), true);
  assert.equal(isValidVerificationAttentionReason("Unverified free-form reason"), false);
});

test("rejection reasons use the controlled resident list", () => {
  assert.equal(isValidVerificationRejectionReason("Not a resident of this barangay"), true);
  assert.equal(isValidVerificationRejectionReason("Fraudulent or invalid document"), true);
  assert.equal(isValidVerificationRejectionReason("Identity mismatch"), true);
  assert.equal(isValidVerificationRejectionReason("Duplicate account registration"), true);
  assert.equal(isValidVerificationRejectionReason("Unable to verify residency"), true);
  assert.equal(isValidVerificationRejectionReason("Other"), true);
  assert.equal(isValidVerificationRejectionReason("Invalid reason test"), false);
});

test("resident document types match the submission stage", () => {
  assert.equal(isValidResidentVerificationDocumentType("National ID", "initial_document"), true);
  assert.equal(isValidResidentVerificationDocumentType("Driver's License", "additional_document"), true);
  assert.equal(isValidResidentVerificationDocumentType("Postal ID", "initial_document"), true);
  assert.equal(isValidResidentVerificationDocumentType("Barangay Certificate", "additional_document"), true);
  assert.equal(isValidResidentVerificationDocumentType("Other Proof of Address", "initial_document"), true);
  assert.equal(isValidResidentVerificationDocumentType("Student ID", "initial_document"), false);
  assert.equal(isValidResidentVerificationDocumentType("Passport", "additional_document"), false);
});

test("barangay leaders and delegated officials review only their own barangay", () => {
  const resident = { role: "resident", barangayId: "barili_cabcaban" };
  assert.equal(canReviewResidentVerification({
    role: "barangay_secretary",
    barangayId: "barili_cabcaban",
    canVerifyResidents: true,
  }, resident), true);
  assert.equal(canReviewResidentVerification({
    role: "barangay_secretary",
    barangayId: "barili_poblacion",
    canVerifyResidents: true,
  }, resident), false);
  assert.equal(canReviewResidentVerification({
    role: "barangay_captain",
    barangayId: "barili_cabcaban",
    canVerifyResidents: false,
  }, resident), true);
  assert.equal(canReviewResidentVerification({
    role: "super_admin",
    barangayId: "barili_cabcaban",
    canVerifyResidents: true,
  }, resident), false);
});

for (const role of ["barangay_captain", "barangay_vice_captain", "barangay_secretary"]) {
  test(`${role} can review its own residents without the legacy permission flag`, () => {
    const reviewer = { role, barangay: "Cabcaban", barangayId: "barili_cabcaban" };
    assert.equal(canReviewResidentVerification(reviewer, { role: "resident", barangayId: "barili_cabcaban" }), true);
    assert.equal(canReviewResidentVerification(reviewer, { role: "resident", barangayId: "barili_vito" }), false);
  });
}

test("all 42 barangays give leaders verification authority only within their assignment", () => {
  const { BARILI_BARANGAYS, barangayIdFor } = require("./verification_helpers");
  assert.equal(BARILI_BARANGAYS.length, 42);
  for (const [index, barangay] of BARILI_BARANGAYS.entries()) {
    const ownId = barangayIdFor(barangay);
    const otherId = barangayIdFor(BARILI_BARANGAYS[(index + 1) % BARILI_BARANGAYS.length]);
    for (const role of ["barangay_captain", "barangay_vice_captain", "barangay_secretary"]) {
      for (const flag of [undefined, false, true]) {
        const official = { role, barangay, barangayId: ownId, canVerifyResidents: flag };
        assert.equal(canReviewResidentVerification(official, { role: "resident", barangayId: ownId }), true, `${barangay}: ${role}`);
        assert.equal(canReviewResidentVerification(official, { role: "resident", barangayId: otherId }), false, `${barangay}: cross-barangay access`);
      }
    }
  }
});

test("barangay officials manage only residents with matching verified assignments", () => {
  const cabcabanResident = { role: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban" };
  assert.equal(canManageResidentAccount({ role: "super_admin" }, cabcabanResident), true);
  assert.equal(canManageResidentAccount({ role: "barangay_secretary", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }, cabcabanResident), true);
  assert.equal(canManageResidentAccount({ role: "barangay_councilor", barangay: "Cabcaban", canVerifyResidents: true }, cabcabanResident), true);
  assert.equal(canManageResidentAccount({ role: "barangay_captain", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: false }, cabcabanResident), false);
  assert.equal(canManageResidentAccount({ role: "barangay_captain", barangay: "Vito", barangayId: "barili_vito", canVerifyResidents: true }, cabcabanResident), false);
  assert.equal(canManageResidentAccount({ role: "barangay_captain", barangay: "Vito", barangayId: "barili_cabcaban", canVerifyResidents: true }, cabcabanResident), false);
  assert.equal(canManageResidentAccount({ role: "barangay_captain", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }, { ...cabcabanResident, barangay: "Vito" }), false);
  assert.equal(canManageResidentAccount({ role: "lgu", barangay: "Cabcaban", barangayId: "barili_cabcaban" }, cabcabanResident), false);
  assert.equal(canManageResidentAccount({ role: "barangay_captain", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true }, { ...cabcabanResident, role: "barangay_captain" }), false);
});

test("municipal administrators and delegated home barangay officials restrict residents", () => {
  const resident = { role: "resident", barangay: "Cabcaban", barangayId: "barili_cabcaban", verifiedBarangayId: "barili_cabcaban", verificationStatus: "verified" };
  const official = { role: "barangay_secretary", barangay: "Cabcaban", barangayId: "barili_cabcaban", canVerifyResidents: true };
  assert.equal(canRestrictResidentAccount(official, resident), true);
  assert.equal(canRestrictResidentAccount({ role: "super_admin" }, resident), true);
  assert.equal(canRestrictResidentAccount({ role: "super_admin" }, { ...resident, verificationStatus: "submitted" }), true);
  assert.equal(canRestrictResidentAccount({ ...official, role: "lgu" }, resident), false);
  assert.equal(canRestrictResidentAccount({ ...official, role: "organization" }, resident), false);
  assert.equal(canRestrictResidentAccount({ ...official, barangay: "Vito", barangayId: "barili_vito" }, resident), false);
  assert.equal(canRestrictResidentAccount(official, { ...resident, verifiedBarangayId: "barili_vito" }), false);
  assert.equal(canRestrictResidentAccount(official, { ...resident, verificationStatus: "submitted" }), true);
});
