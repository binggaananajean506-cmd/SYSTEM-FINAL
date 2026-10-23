const assert = require("node:assert/strict");
const test = require("node:test");
const {
  COMPLAINT_OUTCOMES,
  COMPLAINT_TYPES,
  RESPONDENT_RELATIONSHIPS,
  complaintOutcome,
  isComplaint,
  pickFrom,
  validComplaintReference,
} = require("./complaint_helpers");

test("complaint references use the BC-year-number format", () => {
  assert.equal(validComplaintReference("BC-2026-014200"), "BC-2026-014200");
  assert.equal(validComplaintReference(" BC-2026-014200 "), "BC-2026-014200");
  assert.equal(validComplaintReference("CON-2026-014200"), "");
  assert.equal(validComplaintReference("BC-26-1"), "");
});

test("types and relationships only accept listed values, ignoring case", () => {
  assert.equal(pickFrom(COMPLAINT_TYPES, "noise"), "Noise");
  assert.equal(pickFrom(COMPLAINT_TYPES, "Arson"), "");
  assert.equal(pickFrom(RESPONDENT_RELATIONSHIPS, "NEIGHBOR"), "Neighbor");
});

test("outcomes are limited to the mediation results", () => {
  assert.equal(complaintOutcome("Settled"), "settled");
  assert.equal(complaintOutcome("referred"), "referred");
  assert.equal(complaintOutcome("resolved"), "");
  assert.equal(complaintOutcome("toString"), "");
  assert.equal(COMPLAINT_OUTCOMES.settled.note("Pay ₱3,000"), "Settled: Pay ₱3,000");
});

test("complaints are recognized by kind", () => {
  assert.equal(isComplaint({ kind: "complaint" }), true);
  assert.equal(isComplaint({ kind: "concern" }), false);
  assert.equal(isComplaint(null), false);
});

