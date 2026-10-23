"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { positionAvailability, positionIdForAccount } = require("./staff_registration_helpers");

test("legacy active captain occupies only their own barangay and archived accounts do not", () => {
  const users = [
    { role: "barangay_captain", barangayId: "barili_vito", accountStatus: "active" },
    { role: "barangay_captain", barangayId: "barili_poblacion", accountStatus: "deactivated" },
  ];
  assert.equal(positionAvailability("barangay_captain", users, [], "barili_vito").available, false);
  assert.equal(positionAvailability("barangay_captain", users, [], "barili_poblacion").available, true);
  assert.equal(positionIdForAccount(users[0]), "barangay_captain");
});

test("pending requests consume capacity and rejected requests release it", () => {
  const requests = [
    { id: "one", positionId: "barangay_secretary", barangayId: "barili_vito", status: "pending" },
    { id: "two", positionId: "barangay_secretary", barangayId: "barili_vito", status: "rejected" },
  ];
  assert.deepEqual(positionAvailability("barangay_secretary", [], requests, "barili_vito"), {
    occupiedSlots: 0, pendingSlots: 1, maxSlots: 1, availableSlots: 0, available: false,
  });
  assert.equal(positionAvailability("barangay_secretary", [], requests, "barili_vito", {}, "one").available, true);
});

test("multi-slot positions honor configured capacity", () => {
  const users = Array.from({ length: 2 }, () => ({ positionCode: "barangay_kagawad", barangayId: "barili_vito", status: "approved" }));
  const settings = { barangayPositionCapacities: { barangay_kagawad: 3 } };
  assert.equal(positionAvailability("barangay_kagawad", users, [], "barili_vito", settings).availableSlots, 1);
  assert.equal(positionAvailability("barangay_staff", users, [], "barili_vito").available, true);
});
