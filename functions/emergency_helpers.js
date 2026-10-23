"use strict";

const TERMINAL_EMERGENCY_STATUSES = new Set(["ended", "cancelled", "expired"]);

function canonicalSeverity(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (normalized === "critical") return "emergency";
  return ["information", "advisory", "warning", "emergency"].includes(normalized)
    ? normalized
    : "information";
}

function canonicalArea(value) {
  return String(value || "").trim().toLowerCase().replace(/^barangay\s+/, "");
}

function residentMatchesAlert(profile, alert) {
  if (String(profile?.role || "").trim().toLowerCase() !== "resident") return false;
  if (alert.visibility === "public" || alert.audience === "municipality") return true;
  const residentBarangay = canonicalArea(profile.barangay);
  return Array.isArray(alert.targetBarangays) && alert.targetBarangays
    .map(canonicalArea)
    .includes(residentBarangay);
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(String(value || ""));
  return Number.isFinite(parsed) ? parsed : NaN;
}

function isActiveEmergency(alert, nowMs = Date.now()) {
  const status = String(alert?.status || "active").trim().toLowerCase();
  if (alert?.active === false || TERMINAL_EMERGENCY_STATUSES.has(status)) return false;
  const startsAt = timestampMillis(alert?.startAt);
  const expiresAt = timestampMillis(alert?.expiresAt);
  return (!Number.isFinite(startsAt) || startsAt <= nowMs)
    && (!Number.isFinite(expiresAt) || expiresAt > nowMs);
}

function reminderCycle(nowMs, intervalMinutes) {
  const intervalMs = Math.max(1, Number(intervalMinutes) || 15) * 60 * 1000;
  return Math.floor(nowMs / intervalMs);
}

function isReminderEligible(alert, residentStatus, nowMs, intervalMinutes, maxReminders) {
  if (canonicalSeverity(alert?.severity) !== "emergency" || !isActiveEmergency(alert, nowMs)) {
    return false;
  }
  if (residentStatus?.acknowledgedAt || residentStatus?.status === "acknowledged") return false;
  const configuredMaximum = Number(maxReminders);
  if (Number.isFinite(configuredMaximum) && configuredMaximum > 0
    && Number(residentStatus?.reminderCount || 0) >= configuredMaximum) {
    return false;
  }
  return residentStatus?.lastReminderCycle !== reminderCycle(nowMs, intervalMinutes);
}

module.exports = {
  canonicalSeverity,
  isActiveEmergency,
  isReminderEligible,
  reminderCycle,
  residentMatchesAlert,
};
