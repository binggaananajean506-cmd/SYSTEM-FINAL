import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'package:esugid/features/bayanihan_messages/presentation/widgets/bayanihan_unread_button.dart';
import 'package:esugid/pages/request_help_page.dart';

void main() {
  final user = User(
    uid: 'test_user',
    email: 'test@example.com',
    role: UserRole.resident,
    name: 'Test Resident',
  );

  testWidgets(
    'BayanihanUnreadButton renders 3D glassmorphic button and unread count',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BayanihanUnreadButton(
              unreadStream: Stream.value(5),
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets(
    'RequestHelpPage renders 3D header and all interactive sections',
    (tester) async {
      AuthService.currentUser = user;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(const MaterialApp(home: RequestHelpPage()));
      await tester.pumpAndSettle();

      expect(find.text('BARILI BAYANIHAN'), findsOneWidget);
      expect(find.text('Request Help'), findsOneWidget);
      expect(find.text('Errands'), findsOneWidget);
      expect(find.text('ASK FOR HELP'), findsOneWidget);
    },
  );

  testWidgets(
    'BayanihanMessagesPage renders 3D header, tabs, and 3D empty state',
    (tester) async {
      AuthService.currentUser = user;
      addTearDown(() => AuthService.currentUser = null);

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanMessagesPage(
            user: user,
            conversations: Stream.value(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BARILI CIVIC NETWORK'), findsOneWidget);
      expect(find.text('Bayanihan Messages'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('No Bayanihan conversations yet'), findsOneWidget);
      expect(find.text('Explore Help Requests'), findsOneWidget);
    },
  );

  testWidgets(
    'BayanihanMessagesPage renders 3D segmented tabs with count badges and card matching Local Market',
    (tester) async {
      AuthService.currentUser = user;
      addTearDown(() => AuthService.currentUser = null);

      final conversation = BayanihanConversation(
        id: 'conv1',
        requestId: 'req1',
        offerId: 'off1',
        requesterId: 'test_user',
        helperId: 'helper_1',
        requestTitle: 'Help with harvest',
        requesterName: 'Test Resident',
        helperName: 'Juan Dela Cruz',
        initialMessage: 'Hi! I can help you tomorrow morning.',
        status: BayanihanConversationStatus.pending,
        createdAt: DateTime(2026, 9, 29),
        lastMessage: 'Hi! I can help you tomorrow morning.',
        lastMessageAt: DateTime(2026, 9, 29),
        requesterUnreadCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BayanihanMessagesPage(
            user: user,
            conversations: Stream.value([conversation]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Badge
      expect(find.text('BARILI CIVIC NETWORK'), findsOneWidget);
      expect(find.text('Bayanihan Messages'), findsOneWidget);

      // Tab bar count badge & conversation unread badge
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);

      // Card details matching Local Market Buyer Requests design
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Waiting for your review'), findsOneWidget);
      expect(find.text('Help with harvest'), findsOneWidget);
      expect(find.text('Hi! I can help you tomorrow morning.'), findsOneWidget);

      // Action buttons
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept & Chat'), findsOneWidget);

      // Verified blue badge check icon
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
    },
  );
}
