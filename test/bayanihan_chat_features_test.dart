import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_conversation_page.dart';
import 'package:esugid/features/bayanihan_messages/services/bayanihan_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBayanihanMessagingService extends BayanihanMessagingService {
  String? lastReactedMessageId;
  String? lastReactedEmoji;
  String? lastEditedMessageId;
  String? lastEditedText;
  String? lastUnsentMessageId;

  @override
  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji, {
    String? userId,
  }) async {
    lastReactedMessageId = messageId;
    lastReactedEmoji = emoji;
  }

  @override
  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newText, {
    String? userId,
  }) async {
    lastEditedMessageId = messageId;
    lastEditedText = newText;
  }

  @override
  Future<void> unsendMessage(
    String conversationId,
    String messageId, {
    String? userId,
  }) async {
    lastUnsentMessageId = messageId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    uid: 'user_123',
    email: 'user123@barili.gov.ph',
    role: UserRole.resident,
    name: 'Ana Jean',
  );

  final testConversation = BayanihanConversation(
    id: 'conv_123',
    requestId: 'req_123',
    offerId: 'user_123',
    requesterId: 'requester_456',
    helperId: 'user_123',
    requestTitle: 'Tabang',
    requesterName: 'Ana Jean Atamosa',
    helperName: 'Helper User',
    initialMessage: 'Hi! I am available to help.',
    status: BayanihanConversationStatus.active,
    createdAt: DateTime(2026, 9, 30),
  );

  final testMessage = BayanihanMessage(
    id: 'msg_001',
    senderId: 'user_123',
    text: 'okay',
    sentAt: DateTime(2026, 9, 30, 10, 0),
    kind: 'message',
    reactions: {'user_123': '❤️'},
  );

  group('Bayanihan Chat Styling & Actions', () {
    testWidgets('Message bubble uses e-sugid civic emerald theme and NOT orange',
        (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      final mockService = MockBayanihanMessagingService();

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanConversationPage(
            initialConversation: testConversation,
            service: mockService,
            messageStream: Stream.value([testMessage]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the message text is rendered
      expect(find.text('okay'), findsOneWidget);

      // Verify that the sent bubble decoration color is emerald, not amber/orange (0xFFF59E0B)
      final containers = tester.widgetList<Container>(find.byType(Container));
      bool hasOrange = false;
      bool hasEmeraldBubble = false;

      for (final container in containers) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          final color = decoration.color;
          if (color == const Color(0xFFF59E0B) || color == const Color(0xFFD97706)) {
            hasOrange = true;
          }
          if (color == ESugidColors.light.brand) {
            hasEmeraldBubble = true;
          }
        }
      }

      expect(hasOrange, isFalse, reason: 'No message elements should use orange color');
      expect(hasEmeraldBubble, isTrue, reason: 'Sent message bubble must use E-Sugid emerald');
    });

    testWidgets('Long press on message allows reaction, edit, and unsend actions',
        (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      final mockService = MockBayanihanMessagingService();

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanConversationPage(
            initialConversation: testConversation,
            service: mockService,
            messageStream: Stream.value([testMessage]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press message to open action menu
      await tester.longPress(find.text('okay'));
      await tester.pumpAndSettle();

      // Check Messenger-style reactions and actions appear
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('Edit message'), findsOneWidget);
      expect(find.text('Unsend message'), findsOneWidget);

      // Test reaction selection
      await tester.tap(find.text('👍'));
      await tester.pumpAndSettle();

      expect(mockService.lastReactedMessageId, 'msg_001');
      expect(mockService.lastReactedEmoji, '👍');
    });

    testWidgets('Unsend message dialog prompts and triggers unsend callback',
        (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      final mockService = MockBayanihanMessagingService();

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanConversationPage(
            initialConversation: testConversation,
            service: mockService,
            messageStream: Stream.value([testMessage]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press message
      await tester.longPress(find.text('okay'));
      await tester.pumpAndSettle();

      // Tap "Unsend message"
      await tester.tap(find.text('Unsend message'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Unsend message?'), findsOneWidget);
      expect(find.text('Unsend'), findsOneWidget);

      // Tap confirm Unsend
      await tester.tap(find.text('Unsend'));
      await tester.pumpAndSettle();

      expect(mockService.lastUnsentMessageId, 'msg_001');
      expect(find.text('Message unsent'), findsOneWidget);
    });

    testWidgets('Edit message dialog updates text and triggers edit callback',
        (tester) async {
      AuthService.currentUser = testUser;
      addTearDown(() => AuthService.currentUser = null);

      final mockService = MockBayanihanMessagingService();

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanConversationPage(
            initialConversation: testConversation,
            service: mockService,
            messageStream: Stream.value([testMessage]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press message
      await tester.longPress(find.text('okay'));
      await tester.pumpAndSettle();

      // Tap "Edit message"
      await tester.tap(find.text('Edit message'));
      await tester.pumpAndSettle();

      // Dialog opens with initial text
      expect(find.text('Edit Message'), findsOneWidget);

      // Enter new text and save
      await tester.enterText(find.byType(TextField).last, 'okay, see you!');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(mockService.lastEditedMessageId, 'msg_001');
      expect(mockService.lastEditedText, 'okay, see you!');
      expect(find.text('Message updated'), findsOneWidget);
    });
  });
}
