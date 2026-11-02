import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'barili_barangays.dart';
import 'features/verification/domain/residency_verification.dart';
import 'firestore_converters.dart';
import 'signup_draft.dart';

const minimumResidentAge = 15;

enum UserRole { resident, lgu, partner, barangay }

enum AccountStatus { active, pendingApproval, suspended, disabled }

enum VerificationStatus {
  notVerified,
  submitted,
  underReview,
  verified,
  rejected,
  additionalDocumentRequired,
}

enum SessionDestination { unavailable, adminWeb, home }

extension AccountStatusWireValue on AccountStatus {
  String get wireValue => switch (this) {
    AccountStatus.active => 'active',
    AccountStatus.pendingApproval => 'pending_approval',
    AccountStatus.suspended => 'suspended',
    AccountStatus.disabled => 'disabled',
  };

  String get legacyValue => switch (this) {
    AccountStatus.active => 'approved',
    AccountStatus.pendingApproval => 'pending_review',
    AccountStatus.suspended => 'suspended',
    AccountStatus.disabled => 'disabled',
  };
}

extension VerificationStatusWireValue on VerificationStatus {
  String get wireValue => switch (this) {
    VerificationStatus.notVerified => 'not_submitted',
    VerificationStatus.submitted => 'submitted',
    VerificationStatus.underReview => 'under_review',
    VerificationStatus.verified => 'verified',
    VerificationStatus.rejected => 'rejected',
    VerificationStatus.additionalDocumentRequired =>
      'additional_document_required',
  };
}

AccountStatus _accountStatusFromMap(Map<String, dynamic> map, UserRole role) {
  final explicit = map['accountStatus']?.toString().trim().toLowerCase();
  if (explicit != null && explicit.isNotEmpty) {
    return switch (explicit) {
      'active' || 'approved' => AccountStatus.active,
      'pending' ||
      'pending_review' ||
      'pending_approval' => AccountStatus.pendingApproval,
      'suspended' => AccountStatus.suspended,
      'disabled' || 'rejected' => AccountStatus.disabled,
      _ => AccountStatus.pendingApproval,
    };
  }

  final legacy = map['status']?.toString().trim().toLowerCase() ?? '';
  if (role == UserRole.resident) {
    return switch (legacy) {
      'suspended' => AccountStatus.suspended,
      'disabled' => AccountStatus.disabled,
      _ => AccountStatus.active,
    };
  }
  return switch (legacy) {
    'approved' || 'active' => AccountStatus.active,
    'suspended' => AccountStatus.suspended,
    'disabled' || 'rejected' => AccountStatus.disabled,
    _ => AccountStatus.pendingApproval,
  };
}

VerificationStatus _verificationStatusFromMap(
  Map<String, dynamic> map,
  UserRole role,
) {
  final explicit = map['verificationStatus']?.toString().trim().toLowerCase();
  if (explicit != null && explicit.isNotEmpty) {
    return switch (explicit) {
      'verified' || 'approved' => VerificationStatus.verified,
      'submitted' => VerificationStatus.submitted,
      'pending' ||
      'pending_review' ||
      'under_review' => VerificationStatus.underReview,
      'additional_document_required' ||
      'needs_attention' ||
      'needsattention' ||
      'needs_correction' ||
      'correction_required' => VerificationStatus.additionalDocumentRequired,
      'rejected' => VerificationStatus.rejected,
      _ => VerificationStatus.notVerified,
    };
  }
  if (role != UserRole.resident) return VerificationStatus.notVerified;
  if (map['identityVerified'] == true ||
      map['verifiedAt'] != null ||
      map['verificationApprovedAt'] != null) {
    return VerificationStatus.verified;
  }
  final legacy = map['status']?.toString().trim().toLowerCase() ?? '';
  return switch (legacy) {
    'submitted' => VerificationStatus.submitted,
    'pending' ||
    'pending_review' ||
    'under_review' => VerificationStatus.underReview,
    'additional_document_required' ||
    'needs_attention' ||
    'needsattention' ||
    'needs_correction' ||
    'correction_required' => VerificationStatus.additionalDocumentRequired,
    'rejected' => VerificationStatus.rejected,
    _ => VerificationStatus.notVerified,
  };
}

