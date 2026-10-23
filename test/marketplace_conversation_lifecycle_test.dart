import 'dart:async';

import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/marketplace_conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MarketplaceInterestRequest _request(String id) => MarketplaceInterestRequest(
  id: id, itemId: 'item', itemName: 'Mangoes', itemImageUrl: '',
  buyerId: 'buyer', buyerName: 'Buyer', sellerId: 'seller', sellerName: 'Seller',
  initialMessage: 'Hello', status: MarketplaceInterestStatus.pending,
  createdAt: DateTime(2026),
);

void main() {
  testWidgets('failed marketplace conversation offers an explicit retry', (tester) async {
    final conversation = StreamController<MarketplaceInterestRequest?>.broadcast();
    final messages = StreamController<List<Map<String, dynamic>>>.broadcast();
    await tester.pumpWidget(MaterialApp(home: MarketplaceConversationPage(
      request: _request('one'), conversationStream: conversation.stream,
      messageStream: messages.stream,
    )));
    conversation.addError(StateError('private'));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    conversation.add(_request('one'));
    await tester.pump();
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await conversation.close();
    await messages.close();
  });
  testWidgets('shares subscriptions and cancels old conversation and message sources', (tester) async {
    var cancellations = 0;
    StreamController<T> source<T>() => StreamController<T>(onCancel: () { cancellations++; });
    final conversation = source<MarketplaceInterestRequest?>();
    final messages = source<List<Map<String, dynamic>>>();
    final replacementConversation = source<MarketplaceInterestRequest?>();
    final replacementMessages = source<List<Map<String, dynamic>>>();
    Future<void> show(String id, Stream<MarketplaceInterestRequest?> conv, Stream<List<Map<String, dynamic>>> msg) async {
      await tester.pumpWidget(MaterialApp(home: MarketplaceConversationPage(
        request: _request(id), conversationStream: conv, messageStream: msg,
      )));
      await tester.pump();
    }
    await show('one', conversation.stream, messages.stream);
    expect(tester.takeException(), isNull);
    await show('one', conversation.stream, messages.stream);
    expect(cancellations, 0);
    await show('two', replacementConversation.stream, replacementMessages.stream);
    expect(tester.takeException(), isNull);
    expect(cancellations, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(cancellations, 4);
  });
}
