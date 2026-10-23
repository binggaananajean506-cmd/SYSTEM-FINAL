"use strict";

// Barangay complaints: disputes between residents, handled by summons and
// mediation. They are stored in `submissions` with kind "complaint" and are
// always private to the complainant and the barangay.

const COMPLAINT_TYPES = Object.freeze([
  "Noise",
  "Boundary or property",
  "Unpaid debt",
  "Threats or harassment",
  "Animals",
  "Other",
]);

const RESPONDENT_RELATIONSHIPS = Object.freeze([
  "Neighbor",
  "Relative",
  "Landlord or tenant",
  "Other",
]);

// How a complaint can be closed after review or a hearing.
const COMPLAINT_OUTCOMES = Object.freeze({
  settled: {
    label: "Settled",
    title: "Complaint settled",
    note: (text) => `Settled: ${text}`,
  },
  referred: {
    label: "Referred",
    title: "Complaint referred",
    note: (text) => `Referred with a certificate to file action: ${text}`,
  },
  withdrawn: {
    label: "Withdrawn",
    title: "Complaint withdrawn",
    note: (text) => `Withdrawn: ${text}`,
  },
  dismissed: {
    label: "Dismissed",
    title: "Complaint dismissed",
    note: (text) => `Dismissed: ${text}`,
  },
  unsettled: {
    label: "Unsettled",
    title: "Complaint unsettled",
    note: (text) => `Unsettled: ${text}`,
  },
});

function validComplaintReference(value) {
  const reference = String(value || "").trim();
  return /^BC-\d{4}-\d{6}$/.test(reference) ? reference : "";
}

function pickFrom(list, value) {
  const text = String(value || "").trim();
  return list.find((item) => item.toLowerCase() === text.toLowerCase()) || "";
}

function complaintOutcome(value) {
  const key = String(value || "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(COMPLAINT_OUTCOMES, key) ? key : "";
}

function isComplaint(submission) {
  return String(submission?.kind || "").toLowerCase() === "complaint";
}

module.exports = {
  COMPLAINT_OUTCOMES,
  COMPLAINT_TYPES,
  RESPONDENT_RELATIONSHIPS,
  complaintOutcome,
  isComplaint,
  pickFrom,
  validComplaintReference,
};

