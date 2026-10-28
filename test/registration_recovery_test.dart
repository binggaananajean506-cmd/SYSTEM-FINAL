// Firebase platform interfaces replace only the native/network boundary.
// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as store;
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart'
    as functions;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/email_otp_verification_screen.dart';
import 'package:esugid/signup_screen.dart';

const _uid = 'signup-recovery-resident';
const _email = 'registration-recovery@example.com';
const _password = 'Dummy-password-123!';

Future<String?> _register({String password = _password}) {
  return AuthService.register(
    email: _email,
    password: password,
    name: 'Newly entered name',
    role: UserRole.resident,
    barangay: 'Poblacion',
    birthDate: '2001-05-14',
    acceptedPolicyVersion: '2026-09-01',
    policyAcceptedAt: '2026-10-26T04:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final nativeAuth = _RegistrationAuth();
  final nativeStore = _RegistrationStore(nativeAuth);
  late _RegistrationFunctions nativeFunctions;

  setUpAll(() async {
    await Firebase.initializeApp();
    auth.FirebaseAuthPlatform.instance = nativeAuth;
    store.FirebaseFirestorePlatform.instance = nativeStore;
    nativeFunctions = _RegistrationFunctions(nativeStore);
    functions.FirebaseFunctionsPlatform.instance = nativeFunctions;
  });

  setUp(() {
    AuthService.cancelPendingSignup();
    nativeFunctions.failureCode = null;
    nativeFunctions.requests.clear();
    AuthService.currentUser = null;
    nativeAuth.signedInUser = null;
    nativeStore.profile = {
      'uid': _uid,
      'email': _email,
      'name': 'Original resident name',
      'role': 'resident',
      'accountStatus': 'active',
      'verificationStatus': 'not_submitted',
      'barangay': 'Poblacion',
      'barangayId': 'poblacion',
      'birthDate': '2001-05-14',
      'emailOtpRequired': true,
      'emailOtpVerified': false,
    };
  });

  tearDown(AuthService.cancelPendingSignup);

  test(
    'requesting signup verification does not create or sign into an account',
    () async {
      expect(await _register(), isNull);
      expect(nativeAuth.currentUser, isNull);
      expect(AuthService.currentUser, isNull);
    },
  );

  test(
    'restarting signup replaces only the pending verification request',
    () async {
      expect(await _register(), isNull);
      expect(await _register(password: 'Changed-dummy-password-123!'), isNull);
      expect(nativeAuth.currentUser, isNull);
      expect(AuthService.currentUser, isNull);
    },
  );

  test('delivery failures leave no pending account', () async {
    nativeFunctions.failureCode = 'unavailable';
    expect(await _register(), contains('could not be sent'));
    expect(AuthService.hasPendingSignup, isFalse);
    expect(nativeAuth.currentUser, isNull);
  });

  test(
    'resending sends only the email and keeps registration pending',
    () async {
      expect(await _register(), isNull);
      await AuthService.requestRegistrationOtp();
      expect(nativeFunctions.requests.last.keys, ['email']);
      expect(AuthService.hasPendingSignup, isTrue);
      expect(nativeAuth.currentUser, isNull);
    },
  );

  test('an incorrect code leaves signup pending and signed out', () async {
    expect(await _register(), isNull);
    nativeFunctions.failureCode = 'invalid-argument';
    await expectLater(
      AuthService.verifyRegistrationOtp('000000'),
      throwsA(isA<FirebaseException>()),
    );
    expect(AuthService.hasPendingSignup, isTrue);
    expect(nativeAuth.currentUser, isNull);
    expect(AuthService.currentUser, isNull);
  });

  test(
    'successful verification signs in only after server account completion',
    () async {
      expect(await _register(), isNull);
      await AuthService.verifyRegistrationOtp('123456');
      expect(nativeFunctions.requests.last['password'], _password);
      expect(nativeFunctions.requests.last['code'], '123456');
      expect(nativeAuth.currentUser?.uid, _uid);
      expect(AuthService.currentUser?.emailOtpVerified, isTrue);
      expect(AuthService.hasPendingSignup, isFalse);
    },
  );

  test(
    'cancelling verification leaves no account to block another signup',
    () async {
      expect(await _register(), isNull);
      AuthService.cancelPendingSignup();
      expect(AuthService.hasPendingSignup, isFalse);
      expect(nativeAuth.currentUser, isNull);
      expect(await _register(), isNull);
      expect(nativeAuth.currentUser, isNull);
    },
  );
  testWidgets(
    'changing the verification email restores the form at its email field',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<auth.UserPlatform?>(
            valueListenable: nativeAuth.session,
            builder: (context, user, child) {
              if (user != null) return const EmailOtpVerificationScreen();
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SignupScreen(),
                      ),
                    ),
                    child: const Text('Begin signup'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Begin signup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
      await tester.enterText(find.byType(TextFormField).at(1), 'Maria');
      await tester.enterText(find.byType(TextFormField).at(2), 'Resident');
      await tester.enterText(
        find.byKey(const ValueKey('signup-dob-field')),
        '05142001',
      );
      final barangay = find.byKey(const ValueKey('signup-barangay-selector'));
      await tester.ensureVisible(barangay);
      await tester.pumpAndSettle();
      await tester.tap(barangay);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('barangay-search-field')),
        'Poblacion',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Poblacion'));
      await tester.pumpAndSettle();
      final email = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.emailAddress,
      );
      await tester.enterText(email, _email);
      final passwords = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText,
      );
      await tester.enterText(passwords.at(0), _password);
      await tester.enterText(passwords.at(1), _password);
      final policies = find.byKey(const ValueKey('signup-policy-checkbox'));
      await tester.ensureVisible(policies);
      await tester.pumpAndSettle();
      await tester.tap(policies);
      final submit = find.byKey(const ValueKey('signup-submit-button'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('Use a different email'), findsOneWidget);
      await tester.tap(find.text('Use a different email'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Resident'), findsOneWidget);
      expect(find.text('05/14/2001'), findsOneWidget);
      expect(find.text('Poblacion'), findsOneWidget);
      expect(find.text(_password), findsNWidgets(2));
      final emailInput = tester.widget<TextField>(email);
      expect(emailInput.controller?.text, _email);
      expect(emailInput.focusNode?.hasFocus, isTrue);
      expect(
        tester.getRect(email).overlaps(const Rect.fromLTWH(0, 0, 390, 844)),
        isTrue,
      );
      expect(tester.widget<InkWell>(submit).onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}

class _RegistrationAuth extends auth.FirebaseAuthPlatform {
  final session = ValueNotifier<auth.UserPlatform?>(null);
  auth.UserPlatform? get signedInUser => session.value;
  set signedInUser(auth.UserPlatform? user) => session.value = user;

  @override
  auth.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  auth.FirebaseAuthPlatform setInitialValues({
    auth.PigeonUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  auth.UserPlatform? get currentUser => signedInUser;

  @override
  Future<auth.UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    throw StateError('Signup must not create an Auth account before OTP');
  }

  @override
  Future<auth.UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    expect(email, _email);
    expect(password, _password);
    signedInUser = _RegistrationUser(this);
    return _RegistrationCredential(this, signedInUser!);
  }

  @override
  Future<void> signOut() async {
    signedInUser = null;
  }
}

class _RegistrationUser extends auth.UserPlatform {
  _RegistrationUser(auth.FirebaseAuthPlatform authPlatform)
    : super(
        authPlatform,
        _RegistrationMultiFactor(authPlatform),
        auth.PigeonUserDetails(
          userInfo: auth.PigeonUserInfo(
            uid: _uid,
            email: _email,
            isAnonymous: false,
            isEmailVerified: false,
          ),
          providerData: [
            {'providerId': 'password', 'uid': _email, 'email': _email},
          ],
        ),
      );

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'test-id-token';
}

class _RegistrationMultiFactor extends auth.MultiFactorPlatform {
  _RegistrationMultiFactor(super.auth);
}

class _RegistrationCredential extends auth.UserCredentialPlatform {
  _RegistrationCredential(
    auth.FirebaseAuthPlatform authPlatform,
    auth.UserPlatform userPlatform,
  ) : super(auth: authPlatform, user: userPlatform);
}

class _RegistrationStore extends store.FirebaseFirestorePlatform {
  _RegistrationStore(this.authPlatform);

  final _RegistrationAuth authPlatform;
  Map<String, dynamic> profile = {};

  @override
  store.FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;

  @override
  store.CollectionReferencePlatform collection(String collectionPath) {
    return _RegistrationCollection(this, collectionPath);
  }

  @override
  store.DocumentReferencePlatform doc(String documentPath) {
    return _RegistrationDocument(this, documentPath);
  }
}

class _RegistrationCollection extends store.CollectionReferencePlatform {
  _RegistrationCollection(super.firestore, super.path);

  @override
  store.DocumentReferencePlatform doc([String? path]) {
    return firestore.doc('${this.path}/$path');
  }
}

class _RegistrationDocument extends store.DocumentReferencePlatform {
  _RegistrationDocument(super.firestore, super.path);

  @override
  Future<store.DocumentSnapshotPlatform> get([
    store.GetOptions options = const store.GetOptions(),
  ]) async {
    final backend = firestore as _RegistrationStore;
    if (path != 'users/$_uid' ||
        backend.authPlatform.currentUser?.uid != _uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return store.DocumentSnapshotPlatform(
      firestore,
      path,
      backend.profile,
      store.PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
    );
  }
}

class _RegistrationFunctions extends functions.FirebaseFunctionsPlatform {
  _RegistrationFunctions(this.store) : super(Firebase.app(), 'asia-southeast1');
  final _RegistrationStore store;
  String? failureCode;
  final List<Map<String, dynamic>> requests = [];

  @override
  functions.FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => this;

  @override
  functions.HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    functions.HttpsCallableOptions options,
  ) => _RegistrationCallable(this, origin, name, options);
}

class _RegistrationCallable extends functions.HttpsCallablePlatform {
  _RegistrationCallable(
    this.backend,
    String? origin,
    String name,
    functions.HttpsCallableOptions options,
  ) : super(backend, origin, name, options, null);

  final _RegistrationFunctions backend;

  @override
  Future<dynamic> call([dynamic parameters]) async {
    backend.requests.add(Map<String, dynamic>.from(parameters as Map? ?? {}));
    if (backend.failureCode != null) {
      throw functions.FirebaseFunctionsException(
        code: backend.failureCode!,
        message: 'The verification email could not be sent or verified.',
      );
    }
    if (name == 'completeResidentSignup') {
      backend.store.profile['emailOtpVerified'] = true;
      return {'verified': true, 'uid': _uid};
    }
    if (name != 'getRegistrationOtpStatus' && name != 'beginResidentSignup') {
      throw StateError('Unexpected registration callable: $name');
    }
    return {
      'sessionId': 'test-signup-session',
      'verified': false,
      'hasActiveCode': true,
      'retryAfterSeconds': 0,
      'maskedEmail': 're****@example.com',
    };
  }
}