String? _extractBirthDate(Map<String, dynamic> map) {
  dynamic raw =
      map['birthDate'] ??
      map['birthdate'] ??
      map['birth_date'] ??
      map['birthday'] ??
      map['dateOfBirth'] ??
      map['date_of_birth'];
  if (raw == null && map['verificationData'] is Map) {
    final vData = map['verificationData'] as Map;
    raw = vData['birthDate'] ?? vData['birthdate'] ?? vData['birth_date'];
  }
  if (raw == null) return null;
  if (raw is DateTime) {
    return storedBirthDateValue(raw);
  }
  if (raw is Timestamp) {
    return storedBirthDateValue(raw.toDate());
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parsed = parseResidentBirthDate(text);
  return parsed != null ? storedBirthDateValue(parsed) : text;
}

UserRole userRoleGroup(String? value) {
  final role = (value ?? '').trim().toLowerCase();
  if (role == 'super_admin' || role == 'lgu') return UserRole.lgu;
  if (role == 'organization' || role == 'partner') return UserRole.partner;
  if (role == 'barangay' || role.startsWith('barangay_')) {
    return UserRole.barangay;
  }
  return UserRole.resident;
}

SessionDestination sessionDestinationFor(User user) {
  if (!user.isActive || user.isRestricted) {
    return SessionDestination.unavailable;
  }
  return user.role == UserRole.lgu
      ? SessionDestination.adminWeb
      : SessionDestination.home;
}

enum GoogleLoginStatus { success, canceled, profileMissing, error }

class GoogleLoginResult {
  final GoogleLoginStatus status;
  final String? message;

  const GoogleLoginResult(this.status, [this.message]);
}

class User {
  final String uid;
  final String email;
  final UserRole role;
  final String staffRole;
  final String? positionTitle;
  final String name;
  final AccountStatus accountStatus;
  final VerificationStatus verificationStatus;
  final String? residentId;
  final String? idNumber;
  final String? organizationName;
  final String? organizationId;
  final String? barangay;
  final String? barangayId;
  final bool canVerifyResidents;
  final String? address;
  final String? contactNumber;
  final String? birthDate;
  final String? profilePhotoUrl;
  final String? profilePhotoStoragePath;
  final String? acceptedPolicyVersion;
  final String? policyAcceptedAt;
  final bool emailOtpRequired;
  final bool emailOtpVerified;
  final DateTime? emailVerifiedAt;
  final String? verificationReviewNote;
  final String? verificationReviewReason;
  final String? verificationRejectionReason;
  final String? verificationRejectionNote;
  final String? verifiedBarangayId;
  final DateTime? verificationSubmittedAt;
  final String? restrictionStatus;
  final DateTime? restrictionEndDate;
  final String? restrictionReason;
  final String? statusReason;
  final String? restrictedBy;
  final String? restrictedByName;
  final String? restrictedByRole;
  final String? restrictedByOffice;

  User({
    required this.uid,
    required this.email,
    required this.role,
    this.staffRole = '',
    this.positionTitle,
    required this.name,
    this.accountStatus = AccountStatus.active,
    this.verificationStatus = VerificationStatus.notVerified,
    this.residentId,
    this.idNumber,
    this.organizationName,
    this.organizationId,
    this.barangay,
    this.barangayId,
    this.canVerifyResidents = false,
    this.address,
    this.contactNumber,
    this.birthDate,
    this.profilePhotoUrl,
    this.profilePhotoStoragePath,
    this.acceptedPolicyVersion,
    this.policyAcceptedAt,
    this.emailOtpRequired = false,
    this.emailOtpVerified = false,
    this.emailVerifiedAt,
    this.verificationReviewNote,
    this.verificationReviewReason,
    this.verificationRejectionReason,
    this.verificationRejectionNote,
    this.verifiedBarangayId,
    this.verificationSubmittedAt,
    this.restrictionStatus,
    this.restrictionEndDate,
    this.restrictionReason,
    this.statusReason,
    this.restrictedBy,
    this.restrictedByName,
    this.restrictedByRole,
    this.restrictedByOffice,
  });

  User copyWith({
    String? uid,
    String? email,
    UserRole? role,
    String? staffRole,
    String? positionTitle,
    String? name,
    AccountStatus? accountStatus,
    VerificationStatus? verificationStatus,
    String? residentId,
    String? idNumber,
    String? organizationName,
    String? organizationId,
    String? barangay,
    String? barangayId,
    bool? canVerifyResidents,
    String? address,
    String? contactNumber,
    String? birthDate,
    String? profilePhotoUrl,
    String? profilePhotoStoragePath,
    String? acceptedPolicyVersion,
    String? policyAcceptedAt,
    bool? emailOtpRequired,
    bool? emailOtpVerified,
    DateTime? emailVerifiedAt,
    String? verificationReviewNote,
    String? verificationReviewReason,
    String? verificationRejectionReason,
    String? verificationRejectionNote,
    String? verifiedBarangayId,
    DateTime? verificationSubmittedAt,
    String? restrictionStatus,
    DateTime? restrictionEndDate,
    String? restrictionReason,
    String? statusReason,
    String? restrictedBy,
    String? restrictedByName,
    String? restrictedByRole,
    String? restrictedByOffice,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      staffRole: staffRole ?? this.staffRole,
      positionTitle: positionTitle ?? this.positionTitle,
      name: name ?? this.name,
      accountStatus: accountStatus ?? this.accountStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      residentId: residentId ?? this.residentId,
      idNumber: idNumber ?? this.idNumber,
      organizationName: organizationName ?? this.organizationName,
      organizationId: organizationId ?? this.organizationId,
      barangay: barangay ?? this.barangay,
      barangayId: barangayId ?? this.barangayId,
      canVerifyResidents: canVerifyResidents ?? this.canVerifyResidents,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      birthDate: birthDate ?? this.birthDate,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profilePhotoStoragePath:
          profilePhotoStoragePath ?? this.profilePhotoStoragePath,
      acceptedPolicyVersion:
          acceptedPolicyVersion ?? this.acceptedPolicyVersion,
      policyAcceptedAt: policyAcceptedAt ?? this.policyAcceptedAt,
      emailOtpRequired: emailOtpRequired ?? this.emailOtpRequired,
      emailOtpVerified: emailOtpVerified ?? this.emailOtpVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      verificationReviewNote:
          verificationReviewNote ?? this.verificationReviewNote,
      verificationReviewReason:
          verificationReviewReason ?? this.verificationReviewReason,
      verificationRejectionReason:
          verificationRejectionReason ?? this.verificationRejectionReason,
      verificationRejectionNote:
          verificationRejectionNote ?? this.verificationRejectionNote,
      verifiedBarangayId: verifiedBarangayId ?? this.verifiedBarangayId,
      verificationSubmittedAt:
          verificationSubmittedAt ?? this.verificationSubmittedAt,
      restrictionStatus: restrictionStatus ?? this.restrictionStatus,
      restrictionEndDate: restrictionEndDate ?? this.restrictionEndDate,
      restrictionReason: restrictionReason ?? this.restrictionReason,
      statusReason: statusReason ?? this.statusReason,
      restrictedBy: restrictedBy ?? this.restrictedBy,
      restrictedByName: restrictedByName ?? this.restrictedByName,
      restrictedByRole: restrictedByRole ?? this.restrictedByRole,
      restrictedByOffice: restrictedByOffice ?? this.restrictedByOffice,
    );
  }

  bool get isActive => accountStatus == AccountStatus.active;

  bool get isRestricted =>
      restrictionStatus == 'active' &&
      (restrictionEndDate == null ||
          restrictionEndDate!.isAfter(DateTime.now()));

  /// Existing profiles predate registration OTP and remain valid. New
  /// profiles explicitly opt into this gate through [emailOtpRequired].
  bool get hasCompletedRegistrationEmailVerification =>
      !emailOtpRequired || emailOtpVerified;

  bool get isVerified => role == UserRole.resident
      ? verificationStatus == VerificationStatus.verified
      : isActive;

  /// Authoritative check for whether a resident can use verified resident features.
  bool get canUseVerifiedResidentFeatures =>
      isActive && !isRestricted && role == UserRole.resident && isVerified;

  /// Client-side presentation hint. Firebase rules remain the authority for
  /// every write, so this must never be the only access-control check.
  bool get canUseInteractiveFeatures =>
      isActive && !isRestricted && (role != UserRole.resident || isVerified);

  String get status => accountStatus.legacyValue;

  String get canonicalStaffRole {
    final value = staffRole.isEmpty ? role.name : staffRole;
    if (value == 'barangay') return 'barangay_captain';
    if (value == 'partner') return 'organization';
    return value;
  }

  bool get isUnderReview => accountStatus == AccountStatus.pendingApproval;

  bool get isVerificationUnderReview =>
      verificationStatus == VerificationStatus.submitted ||
      verificationStatus == VerificationStatus.underReview;

  bool get needsAdditionalVerificationDocument =>
      verificationStatus == VerificationStatus.additionalDocumentRequired;

  bool get canPublishAnnouncements =>
      isActive &&
      (role == UserRole.barangay ||
          role == UserRole.partner ||
          role == UserRole.lgu);

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': staffRole.isEmpty ? role.name : staffRole,
      'positionTitle': positionTitle,
      'name': name,
      'status': role == UserRole.resident && !isVerified
          ? switch (verificationStatus) {
              VerificationStatus.submitted => 'pending_review',
              VerificationStatus.underReview => 'pending_review',
              VerificationStatus.additionalDocumentRequired =>
                'additional_document_required',
              VerificationStatus.rejected => 'rejected',
              _ => 'unverified',
            }
          : accountStatus.legacyValue,
      'accountStatus': accountStatus.wireValue,
      'verificationStatus': verificationStatus.wireValue,
      'residentId': residentId,
      'idNumber': idNumber,
      'organizationName': organizationName,
      'organizationId': organizationId,
      'barangay': barangay,
      'barangayId': barangayId,
      'canVerifyResidents': canVerifyResidents,
      'address': address,
      'contactNumber': contactNumber,
      'birthDate': birthDate,
      'profilePhotoUrl': profilePhotoUrl,
      'profilePhotoStoragePath': profilePhotoStoragePath,
      'acceptedPolicyVersion': acceptedPolicyVersion,
      'policyAcceptedAt': policyAcceptedAt,
      'emailOtpRequired': emailOtpRequired,
      'emailOtpVerified': emailOtpVerified,
      'emailVerifiedAt': emailVerifiedAt?.toUtc().toIso8601String(),
      'reviewNote': verificationReviewNote,
      'reviewReason': verificationReviewReason,
      'rejectionReason': verificationRejectionReason,
      'rejectionNote': verificationRejectionNote,
      'verifiedBarangayId': verifiedBarangayId,
      'submittedAt': verificationSubmittedAt?.toUtc().toIso8601String(),
      'restrictionStatus': restrictionStatus,
      'restrictionEndDate': restrictionEndDate?.toUtc().toIso8601String(),
      'restrictionReason': restrictionReason,
      'statusReason': statusReason ?? restrictionReason,
      'restrictedBy': restrictedBy,
      'restrictedByName': restrictedByName,
      'restrictedByRole': restrictedByRole,
      'restrictedByOffice': restrictedByOffice,
    };
  }

  factory User.fromMap(
    Map<String, dynamic> map, {
    String? fallbackProfilePhotoUrl,
  }) {
    final role = userRoleGroup(map['role']?.toString());
    final storedPhotoUrl =
        <dynamic>[map['profilePhotoUrl'], map['photoUrl'], map['avatarUrl']]
            .map((value) => value?.toString().trim() ?? '')
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return User(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: role,
      staffRole: map['role']?.toString().trim().toLowerCase() ?? '',
      positionTitle: map['positionTitle']?.toString(),
      name: map['name'] ?? '',
      accountStatus: _accountStatusFromMap(map, role),
      verificationStatus: _verificationStatusFromMap(map, role),
      residentId: map['residentId'],
      idNumber: map['idNumber'],
      organizationName: map['organizationName'],
      organizationId: map['organizationId'],
      barangay: (map['barangay']?.toString().trim().isNotEmpty == true)
          ? map['barangay']?.toString().trim()
          : (bariliBarangayNameForId(map['barangayId']?.toString()) ??
                bariliBarangayNameForId(map['verifiedBarangayId']?.toString())),
      barangayId:
          map['barangayId']?.toString() ??
          bariliBarangayId(map['barangay']?.toString()) ??
          map['verifiedBarangayId']?.toString(),
      canVerifyResidents: map['canVerifyResidents'] == true,
      address: map['address'],
      contactNumber: map['contactNumber'],
      birthDate: _extractBirthDate(map),
      profilePhotoUrl: storedPhotoUrl.isNotEmpty
          ? storedPhotoUrl
          : fallbackProfilePhotoUrl?.trim(),
      profilePhotoStoragePath: map['profilePhotoStoragePath']?.toString(),
      acceptedPolicyVersion: map['acceptedPolicyVersion'],
      policyAcceptedAt: map['policyAcceptedAt'],
      emailOtpRequired: map['emailOtpRequired'] == true,
      emailOtpVerified: map['emailOtpVerified'] == true,
      emailVerifiedAt: nullableDateTimeFromFirestore(map['emailVerifiedAt']),
      verificationReviewNote: map['reviewNote']?.toString(),
      verificationReviewReason: map['reviewReason']?.toString(),
      verificationRejectionReason: map['rejectionReason']?.toString(),
      verificationRejectionNote: map['rejectionNote']?.toString(),
      verifiedBarangayId: map['verifiedBarangayId']?.toString(),
      verificationSubmittedAt: nullableDateTimeFromFirestore(
        map['submittedAt'] ??
            (map['verificationData'] is Map
                ? (map['verificationData'] as Map)['submittedAt']
                : null),
      ),
      restrictionStatus: map['restrictionStatus']?.toString(),
      restrictionEndDate: nullableDateTimeFromFirestore(
        map['restrictionEndDate'],
      ),
      restrictionReason:
          map['restrictionReason']?.toString() ??
          map['statusReason']?.toString(),
      statusReason: map['statusReason']?.toString(),
      restrictedBy: map['restrictedBy']?.toString(),
      restrictedByName: map['restrictedByName']?.toString(),
      restrictedByRole: map['restrictedByRole']?.toString(),
      restrictedByOffice: map['restrictedByOffice']?.toString(),
    );
  }
}

