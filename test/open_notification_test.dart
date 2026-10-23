import 'dart:async';

import 'package:esugid/features/notifications/application/open_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a pending read receipt does not delay opening the destination',
    () async {
      final receipt = Completer<void>();
      var opened = false;
      final opening = openNotification(
        isRead: false,
        markRead: () => receipt.future,
        openDestination: () async {
          opened = true;
        },
        onReceiptError: (_) => fail('Receipt should succeed'),
      );
      addTearDown(() {
        if (!receipt.isCompleted) receipt.complete();
      });
      await Future<void>.delayed(Duration.zero);
      expect(opened, isTrue);
      receipt.complete();
      await opening;
    },
  );

  test(
    'receipt failures are reported while the destination still opens',
    () async {
      final errors = <Object>[];
      var opened = false;
      await openNotification(
        isRead: false,
        markRead: () => Future<void>.error(StateError('offline')),
        openDestination: () async {
          opened = true;
        },
        onReceiptError: errors.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(opened, isTrue);
      expect(errors.single, isA<StateError>());
    },
  );

  testWidgets('stalled read receipts report a timeout after eight seconds', (
    tester,
  ) async {
    final receipt = Completer<void>();
    final errors = <Object>[];
    var opened = false;
    unawaited(
      openNotification(
        isRead: false,
        markRead: () => receipt.future,
        openDestination: () async {
          opened = true;
        },
        onReceiptError: errors.add,
      ),
    );
    addTearDown(() {
      if (!receipt.isCompleted) receipt.complete();
    });
    await tester.pump(const Duration(seconds: 8));
    expect(opened, isTrue);
    expect(errors.single, isA<TimeoutException>());
    receipt.complete();
    await tester.pump();
    expect(errors, hasLength(1));
  });

  test('already read notifications open without a receipt write', () async {
    var opened = false;
    await openNotification(
      isRead: true,
      markRead: () async {
        fail('No write needed');
      },
      openDestination: () async {
        opened = true;
      },
      onReceiptError: (_) => fail('No receipt error'),
    );
    expect(opened, isTrue);
  });
}
