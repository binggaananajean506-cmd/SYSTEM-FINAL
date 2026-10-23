"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canonicalSeverity,
  isReminderEligible,
  reminderCycle,
  residentMatchesAlert,
} = require("./emergency_helpers");

test("severity supports the production levels and legacy critical", () => {
  assert.equal(canonicalSeverity("Information"), "information");
  assert.equal(canonicalSeverity("Critical"), "emergency");
  assert.equal(canonicalSeverity("Emergency"), "emergency");
});

test("targeted emergencies only match residents in selected barangays", () => {
  const alert = { visibility: "targeted", targetBarangays: ["Vito"] };
  assert.equal(residentMatchesAlert({ role: "resident", barangay: "Barangay Vito" }, alert), true);
  assert.equal(residentMatchesAlert({ role: "resident", barangay: "Cagay" }, alert), false);
  assert.equal(residentMatchesAlert({ role: "lgu", barangay: "Vito" }, alert), false);
});

test("acknowledged and ended emergencies cannot produce reminders", () => {
  const now = Date.now();
  const alert = { severity: "Emergency", active: true, status: "active" };
  assert.equal(isReminderEligible(alert, { status: "acknowledged" }, now, 15, 12), false);
  assert.equal(isReminderEligible({ ...alert, status: "ended" }, {}, now, 15, 12), false);
});

test("a resident can be claimed only once in a reminder cycle", () => {
  const now = Date.now();
  const cycle = reminderCycle(now, 15);
  const alert = { severity: "Emergency", active: true, status: "active" };
  assert.equal(isReminderEligible(alert, { lastReminderCycle: cycle - 1 }, now, 15, 12), true);
  assert.equal(isReminderEligible(alert, { lastReminderCycle: cycle }, now, 15, 12), false);
});

test("zero reminder maximum continues until acknowledgement or termination", () => {
  const now = Date.now();
  const alert = { severity: "Emergency", active: true, status: "active" };
  assert.equal(isReminderEligible(alert, { reminderCount: 500 }, now, 15, 0), true);
});

test("Firestore timestamp expiration prevents reboot recovery and reminders", () => {
  const now = Date.now();
  const alert = {
    severity: "Emergency",
    active: true,
    status: "active",
    expiresAt: { toMillis: () => now - 1 },
  };
  assert.equal(isReminderEligible(alert, {}, now, 15, 0), false);
});
