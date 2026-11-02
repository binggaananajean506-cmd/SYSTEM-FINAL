import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/features/app_assistant/app_assistant_dock.dart';
import 'package:esugid/pages/profile_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('profile scrolls with floating assistant in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildESugidClayTheme(brightness),
          home: const Scaffold(
            body: AppAssistantDock(
              bottomInset: 94,
              launcher: Icon(Icons.auto_awesome_rounded),
              child: ProfilePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Log Out'));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.text('Log Out'));
      final assistant = tester.getRect(
        find.byKey(const ValueKey('assistant-drag-target')),
      );
      expect(button.overlaps(assistant), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  for (final configuration in <(double, double)>[
    (240, 1),
    (320, 1.5),
    (390, 2),
  ]) {
    final (width, textScale) = configuration;
    testWidgets(
      'profile omits resident ID and fits ${width.toInt()}px at ${textScale}x text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        AuthService.currentUser = User(
          uid: 'resident-id',
          email: 'resident@example.com',
          role: UserRole.resident,
          name: 'Ana Jean',
          barangay: 'Vito',
          residentId: 'BAR-2026-U4IZ',
        );
        addTearDown(() => AuthService.currentUser = null);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: const ProfilePage(),
            ),
          ),
        );

        expect(find.text('Messages'), findsNothing);
        expect(find.text('My Activity'), findsNothing);
        expect(find.text('Profile & ID'), findsNothing);
        expect(find.text('Concerns'), findsNothing);
        expect(find.text('Complaints'), findsNothing);
        expect(find.text('Help Requests'), findsNothing);
        expect(find.text('Saved Places'), findsNothing);
        expect(find.text('Personal Information'), findsOneWidget);
        expect(find.text('Account & Security'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Privacy'), findsOneWidget);
        expect(find.text('App Preferences'), findsOneWidget);
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resident profile opens personal fields edit sheet on tapping Personal Information', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AuthService.currentUser = User(
      uid: 'resident-id',
      email: 'cris@example.com',
      role: UserRole.resident,
      name: 'Cris',
      barangay: 'Cabcaban',
      barangayId: 'cabcaban',
      contactNumber: '+639123456789',
    );
    addTearDown(() => AuthService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.tap(find.text('Personal Information').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Address / Purok'), findsOneWidget);
    expect(find.text('Barangay'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Birth date'), findsOneWidget);
    expect(find.text('Barangay and email cannot be changed here.'),
        findsOneWidget);
    expect(find.textContaining('REGISTERED'), findsNothing);
    expect(find.textContaining('Personal details registered'), findsNothing);
    expect(find.textContaining('Age:'), findsNothing);
    expect(find.text('Role'), findsNothing);
    expect(find.text('Permissions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verification status is shown on the resident profile badge', (
    tester,
  ) async {
    AuthService.currentUser = User(
      uid: 'verified-resident',
      email: 'verified@example.com',
      role: UserRole.resident,
      name: 'Verified Resident',
      barangay: 'Vito',
      verificationStatus: VerificationStatus.verified,
    );
    addTearDown(() => AuthService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

    expect(find.text('Resident Verification'), findsNothing);
    expect(find.textContaining('Verified Resident'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Settings shortcut navigates to Settings page', (
    tester,
  ) async {
    AuthService.currentUser = User(
      uid: 'settings-resident',
      email: 'resident@barili.gov.ph',
      role: UserRole.resident,
      name: 'Maria Clara',
      barangay: 'Cabcaban',
    );
    addTearDown(() => AuthService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    final accountFinder = find.text('Account & Security');
    await tester.ensureVisible(accountFinder);
    await tester.tap(accountFinder);
    await tester.pumpAndSettle();

    expect(find.text('Account Protected'), findsOneWidget);
    expect(find.text('Change Password'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping logout button opens enhanced card confirmation modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AuthService.currentUser = User(
      uid: 'logout-resident',
      email: 'logout@barili.gov.ph',
      role: UserRole.resident,
      name: 'Test Resident',
      barangay: 'Poblacion',
    );
    addTearDown(() => AuthService.currentUser = null);

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    final logoutFinder = find.widgetWithText(InkWell, 'Log Out');
    await tester.ensureVisible(logoutFinder);
    await tester.pumpAndSettle();
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    expect(find.text('Log out of E-SUGID?'), findsOneWidget);
    expect(find.text('Stay Signed In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

