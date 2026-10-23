import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/emergency_alert_service.dart';
import 'package:esugid/pages/emergency_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EmergencyAlertService.mockCallHandler = (name, id) async {};
    EmergencyAlertService.mockResidentStatusHandler =
        (id, resId) => Stream.value(null);
  });

  group('EmergencyAlertService empty path safety (Crash prevention)', () {
    test('watchAlert with empty or whitespace string yields null without throwing', () async {
      final stream = EmergencyAlertService.watchAlert('');
      final result = await stream.first;
      expect(result, isNull);

      final streamSpace = EmergencyAlertService.watchAlert('   ');
      final resultSpace = await streamSpace.first;
      expect(resultSpace, isNull);
    });

    test('watchResidentStatus with empty id yields null without throwing', () async {
      final stream = EmergencyAlertService.watchResidentStatus('', 'user123');
      final result = await stream.first;
      expect(result, isNull);
    });

    test('fetchAlert with empty id returns null safely', () async {
      final result = await EmergencyAlertService.fetchAlert('');
      expect(result, isNull);
    });

    test('loadCachedAlert with empty id returns null safely', () async {
      final result = await EmergencyAlertService.loadCachedAlert('');
      expect(result, isNull);
    });

    test('acknowledge with empty id returns synchronized safely', () async {
      final result = await EmergencyAlertService.acknowledge('');
      expect(result, EmergencyAcknowledgementResult.synchronized);
    });
  });

  group('EmergencyDetailsPage UI and Actions', () {
    testWidgets('EmergencyDetailsPage with empty emergencyId renders gracefully without crash',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyDetailsPage(emergencyId: ''),
        ),
      );

      // Verify no unhandled exception occurred and the page rendered
      expect(find.text('Emergency Details'), findsOneWidget);
      expect(find.text('BARILI CIVIC NETWORK • EMERGENCY'), findsOneWidget);
    });

    testWidgets('EmergencyDetailsPage displays civic theme with red highlights & action buttons',
        (tester) async {
      AuthService.currentUser = User(
        uid: 'resident-vito-1',
        email: 'resident@barili.gov.ph',
        role: UserRole.resident,
        name: 'Vito Resident',
        barangay: 'Vito',
      );

      final testAlert = CommunityAlert(
        id: 'emergency-vito-99',
        title: 'Flash Flood Warning',
        message: 'Water levels rising rapidly in Vito riverbanks.',
        severity: 'emergency',
        category: 'Flood',
        alertType: 'Flood',
        instructions: 'Evacuate immediately to higher ground safety centers.',
        sourceName: 'Barangay Vito',
        targetBarangay: 'Vito',
        targetBarangays: const ['Vito'],
        visibility: 'targeted',
        status: 'active',
        createdAt: DateTime(2026, 9, 30, 10, 20),
        publishedAt: DateTime(2026, 9, 30, 10, 20),
        active: true,
      );

      EmergencyAlertService.mockWatchAlertHandler =
          (id) => Stream.value(testAlert);
      await EmergencyAlertService.cacheAlert(testAlert);

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyDetailsPage(emergencyId: 'emergency-vito-99'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check Header & Beacon
      expect(find.text('BARILI CIVIC NETWORK • EMERGENCY'), findsOneWidget);
      expect(find.text('E-SUGID EMERGENCY ALERT'), findsOneWidget);
      expect(find.text('Flash Flood Warning'), findsOneWidget);

      // Check Facts & Red Highlights
      expect(find.text('Severity'), findsOneWidget);
      expect(find.text('EMERGENCY'), findsOneWidget);
      expect(find.text('Barangay Vito'), findsOneWidget);
      expect(find.text('WHAT TO DO'), findsOneWidget);

      // Check Actions
      expect(find.text('I HAVE SEEN THIS ALERT'), findsOneWidget);
      final dontRemindButton = find.text("Don't Remind Me Again");
      expect(dontRemindButton, findsOneWidget);

      // Verify clicking "Don't Remind Me Again" records do-not-remind
      await tester.ensureVisible(dontRemindButton);
      await tester.pumpAndSettle();
      await tester.tap(dontRemindButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        await EmergencyAlertService.isDoNotRemind('emergency-vito-99'),
        isTrue,
      );

      // Cleanly unmount to complete all streams
      await tester.pumpWidget(const SizedBox());
    });

    test('EmergencyAlertService markDoNotRemind persists and checks correctly', () async {
      const testId = 'emergency-dont-remind-123';
      expect(await EmergencyAlertService.isDoNotRemind(testId), isFalse);

      await EmergencyAlertService.markDoNotRemind(testId);
      expect(await EmergencyAlertService.isDoNotRemind(testId), isTrue);

      final ids = await EmergencyAlertService.getDoNotRemindIds();
      expect(ids.contains(testId), isTrue);
    });
  });
}