enum LoginFailureType {
  invalidEmail,
  accountNotFound,
  incorrectPassword,
  network,
  general,

  /// Credentials are correct, but the resident is below the minimum age.
  underageAccount,
}

class LoginResult {
  const LoginResult.success() : failureType = null, message = null;

  const LoginResult.failure(this.failureType, [this.message]);

  final LoginFailureType? failureType;
  final String? message;

  bool get isSuccess => failureType == null;
}

typedef LoginHandler =
    Future<LoginResult> Function(String email, String password);

class RegistrationOtpStatus {
  const RegistrationOtpStatus({
    required this.verified,
    required this.hasActiveCode,
    required this.retryAfterSeconds,
    required this.maskedEmail,
    this.expiresAt,
  });

  final bool verified;
  final bool hasActiveCode;
  final int retryAfterSeconds;
  final String maskedEmail;
  final DateTime? expiresAt;
}

class AuthService {
  static User? currentUser;
  static bool isLoggingOut = false;
  static bool get canUseVerifiedResidentFeatures =>
      currentUser != null && currentUser!.canUseVerifiedResidentFeatures;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static Future<void>? _googleInitialization;
  static String? _currentUserStreamUid;
  static Stream<User?>? _cachedCurrentUserDocStream;

  static final Map<String, String> _birthDateMemoryCache = {};

