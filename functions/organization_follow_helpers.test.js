const assert = require("node:assert/strict");
const test = require("node:test");
const {
  MAX_FOLLOWED_ORGANIZATIONS,
  canonicalOrganizationId,
  followedOrganizationIds,
  isFollowableOrganization,
  isPrivateSectorOrganization,
  organizationIdForPost,
  planFollowChange,
} = require("./organization_follow_helpers");

test("posts are traced to their publishing organization", () => {
  assert.equal(organizationIdForPost({ publisherEntityType: "organization", publisherEntityId: "kawssco" }), "kawssco");
  assert.equal(organizationIdForPost({ publisherEntityType: "barangay", publisherEntityId: "vito", authorRole: "barangay_captain" }), "");
  assert.equal(organizationIdForPost({ publisherEntityType: "lgu", publisherEntityId: "municipality-of-barili" }), "");
  assert.equal(organizationIdForPost({ authorRole: "organization", publisherEntityId: "kawssco" }), "kawssco");
  assert.equal(organizationIdForPost({ publisherEntityType: "organization" }), "");
  assert.equal(organizationIdForPost(null), "");
  // A deactivated private organization's old posts still count as private.
  assert.equal(isPrivateSectorOrganization({ organizationSector: "private", status: "deactivated" }), true);
  assert.equal(isPrivateSectorOrganization({ organizationSector: "public" }), false);
});

const kawssco = {
  id: "kawssco",
  exists: true,
  data: { organizationSector: "private", status: "approved" },
};

test("only active private-sector organizations can be followed", () => {
  assert.equal(isFollowableOrganization({ organizationSector: "private" }), true);
  assert.equal(isFollowableOrganization({ sector: "Private", status: "active" }), true);
  assert.equal(isFollowableOrganization({ organizationSector: "public" }), false);
  assert.equal(isFollowableOrganization({ organizationSector: "private", status: "deactivated" }), false);
  assert.equal(isFollowableOrganization(null), false);
});

test("organization IDs are trimmed and path-safe", () => {
  assert.equal(canonicalOrganizationId("  kawssco "), "kawssco");
  assert.equal(canonicalOrganizationId("a/b"), "");
  assert.equal(canonicalOrganizationId(""), "");
  assert.equal(canonicalOrganizationId("x".repeat(129)), "");
  assert.deepEqual(followedOrganizationIds({ followedOrganizationIds: ["a", 3, "b"] }), ["a", "b"]);
  assert.deepEqual(followedOrganizationIds({}), []);
});

test("following changes the count once and repeats are no-ops", () => {
  assert.deepEqual(planFollowChange({ currentIds: [], follow: true, organization: kawssco }), { delta: 1 });
  assert.deepEqual(planFollowChange({ currentIds: ["kawssco"], follow: true, organization: kawssco }), { delta: 0 });
  assert.deepEqual(planFollowChange({ currentIds: ["kawssco"], follow: false, organization: kawssco }), { delta: -1 });
  assert.deepEqual(planFollowChange({ currentIds: [], follow: false, organization: kawssco }), { delta: 0 });
});

test("unfollowing works even after the organization is removed", () => {
  const removed = { id: "kawssco", exists: false, data: null };
  assert.deepEqual(planFollowChange({ currentIds: ["kawssco"], follow: false, organization: removed }), { delta: -1 });
  assert.equal(planFollowChange({ currentIds: [], follow: true, organization: removed }).code, "not-found");
});

test("public organizations and full lists are refused", () => {
  const publicOrg = { id: "deped", exists: true, data: { organizationSector: "public" } };
  assert.equal(planFollowChange({ currentIds: [], follow: true, organization: publicOrg }).code, "not-found");
  const full = Array.from({ length: MAX_FOLLOWED_ORGANIZATIONS }, (_, i) => `org${i}`);
  assert.equal(planFollowChange({ currentIds: full, follow: true, organization: kawssco }).code, "resource-exhausted");
});
