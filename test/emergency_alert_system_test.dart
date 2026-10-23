import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/emergency_alert_service.dart';
import 'package:esugid/emergency_service.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CommunityAlert alert({
    String id = 'emergency-1',
    String severity = 'Emergency',
    String status = 'active',
    bool active = true,
    String barangay = 'Vito',
    DateTime? publishedAt,
    DateTime? expiresAt,
  }) {
    return CommunityAlert(
      id: id,
      title: 'Flash flood warning',
      message: 'Move away from the river.',
      severity: severity,
      category: 'Emergency',
      alertType: 'Flood',
      instructions: 'Proceed to higher ground.',
      sourceName: 'E-SUGID',
      targetBarangay: barangay,
      targetBarangays: [barangay],
      visibility: 'targeted',
      status: status,
      createdAt: DateTime(2026, 8, 31),
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      targetedCount: 20,
      acknowledgedCount: 7,
      active: active,
    );
  }

  test('only Emergency and legacy Critical use emergency behavior', () {
    expect(alert().isEmergency, isTrue);
    expect(alert(severity: 'Critical').isEmergency, isTrue);
    expect(alert(severity: 'Warning').isEmergency, isFalse);
    expect(alert(severity: 'Advisory').isEmergency, isFalse);
  });

  test('resident emergency stream supports multiple listeners', () async {
    EmergencyService.clearCaches();
    final resident = User(
      uid: 'resident-stream-test',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
    );

    final reports = EmergencyService.reportsForResponder(resident);

    await expectLater(reports, emits(const <EmergencyReport>[]));
    await expectLater(reports, emitsDone);
  });

  test('ended, cancelled, and expired alerts are no longer active', () {
    expect(alert(status: 'ended').isCurrentlyActive, isFalse);
    expect(alert(status: 'cancelled').isCurrentlyActive, isFalse);
    expect(alert(status: 'expired').isCurrentlyActive, isFalse);
  });

  test('aggregate awaiting count cannot become negative', () {
    expect(alert().awaitingAcknowledgementCount, 13);
  });

  test('opening and silencing do not acknowledge an emergency', () {
    const opened = ResidentEmergencyStatus(
      emergencyId: 'emergency-1',
      residentId: 'resident-1',
      status: 'opened',
    );
    const silenced = ResidentEmergencyStatus(
      emergencyId: 'emergency-1',
      residentId: 'resident-1',
      status: 'silenced',
    );
    expect(opened.isAcknowledged, isFalse);
    expect(silenced.isAcknowledged, isFalse);
  });

  test('emergency notification presents acknowledgement state', () {
    final notification = ResidentNotification(
      id: 'notification-1',
      title: 'Flash flood warning',
      message: 'Move away from the river.',
      type: 'emergency_alert',
      referenceId: 'emergency-1',
      read: true,
      createdAt: DateTime(2026, 8, 31),
      severity: 'emergency',
      emergencyStatus: 'active',
      acknowledged: true,
    );
    expect(notification.isEmergency, isTrue);
    expect(notification.displayMessage, contains('Acknowledged'));
  });

  test(
    'startup recovery keeps only relevant active emergencies newest first',
    () {
      final resident = User(
        uid: 'resident-1',
        email: 'resident@example.com',
        role: UserRole.resident,
        name: 'Resident',
        barangay: 'Vito',
      );
      final prioritized = EmergencyAlertService.prioritizeRecoverableAlerts([
        alert(id: 'older', publishedAt: DateTime(2026, 8, 31, 8)),
        alert(id: 'newer', publishedAt: DateTime(2026, 8, 31, 10)),
        alert(id: 'wrong-area', barangay: 'Cagay'),
        alert(id: 'ended', status: 'ended'),
        alert(id: 'warning', severity: 'Warning'),
        alert(id: 'expired', expiresAt: DateTime(2020)),
      ], resident);

      expect(prioritized.map((item) => item.id), ['newer', 'older']);
    },
  );

  test('markDoNotRemind records suppression state locally', () async {
    SharedPreferences.setMockInitialValues({});
    EmergencyAlertService.mockCallHandler = (name, id) async {};

    const emergencyId = 'emergency-flood-test-456';
    expect(await EmergencyAlertService.isDoNotRemind(emergencyId), isFalse);

    await EmergencyAlertService.markDoNotRemind(emergencyId);
    expect(await EmergencyAlertService.isDoNotRemind(emergencyId), isTrue);

    final set = await EmergencyAlertService.getDoNotRemindIds();
    expect(set.contains(emergencyId), isTrue);
  });
}
