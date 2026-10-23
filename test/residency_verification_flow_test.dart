import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/barili_barangays.dart';
import 'package:esugid/features/verification/domain/residency_verification.dart';

void main() {
  test('all canonical resident verification states map from Firestore', () {
    VerificationStatus status(String value) => User.fromMap({
      'uid': value,
      'email': '$value@example.com',
      'name': 'Resident',
      'role': 'resident',
      'accountStatus': 'active',
      'verificationStatus': value,
    }).verificationStatus;

    expect(status('not_submitted'), VerificationStatus.notVerified);
    expect(status('submitted'), VerificationStatus.submitted);
    expect(status('under_review'), VerificationStatus.underReview);
    expect(status('verified'), VerificationStatus.verified);
    expect(status('rejected'), VerificationStatus.rejected);
    expect(
      status('additional_document_required'),
      VerificationStatus.additionalDocumentRequired,
    );
    expect(
      status('needs_attention'),
      VerificationStatus.additionalDocumentRequired,
    );
  });

  test('only the needs-attention state allows a corrected document', () {
    expect(
      verificationRequiresAdditionalDocument(
        VerificationStatus.additionalDocumentRequired,
      ),
      isTrue,
    );
    expect(
      verificationRequiresAdditionalDocument(VerificationStatus.notVerified),
      isFalse,
    );
    expect(
      verificationRequiresAdditionalDocument(VerificationStatus.submitted),
      isFalse,
    );
  });

  test('verification submission timestamps are available to pending UI', () {
    final submittedAt = DateTime.utc(2026, 9, 2, 8, 30);
    final resident = User.fromMap({
      'uid': 'resident-pending',
      'email': 'pending@example.com',
      'name': 'Pending Resident',
      'role': 'resident',
      'accountStatus': 'active',
      'verificationStatus': 'submitted',
      'submittedAt': submittedAt.toIso8601String(),
    });

    expect(resident.verificationSubmittedAt, submittedAt);
  });

  test('the first verification step offers approved one-document options', () {
    expect(residencyVerificationDocumentTypes, contains('National ID'));
    expect(residencyVerificationDocumentTypes, contains("Driver's License"));
    expect(residencyVerificationDocumentTypes, contains('Postal ID'));
    expect(
      residencyVerificationDocumentTypes,
      contains('Barangay Certificate'),
    );
    expect(
      residencyVerificationDocumentTypes,
      contains('Other Proof'),
    );
    expect(residencyVerificationDocumentTypes, isNot(contains('Student ID')));
    expect(residencyVerificationDocumentTypes, isNot(contains('Passport')));
    expect(residencyVerificationDocumentTypes, isNot(contains('PRC ID')));
  });

  test('birth date input validates real dates and calculates age', () {
    final date = parseResidentBirthDate('09/15/2005');
    expect(date, DateTime(2005, 9, 15));
    expect(storedBirthDateValue(date!), '2005-09-15');
    expect(registrationBirthDateValue(date), '09/15/2005');
    expect(
      parseResidentBirthDate('2005-09-15T00:00:00.000'),
      DateTime(2005, 9, 15),
    );
    expect(residentAge(date, onDate: DateTime(2026, 9, 10)), 20);
    expect(validateResidentBirthDate('02/30/2005'), 'Enter a real date');
    expect(
      validateResidentBirthDate('09/11/2026', now: DateTime(2026, 9, 10)),
      'Birth date cannot be in the future',
    );
  });

  test(
    'barangay routing uses a stable ID while preserving the display name',
    () {
      expect(bariliBarangayId('Barangay Cabcaban'), 'barili_cabcaban');
      expect(bariliBarangayId('Santa Ana'), 'barili_santa_ana');
      expect(bariliBarangayNameForId('barili_cabcaban'), 'Cabcaban');

      final resident = User.fromMap({
        'uid': 'resident-cabcaban',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'accountStatus': 'active',
        'verificationStatus': 'submitted',
        'barangay': 'Cabcaban',
        'barangayId': 'barili_cabcaban',
      });
      expect(resident.barangay, 'Cabcaban');
      expect(resident.barangayId, 'barili_cabcaban');
    },
  );

  test('delegated resident verification permission is parsed explicitly', () {
    final official = User.fromMap({
      'uid': 'secretary-cabcaban',
      'email': 'secretary@example.com',
      'name': 'Secretary',
      'role': 'barangay_secretary',
      'accountStatus': 'active',
      'barangay': 'Cabcaban',
      'barangayId': 'barili_cabcaban',
      'canVerifyResidents': true,
    });
    expect(official.canVerifyResidents, isTrue);
  });
}
