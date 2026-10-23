import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';

void main() {
  test(
    'profile photo uses stored value before the authentication fallback',
    () {
      final withFallback = User.fromMap({
        'uid': 'resident-photo',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
      }, fallbackProfilePhotoUrl: 'https://example.com/auth-photo.jpg');
      final withStoredPhoto = User.fromMap({
        'uid': 'resident-photo',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'profilePhotoUrl': 'https://example.com/profile-photo.jpg',
      }, fallbackProfilePhotoUrl: 'https://example.com/auth-photo.jpg');

      expect(
        withFallback.profilePhotoUrl,
        'https://example.com/auth-photo.jpg',
      );
      expect(
        withStoredPhoto.profilePhotoUrl,
        'https://example.com/profile-photo.jpg',
      );
    },
  );

  group('user status compatibility', () {
    test('registration OTP gates only profiles that explicitly require it', () {
      final legacyResident = User.fromMap({
        'uid': 'legacy-resident',
        'email': 'legacy@example.com',
        'name': 'Legacy Resident',
        'role': 'resident',
      });
      final pendingOtpResident = User.fromMap({
        'uid': 'new-resident',
        'email': 'new@example.com',
        'name': 'New Resident',
        'role': 'resident',
        'emailOtpRequired': true,
        'emailOtpVerified': false,
      });
      final verifiedOtpResident = User.fromMap({
        ...pendingOtpResident.toMap(),
        'emailOtpVerified': true,
        'emailVerifiedAt': '2026-09-12T00:00:00Z',
      });

      expect(legacyResident.hasCompletedRegistrationEmailVerification, isTrue);
      expect(
        pendingOtpResident.hasCompletedRegistrationEmailVerification,
        isFalse,
      );
      expect(
        verifiedOtpResident.hasCompletedRegistrationEmailVerification,
        isTrue,
      );
      expect(verifiedOtpResident.emailVerifiedAt, isNotNull);
    });

    test('legacy approved resident is active but not identity verified', () {
      final user = User.fromMap({
        'uid': 'resident-1',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'status': 'approved',
      });

      expect(user.accountStatus, AccountStatus.active);
      expect(user.verificationStatus, VerificationStatus.notVerified);
      expect(user.isActive, isTrue);
      expect(user.isVerified, isFalse);
    });

    test('legacy verification evidence remains verified', () {
      final user = User.fromMap({
        'uid': 'resident-2',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'status': 'approved',
        'verificationApprovedAt': '2026-08-15T00:00:00Z',
      });

      expect(user.verificationStatus, VerificationStatus.verified);
      expect(user.isVerified, isTrue);
    });

    test('canonical fields take priority over legacy status', () {
      final user = User.fromMap({
        'uid': 'resident-3',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'status': 'approved',
        'accountStatus': 'suspended',
        'verificationStatus': 'verified',
      });

      expect(user.accountStatus, AccountStatus.suspended);
      expect(user.verificationStatus, VerificationStatus.verified);
      expect(user.isActive, isFalse);
    });

    test('unverified residents are read-only until barangay approval', () {
      final unverified = User.fromMap({
        'uid': 'resident-4',
        'email': 'resident@example.com',
        'name': 'Resident',
        'role': 'resident',
        'accountStatus': 'active',
        'verificationStatus': 'needs_correction',
        'reviewNote': 'Upload a clearer proof of residency.',
      });
      final verified = User.fromMap({
        ...unverified.toMap(),
        'verificationStatus': 'verified',
      });

      expect(unverified.canUseInteractiveFeatures, isFalse);
      expect(
        unverified.verificationStatus,
        VerificationStatus.additionalDocumentRequired,
      );
      expect(
        unverified.verificationReviewNote,
        'Upload a clearer proof of residency.',
      );
      expect(verified.canUseInteractiveFeatures, isTrue);
    });
  });

  group('role capabilities', () {
    User staff(String role, {String accountStatus = 'active'}) => User.fromMap({
      'uid': role,
      'email': '$role@example.com',
      'name': role,
      'role': role,
      'status': 'approved',
      'accountStatus': accountStatus,
      'verificationStatus': 'not_submitted',
    });

    test('active staff publishers retain their role-specific capability', () {
      expect(staff('barangay_secretary').canPublishAnnouncements, isTrue);
      expect(staff('organization').canPublishAnnouncements, isTrue);
      expect(staff('lgu').canPublishAnnouncements, isTrue);
      expect(staff('super_admin').canPublishAnnouncements, isTrue);
    });

    test('residents and inactive staff cannot publish', () {
      expect(staff('resident').canPublishAnnouncements, isFalse);
      expect(
        staff(
          'organization',
          accountStatus: 'pending_approval',
        ).canPublishAnnouncements,
        isFalse,
      );
    });
  });

  test('session destination follows account state and role', () {
    User user(String role, String status) => User.fromMap({
      'uid': role,
      'email': '$role@example.com',
      'name': role,
      'role': role,
      'accountStatus': status,
    });

    expect(
      sessionDestinationFor(user('resident', 'active')),
      SessionDestination.home,
    );
    expect(
      sessionDestinationFor(user('barangay_secretary', 'active')),
      SessionDestination.home,
    );
    expect(
      sessionDestinationFor(user('organization', 'active')),
      SessionDestination.home,
    );
    expect(
      sessionDestinationFor(user('lgu', 'active')),
      SessionDestination.adminWeb,
    );
    expect(
      sessionDestinationFor(user('super_admin', 'active')),
      SessionDestination.adminWeb,
    );
    expect(
      sessionDestinationFor(user('resident', 'suspended')),
      SessionDestination.unavailable,
    );
    expect(
      sessionDestinationFor(user('barangay_councilor', 'pending_approval')),
      SessionDestination.unavailable,
    );
  });

  test('restricted accounts cannot access the app and are routed to unavailable', () {
    final resident = User.fromMap({
      'uid': 'restricted-resident',
      'email': 'resident@example.com',
      'name': 'Resident',
      'role': 'resident',
      'status': 'active',
      'accountStatus': 'active',
      'verificationStatus': 'verified',
      'restrictionStatus': 'active',
    });
    expect(sessionDestinationFor(resident), SessionDestination.unavailable);
    expect(resident.isRestricted, isTrue);
    expect(resident.canUseInteractiveFeatures, isFalse);
    expect(resident.canUseVerifiedResidentFeatures, isFalse);

    // Restriction explicitly removed
    final restored = resident.copyWith(restrictionStatus: 'removed');
    expect(restored.isRestricted, isFalse);
    expect(sessionDestinationFor(restored), SessionDestination.home);

    // Future restriction end date -> still restricted
    final futureRestriction = resident.copyWith(
      restrictionEndDate: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(futureRestriction.isRestricted, isTrue);
    expect(sessionDestinationFor(futureRestriction), SessionDestination.unavailable);

    // Past restriction end date (expired) -> restriction ended, can log in normally
    final expiredRestriction = resident.copyWith(
      restrictionEndDate: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    expect(expiredRestriction.isRestricted, isFalse);
    expect(sessionDestinationFor(expiredRestriction), SessionDestination.home);
  });
}
