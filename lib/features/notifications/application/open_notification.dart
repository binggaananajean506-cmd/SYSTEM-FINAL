import 'dart:async';

/// Opens immediately while observing the independent read receipt write.
Future<void> openNotification({
  required bool isRead,
  required Future<void> Function() markRead,
  required Future<void> Function() openDestination,
  required void Function(Object error) onReceiptError,
}) async {
  if (!isRead) {
    unawaited(
      Future<void>.sync(
        markRead,
      ).timeout(const Duration(seconds: 8)).catchError((Object error) {
        onReceiptError(error);
      }),
    );
  }
  await openDestination();
}
