// The callable below is the single source used by the resident and Admin forms.
// IDs are persisted; labels may change without changing routing.
const CONCERN_CATEGORIES = Object.freeze([
  { id: "public_safety", name: "Public Safety", sector: "public" },
  { id: "disaster_response", name: "Disaster Response", sector: "public" },
  { id: "roads", name: "Roads", sector: "public" },
  { id: "infrastructure", name: "Infrastructure", sector: "public" },
  { id: "drainage", name: "Drainage", sector: "public" },
  { id: "sanitation", name: "Sanitation", sector: "public" },
  { id: "water_services", name: "Water Services", sector: "public" },
  { id: "electricity", name: "Electricity", sector: "public" },
  { id: "health", name: "Health", sector: "public" },
  { id: "public_school_education", name: "School & Education", sector: "public" },
  { id: "social_services", name: "Social Services", sector: "public" },
  { id: "environment", name: "Environment", sector: "public" },
  { id: "agriculture", name: "Agriculture", sector: "public" },
  { id: "transportation", name: "Transportation", sector: "public" },
  { id: "community_services", name: "Community Services", sector: "public" },
  { id: "animal_services", name: "Animal Services", sector: "public" },
  { id: "business_livelihood", name: "Business & Livelihood", sector: "public" },
  { id: "private_banking_finance", name: "Banking & Finance", sector: "private" },
  { id: "private_school_education", name: "School & Education", sector: "private" },
  { id: "private_health_medical", name: "Health & Medical", sector: "private" },
  { id: "private_internet_telecom", name: "Internet & Telecom", sector: "private" },
  { id: "private_water_services", name: "Water Services", sector: "private" },
  { id: "private_electricity", name: "Electricity", sector: "private" },
  { id: "private_transportation", name: "Transportation", sector: "private" },
  { id: "private_agriculture_livelihood", name: "Agriculture & Livelihood", sector: "private" },
  { id: "private_business_services", name: "Business Services", sector: "private" },
]);

// Existing organization records keep their stored IDs; normalize them at the
// routing boundary so approved PNP/BFP accounts remain eligible for Public Safety.
const LEGACY_CATEGORY_IDS = Object.freeze({
  peace_public_safety: "public_safety",
  roads_accessibility: "roads",
  infrastructure_facilities: "infrastructure",
  drainage_flooding: "drainage",
  sanitation_waste: "sanitation",
  streetlights_utilities: "electricity",
});

function canonicalConcernCategoryId(id) {
  return LEGACY_CATEGORY_IDS[id] || id;
}

function concernCategory(id) {
  return CONCERN_CATEGORIES.find((category) => category.id === canonicalConcernCategoryId(id)) || null;
}

// Incident dates are calendar days; submissions without one use the day they
// were reported in Barili (UTC+8). Residents review suggested matches before
// deciding whether a concern at that place is actually the same issue.
function concernDateKey(incidentDate, reportedAt) {
  const day = /^(\d{4}-\d{2}-\d{2})(?:$|T)/.exec(String(incidentDate || "").trim())?.[1];
  if (day) {
    const parsed = new Date(`${day}T00:00:00Z`);
    if (!Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === day) return day;
  }
  const reportedMs = typeof reportedAt === "number" ? reportedAt
    : reportedAt?.toMillis?.() || reportedAt?.getTime?.() || 0;
  return reportedMs ? new Date(reportedMs + 8 * 60 * 60 * 1000).toISOString().slice(0, 10) : "";
}

function similarPublicConcern(proposed, existing, nowMs = Date.now()) {
  if (existing.visibility !== "public"
      || canonicalConcernCategoryId(existing.categoryId) !== canonicalConcernCategoryId(proposed.categoryId)
      || existing.barangayId !== proposed.barangayId
      || ["resolved", "closed", "rejected"].includes(String(existing.status || "").toLowerCase())) return false;
  const proposedDay = concernDateKey(proposed.incidentDate, nowMs);
  const existingDay = concernDateKey(existing.incidentDate, existing.date || existing.submittedAt);
  if (!proposedDay || proposedDay !== existingDay) return false;
  const words = (value) => new Set(String(value || "").toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ").split(/\s+/)
    .filter((word) => (word.length > 2 || /^\d+$/.test(word))
      && !["near", "barangay", "the", "and"].includes(word)));
  const proposedWords = words(proposed.location);
  const existingWords = words(existing.location);
  if (!proposedWords.size || !existingWords.size) return false;
  const proposedNumbers = [...proposedWords].filter((word) => /^\d+$/.test(word));
  const existingNumbers = [...existingWords].filter((word) => /^\d+$/.test(word));
  if (proposedNumbers.length && existingNumbers.length
      && !proposedNumbers.some((number) => existingNumbers.includes(number))) return false;
  const commonWords = [...proposedWords].filter((word) => existingWords.has(word)).length;
  return commonWords / Math.min(proposedWords.size, existingWords.size) >= 0.5;
}

function publicConcernSummary(id, concern) {
  if (!concern || Number(concern.schemaVersion || 0) < 4 || concern.visibility !== "public") return null;
  return {
    id,
    schemaVersion: 4,
    visibility: "public",
    title: concern.title,
    category: concern.category,
    categoryId: concern.categoryId,
    description: concern.description,
    barangay: concern.barangay,
    barangayId: concern.barangayId,
    location: concern.location,
    status: concern.status,
    reporterCount: concern.reporterCount || 1,
    date: concern.date,
    latestReportAt: concern.latestReportAt || concern.date,
  };
}

module.exports = { CONCERN_CATEGORIES, LEGACY_CATEGORY_IDS, canonicalConcernCategoryId, concernCategory, concernDateKey, similarPublicConcern, publicConcernSummary };
