import 'dart:async';

import 'package:esugid/auth_service.dart';
import 'package:esugid/features/bayanihan_messages/models/bayanihan_conversation.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_conversation_page.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'package:esugid/features/bayanihan_messages/services/bayanihan_messaging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends BayanihanMessagingService {
  final conversationIds = <String>[];
  final messageIds = <String>[];
  final inboxIds = <String>[];
  int cancellations = 0;
  bool failConversation = false;
  Completer<void>? pendingSend;

  @override
  Future<void> sendMessage(String conversationId, String text, {String? userId}) async {
    await pendingSend?.future;
  }

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Stream<BayanihanConversation?> conversation(String id) {
    conversationIds.add(id);
    return failConversation ? Stream.error(StateError('private')) : Stream.value(_conversation(id));
  }

  @override
  Stream<List<BayanihanMessage>> messages(String id) {
    messageIds.add(id);
    return StreamController<List<BayanihanMessage>>(
      onCancel: () { cancellations++; },
    ).stream;
  }

  @override
  Stream<List<BayanihanConversation>> conversationsFor(String id) {
    inboxIds.add(id);
    return Stream.value(const []);
  }
}

BayanihanConversation _conversation(String id) => BayanihanConversation(
  id: id, requestId: 'request', offerId: 'offer', requesterId: 'requester',
  helperId: 'helper', requestTitle: 'Help', requesterName: 'Requester',
  helperName: 'Helper', initialMessage: 'Hello',
  status: BayanihanConversationStatus.active, createdAt: DateTime(2026),
);

User _user(String id) => User(uid: id, email: '$id@example.com', role: UserRole.resident, name: id);

void main() {
  tearDown(() => AuthService.currentUser = null);

  testWidgets('send failure after leaving conversation never writes a disposed controller', (tester) async {
    AuthService.currentUser = _user('requester');
    final send = Completer<void>();
    final service = _Service()..pendingSend = send;
    await tester.pumpWidget(MaterialApp(home: BayanihanConversationPage(
      initialConversation: _conversation('one'), service: service,
    )));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpWidget(const SizedBox());
    send.completeError(StateError('private'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('send failure preserves the newer draft', (tester) async {
    AuthService.currentUser = _user('requester');
    final send = Completer<void>();
    final service = _Service()..pendingSend = send;
    await tester.pumpWidget(MaterialApp(home: BayanihanConversationPage(
      initialConversation: _conversation('one'), service: service,
    )));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Original');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'New draft');
    send.completeError(StateError('private'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'New draft');
  });

  testWidgets('conversation streams stay stable and refresh for service and ID changes', (tester) async {
    AuthService.currentUser = _user('requester');
    final first = _Service();
    final second = _Service();
    Future<void> show(_Service service, String id) async {
      await tester.pumpWidget(MaterialApp(home: BayanihanConversationPage(
        initialConversation: _conversation(id), service: service,
      )));
      await tester.pump();
    }
    await show(first, 'one');
    await show(first, 'one');
    expect(first.conversationIds, ['one']);
    expect(first.messageIds, ['one']);
    await show(second, 'one');
    expect(second.conversationIds, ['one']);
    expect(second.messageIds, ['one']);
    expect(first.cancellations, 1);
    await show(second, 'two');
    expect(second.conversationIds, ['one', 'two']);
    expect(second.messageIds, ['one', 'two']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(second.cancellations, 2);
  });

  testWidgets('Retry recreates a failed conversation stream', (tester) async {
    final service = _Service()..failConversation = true;
    await tester.pumpWidget(MaterialApp(home: BayanihanConversationPage(
      initialConversation: _conversation('one'), service: service,
    )));
    await tester.pump();
    service.failConversation = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(service.conversationIds, ['one', 'one']);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('inbox refreshes when account or service changes', (tester) async {
    final first = _Service();
    final second = _Service();
    Future<void> show(_Service service, String id) async {
      await tester.pumpWidget(MaterialApp(home: BayanihanMessagesPage(user: _user(id), service: service)));
      await tester.pump();
    }
    await show(first, 'one');
    await show(first, 'two');
    expect(first.inboxIds, ['one', 'two']);
    await show(second, 'two');
    expect(second.inboxIds, ['two']);
  });
}
