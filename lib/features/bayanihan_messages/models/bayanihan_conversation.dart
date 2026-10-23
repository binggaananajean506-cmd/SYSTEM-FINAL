import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firestore_converters.dart';

enum BayanihanConversationStatus {
  pending,
  active,
  completed,
  declined,
  cancelled,
  withdrawn;

  static BayanihanConversationStatus parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'active' || 'accepted' => active,
      'completed' || 'complete' => completed,
      'declined' || 'rejected' => declined,
      'cancelled' || 'canceled' => cancelled,
      'withdrawn' => withdrawn,
      _ => pending,
    };
  }

  bool get isArchived => this != pending && this != active;
  bool get canSendMessages => this == active;

  String get label => switch (this) {
    pending => 'Pending',
    active => 'Active',
    completed => 'Completed',
    declined => 'Declined',
    cancelled => 'Cancelled',
    withdrawn => 'Withdrawn',
  };

  String get readOnlyMessage => switch (this) {
    pending => 'Waiting for requester approval.',
    completed =>
      'This help request was marked as completed. The conversation is closed.',
    declined => 'This help offer was declined.',
    cancelled => 'This help request was cancelled.',
    withdrawn => 'The helper withdrew from this request.',
    active => '',
  };
}

class BayanihanConversation {
  const BayanihanConversation({
    required this.id,
    required this.requestId,
    required this.offerId,
    required this.requesterId,
    required this.helperId,
    required this.requestTitle,
    required this.requesterName,
    required this.helperName,
    required this.initialMessage,
    required this.status,
    required this.createdAt,
    this.requesterPhotoUrl,
    this.helperPhotoUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.requesterUnreadCount = 0,
    this.helperUnreadCount = 0,
    this.availability,
    this.declineReason,
    this.activatedAt,
    this.closedAt,
  });

  final String id;
  final String requestId;
  final String offerId;
  final String requesterId;
  final String helperId;
  final String requestTitle;
  final String requesterName;
  final String helperName;
  final String? requesterPhotoUrl;
  final String? helperPhotoUrl;
  final String initialMessage;
  final BayanihanConversationStatus status;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int requesterUnreadCount;
  final int helperUnreadCount;
  final String? availability;
  final String? declineReason;
  final DateTime? activatedAt;
  final DateTime? closedAt;

  bool isRequester(String userId) => requesterId == userId;
  bool isParticipant(String userId) =>
      requesterId == userId || helperId == userId;
  String otherParticipantName(String userId) =>
      isRequester(userId) ? helperName : requesterName;
  String? otherParticipantPhotoUrl(String userId) =>
      isRequester(userId) ? helperPhotoUrl : requesterPhotoUrl;
  int unreadCountFor(String userId) =>
      isRequester(userId) ? requesterUnreadCount : helperUnreadCount;

  factory BayanihanConversation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return BayanihanConversation(
      id: document.id,
      requestId: data['requestId']?.toString() ?? '',
      offerId: data['offerId']?.toString() ?? '',
      requesterId: data['requesterId']?.toString() ?? '',
      helperId: data['helperId']?.toString() ?? '',
      requestTitle: data['requestTitle']?.toString() ?? 'Help request',
      requesterName: data['requesterName']?.toString() ?? 'Requester',
      helperName: data['helperName']?.toString() ?? 'Helper',
      requesterPhotoUrl: data['requesterPhotoUrl']?.toString() ??
          data['requesterPhoto']?.toString(),
      helperPhotoUrl: data['helperPhotoUrl']?.toString() ??
          data['helperPhoto']?.toString(),
      initialMessage: data['initialMessage']?.toString() ?? '',
      status: BayanihanConversationStatus.parse(data['status']),
      createdAt: dateTimeFromFirestore(data['createdAt']),
      lastMessage: data['lastMessage']?.toString(),
      lastMessageAt: nullableDateTimeFromFirestore(data['lastMessageAt']),
      requesterUnreadCount: _nonNegativeInt(data['requesterUnreadCount']),
      helperUnreadCount: _nonNegativeInt(data['helperUnreadCount']),
      availability: data['availability']?.toString(),
      declineReason: data['declineReason']?.toString(),
      activatedAt: nullableDateTimeFromFirestore(data['activatedAt']),
      closedAt: nullableDateTimeFromFirestore(
        data['closedAt'] ?? data['completedAt'] ?? data['archivedAt'],
      ),
    );
  }

  static int _nonNegativeInt(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}

class BayanihanMessage {
  const BayanihanMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.kind = 'message',
    this.imageUrl,
    this.reactions = const <String, String>{},
    this.isEdited = false,
    this.editedAt,
    this.isUnsent = false,
    this.unsentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String kind;
  final String? imageUrl;
  final Map<String, String> reactions; // userId -> emoji
  final bool isEdited;
  final DateTime? editedAt;
  final bool isUnsent;
  final DateTime? unsentAt;

  factory BayanihanMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final reactionsData = data['reactions'];
    final reactions = <String, String>{};
    if (reactionsData is Map) {
      for (final entry in reactionsData.entries) {
        reactions[entry.key.toString()] = entry.value.toString();
      }
    }

    return BayanihanMessage(
      id: document.id,
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      sentAt: dateTimeFromFirestore(data['sentAt']),
      kind: data['kind']?.toString() ?? 'message',
      imageUrl: data['imageUrl']?.toString(),
      reactions: reactions,
      isEdited: data['isEdited'] == true,
      editedAt: nullableDateTimeFromFirestore(data['editedAt']),
      isUnsent: data['isUnsent'] == true,
      unsentAt: nullableDateTimeFromFirestore(data['unsentAt']),
    );
  }
}
