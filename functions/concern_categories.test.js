const assert = require("node:assert/strict");
const test = require("node:test");
const { CONCERN_CATEGORIES, canonicalConcernCategoryId, concernCategory,
  concernDateKey, similarPublicConcern, publicConcernSummary } = require("./concern_categories");
const { ORGANIZATION_TYPES } = require("./staff_registration_helpers");

test("concern category IDs are stable and unique", () => {
  assert.equal(CONCERN_CATEGORIES.length, 26);
  assert.equal(new Set(CONCERN_CATEGORIES.map((category) => category.id)).size, 26);
  assert.equal(CONCERN_CATEGORIES.filter((category) => category.sector === "public").length, 17);
  assert.equal(CONCERN_CATEGORIES.filter((category) => category.sector === "private").length, 9);
  assert.notEqual(concernCategory("water_services").id, concernCategory("private_water_services").id);
  assert.notEqual(concernCategory("public_school_education").id, concernCategory("private_school_education").id);
  assert.deepEqual(ORGANIZATION_TYPES.map(({ id }) => id), CONCERN_CATEGORIES.map(({ id }) => id));
  assert.equal(concernCategory("public_safety").name, "Public Safety");
  assert.equal(canonicalConcernCategoryId("peace_public_safety"), "public_safety");
  assert.equal(concernCategory("unknown"), null);
});

test("similar suggestions use category, incident day, and location, never title or recipient", () => {
  const now = Date.UTC(2026, 8, 28, 4);
  const proposed = {
    categoryId: "drainage_flooding", barangayId: "barili_vito",
    incidentDate: "2026-09-27T00:00:00.000", title: "Flooding near school",
    description: "Water beside the gate", location: "Near Vito Elementary School",
    recipientType: "organization", organizationId: "pnp",
  };
  const existing = { ...proposed, visibility: "public", status: "new", recipientType: "barangay",
    organizationIds: ["bfp"], title: "Broken drain in another street",
    description: "Unrelated description", location: "Vito Elementary School gate",
    date: { toMillis: () => now - 1000 } };
  assert.equal(similarPublicConcern(proposed, existing, now), true);
  assert.equal(similarPublicConcern(proposed, { ...existing, visibility: "private" }, now), false);
  assert.equal(similarPublicConcern(proposed, { ...existing, barangayId: "barili_cabcaban" }, now), false);
  assert.equal(similarPublicConcern(proposed, { ...existing, categoryId: "roads_accessibility" }, now), false);
  assert.equal(similarPublicConcern(proposed, { ...existing, location: "Vito Health Center" }, now), false);
  assert.equal(similarPublicConcern(proposed, { ...existing, status: "resolved" }, now), false);
  assert.equal(similarPublicConcern(proposed, { ...existing, incidentDate: "2026-09-28" }, now), false);
  assert.equal(similarPublicConcern({ ...proposed, categoryId: "roads" },
    { ...existing, categoryId: "roads_accessibility" }, now), true);
  assert.equal(similarPublicConcern({ ...proposed, location: "Purok 1" },
    { ...existing, location: "Purok 2" }, now), false);
  assert.equal(similarPublicConcern({ ...proposed, location: "Purok 1" },
    { ...existing, location: "Near Purok 1 market" }, now), true);
});

test("missing incident dates compare the reported day in Philippine time", () => {
  const now = Date.UTC(2026, 8, 27, 18); // September 28 in Barili.
  const proposed = { categoryId: "drainage", barangayId: "barili_vito", location: "Purok 2" };
  const existing = { ...proposed, visibility: "public", status: "new",
    date: { toMillis: () => Date.UTC(2026, 8, 27, 17) } };
  assert.equal(concernDateKey(null, now), "2026-09-28");
  assert.equal(similarPublicConcern(proposed, existing, now), true);
  assert.equal(similarPublicConcern(proposed, { ...existing,
    date: { toMillis: () => Date.UTC(2026, 8, 27, 15) } }, now), false);
  assert.equal(concernDateKey("2026-02-30", now), "2026-09-28");
  assert.equal(concernDateKey("2026-09-27invalid", now), "2026-09-28");
});

test("public concern summary excludes reporter identities and evidence", () => {
  const concern = {
    schemaVersion: 4, visibility: "public", title: "Flooding", category: "Drainage and Flooding",
    categoryId: "drainage_flooding", description: "Water near the school", barangay: "Vito",
    barangayId: "barili_vito", location: "School gate", status: "new", reporterCount: 2,
    date: new Date(), reporterIds: ["resident-1", "resident-2"], userId: "resident-1",
    residentName: "Private name", attachmentStoragePath: "concerns/resident-1/evidence.jpg",
    statusHistory: [{ actorId: "resident-2" }],
  };
  const summary = publicConcernSummary("CON-2026-000001", concern);
  assert.equal(summary.reporterCount, 2);
  assert.equal(summary.barangayId, "barili_vito");
  for (const privateField of ["reporterIds", "userId", "residentName", "attachmentStoragePath", "statusHistory"]) {
    assert.equal(Object.hasOwn(summary, privateField), false);
  }
  assert.equal(publicConcernSummary("CON-2026-000002", { ...concern, visibility: "private" }), null);
});
