const test = require("node:test");
const assert = require("node:assert/strict");
const { canReviewInteraction, marketConfirmation, reviewId } = require("./community_review_helpers");

test("only accepted, completed Bayanihan participants can review each other", () => {
  const conversation = { status: "completed", activatedAt: true, requesterId: "requester", helperId: "helper" };
  assert.equal(canReviewInteraction("bayanihan", conversation, "requester", "helper"), true);
  assert.equal(canReviewInteraction("bayanihan", conversation, "helper", "requester"), true);
  assert.equal(canReviewInteraction("bayanihan", { ...conversation, activatedAt: null }, "requester", "helper"), false);
  assert.equal(canReviewInteraction("bayanihan", { ...conversation, status: "cancelled" }, "requester", "helper"), false);
  assert.equal(canReviewInteraction("bayanihan", conversation, "stranger", "helper"), false);
  assert.equal(canReviewInteraction("bayanihan", conversation, "helper", "helper"), false);
});

test("market reviews require both parties to confirm the handoff", () => {
  const conversation = { status: "completed", buyerConfirmedAt: true, sellerConfirmedAt: true, buyerId: "buyer", sellerId: "seller" };
  assert.equal(canReviewInteraction("market", conversation, "buyer", "seller"), true);
  assert.equal(canReviewInteraction("market", conversation, "seller", "buyer"), true);
  assert.equal(canReviewInteraction("market", { ...conversation, sellerConfirmedAt: null }, "buyer", "seller"), false);
  assert.equal(canReviewInteraction("market", conversation, "stranger", "seller"), false);
  assert.equal(marketConfirmation({ ...conversation, status: "accepted", sellerConfirmedAt: null }, "buyer").otherConfirmed, false);
  assert.equal(marketConfirmation({ ...conversation, status: "accepted" }, "seller").ownField, "sellerConfirmedAt");
  assert.equal(marketConfirmation(conversation, "buyer"), null);
});

test("review identity is stable per interaction and reviewer", () => {
  assert.equal(reviewId("market", "trade-1", "buyer"), reviewId("market", "trade-1", "buyer"));
  assert.notEqual(reviewId("market", "trade-1", "buyer"), reviewId("market", "trade-1", "seller"));
  assert.notEqual(reviewId("market", "trade-1", "buyer"), reviewId("bayanihan", "trade-1", "buyer"));
});
