import 'dart:async';

import 'package:esugid/features/notifications/presentation/notification_inbox.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refreshes notifications when the account stream factory changes', (tester) async {
    var firstCalls = 0;
    var secondCalls = 0;
    Stream<List<ResidentNotification>> first() {
      firstCalls++;
      return Stream.value(const []);
    }
    Stream<List<ResidentNotification>> second() {
      secondCalls++;
      return Stream.value(const []);
    }
    Future<void> show(NotificationStreamFactory factory) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationInbox(
        watchNotifications: factory, onOpen: (_) async {},
      ))));
      await tester.pump();
    }
    await show(first);
    await show(first);
    expect(firstCalls, 1);
    await show(second);
    expect(secondCalls, 1);
  });

  Widget inboxWith(List<ResidentNotification> notifications) {
    return MaterialApp(
      home: Scaffold(
        body: NotificationInbox(
          watchNotifications: () => Stream.value(notifications),
          onOpen: (_) async {},
        ),
      ),
    );
  }

  ResidentNotification notification({required bool read}) {
    return ResidentNotification(
      id: read ? 'read-notification' : 'unread-notification',
      title: read ? 'Service request updated' : 'Account verified',
      message: read
          ? 'Your barangay clearance is processing.'
          : 'Your residency has been verified.',
      type: read ? 'document_request_update' : 'verification_update',
      referenceId: 'reference-1',
      read: read,
      createdAt: DateTime.now(),
    );
  }

  testWidgets('failed notification navigation shows safe feedback', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationInbox(
      watchNotifications: () => Stream.value([notification(read: false)]),
      onOpen: (_) async => throw StateError('private backend details'),
    ))));
    await tester.pump();
    await tester.tap(find.text('Account verified'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not open this notification. Please try again.'), findsOneWidget);
    expect(find.textContaining('private backend'), findsNothing);
  });

  testWidgets('late notification failure after unmount is handled safely', (tester) async {
    final opened = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationInbox(
      watchNotifications: () => Stream.value([notification(read: false)]),
      onOpen: (_) => opened.future,
    ))));
    await tester.pump();
    await tester.tap(find.text('Account verified'));
    await tester.pumpWidget(const SizedBox());
    opened.completeError(StateError('private'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a useful empty state instead of a blank page', (
    tester,
  ) async {
    await tester.pumpWidget(inboxWith(const []));
    await tester.pump();

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.textContaining('Updates about your account'), findsOneWidget);
  });

  testWidgets('shows a retry state when Firestore cannot load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationInbox(
            watchNotifications: () => Stream.error(StateError('offline')),
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("Couldn't load notifications."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows persistent notifications and filters unread items', (
    tester,
  ) async {
    await tester.pumpWidget(
      inboxWith([notification(read: false), notification(read: true)]),
    );
    await tester.pump();

    expect(find.text('Account verified'), findsOneWidget);
    expect(find.text('Service request updated'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('Account verified'), findsOneWidget);
    expect(find.text('Service request updated'), findsNothing);
  });

  testWidgets('inbox controls fit a compact phone', (tester) async {
    tester.view.physicalSize = const Size(240, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      inboxWith([notification(read: false), notification(read: true)]),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mark all as read'), findsOneWidget);
  });

  test('formats recent notification times for people', () {
    final now = DateTime(2026, 9, 4, 10);

    expect(
      notificationTimeLabel(DateTime(2026, 9, 4, 9, 58), now: now),
      '2 min ago',
    );
    expect(
      notificationTimeLabel(DateTime(2026, 9, 4, 8), now: now),
      '2 hours ago',
    );
  });

  testWidgets('renders collapsible header with clean title and no old subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationInbox(
            includeHeader: true,
            showBackButton: true,
            watchNotifications: () => Stream.value([notification(read: false)]),
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header title is present
    expect(find.text('Notifications'), findsOneWidget);
    // Verify old removed subtitle is NOT present
    expect(find.text('Updates that need your attention.'), findsNothing);
  });

  testWidgets('tapping notification card invokes onOpen callback', (
    tester,
  ) async {
    ResidentNotification? openedNotification;
    final item = notification(read: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationInbox(
            watchNotifications: () => Stream.value([item]),
            onOpen: (n) async {
              openedNotification = n;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account verified'));
    await tester.pump();

    expect(openedNotification, isNotNull);
    expect(openedNotification!.id, 'unread-notification');
  });
}