  static void cacheBirthDateInMemory({
    String? uid,
    String? email,
    String? name,
    required String wireDate,
  }) {
    if (wireDate.trim().isEmpty) return;
    final normalizedDate = parseResidentBirthDate(wireDate);
    final dateStr = normalizedDate != null
        ? storedBirthDateValue(normalizedDate)
        : wireDate.trim();
    if (uid != null && uid.trim().isNotEmpty) {
      _birthDateMemoryCache[uid.trim()] = dateStr;
    }
    if (email != null && email.trim().isNotEmpty) {
      _birthDateMemoryCache[email.trim().toLowerCase()] = dateStr;
    }
    if (name != null && name.trim().isNotEmpty) {
      _birthDateMemoryCache[name.trim().toLowerCase()] = dateStr;
    }
    _birthDateMemoryCache['last_signup_birth_date'] = dateStr;
  }

  static String? getCachedBirthDateFor({
    String? uid,
    String? email,
    String? name,
  }) {
    final uidKey = uid?.trim();
    final emailKey = email?.trim().toLowerCase();
    final nameKey = name?.trim().toLowerCase();

    if (uidKey != null && _birthDateMemoryCache.containsKey(uidKey)) {
      return _birthDateMemoryCache[uidKey];
    }
    if (emailKey != null && _birthDateMemoryCache.containsKey(emailKey)) {
      return _birthDateMemoryCache[emailKey];
    }
    if (nameKey != null && _birthDateMemoryCache.containsKey(nameKey)) {
      return _birthDateMemoryCache[nameKey];
    }
    return _birthDateMemoryCache['last_signup_birth_date'];
  }

