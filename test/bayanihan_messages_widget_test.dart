import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_conversation_page.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'package:esugid/features/bayanihan_messages/presentation/widgets/bayanihan_unread_button.dart';
import 'package:esugid/features/bayanihan_messages/presentation/widgets/offer_help_dialog.dart';
import 'package:esugid/jobs_service.dart';

void main() {
  final user = User(
    uid: 'requester',
    email: 'requester@example.com',
    role: UserRole.resident,
    name: 'Requester',
  );

  testWidgets('empty inbox has a designed Bayanihan empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BayanihanMessagesPage(
          user: user,
          conversations: Stream.value(const []),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No Bayanihan conversations yet'), findsOneWidget);
  });

  testWidgets('pending requester can review the offer', (tester) async {
    final conversation = _conversation(BayanihanConversationStatus.pending);
    AuthService.currentUser = user;
    addTearDown(() => AuthService.currentUser = null);
    await _pumpConversation(tester, conversation);
    expect(find.text('Review this offer'), findsOneWidget);
    expect(find.text('Accept Offer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('active conversation shows a composer', (tester) async {
    final conversation = _conversation(BayanihanConversationStatus.active);
    AuthService.currentUser = user;
    addTearDown(() => AuthService.currentUser = null);
    await _pumpConversation(tester, conversation);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(
      find.text('Open the request to mark the help as completed.'),
      findsOneWidget,
    );
  });

  testWidgets('View Request forwards the linked request id', (tester) async {
    final conversation = _conversation(BayanihanConversationStatus.active);
    AuthService.currentUser = user;
    addTearDown(() => AuthService.currentUser = null);
    String? openedRequestId;
    await _pumpConversation(
      tester,
      conversation,
      onViewRequest: (requestId) => openedRequestId = requestId,
    );
    await tester.tap(find.text('View Request'));
    expect(openedRequestId, 'request');
  });

  testWidgets('archived conversation is read-only', (tester) async {
    final conversation = _conversation(BayanihanConversationStatus.completed);
    AuthService.currentUser = user;
    addTearDown(() => AuthService.currentUser = null);
    await _pumpConversation(tester, conversation);
    expect(find.textContaining('conversation is read-only'), findsOneWidget);
    expect(find.byTooltip('Send message'), findsNothing);
  });

  testWidgets('unread button displays the unread count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BayanihanUnreadButton(
            unreadStream: Stream.value(3),
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  for (final configuration in <(double, double)>[
    (240, 1),
    (320, 1.5),
    (360, 2),
    (390, 2),
    (600, 2),
  ]) {
    final (width, scale) = configuration;
    testWidgets('inbox fits ${width.toInt()}px at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: BayanihanMessagesPage(
              user: user,
              conversations: Stream.value([
                _conversation(BayanihanConversationStatus.pending),
              ]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final configuration in <(double, double)>[
    (240, 1),
    (320, 1.5),
    (360, 2),
    (390, 2),
    (600, 2),
  ]) {
    final (width, scale) = configuration;
    testWidgets('conversation fits ${width.toInt()}px at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AuthService.currentUser = user;
      addTearDown(() => AuthService.currentUser = null);
      final conversation = _conversation(BayanihanConversationStatus.active);
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/jobs': (_) => const Scaffold()},
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: BayanihanConversationPage(
              initialConversation: conversation,
              conversationStream: Stream.value(conversation),
              messageStream: Stream.value([
                BayanihanMessage(
                  id: 'message',
                  senderId: 'helper',
                  text: 'I can help Saturday morning.',
                  sentAt: DateTime(2026),
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending review panel fits 240px at 2.0x text', (tester) async {
    tester.view.physicalSize = const Size(240, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.currentUser = user;
    addTearDown(() => AuthService.currentUser = null);
    final conversation = _conversation(BayanihanConversationStatus.pending);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BayanihanConversationPage(
            initialConversation: conversation,
            conversationStream: Stream.value(conversation),
            messageStream: Stream.value(const []),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offer form fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: OfferHelpDialog(
              request: JobItem(
                id: 'request',
                posterId: 'requester',
                title: 'Harvest corn',
                company: 'Requester',
                salary: '',
                type: 'Help Request',
                description: 'Help needed',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpConversation(
  WidgetTester tester,
  BayanihanConversation conversation, {
  ValueChanged<String>? onViewRequest,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {'/jobs': (_) => const Scaffold()},
      home: BayanihanConversationPage(
        initialConversation: conversation,
        onViewRequest: onViewRequest,
        conversationStream: Stream.value(conversation),
        messageStream: Stream.value([
          BayanihanMessage(
            id: 'initial',
            senderId: 'helper',
            text: 'I can help Saturday morning.',
            sentAt: DateTime(2026),
          ),
        ]),
      ),
    ),
  );
  await tester.pump();
}

BayanihanConversation _conversation(BayanihanConversationStatus status) {
  return BayanihanConversation(
    id: 'conversation',
    requestId: 'request',
    offerId: 'helper',
    requesterId: 'requester',
    helperId: 'helper',
    requestTitle: 'Harvest corn',
    requesterName: 'Requester',
    helperName: 'Helper',
    initialMessage: 'I can help Saturday morning.',
    status: status,
    createdAt: DateTime(2026),
    lastMessage: 'I can help Saturday morning.',
    lastMessageAt: DateTime(2026),
    requesterUnreadCount: 1,
  );
}
