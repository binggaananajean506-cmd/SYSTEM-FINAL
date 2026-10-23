import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/app_theme_controller.dart';
import 'package:esugid/features/settings/app_preferences_controller.dart';
import 'package:esugid/features/settings/pages/app_preferences_page.dart';
import 'package:esugid/features/settings/pages/notifications_settings_page.dart';
import 'package:esugid/features/settings/pages/settings_page.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.initialize();
    await AppPreferencesController.initialize();
  });

  group('Settings & Profile Enhanced UI Tests', () {
    testWidgets('SettingsPage renders all 7 setting cards and the Log Out card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Settings'), findsOneWidget);

      // Check all 7 cards
      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('App Preferences'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      // Check Log Out button
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('NotificationsSettingsPage renders all 7 notification items and toggles', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Emergency Alerts'), findsOneWidget);
      expect(find.text('Always enabled'), findsOneWidget);
      expect(find.text('Barangay Announcements'), findsOneWidget);
      expect(find.text('Public Advisories'), findsOneWidget);
      expect(find.text('Events & Activities'), findsOneWidget);
      expect(find.text('Concern Updates'), findsOneWidget);
      expect(find.text('Complaint Updates'), findsOneWidget);
      expect(find.text('Organization Updates'), findsOneWidget);

      // Verify toggling works
      final announcementSwitch = find.byType(Switch).at(1);
      await tester.tap(announcementSwitch);
      await tester.pumpAndSettle();
      expect(AppPreferencesController.barangayAnnouncements.value, isFalse);
    });

    testWidgets('AppPreferencesPage renders Theme and Text Size pills and responds to interaction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppPreferencesPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('App Preferences'), findsOneWidget);
      // Language section is removed as outlined
      expect(find.text('Language'), findsNothing);
      expect(find.text('English'), findsNothing);
      expect(find.text('Cebuano'), findsNothing);

      // All three Flutter ThemeMode options are available.
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);

      expect(find.text('Text Size'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);

      // Tap Dark theme
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(AppThemeController.mode.value, ThemeMode.dark);

      // Tap Large text size
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(AppPreferencesController.textSize.value, 'large');
      expect(AppPreferencesController.textScaleFactor.value, 1.15);
    });
  });
}
