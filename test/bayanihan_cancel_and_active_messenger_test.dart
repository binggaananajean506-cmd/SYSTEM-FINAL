import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'package:esugid/features/bayanihan_messages/presentation/widgets/cancel_offer_dialog.dart';
import 'package:esugid/features/bayanihan_messages/services/bayanihan_messaging_service.dart';

class _FakeMessagingService extends BayanihanMessagingService {
  String? lastWithdrawnConversationId;
  String? lastWithdrawReason;
  String? lastSentMessage;

  @override
  Future<void> withdraw(String conversationId, {required String reason}) async {
    lastWithdrawnConversationId = conversationId;
    lastWithdrawReason = reason;
  }

  @override
  Future<void> sendMessage(
    String conversationId,
    String text, {
    String? userId,
  }) async {
    lastSentMessage = text;
  }
}

void main() {
  final helperUser = User(
    uid: 'helper_1',
    email: 'helper@example.com',
    role: UserRole.resident,
    name: 'Helper Resident',
  );

  final pendingConversation = BayanihanConversation(
    id: 'conv_pending',
    requestId: 'req_1',
    offerId: 'off_1',
    requesterId: 'requester_1',
    helperId: 'helper_1',
    requestTitle: 'Need help moving boxes',
    requesterName: 'Julie Mae Tenebroso',
    helperName: 'Helper Resident',
    initialMessage: "Hi! I'm available to help with this request.",
    status: BayanihanConversationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    lastMessage: "Hi! I'm available to help with this request.",
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
    helperUnreadCount: 0,
    requesterUnreadCount: 1,
  );

  final activeConversation = BayanihanConversation(
    id: 'conv_active',
    requestId: 'req_2',
    offerId: 'off_2',
    requesterId: 'requester_1',
    helperId: 'helper_1',
    requestTitle: 'Carpentry assistance',
    requesterName: 'Julie Mae Tenebroso',
    helperName: 'Helper Resident',
    initialMessage: 'I can bring tools.',
    status: BayanihanConversationStatus.active,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    lastMessage: 'Sure, see you at 8am tomorrow!',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
    helperUnreadCount: 3, // 3 unread messages for helper
    requesterUnreadCount: 0,
  );

  group('Cancel Offer with Proper Message', () {
    testWidgets(
      'tapping Cancel Offer opens dialog with polite reasons and sends proper message upon confirmation',
      (tester) async {
        AuthService.currentUser = helperUser;
        addTearDown(() => AuthService.currentUser = null);

        final fakeService = _FakeMessagingService();

        await tester.pumpWidget(
          MaterialApp(
            home: BayanihanMessagesPage(
              user: helperUser,
              service: fakeService,
              conversations: Stream.value([pendingConversation]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pending helper card shows 'Cancel Offer'
        final cancelOfferButton = find.text('Cancel Offer');
        expect(cancelOfferButton, findsOneWidget);

        // Tap 'Cancel Offer'
        await tester.tap(cancelOfferButton);
        await tester.pumpAndSettle();

        // Verify Dialog appears with Title and Recipient details
        expect(find.text('Cancel Help Offer'), findsOneWidget);
        expect(
          find.text('Send a message to Julie Mae Tenebroso'),
          findsOneWidget,
        );

        // Verify predefined reason chips exist
        expect(find.text('Schedule conflict'), findsOneWidget);
        expect(find.text('Emergency / Urgent matter'), findsOneWidget);
        expect(find.text('No longer in area'), findsOneWidget);
        expect(find.text('Other personal reason'), findsOneWidget);

        // Verify polite default message pre-filled in TextField
        expect(
          find.text(
            "I'm sorry, an unexpected schedule conflict came up and I won't be able to help with your request. Sincere apologies for the inconvenience.",
          ),
          findsOneWidget,
        );

        // Tap different reason chip
        await tester.tap(find.text('Emergency / Urgent matter'));
        await tester.pumpAndSettle();

        // Verify text field updated with new polite message
        expect(
          find.text(
            'I am very sorry, but an unexpected personal emergency arose and I am unable to attend. I hope you find another volunteer soon.',
          ),
          findsOneWidget,
        );

        // Confirm cancellation
        final confirmButton = find.widgetWithText(FilledButton, 'Cancel Offer');
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Verify service was called with proper message
        expect(fakeService.lastWithdrawnConversationId, 'conv_pending');
        expect(
          fakeService.lastWithdrawReason,
          contains('emergency arose and I am unable to attend'),
        );
        expect(
          fakeService.lastSentMessage,
          contains('📢 Offer cancelled:'),
        );

        // Verify confirmation SnackBar
        expect(
          find.text(
            'Offer cancelled. Your message was sent to Julie Mae Tenebroso.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('BayanihanCancelOfferDialog can cancel/dismiss without withdrawing', (
      tester,
    ) async {
      String? returnedReason = 'initial';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                returnedReason = await showBayanihanCancelOfferDialog(
                  context,
                  recipientName: 'Ana Jean Atamosa',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Help Offer'), findsOneWidget);
      expect(find.text('Send a message to Ana Jean Atamosa'), findsOneWidget);

      // Tap 'Keep Offer'
      await tester.tap(find.text('Keep Offer'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Help Offer'), findsNothing);
      expect(returnedReason, isNull);
    });
  });

  group('Active Tab Messenger-Style View', () {
    testWidgets(
      'Active tab displays ONLY user account same as Messenger with badge number',
      (tester) async {
        AuthService.currentUser = helperUser;
        addTearDown(() => AuthService.currentUser = null);

        await tester.pumpWidget(
          MaterialApp(
            home: BayanihanMessagesPage(
              user: helperUser,
              conversations: Stream.value([
                pendingConversation,
                activeConversation,
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Active tab
        await tester.tap(find.text('Active'));
        await tester.pumpAndSettle();

        // User account name is visible
        expect(find.text('Julie Mae Tenebroso'), findsOneWidget);

        // Subtitle with snippet is visible
        expect(
          find.textContaining('Sure, see you at 8am tomorrow!'),
          findsOneWidget,
        );

        // Prominent Red Badge number (3 unread messages) is visible
        expect(find.text('3'), findsOneWidget);

        // Verify removed bulky elements from Active are NOT present:
        // No 'Active Chat' badge
        expect(find.text('Active Chat'), findsNothing);
        // No 'Carpentry assistance' request title
        expect(find.text('Carpentry assistance'), findsNothing);
        // No 'Open conversation' label
        expect(find.text('Open conversation'), findsNothing);
      },
    );
  });
}
