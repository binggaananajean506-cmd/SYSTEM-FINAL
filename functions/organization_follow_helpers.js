"use strict";

// Residents follow private organizations from the directory; the list lives
// on their users/{uid} document and only this backend writes it.
const MAX_FOLLOWED_ORGANIZATIONS = 200;
const INACTIVE_ORGANIZATION_STATUSES = new Set(["deactivated", "inactive", "rejected"]);

function canonicalOrganizationId(value) {
  const id = String(value ?? "").trim();
  if (!id || id.length > 128 || id.includes("/")) return "";
  return id;
}

function isPrivateSectorOrganization(data) {
  if (!data || typeof data !== "object") return false;
  return String(data.organizationSector ?? data.sector ?? "").toLowerCase() === "private";
}

/** Matches the Private Organizations directory: private sector and active. */
function isFollowableOrganization(data) {
  if (!isPrivateSectorOrganization(data)) return false;
  const status = String(data.status ?? "").toLowerCase();
  return !INACTIVE_ORGANIZATION_STATUSES.has(status);
}

/** The organization a post was published for, or "" for other publishers. */
function organizationIdForPost(post) {
  if (!post) return "";
  const type = String(post.publisherEntityType ?? "").toLowerCase();
  const role = String(post.authorRole ?? "").toLowerCase();
  const fromOrganization = type === "organization" || type === "private_organization" ||
    (!type && (role === "organization" || role === "partner"));
  return fromOrganization ? canonicalOrganizationId(post.publisherEntityId) : "";
}

function followedOrganizationIds(userData) {
  const ids = userData?.followedOrganizationIds;
  return Array.isArray(ids) ? ids.filter((id) => typeof id === "string") : [];
}

/**
 * Decides what a follow request changes. Returns `{ delta }` (+1, -1 or 0 for
 * the user's list and the organization's follower count) or `{ error, code }`.
 */
function planFollowChange({ currentIds, follow, organization }) {
  const isFollowing = currentIds.includes(organization.id);
  if (follow === isFollowing) return { delta: 0 };
  if (!follow) return { delta: -1 };
  if (!organization.exists || !isFollowableOrganization(organization.data)) {
    return { code: "not-found", error: "This organization cannot be followed." };
  }
  if (currentIds.length >= MAX_FOLLOWED_ORGANIZATIONS) {
    return {
      code: "resource-exhausted",
      error: `You can follow up to ${MAX_FOLLOWED_ORGANIZATIONS} organizations.`,
    };
  }
  return { delta: 1 };
}

module.exports = {
  MAX_FOLLOWED_ORGANIZATIONS,
  canonicalOrganizationId,
  followedOrganizationIds,
  isFollowableOrganization,
  isPrivateSectorOrganization,
  organizationIdForPost,
  planFollowChange,
};
