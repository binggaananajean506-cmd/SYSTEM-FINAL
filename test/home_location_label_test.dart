import 'package:esugid/auth_service.dart';
import 'package:esugid/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  User resident({
    String? barangay,
    String? barangayId,
    String? verifiedBarangayId,
  }) {
    return User(
      uid: 'resident-1',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
      barangay: barangay,
      barangayId: barangayId,
      verifiedBarangayId: verifiedBarangayId,
    );
  }

  test('shows the resident registered barangay in the Home header', () {
    expect(
      homeLocationLabelForUser(resident(barangay: 'Vito')),
      'Vito, Barili',
    );
  });

  test(
    'resolves a stored barangay ID when the display name is unavailable',
    () {
      expect(
        homeLocationLabelForUser(resident(barangayId: 'barili_cabcaban')),
        'Cabcaban, Barili',
      );
    },
  );

  test('prefers the barangay confirmed during resident verification', () {
    expect(
      homeLocationLabelForUser(
        resident(
          barangay: 'Vito',
          barangayId: 'barili_vito',
          verifiedBarangayId: 'barili_cabcaban',
        ),
      ),
      'Cabcaban, Barili',
    );
  });
}
