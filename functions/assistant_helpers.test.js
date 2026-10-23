"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  BUILT_IN_MUNICIPAL_OFFICIALS,
  groundedOfficialAnswer,
  inferKnownIntent,
  isActionAllowed,
  routeContextForRole,
  safeClientContext,
} = require("./assistant_helpers");

const difficultQuestions = [
  ["Who is the current mayor of Barili?", "municipal_officials", "municipalOfficials"],
  ["Where can I see all municipal officials?", "municipal_officials", "municipalOfficials"],
  ["I forgot where the page showing the people running the municipality is.", "municipal_officials", "municipalOfficials"],
  ["Who is my barangay captain?", "barangay_officials", "myBarangay"],
  ["Where can I submit a drainage concern?", "concern_file", "fileConcern"],
  ["What happens after I submit a concern?", "concern_process", "myConcerns"],
  ["Do I have an unfinished concern?", "concern_drafts", "concernDraft"],
  ["What events are coming?", "calendar", "calendar"],
  ["Where can I visit in Barili?", "explore", "exploreBarili"],
  ["Where is Mantayupan Falls?", "explore", "exploreBarili"],
  ["What number should I call for a fire emergency?", "emergency_hotlines", "hotlines"],
  ["What feature allows residents to help other residents?", "bayanihan", "jobs"],
  ["What's the difference between announcements and emergency alerts?", "announcement_comparison", "emergencyCenter"],
  ["If I have an electricity concern, what should I do?", "concern_file", "fileConcern"],
  ["Where can I see my concern status?", "concern_status", "myConcerns"],
];

test("classifies the 15 required difficult questions to selective sources and exact routes", () => {
  for (const [question, source, action] of difficultQuestions) {
    const result = inferKnownIntent(question);
    assert.ok(result, `Expected an intent for: ${question}`);
    assert.equal(result.source, source, question);
    assert.equal(result.action, action, question);
  }
});

test("uses recent context for municipal official and place follow-ups", () => {
  const official = inferKnownIntent("How about the Vice Mayor?", [
    { text: "Who is the Mayor?" },
  ]);
  assert.equal(official.source, "municipal_officials");
  assert.equal(official.entities.position, "Vice Mayor");

  const place = inferKnownIntent("How do I get there?", [
    { text: "Show me Mantayupan Falls." },
  ]);
  assert.equal(place.source, "explore");
  assert.equal(place.entities.query, "Mantayupan Falls");
});

test("resident-only actions are removed for staff roles", () => {
  assert.equal(isActionAllowed("fileConcern", "resident"), true);
  assert.equal(isActionAllowed("fileConcern", "barangay_captain"), false);
  assert.equal(isActionAllowed("municipalOfficials", "barangay_captain"), true);
  assert.equal(isActionAllowed("myBarangay", "barangay_vice_captain"), true);
  assert.equal(
    routeContextForRole("barangay_captain").some((route) => route.action === "fileConcern"),
    false,
  );
});

test("accepts only non-sensitive bounded draft context", () => {
  assert.deepEqual(safeClientContext({
    manualDraftCount: 2,
    latestDraftId: "draft-1",
    latestDraftUpdatedAt: "2026-09-09T10:00:00.000Z",
    title: "private draft title",
    description: "private draft description",
  }), {
    manualDraftCount: 2,
    latestDraftId: "draft-1",
    latestDraftUpdatedAt: "2026-09-09T10:00:00.000Z",
  });
});

test("routes changing Barili facts to verified knowledge instead of a hardcoded answer", () => {
  const result = inferKnownIntent("How many barangays are in the Municipality of Barili?");
  assert.equal(result.source, "barili_knowledge");
  assert.equal(result.action, "none");
});

test("built-in officials directory answers the mayor question when live records are unavailable", () => {
  const answer = groundedOfficialAnswer(
    "Who is the current mayor of Barili?",
    BUILT_IN_MUNICIPAL_OFFICIALS,
    "Mayor",
  );
  assert.match(answer, /Pablo John "John-John" D\. Garcia IV/);
});

test("recognizes additional direct app navigation requests", () => {
  const questions = [
    ["Open my notifications", "notifications"],
    ["Show my saved announcements", "savedAnnouncements"],
    ["Show me the map of Barili", "barangayMap"],
    ["What is the Barili weather forecast?", "bariliWeather"],
    ["Open my market listings", "myMarketListings"],
    ["Show my Bayanihan messages", "bayanihanMessages"],
  ];
  for (const [question, action] of questions) {
    const result = inferKnownIntent(question);
    assert.equal(result?.source, "navigation", question);
    assert.equal(result?.action, action, question);
  }
});