  static Future<String?> recoverCachedBirthDate({
    String? uid,
    String? email,
    String? name,
  }) async {
    final uidKey = uid?.trim();
    final emailKey = email?.trim().toLowerCase();
    final nameKey = name?.trim().toLowerCase();

    final inMemory = getCachedBirthDateFor(
      uid: uidKey,
      email: emailKey,
      name: nameKey,
    );
    if (inMemory != null && inMemory.isNotEmpty) {
      return inMemory;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? cached =
          (emailKey != null
              ? prefs.getString('user_birth_date_$emailKey')
              : null) ??
          (nameKey != null
              ? prefs.getString('user_birth_date_$nameKey')
              : null) ??
          (uidKey != null
              ? prefs.getString('user_birth_date_$uidKey')
              : null) ??
          prefs.getString('last_signup_birth_date');

      if (cached == null || cached.trim().isEmpty) {
        for (final key in prefs.getKeys()) {
          final lower = key.toLowerCase();
          if (lower.contains('birth') ||
              lower.contains('dob') ||
              lower.contains('bday')) {
            final val = prefs.getString(key);
            if (val != null &&
                val.trim().isNotEmpty &&
                parseResidentBirthDate(val) != null) {
              cached = val;
              break;
            }
          }
        }
      }

      if (cached != null && cached.trim().isNotEmpty) {
        final parsed = parseResidentBirthDate(cached);
        final wire = parsed != null
            ? storedBirthDateValue(parsed)
            : cached.trim();
        cacheBirthDateInMemory(
          uid: uidKey,
          email: emailKey,
          name: nameKey,
          wireDate: wire,
        );
        return wire;
      }
    } catch (_) {}
    return null;
  }

  static User _userFromProfile(Map<String, dynamic> profile) {
    final authenticatedEmail = _auth.currentUser?.email?.trim();
    User user = User.fromMap(
      authenticatedEmail?.isNotEmpty == true
          ? <String, dynamic>{...profile, 'email': authenticatedEmail}
          : profile,
      fallbackProfilePhotoUrl: _auth.currentUser?.photoURL,
    );
    if (user.birthDate == null || user.birthDate!.trim().isEmpty) {
      final uid = user.uid;
      final email = user.email.trim().toLowerCase();
      final name = user.name.trim().toLowerCase();
      final fromMemory =
          (uid.isNotEmpty ? _birthDateMemoryCache[uid] : null) ??
          (email.isNotEmpty ? _birthDateMemoryCache[email] : null) ??
          (name.isNotEmpty ? _birthDateMemoryCache[name] : null) ??
          (currentUser != null &&
                  currentUser!.uid == uid &&
                  currentUser!.birthDate != null
              ? currentUser!.birthDate
              : null) ??
          _birthDateMemoryCache['last_signup_birth_date'];
      if (fromMemory != null && fromMemory.isNotEmpty) {
        final parsed = parseResidentBirthDate(fromMemory);
        final wire = parsed != null ? storedBirthDateValue(parsed) : fromMemory;
        user = user.copyWith(birthDate: wire);
      }
    }
    return user;
  }

