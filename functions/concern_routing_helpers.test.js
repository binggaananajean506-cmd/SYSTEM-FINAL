"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  isConfiguredRecipientAvailable,
  likelyDuplicateConcern,
  selectAssistedRoute,
  selectConfiguredRoute,
} = require("./concern_routing_helpers");

const health = {
  id: "mho",
  displayName: "Municipal Health Office",
  recipientType: "municipalOffice",
  status: "active",
  canReceiveConcerns: true,
  receiverAccountId: "health-user",
  categoriesHandled: ["Health Services"],
};

test("recipient must be active, enabled and connected", () => {
  assert.equal(isConfiguredRecipientAvailable(health), true);
  assert.equal(isConfiguredRecipientAvailable({ ...health, status: "inactive" }), false);
  assert.equal(isConfiguredRecipientAvailable({ ...health, canReceiveConcerns: false }), false);
  assert.equal(isConfiguredRecipientAvailable({ ...health, receiverAccountId: "" }), false);
});

test("duplicate detection suggests only recent, similar concerns from the same resident", () => {
  const now = Date.UTC(2026, 8, 10);
  const candidate = {
    userId: "resident-1",
    category: "Road Repair",
    title: "Large pothole near public market",
    location: "Purok 2 Public Market",
  };
  const similar = {
    ...candidate,
    title: "Pothole near the public market",
    location: "Public Market, Purok 2",
    createdAtMs: now - 60 * 60 * 1000,
  };
  assert.equal(likelyDuplicateConcern(candidate, similar, now), true);
  assert.equal(likelyDuplicateConcern(candidate, { ...similar, userId: "resident-2" }, now), false);
  assert.equal(likelyDuplicateConcern(candidate, { ...similar, category: "Health Services" }, now), false);
  assert.equal(likelyDuplicateConcern(candidate, { ...similar, createdAtMs: now - 8 * 24 * 60 * 60 * 1000 }, now), false);
});

test("direct and assisted routing select only eligible recipients", () => {
  const partner = {
    ...health,
    id: "cebeco",
    displayName: "CEBECO",
    recipientType: "partnerOrganization",
    receiverAccountId: "cebeco-user",
    categoriesHandled: ["Electricity / Water"],
  };
  assert.equal(selectConfiguredRoute({
    recipients: [health, partner],
    requestedType: "municipalOffice",
    requestedRecipientId: "mho",
  }).id, "mho");
  assert.equal(selectConfiguredRoute({
    recipients: [health, partner],
    requestedType: "routingAssistance",
    category: "Electricity / Water",
    concernType: "Complaint",
  }).id, "cebeco");
  assert.equal(selectConfiguredRoute({
    recipients: [{ ...health, status: "inactive" }],
    requestedType: "routingAssistance",
    category: "Health Services",
  }), null);
});

test("assisted routing follows an unavailable recipient's active fallback", () => {
  const unavailableWaterOffice = {
    ...health,
    id: "kawsco",
    status: "inactive",
    receiverAccountId: "",
    categoriesHandled: ["Water Supply"],
    fallbackRecipientId: "municipal-assistance",
  };
  const municipalAssistance = {
    ...health,
    id: "municipal-assistance",
    displayName: "Municipal Office",
    categoriesHandled: [],
  };
  assert.equal(selectAssistedRoute({
    recipients: [unavailableWaterOffice, municipalAssistance],
    category: "Water Supply",
    concernType: "Complaint",
  }).id, "municipal-assistance");
});
