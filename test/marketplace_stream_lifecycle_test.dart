import 'dart:async';

import 'package:esugid/auth_service.dart';
import 'package:esugid/marketplace_service.dart';
import 'package:esugid/pages/marketplace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _CountingStream extends Stream<List<MarketplaceItem>> {
  final controller = StreamController<List<MarketplaceItem>>.broadcast();
  int listens = 0;

  @override
  StreamSubscription<List<MarketplaceItem>> listen(
    void Function(List<MarketplaceItem>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    listens++;
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUp(() {
    AuthService.currentUser = null;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'market categories and feed share one subscription across rebuilds',
    (tester) async {
      final stream = _CountingStream();
      addTearDown(stream.controller.close);
      Widget page() => MaterialApp(home: MarketplacePage(itemsStream: stream));
      await tester.pumpWidget(page());
      await tester.pump();
      expect(stream.listens, 1);
      stream.controller.add(const []);
      await tester.pump();
      await tester.pumpWidget(page());
      await tester.pump();
      expect(stream.listens, 1);
      expect(tester.takeException(), isNull);

      final replacement = _CountingStream();
      addTearDown(replacement.controller.close);
      await tester.pumpWidget(
        MaterialApp(home: MarketplacePage(itemsStream: replacement)),
      );
      await tester.pump();
      expect(stream.controller.hasListener, isFalse);
      expect(replacement.listens, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(replacement.controller.hasListener, isFalse);
    },
  );

  testWidgets('category navigation retains the records delivered to the feed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final stream = _CountingStream();
    addTearDown(stream.controller.close);
    final item = MarketplaceItem.fromMap({
      'id': 'tool-test',
      'name': 'Community Garden Tool',
      'sellerId': '',
      'sellerName': 'Ana',
      'category': 'Tools & Equipment',
      'imageUrl': '',
      'createdAt': DateTime(2026, 10, 17).toIso8601String(),
    });
    await tester.pumpWidget(
      MaterialApp(home: MarketplacePage(itemsStream: stream)),
    );
    stream.controller.add([item]);
    await tester.pumpAndSettle();
    expect(find.text('Community Garden Tool'), findsOneWidget);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Community Garden Tool'), findsOneWidget);
    expect(stream.listens, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
