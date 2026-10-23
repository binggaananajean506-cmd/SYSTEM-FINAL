import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/permission_setup_screen.dart';

void main() {
  testWidgets('permission setup guides notification access before continuing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requested = false;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PermissionSetupScreen(
          permissionRequester: () async => requested = true,
          accessChecker: () async => RequiredNotificationAccess(
            notifications: requested,
            emergencyAlerts: false,
            notificationState: requested
                ? NotificationPermissionState.enabled
                : NotificationPermissionState.notDetermined,
          ),
          notificationSettingsOpener: () async {},
          emergencySettingsOpener: () async {},
          popupSettingsOpener: () async {},
          onComplete: () async => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Required notifications'), findsOneWidget);
    expect(find.text('Emergency alerts'), findsOneWidget);
    expect(find.text('Emergency popups'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Needs attention'), findsNWidgets(2));
    await tester.ensureVisible(
      find.byKey(const ValueKey('allow-permissions-button')),
    );
    await tester.tap(find.byKey(const ValueKey('allow-permissions-button')));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(completed, isFalse);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('allow-permissions-button')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('denied notifications open settings without requesting again', (
    tester,
  ) async {
    var requested = false;
    var settingsOpened = 0;
    var continuedWithLimitedAlerts = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PermissionSetupScreen(
          permissionRequester: () async => requested = true,
          accessChecker: () async => const RequiredNotificationAccess(
            notifications: false,
            notificationState: NotificationPermissionState.denied,
          ),
          notificationSettingsOpener: () async => settingsOpened++,
          emergencySettingsOpener: () async {},
          onContinueWithoutAccess: () async {
            continuedWithLimitedAlerts = true;
          },
          onComplete: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notification-permission-row')));
    await tester.pumpAndSettle();

    expect(requested, isFalse);
    expect(settingsOpened, 1);
    expect(
      find.text(
        'Emergency notifications are disabled. You may miss urgent barangay alerts.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-settings-button')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('continue-with-limited-alerts-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('continue-with-limited-alerts-button')),
    );
    await tester.pump();
    expect(continuedWithLimitedAlerts, isTrue);
  });

  testWidgets(
    'optional location and full-screen access do not block continue',
    (tester) async {
      var completed = false;
      var emergencySettingsOpened = false;
      var popupSettingsOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PermissionSetupScreen(
            accessChecker: () async => const RequiredNotificationAccess(
              notifications: true,
              emergencyAlerts: false,
              location: false,
              notificationState: NotificationPermissionState.enabled,
            ),
            emergencySettingsOpener: () async => emergencySettingsOpened = true,
            popupSettingsOpener: () async => popupSettingsOpened = true,
            onComplete: () async => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('emergency-permission-row')));
      await tester.pump();
      expect(emergencySettingsOpened, isTrue);

      await tester.ensureVisible(
        find.byKey(const ValueKey('emergency-popup-permission-row')),
      );
      await tester.tap(find.byKey(const ValueKey('emergency-popup-permission-row')));
      await tester.pump();
      expect(popupSettingsOpened, isTrue);

      await tester.ensureVisible(
        find.byKey(const ValueKey('allow-permissions-button')),
      );
      await tester.tap(find.byKey(const ValueKey('allow-permissions-button')));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
    },
  );

  testWidgets('permission setup cannot be skipped while access is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PermissionSetupScreen(
          accessChecker: () async =>
              const RequiredNotificationAccess(notifications: false),
          notificationSettingsOpener: () async {},
          emergencySettingsOpener: () async {},
          onComplete: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('skip-permissions-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('allow-permissions-button')),
      findsOneWidget,
    );
  });
}
