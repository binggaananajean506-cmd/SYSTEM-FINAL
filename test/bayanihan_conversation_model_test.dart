import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';

void main() {
  test('conversation lifecycle normalizes legacy offer statuses', () {
    expect(
      BayanihanConversationStatus.parse('accepted'),
      BayanihanConversationStatus.active,
    );
    expect(
      BayanihanConversationStatus.parse('rejected'),
      BayanihanConversationStatus.declined,
    );
    expect(
      BayanihanConversationStatus.parse('canceled'),
      BayanihanConversationStatus.cancelled,
    );
    expect(
      BayanihanConversationStatus.parse(null),
      BayanihanConversationStatus.pending,
    );
  });

  test('only active conversations allow sending', () {
    for (final status in BayanihanConversationStatus.values) {
      expect(
        status.canSendMessages,
        status == BayanihanConversationStatus.active,
      );
      expect(
        status.isArchived,
        !{
          BayanihanConversationStatus.pending,
          BayanihanConversationStatus.active,
        }.contains(status),
      );
    }
  });

  test('unread state is private to each participant', () {
    final conversation = _conversation(
      requesterUnreadCount: 3,
      helperUnreadCount: 1,
    );
    expect(conversation.unreadCountFor('requester'), 3);
    expect(conversation.unreadCountFor('helper'), 1);
    expect(conversation.otherParticipantName('requester'), 'Helper');
    expect(conversation.otherParticipantName('helper'), 'Requester');
  });
}

BayanihanConversation _conversation({
  int requesterUnreadCount = 0,
  int helperUnreadCount = 0,
}) {
  return BayanihanConversation(
    id: 'conversation',
    requestId: 'request',
    offerId: 'helper',
    requesterId: 'requester',
    helperId: 'helper',
    requestTitle: 'Harvest corn',
    requesterName: 'Requester',
    helperName: 'Helper',
    initialMessage: 'I can help.',
    status: BayanihanConversationStatus.active,
    createdAt: DateTime(2026),
    requesterUnreadCount: requesterUnreadCount,
    helperUnreadCount: helperUnreadCount,
  );
}
