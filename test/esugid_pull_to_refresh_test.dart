import 'dart:async';

import 'package:esugid/core/widgets/esugid_pull_to_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testPage(ESugidRefreshCallback onRefresh) {
  return MaterialApp(
    home: Scaffold(
      body: ESugidPullToRefresh(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 900, child: Text('Cached data'))],
        ),
      ),
    ),
  );
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 320));
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('keeps content visible and prevents concurrent refreshes', (
    tester,
  ) async {
    final completion = Completer<ESugidRefreshOutcome>();
    var refreshCount = 0;
    await tester.pumpWidget(
      _testPage(() {
        refreshCount++;
        return completion.future;
      }),
    );

    await _pullToRefresh(tester);
    expect(refreshCount, 1);
    expect(find.text('Cached data'), findsOneWidget);
    expect(find.text('Refreshing...'), findsOneWidget);

    await _pullToRefresh(tester);
    expect(refreshCount, 1);

    completion.complete(ESugidRefreshOutcome.updated);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('✓ Latest updates loaded'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('✓ Latest updates loaded'), findsNothing);
  });

  testWidgets('shows a compact retry instruction after refresh failure', (
    tester,
  ) async {
    await tester.pumpWidget(_testPage(() async => throw StateError('offline')));

    await _pullToRefresh(tester);
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Cached data'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. Pull down to try again."),
      findsOneWidget,
    );
  });
}
