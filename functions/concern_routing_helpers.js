"use strict";

const RECIPIENT_TYPES = new Set([
  "barangay",
  "municipalOffice",
  "partnerOrganization",
]);

function normalize(value) {
  return String(value || "").trim().toLowerCase();
}

function canonicalRecipientType(value) {
  const type = String(value || "").trim();
  return ({ municipal: "municipalOffice", partner: "partnerOrganization", other: "routingAssistance" })[type]
    || type;
}

function isConfiguredRecipientAvailable(recipient) {
  return Boolean(recipient)
    && RECIPIENT_TYPES.has(canonicalRecipientType(recipient.recipientType))
    && ["active", "approved"].includes(normalize(recipient.status))
    && recipient.canReceiveConcerns === true
    && Boolean(String(recipient.receiverAccountId || recipient.inboxId || "").trim());
}

function categoryMatches(recipient, category, concernType) {
  const requested = new Set([normalize(category), normalize(concernType)].filter(Boolean));
  return (Array.isArray(recipient.categoriesHandled) ? recipient.categoriesHandled : [])
    .some((item) => requested.has(normalize(item)));
}

function selectConfiguredRoute({ recipients, requestedType, requestedRecipientId, category, concernType }) {
  const available = recipients.filter(isConfiguredRecipientAvailable);
  const type = canonicalRecipientType(requestedType);
  if (["municipalOffice", "partnerOrganization"].includes(type)) {
    return available.find((item) => item.id === requestedRecipientId && canonicalRecipientType(item.recipientType) === type) || null;
  }
  if (type === "routingAssistance") {
    return available.find((item) => categoryMatches(item, category, concernType)) || null;
  }
  return null;
}

function selectAssistedRoute({ recipients, category, concernType }) {
  const direct = selectConfiguredRoute({
    recipients,
    requestedType: "routingAssistance",
    requestedRecipientId: "",
    category,
    concernType,
  });
  if (direct) return direct;
  const available = recipients.filter(isConfiguredRecipientAvailable);
  for (const preferred of recipients.filter((item) => categoryMatches(item, category, concernType))) {
    const fallbackId = String(preferred.fallbackRecipientId || "").trim();
    const fallback = available.find((item) => item.id === fallbackId);
    if (fallback) return fallback;
  }
  return null;
}

function normalizedTokens(value) {
  return new Set(String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((token) => token.length > 2));
}

function tokenSimilarity(left, right) {
  const a = normalizedTokens(left);
  const b = normalizedTokens(right);
  if (!a.size || !b.size) return 0;
  const overlap = [...a].filter((token) => b.has(token)).length;
  return overlap / Math.min(a.size, b.size);
}

function likelyDuplicateConcern(candidate, existing, nowMs, windowMs = 7 * 24 * 60 * 60 * 1000) {
  if (!candidate || !existing || candidate.userId !== existing.userId) return false;
  const existingMs = Number(existing.createdAtMs || existing.dateMs || 0);
  if (!existingMs || Math.abs(nowMs - existingMs) > windowMs) return false;
  if (normalize(candidate.category) !== normalize(existing.category)) return false;
  const titleMatch = tokenSimilarity(candidate.title, existing.title) >= 0.6;
  const locationMatch = tokenSimilarity(candidate.location, existing.location) >= 0.6
    || normalize(candidate.location) === normalize(existing.location);
  return titleMatch && locationMatch;
}

module.exports = {
  RECIPIENT_TYPES,
  canonicalRecipientType,
  categoryMatches,
  isConfiguredRecipientAvailable,
  likelyDuplicateConcern,
  selectAssistedRoute,
  selectConfiguredRoute,
};
