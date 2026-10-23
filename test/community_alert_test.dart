import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  User resident(String barangay) => User(
    uid: 'resident-$barangay',
    name: 'Resident',
    email: 'resident@example.com',
    role: UserRole.resident,
    barangay: barangay,
  );

  CommunityAlert alert({
    String visibility = 'public',
    String targetBarangay = 'All Barangays',
    List<String> targetBarangays = const [],
    DateTime? expiresAt,
    bool active = true,
    String status = 'active',
  }) => CommunityAlert(
    id: 'ALT-1',
    title: 'Flood warning',
    message: 'River levels are rising.',
    severity: 'critical',
    category: 'Emergency',
    alertType: 'Flood',
    instructions: 'Move to higher ground.',
    sourceName: 'Municipality of Barili',
    targetBarangay: targetBarangay,
    targetBarangays: targetBarangays,
    visibility: visibility,
    status: status,
    createdAt: DateTime(2026, 8, 22),
    expiresAt: expiresAt,
    active: active,
  );

  test('public emergency alerts are visible throughout Barili', () {
    expect(alert().isVisibleTo(resident('Vito')), isTrue);
  });

  test('targeted emergency alerts only reach selected barangays', () {
    final targeted = alert(
      visibility: 'targeted',
      targetBarangay: 'Vito',
      targetBarangays: const ['Vito', 'Mantalongon'],
    );

    expect(targeted.isVisibleTo(resident('Barangay Vito')), isTrue);
    expect(targeted.isVisibleTo(resident('Mantalongon')), isTrue);
    expect(targeted.isVisibleTo(resident('Poblacion')), isFalse);
  });

  test('expired or resolved alerts are not current', () {
    expect(
      alert(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ).isCurrentlyActive,
      isFalse,
    );
    expect(alert(status: 'resolved').isCurrentlyActive, isFalse);
  });
}