  static Future<void> _syncAuthenticatedEmail(
    DocumentReference<Map<String, dynamic>> profileReference,
    Map<String, dynamic> profile,
  ) async {
    final authenticatedEmail = _auth.currentUser?.email?.trim().toLowerCase();
    final storedEmail = profile['email']?.toString().trim().toLowerCase();
    if (authenticatedEmail == null ||
        authenticatedEmail.isEmpty ||
        authenticatedEmail == storedEmail) {
      return;
    }
    try {
      await profileReference.update({
        'email': authenticatedEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      // A verified Auth email is still used in memory. Persisting it can be
      // retried after the corresponding Firestore rule has been deployed.
      debugPrint('Authenticated email profile sync failed: ${error.code}');
    }
  }

  static Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= GoogleSignIn.instance.initialize();
  }

  // Add a real-time listener for the CURRENT user document specifically
  static Stream<User?> get currentUserDocStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _currentUserStreamUid = null;
      _cachedCurrentUserDocStream = null;
      return Stream.value(null);
    }
    if (_currentUserStreamUid == uid && _cachedCurrentUserDocStream != null) {
      return _cachedCurrentUserDocStream!;
    }
    _currentUserStreamUid = uid;
    return _cachedCurrentUserDocStream = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            currentUser = _userFromProfile(doc.data() as Map<String, dynamic>);
            return currentUser;
          }
          return null;
        });
  }

  /// Confirms the signed-in profile against the Firestore server while
  /// leaving the last loaded [currentUser] available if the request fails.
  static Future<User> refreshCurrentUserFromServer() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No signed-in account is available to refresh.');
    }

    await _auth.currentUser?.reload();
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (_) {}
    final profileReference = _firestore.collection('users').doc(uid);
    final profile = await profileReference.get(
      const GetOptions(source: Source.server),
    );
    final data = profile.data();
    if (!profile.exists || data == null) {
      throw StateError('The signed-in account profile no longer exists.');
    }

    await _syncAuthenticatedEmail(profileReference, data);
    final refreshedUser = _userFromProfile(data);
    User finalUser = refreshedUser;
    if (finalUser.birthDate == null || finalUser.birthDate!.trim().isEmpty) {
      final recoveredDate = await recoverCachedBirthDate(
        uid: finalUser.uid,
        email: finalUser.email,
        name: finalUser.name,
      );
      if (recoveredDate != null && recoveredDate.isNotEmpty) {
        finalUser = finalUser.copyWith(birthDate: recoveredDate);
        _firestore
            .collection('users')
            .doc(finalUser.uid)
            .update({
              'birthDate': recoveredDate,
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      }
    }
    currentUser = finalUser;
    return finalUser;
  }

  static Future<LoginResult> login(String email, String password) async {
    try {
      auth.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Fast fetch user details: check cache first for instant login, then server fallback
        DocumentSnapshot doc;
        try {
          doc = await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .get(const GetOptions(source: Source.cache));
          if (!doc.exists) {
            doc = await _firestore
                .collection('users')
                .doc(result.user!.uid)
                .get();
          }
        } catch (_) {
          doc = await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .get();
        }
        if (doc.exists) {
          currentUser = _userFromProfile(doc.data() as Map<String, dynamic>);

          // ── If birthDate was missing in Firestore, attempt recovery from local storage ──
          if (currentUser != null &&
              (currentUser!.birthDate == null ||
                  currentUser!.birthDate!.trim().isEmpty)) {
            final recoveredDate = await recoverCachedBirthDate(
              uid: result.user!.uid,
              email: email,
              name: currentUser!.name,
            );
            if (recoveredDate != null && recoveredDate.isNotEmpty) {
              currentUser = currentUser!.copyWith(birthDate: recoveredDate);
              _firestore
                  .collection('users')
                  .doc(result.user!.uid)
                  .update({
                    'birthDate': recoveredDate,
                    'updatedAt': FieldValue.serverTimestamp(),
                  })
                  .catchError((_) {});
            }
          }

          // Keep the resident age gate consistent with signup eligibility.
          final rawBirthDate = currentUser?.birthDate;
          if (rawBirthDate != null && rawBirthDate.isNotEmpty) {
            try {
              final birthDate = DateTime.parse(rawBirthDate);
              final today = DateTime.now();
              int age = today.year - birthDate.year;
              if (birthDate.month > today.month ||
                  (birthDate.month == today.month &&
                      birthDate.day > today.day)) {
                age--;
              }
              if (age < minimumResidentAge) {
                currentUser = null;
                await _auth.signOut();
                return const LoginResult.failure(
                  LoginFailureType.underageAccount,
                );
              }
            } catch (_) {
              // If the birthDate is malformed, let the login proceed normally.
            }
          }
          // ───────────────────────────────────────────────────────────────
        } else {
          await _auth.signOut();
          return const LoginResult.failure(
            LoginFailureType.general,
            'Your account profile could not be loaded. Please try again.',
          );
        }
      }
      return const LoginResult.success();
    } on auth.FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error: ${e.code} - ${e.message}");
      return switch (e.code) {
        'invalid-email' => const LoginResult.failure(
          LoginFailureType.invalidEmail,
        ),
        'user-not-found' => const LoginResult.failure(
          LoginFailureType.accountNotFound,
        ),
        'wrong-password' || 'invalid-credential' => const LoginResult.failure(
          LoginFailureType.incorrectPassword,
        ),
        'network-request-failed' => const LoginResult.failure(
          LoginFailureType.network,
        ),
        'too-many-requests' => const LoginResult.failure(
          LoginFailureType.general,
          'Too many login attempts. Please wait and try again.',
        ),
        'user-disabled' => const LoginResult.failure(
          LoginFailureType.general,
          'This account has been disabled. Contact E-SUGID support.',
        ),
        _ => const LoginResult.failure(LoginFailureType.general),
      };
    } catch (e) {
      debugPrint("General Auth Error: $e");
      return const LoginResult.failure(LoginFailureType.general);
    }
  }

  static Future<GoogleLoginResult> loginWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const GoogleLoginResult(
          GoogleLoginStatus.error,
          'Google sign-in is not available on this device.',
        );
      }

      final googleAccount = await GoogleSignIn.instance.authenticate();
      if (!googleAccount.email.toLowerCase().endsWith('@gmail.com')) {
        await GoogleSignIn.instance.signOut();
        return const GoogleLoginResult(
          GoogleLoginStatus.error,
          'Please choose a Gmail account ending in @gmail.com.',
        );
      }

      final googleAuthentication = googleAccount.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        idToken: googleAuthentication.idToken,
      );
      final firebaseCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = firebaseCredential.user;
      if (firebaseUser == null) {
        return const GoogleLoginResult(
          GoogleLoginStatus.error,
          'Google sign-in could not be completed.',
        );
      }

      final profile = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (!profile.exists) {
        await _auth.signOut();
        await GoogleSignIn.instance.signOut();
        currentUser = null;
        return const GoogleLoginResult(
          GoogleLoginStatus.profileMissing,
          'No E-SUGID profile is linked to this Google account. Create an account first.',
        );
      }

      currentUser = _userFromProfile(profile.data() as Map<String, dynamic>);
      return const GoogleLoginResult(GoogleLoginStatus.success);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return const GoogleLoginResult(GoogleLoginStatus.canceled);
      }
      debugPrint('Google Sign-In Error: ${error.code} - ${error.description}');
      return const GoogleLoginResult(
        GoogleLoginStatus.error,
        'Google sign-in failed. Please try again.',
      );
    } on auth.FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase Google Auth Error: ${error.code} - ${error.message}',
      );
      if (error.code == 'account-exists-with-different-credential') {
        return const GoogleLoginResult(
          GoogleLoginStatus.error,
          'This Gmail uses a password login. Log in with your password first.',
        );
      }
      if (error.code == 'operation-not-allowed') {
        return const GoogleLoginResult(
          GoogleLoginStatus.error,
          'Google sign-in is not enabled yet. Please contact the administrator.',
        );
      }
      return const GoogleLoginResult(
        GoogleLoginStatus.error,
        'Google authentication failed. Please try again.',
      );
    } catch (error) {
      debugPrint('Google Login Error: $error');
      return const GoogleLoginResult(
        GoogleLoginStatus.error,
        'Unable to use Google sign-in right now.',
      );
    }
  }

  // The pending signup and its password live only in memory. No Firebase Auth
  // user or resident profile is created until the server accepts the OTP.
  static Map<String, dynamic>? _pendingSignup;
  static RegistrationOtpStatus? _pendingSignupStatus;
  static String? get pendingSignupEmail => _pendingSignup?['email'] as String?;
  static bool get hasPendingSignup => _pendingSignup != null;

  static void cancelPendingSignup() {
    _pendingSignup = null;
    _pendingSignupStatus = null;
    SignupDraftStore.clear();
  }

  static RegistrationOtpStatus _otpStatus(Map<String, dynamic> data) {
    final expiresAtMillis = (data['expiresAtMillis'] as num?)?.toInt();
    return RegistrationOtpStatus(
      verified: data['verified'] == true,
      hasActiveCode: data['hasActiveCode'] == true || data['sent'] == true,
      retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 0,
      maskedEmail: data['maskedEmail']?.toString() ?? 'your email address',
      expiresAt: expiresAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
    );
  }

  static Future<String?> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? address,
    String? contactNumber,
    String? birthDate,
    String? idNumber,
    String? organizationName,
    String? barangay,
    required String acceptedPolicyVersion,
    required String policyAcceptedAt,
  }) async {
    if (role != UserRole.resident) {
      return 'Staff accounts must be created and approved by an administrator.';
    }
    final canonicalBarangay = canonicalBariliBarangay(barangay);
    if (canonicalBarangay == null) return 'Select a valid Barili barangay.';
    final parsedBirth = birthDate == null
        ? null
        : parseResidentBirthDate(birthDate);
    final details = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': password,
      'name': name,
      'barangay': canonicalBarangay,
      'address': address?.trim().isNotEmpty == true
          ? address!.trim()
          : canonicalBarangay,
      'contactNumber': contactNumber ?? '',
      'birthDate': parsedBirth == null
          ? birthDate ?? ''
          : storedBirthDateValue(parsedBirth),
      'acceptedPolicyVersion': acceptedPolicyVersion,
      'policyAcceptedAt': policyAcceptedAt,
    };
    try {
      final result = await _functions
          .httpsCallable('beginResidentSignup')
          .call<Object?>({'email': details['email'], 'name': details['name']})
          .timeout(const Duration(seconds: 45));
      final data = Map<String, dynamic>.from(result.data as Map);
      final sessionId = data['sessionId']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('Missing signup session');
      }
      _pendingSignup = {...details, 'sessionId': sessionId};
      _pendingSignupStatus = _otpStatus(data);
      return null;
    } on FirebaseFunctionsException catch (error) {
      return error.message ??
          'Unable to send a verification code. Please try again.';
    } on TimeoutException {
      return 'Sending the verification email took too long. Please try again.';
    } catch (_) {
      return 'Unable to start signup right now. Check your connection and try again.';
    }
  }

  static Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null;
    } on auth.FirebaseAuthException catch (error) {
      return _authErrorMessage(error);
    } catch (error) {
      debugPrint('Password reset error: $error');
      return 'Unable to send a reset link right now. Please try again.';
    }
  }

  static Future<RegistrationOtpStatus> getRegistrationOtpStatus() async {
    if (_pendingSignupStatus != null) return _pendingSignupStatus!;
    final result = await _functions
        .httpsCallable('getRegistrationOtpStatus')
        .call<Object?>();
    final data = Map<String, dynamic>.from(result.data as Map);
    final expiresAtMillis = (data['expiresAtMillis'] as num?)?.toInt();
    return RegistrationOtpStatus(
      verified: data['verified'] == true,
      hasActiveCode: data['hasActiveCode'] == true,
      retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 0,
      maskedEmail: data['maskedEmail']?.toString() ?? 'your email address',
      expiresAt: expiresAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
    );
  }

  static Future<RegistrationOtpStatus> requestRegistrationOtp() async {
    final pending = _pendingSignup;
    if (pending != null) {
      final result = await _functions
          .httpsCallable('beginResidentSignup')
          .call<Object?>({'email': pending['email'], 'name': pending['name']});
      final data = Map<String, dynamic>.from(result.data as Map);
      _pendingSignup = {...pending, 'sessionId': data['sessionId']};
      return _pendingSignupStatus = _otpStatus(data);
    }
    try {
      final result = await _functions
          .httpsCallable('requestRegistrationOtp')
          .call<Object?>();
      final data = Map<String, dynamic>.from(result.data as Map);
      final expiresAtMillis = (data['expiresAtMillis'] as num?)?.toInt();
      return RegistrationOtpStatus(
        verified: data['verified'] == true,
        hasActiveCode: data['sent'] == true,
        retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt() ?? 0,
        maskedEmail:
            data['maskedEmail']?.toString() ??
            _auth.currentUser?.email ??
            'your email address',
        expiresAt: expiresAtMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
      );
    } on FirebaseFunctionsException {
      rethrow;
    }
  }

  static Future<void> verifyRegistrationOtp(String code) async {
    final pending = _pendingSignup;
    if (pending != null) {
      await _functions.httpsCallable('completeResidentSignup').call<Object?>({
        ...pending,
        'code': code.trim(),
      });
      await _auth.signInWithEmailAndPassword(
        email: pending['email'] as String,
        password: pending['password'] as String,
      );
      await refreshCurrentUserFromServer();
      cancelPendingSignup();
      return;
    }
    await _functions.httpsCallable('verifyRegistrationOtp').call<void>({
      'code': code.trim(),
    });
    SignupDraftStore.clear();
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
    await refreshCurrentUserFromServer();
  }

  static Future<String?> updateResidentPersonalInformation({
    required String name,
    required String contactNumber,
    required String address,
    required String birthDate,
  }) async {
    final firebaseUser = _auth.currentUser;
    final user = currentUser;
    if (firebaseUser == null || user == null) {
      return 'Please sign in again before updating your profile.';
    }
    if (user.role != UserRole.resident) {
      return 'Only resident profiles can be updated here.';
    }

    try {
      await _firestore.collection('users').doc(firebaseUser.uid).update({
        'name': name.trim(),
        'contactNumber': contactNumber,
        'address': address.trim(),
        'birthDate': birthDate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await refreshCurrentUserFromServer();
      return null;
    } on FirebaseException catch (error) {
      debugPrint('Resident profile update failed: ${error.code}');
      return error.code == 'permission-denied'
          ? 'Your profile could not be updated. Please sign in again.'
          : 'Unable to save your profile right now. Please try again.';
    } catch (error) {
      debugPrint('Resident profile update failed: $error');
      return 'Unable to save your profile right now. Please try again.';
    }
  }

  static Future<String?> updateResidentProfilePhoto({
    required String? downloadUrl,
    required String storagePath,
  }) async {
    final firebaseUser = _auth.currentUser;
    final user = currentUser;
    if (firebaseUser == null || user == null) {
      return 'Please sign in again before updating your photo.';
    }
    if (user.role != UserRole.resident) {
      return 'Only resident profiles can be updated here.';
    }

    try {
      final updates = <String, Object?>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (downloadUrl == null) {
        updates['profilePhotoUrl'] = FieldValue.delete();
        updates['profilePhotoStoragePath'] = FieldValue.delete();
      } else {
        updates['profilePhotoUrl'] = downloadUrl;
        updates['profilePhotoStoragePath'] = storagePath;
      }
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .update(updates);
      await refreshCurrentUserFromServer();
      return null;
    } on FirebaseException catch (error) {
      debugPrint('Resident photo update failed: ${error.code}');
      return error.code == 'permission-denied'
          ? 'Your photo could not be updated. Please sign in again.'
          : 'Unable to save your photo right now. Please try again.';
    } catch (error) {
      debugPrint('Resident photo update failed: $error');
      return 'Unable to save your photo right now. Please try again.';
    }
  }

  static Future<String?> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      final firebaseUser = await _reauthenticateWithPassword(currentPassword);
      await firebaseUser.verifyBeforeUpdateEmail(newEmail.trim().toLowerCase());
      return null;
    } on auth.FirebaseAuthException catch (error) {
      debugPrint('Change email failed: ${error.code}');
      return _credentialUpdateError(error);
    } catch (error) {
      debugPrint('Change email failed: $error');
      return error is StateError
          ? error.message
          : 'Unable to update your email right now. Please try again.';
    }
  }

  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final firebaseUser = await _reauthenticateWithPassword(currentPassword);
      await firebaseUser.updatePassword(newPassword);
      return null;
    } on auth.FirebaseAuthException catch (error) {
      debugPrint('Change password failed: ${error.code}');
      return _credentialUpdateError(error);
    } catch (error) {
      debugPrint('Change password failed: $error');
      return error is StateError
          ? error.message
          : 'Unable to update your password right now. Please try again.';
    }
  }

  static Future<auth.User> _reauthenticateWithPassword(String password) async {
    final firebaseUser = _auth.currentUser;
    final email = firebaseUser?.email?.trim();
    if (firebaseUser == null || email == null || email.isEmpty) {
      throw StateError('Please sign in again before updating your login.');
    }
    final isGoogleAccount = firebaseUser.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (isGoogleAccount) {
      throw StateError(
        'This account uses Google sign-in. Manage its password and email through Google.',
      );
    }
    final supportsPassword =
        firebaseUser.providerData.isEmpty ||
        firebaseUser.providerData.any(
          (provider) => provider.providerId == 'password',
        );
    if (!supportsPassword) {
      throw StateError(
        'This account uses an external sign-in provider. Manage its credentials there.',
      );
    }
    final credential = auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final result = await firebaseUser.reauthenticateWithCredential(credential);
    return result.user ?? firebaseUser;
  }

  static String _credentialUpdateError(auth.FirebaseAuthException error) {
    return switch (error.code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'ERROR_WRONG_PASSWORD' =>
        'Your current password is incorrect. Please check and try again.',
      'email-already-in-use' => 'An account already uses this email address.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' =>
        'Password must be at least 8 characters and include letters, numbers, and symbols.',
      'requires-recent-login' =>
        'For security, sign out and sign in again before trying this change.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' =>
        'Unable to connect. Check your internet connection and try again.',
      _ =>
        error.message?.isNotEmpty == true
            ? error.message!
            : 'Unable to update your password right now. Please try again.',
    };
  }

  static String _authErrorMessage(auth.FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'The email address is invalid.',
      'user-disabled' => 'This user has been disabled.',
      'email-already-in-use' => 'An account already uses this email address.',
      'weak-password' => 'Choose a stronger password and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' =>
        'A network error occurred. Check your connection and try again.',
      'operation-not-allowed' =>
        'This sign-in method is currently unavailable.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      _ => 'Authentication failed. Please try again.',
    };
  }

  static Future<void> logout() async {
    isLoggingOut = true;
    cancelPendingSignup();
    currentUser = null;
    _currentUserStreamUid = null;
    _cachedCurrentUserDocStream = null;
    try {
      await _auth.signOut();
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google Sign-Out Error: $error');
      }
    } finally {
      isLoggingOut = false;
    }
  }
}
