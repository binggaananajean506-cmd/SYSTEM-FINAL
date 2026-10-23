import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';

import '../../../auth_service.dart';
import '../../../core/errors/user_facing_error.dart';
import '../models/bayanihan_conversation.dart';

class BayanihanMessagingException implements Exception {
  const BayanihanMessagingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BayanihanMessagingService {
  BayanihanMessagingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _providedFirestore = firestore,
       _providedFunctions = functions;

  final FirebaseFirestore? _providedFirestore;
  final FirebaseFunctions? _providedFunctions;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _providedFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  String? _effectiveUserId(String? overrideId) {
    final explicit = overrideId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return AuthService.currentUser?.uid ??
        auth.FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<List<BayanihanConversation>> conversationsFor(String userId) {
    if (Firebase.apps.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('bayanihan_conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BayanihanConversation.fromDoc)
              .where((conversation) => conversation.isParticipant(userId))
              .toList(),
        );
  }

  Stream<BayanihanConversation?> conversation(String conversationId) {
    if (Firebase.apps.isEmpty) return Stream.value(null);
    return _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .snapshots()
        .map(
          (document) =>
              document.exists ? BayanihanConversation.fromDoc(document) : null,
        );
  }

  Stream<List<BayanihanMessage>> messages(String conversationId) {
    if (Firebase.apps.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(BayanihanMessage.fromDoc).toList(),
        );
  }

  Stream<int> unreadCount(String userId) => conversationsFor(userId).map(
    (items) =>
        items.fold(0, (total, item) => total + item.unreadCountFor(userId)),
  );

  Future<String> sendOffer({
    required String requestId,
    required String initialMessage,
    String? availability,
  }) async {
    final result = await _call('createBayanihanOffer', {
      'requestId': requestId,
      'initialMessage': initialMessage.trim(),
      'availability': availability?.trim() ?? '',
    });
    return result['conversationId']?.toString() ?? '';
  }

  Future<void> acceptOffer(String conversationId) =>
      _callVoid('acceptBayanihanOffer', {'conversationId': conversationId});

  Future<void> declineOffer(String conversationId, {required String reason}) =>
      _callVoid('declineBayanihanOffer', {
        'conversationId': conversationId,
        'reason': reason.trim(),
      });

  Future<void> withdraw(String conversationId, {required String reason}) =>
      _callVoid('withdrawBayanihanHelp', {
        'conversationId': conversationId,
        'reason': reason.trim(),
      });

  Future<void> closeRequest(String requestId, {required bool completed}) =>
      _callVoid('closeBayanihanRequest', {
        'requestId': requestId,
        'outcome': completed ? 'completed' : 'cancelled',
      });

  Future<void> markRead(String conversationId) {
    if (Firebase.apps.isEmpty) return Future.value();
    return _callVoid(
      'markBayanihanConversationRead',
      {'conversationId': conversationId},
    );
  }

  Future<void> sendMessage(
    String conversationId,
    String text, {
    String? userId,
  }) async {
    final effectiveUserId = _effectiveUserId(userId);
    final normalized = text.trim();
    if (effectiveUserId == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    if (normalized.isEmpty || normalized.length > 1000) {
      throw const BayanihanMessagingException(
        'Enter a message with no more than 1,000 characters.',
      );
    }
    await _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'senderId': effectiveUserId,
          'text': normalized,
          'kind': 'message',
          'sentAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> sendImageMessage(
    String conversationId, {
    required String imageUrl,
    String? caption,
    String? userId,
  }) async {
    final effectiveUserId = _effectiveUserId(userId);
    if (effectiveUserId == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    await _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
          'senderId': effectiveUserId,
          'text': caption?.trim() ?? '',
          'imageUrl': imageUrl,
          'kind': 'image',
          'sentAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText, {
    String? userId,
  }) async {
    final effectiveUserId = _effectiveUserId(userId);
    final normalized = newText.trim();
    if (effectiveUserId == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    if (normalized.isEmpty || normalized.length > 1000) {
      throw const BayanihanMessagingException('Message cannot be empty or exceed 1,000 characters.');
    }
    await _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': normalized,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> unsendMessage(
    String conversationId,
    String messageId, {
    String? userId,
  }) async {
    final effectiveUserId = _effectiveUserId(userId);
    if (effectiveUserId == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    await _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isUnsent': true,
          'unsentAt': FieldValue.serverTimestamp(),
          'text': '',
        });
  }

  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji, {
    String? userId,
  }) async {
    final effectiveUserId = _effectiveUserId(userId);
    if (effectiveUserId == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    final messageRef = _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(messageRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
        if (reactions[effectiveUserId] == emoji) {
          reactions.remove(effectiveUserId);
        } else {
          reactions[effectiveUserId] = emoji;
        }
        tx.update(messageRef, {'reactions': reactions});
      });
    } catch (_) {
      // Fallback direct document update
      final snap = await messageRef.get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      if (reactions[effectiveUserId] == emoji) {
        reactions.remove(effectiveUserId);
      } else {
        reactions[effectiveUserId] = emoji;
      }
      await messageRef.update({'reactions': reactions});
    }
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final userId = AuthService.currentUser?.uid;
    if (userId == null) return;
    final snap = await _firestore
        .collection('bayanihan_conversations')
        .doc(conversationId)
        .collection('messages')
        .get();
    for (final doc in snap.docs) {
      if (doc.data()['senderId'] == userId) {
        await doc.reference.update({
          'isUnsent': true,
          'unsentAt': FieldValue.serverTimestamp(),
          'text': '',
        });
      }
    }
  }

  Future<void> reportConversation(
    BayanihanConversation conversation,
    String details,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw const BayanihanMessagingException('Please sign in again.');
    }
    final ticket = _firestore.collection('helpdesk_tickets').doc();
    await ticket.set({
      'id': ticket.id,
      'userId': user.uid,
      'userName': user.name,
      'subject': 'Reported Bayanihan conversation',
      'message': details.trim().isEmpty
          ? 'Please review this Bayanihan conversation.'
          : details.trim(),
      'category': 'Bayanihan safety',
      'conversationId': conversation.id,
      'requestId': conversation.requestId,
      'status': 'Open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
          )
          .call(data);
      return Map<String, dynamic>.from(result.data as Map? ?? const {});
    } on FirebaseFunctionsException catch (error) {
      // Only fixed, reviewed server validation copy may cross this boundary.
      // Unknown server messages can contain internal paths or implementation details.
      const safeMessages = {
        'permission-denied': {
          'Account Restricted. Please contact your barangay office for assistance.',
          'Only the requester can respond to this offer.',
          'Only the helper can withdraw this offer.',
          'You cannot access this conversation.',
          'Only the requester can close this request.',
          'A valid E-SUGID account is required.',
        },
        'not-found': {
          'This help request no longer exists.',
          'Conversation not found.',
        },
        'failed-precondition': {
          'Offers can only be sent to help requests.',
          'You cannot offer help on your own request.',
          'This request is no longer accepting offers.',
          'This offer has already been reviewed.',
          'The help request is unavailable.',
          'The request is already closed.',
          'This request already has enough helpers.',
          'This help relationship is already closed.',
          'This request is already closed.',
        },
        'already-exists': {'You already offered help for this request.'},
        'invalid-argument': {
          'Choose completed or cancelled.',
          'Request is required.',
          'Initial message is required.',
          'Conversation is required.',
          'Reason is required.',
        },
      };
      throw BayanihanMessagingException(
        safeMessages[error.code]?.contains(error.message) == true
            ? error.message!
            : userFacingError(error,
                fallback: 'The Bayanihan request could not be updated. Try again.'),
      );
    } catch (error) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('timeout') || errorStr.contains('deadline')) {
        throw const BayanihanMessagingException(
          'Request timed out. Please check your connection and try again.',
        );
      }
      throw BayanihanMessagingException(
        userFacingError(
          error,
          fallback: 'The Bayanihan request could not be updated. Try again.',
        ),
      );
    }
  }

  Future<void> _callVoid(String name, Map<String, dynamic> data) async {
    await _call(name, data);
  }
}
