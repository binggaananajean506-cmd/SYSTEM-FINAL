"use strict";

const { CONCERN_CATEGORIES } = require("./concern_categories");

const BARANGAY_POSITIONS = Object.freeze([
  { id: "barangay_captain", name: "Barangay Captain", role: "barangay_captain", maxSlots: 1 },
  { id: "barangay_vice_captain", name: "Barangay Vice Captain", role: "barangay_vice_captain", maxSlots: 1, adminOnly: true },
  { id: "barangay_kagawad", name: "Barangay Kagawad", role: "barangay_councilor", maxSlots: 7 },
  { id: "barangay_secretary", name: "Barangay Secretary", role: "barangay_secretary", maxSlots: 1 },
  { id: "barangay_treasurer", name: "Barangay Treasurer", role: "barangay_councilor", maxSlots: 1 },
  { id: "sk_chairperson", name: "SK Chairperson", role: "barangay_councilor", maxSlots: 1 },
  { id: "barangay_staff", name: "Barangay Staff", role: "barangay_councilor", maxSlots: null },
  { id: "other_position", name: "Other Position", role: "barangay_councilor", maxSlots: null },
]);

const LGU_SERVICE_TYPES = Object.freeze([
  { id: "roads_public_works", name: "Roads / Public Works", categoryId: "roads" },
  { id: "infrastructure_engineering", name: "Infrastructure / Engineering", categoryId: "infrastructure" },
  { id: "waste_sanitation", name: "Waste / Sanitation", categoryId: "sanitation" },
  { id: "drainage_flood", name: "Drainage / Flood Management", categoryId: "drainage" },
  { id: "electrical_utilities", name: "Electrical / Public Utilities", categoryId: "electricity" },
  { id: "peace_public_safety", name: "Peace & Order / Public Safety", categoryId: "public_safety" },
  { id: "disaster_risk", name: "Disaster Risk Reduction", categoryId: "disaster_response" },
  { id: "health_services", name: "Health Services", categoryId: "health" },
  { id: "social_welfare", name: "Social Welfare", categoryId: "social_services" },
  { id: "agriculture", name: "Agriculture", categoryId: "agriculture" },
  { id: "other_lgu_service", name: "Other LGU Service", categoryId: null },
]);

const ORGANIZATION_TYPES = Object.freeze(CONCERN_CATEGORIES.map(({ id, name, sector }) =>
  Object.freeze({ id, name, categoryId: id, sector })));

const PROOF_TYPES = Object.freeze({
  barangay: ["appointment", "barangay_certification", "official_barangay_id", "government_document", "other"],
  lgu: ["employee_id", "appointment", "office_certification", "government_document", "other"],
  organization: ["registration", "authorization", "certificate", "government_document", "other"],
});

function positionDefinition(positionId) {
  return BARANGAY_POSITIONS.find((position) => position.id === positionId) || null;
}

function positionIdForAccount(account) {
  const explicit = String(account?.positionId || account?.positionCode || "").trim().toLowerCase();
  if (explicit) return explicit;
  const role = String(account?.role || "").trim().toLowerCase();
  if (role === "barangay") return "barangay_captain";
  return ["barangay_captain", "barangay_secretary", "barangay_vice_captain"].includes(role) ? role : "";
}

function configuredPositionCapacity(positionId, settings = {}) {
  const position = positionDefinition(positionId);
  if (!position) return null;
  const override = settings?.barangayPositionCapacities?.[positionId];
  return Number.isInteger(override) && override >= 1 && override <= 50 ? override : position.maxSlots;
}

function positionAvailability(positionId, users, requests, barangayId, settings = {}, excludeRequestId = "") {
  const maxSlots = configuredPositionCapacity(positionId, settings);
  const inBarangay = (record) => String(record.barangayId || "") === barangayId;
  const active = (record) => {
    const status = String(record.accountStatus || record.status || "").toLowerCase();
    return status === "active" || status === "approved";
  };
  const pending = (record) => ["pending", "pending_approval", "pending_review", "reviewing"]
    .includes(String(record.accountStatus || record.status || "").toLowerCase());
  const occupiedSlots = users.filter((record) => inBarangay(record) && active(record)
    && positionIdForAccount(record) === positionId).length;
  const pendingSlots = requests.filter((record) => record.id !== excludeRequestId && inBarangay(record)
    && pending(record) && positionIdForAccount(record) === positionId).length;
  const availableSlots = maxSlots === null ? null : Math.max(0, maxSlots - occupiedSlots - pendingSlots);
  return { occupiedSlots, pendingSlots, maxSlots, availableSlots,
    available: maxSlots === null || availableSlots > 0 };
}

module.exports = {
  BARANGAY_POSITIONS, LGU_SERVICE_TYPES, ORGANIZATION_TYPES, PROOF_TYPES,
  configuredPositionCapacity, positionAvailability, positionDefinition, positionIdForAccount,
};
