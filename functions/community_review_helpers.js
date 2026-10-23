const { createHash } = require("crypto");

function reviewId(context, sourceId, reviewerId) {
  return createHash("sha256")
    .update(`${context}:${sourceId}:${reviewerId}`)
    .digest("hex");
}

function canReviewInteraction(context, conversation, reviewerId, targetUserId) {
  if (!conversation || reviewerId === targetUserId) return false;
  if (context === "bayanihan") {
    return conversation.status === "completed"
      && Boolean(conversation.activatedAt)
      && ((conversation.requesterId === reviewerId && conversation.helperId === targetUserId)
        || (conversation.helperId === reviewerId && conversation.requesterId === targetUserId));
  }
  if (context === "market") {
    return conversation.status === "completed"
      && Boolean(conversation.buyerConfirmedAt)
      && Boolean(conversation.sellerConfirmedAt)
      && ((conversation.buyerId === reviewerId && conversation.sellerId === targetUserId)
        || (conversation.sellerId === reviewerId && conversation.buyerId === targetUserId));
  }
  return false;
}

function marketConfirmation(conversation, userId) {
  if (!conversation || conversation.status !== "accepted") return null;
  if (userId === conversation.buyerId) {
    return { ownField: "buyerConfirmedAt", otherConfirmed: Boolean(conversation.sellerConfirmedAt) };
  }
  if (userId === conversation.sellerId) {
    return { ownField: "sellerConfirmedAt", otherConfirmed: Boolean(conversation.buyerConfirmedAt) };
  }
  return null;
}

module.exports = { canReviewInteraction, marketConfirmation, reviewId };
