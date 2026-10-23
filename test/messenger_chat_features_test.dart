import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/widgets/chat_message_actions.dart';

void main() {
  group('ChatMessageReactionPill', () {
    testWidgets('renders emojis and counts properly', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChatMessageReactionPill(
                reactions: const {
                  'user1': '❤️',
                  'user2': '👍',
                  'user3': '❤️',
                },
                currentUserId: 'user1',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Verify emojis and count
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Tap pill
      await tester.tap(find.byType(ChatMessageReactionPill));
      expect(tapped, isTrue);
    });

    testWidgets('renders empty when reactions map is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChatMessageReactionPill(
                reactions: const {},
                currentUserId: 'user1',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('❤️'), findsNothing);
      expect(find.byType(ChatMessageReactionPill), findsOneWidget);
    });
  });

  group('Messenger Action Sheet & Reactions', () {
    testWidgets('shows reaction bar and options for sender', (tester) async {
      String? selectedEmoji;
      bool unsendCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showChatMessageActionMenu(
                    context,
                    messageId: 'msg-1',
                    text: 'Hello, this is a test message!',
                    isMine: true,
                    isUnsent: false,
                    currentReactions: const {'user2': '👍'},
                    currentUserId: 'user1',
                    onReactionSelected: (emoji) => selectedEmoji = emoji,
                    onEdit: (_) {},
                    onUnsend: () => unsendCalled = true,
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open menu
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Reaction bar emojis
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
      expect(find.text('😮'), findsOneWidget);
      expect(find.text('😢'), findsOneWidget);
      expect(find.text('😡'), findsOneWidget);

      // Menu options
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Edit message'), findsOneWidget);
      expect(find.text('Unsend message'), findsOneWidget);

      // Select heart emoji
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();

      expect(selectedEmoji, '❤️');
      expect(unsendCalled, isFalse);
    });

    testWidgets('shows only reactions and copy for recipient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showChatMessageActionMenu(
                    context,
                    messageId: 'msg-1',
                    text: 'Message from someone else',
                    isMine: false,
                    isUnsent: false,
                    currentReactions: const {},
                    currentUserId: 'user1',
                    onReactionSelected: (_) {},
                    onEdit: (_) {},
                    onUnsend: () {},
                  );
                },
                child: const Text('Open Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Edit message'), findsNothing);
      expect(find.text('Unsend message'), findsNothing);
    });
  });

  group('Marketplace unread counts & model', () {
    test('MarketplaceInterestRequest calculates unreadCount correctly', () {
      final request = MarketplaceInterestRequest(
        id: 'conv-1',
        itemId: 'item-1',
        itemName: 'Fresh Mangoes',
        itemImageUrl: 'https://example.com/mango.jpg',
        buyerId: 'buyer-1',
        buyerName: 'Buyer One',
        sellerId: 'seller-1',
        sellerName: 'Seller One',
        initialMessage: 'Available?',
        status: MarketplaceInterestStatus.accepted,
        createdAt: DateTime(2026, 9, 30),
        buyerUnreadCount: 2,
        sellerUnreadCount: 5,
      );

      expect(request.unreadCountFor('buyer-1'), 2);
      expect(request.unreadCountFor('seller-1'), 5);
      expect(request.isBuyer('buyer-1'), isTrue);
      expect(request.isSeller('seller-1'), isTrue);
    });
  });

  group('BayanihanMessage model properties', () {
    test('supports imageUrl, reactions, isEdited, and isUnsent', () {
      final msg = BayanihanMessage(
        id: 'msg-1',
        senderId: 'user-1',
        text: 'Updated message',
        sentAt: DateTime(2026, 9, 30),
        kind: 'image',
        imageUrl: 'https://example.com/photo.jpg',
        reactions: {'user-2': '❤️'},
        isEdited: true,
        editedAt: DateTime(2026, 9, 30, 9, 30),
        isUnsent: false,
      );

      expect(msg.imageUrl, 'https://example.com/photo.jpg');
      expect(msg.reactions['user-2'], '❤️');
      expect(msg.isEdited, isTrue);
      expect(msg.isUnsent, isFalse);
    });
  });
}
