import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/verification_screen.dart';

void main() {
  setUp(() {
    AuthService.currentUser = User(
      uid: 'resident-1',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Cris Resident',
      barangay: 'Cabcaban',
      barangayId: 'cabcaban',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  testWidgets('verification form toggles two-sided slots for IDs and single slot for certificates/proofs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VerificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Verify your residency'), findsOneWidget);
    expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
    expect(find.text('Cris Resident'), findsWidgets);
    expect(find.text('Cabcaban'), findsWidgets);
    expect(find.text('Birth Date'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Tap to select birth date'), findsNothing);
    expect(find.text('Contact Number'), findsNothing);
    expect(find.text('Document Type'), findsOneWidget);

    // Initially with no doc selected, shows single Document Photo slot
    expect(find.text('Document Photo'), findsOneWidget);
    expect(find.text('Back View of ID'), findsNothing);

    // Select National ID (two-sided)
    final selectDocTypeFinder = find.text('Select document type');
    await tester.ensureVisible(selectDocTypeFinder);
    await tester.pumpAndSettle();
    await tester.tap(selectDocTypeFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('National ID').last);
    await tester.pumpAndSettle();

    expect(find.text('Front View of ID'), findsOneWidget);
    expect(find.text('Back View of ID'), findsOneWidget);
    expect(
      find.text('Both Front and Back photos of your ID are strictly required.'),
      findsOneWidget,
    );

    // Select Barangay Certificate (single-sided)
    await tester.tap(find.text('National ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barangay Certificate').last);
    await tester.pumpAndSettle();

    expect(find.text('Front View of ID'), findsNothing);
    expect(find.text('Back View of ID'), findsNothing);
    expect(find.text('Document Photo'), findsOneWidget);
    expect(
      find.text('A clear photo of your document is required for manual barangay review.'),
      findsOneWidget,
    );

    // Select Other Proof (single-sided, renamed from Other Proof of Address)
    await tester.tap(find.text('Barangay Certificate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other Proof').last);
    await tester.pumpAndSettle();

    expect(find.text('Front View of ID'), findsNothing);
    expect(find.text('Back View of ID'), findsNothing);
    expect(find.text('Document Photo'), findsOneWidget);
    expect(find.text('Document Name'), findsOneWidget);

    final uploadArea = find.byKey(const ValueKey('verification-upload-area'));
    await tester.ensureVisible(uploadArea);
    await tester.pumpAndSettle();
    await tester.tap(uploadArea);
    await tester.pumpAndSettle();

    expect(find.text('Add verification document'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose File'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verification screen automatically displays birthdate and age locked when provided on user profile', (
    tester,
  ) async {
    AuthService.currentUser = User(
      uid: 'ana-jean-uid',
      email: 'anajean@example.com',
      role: UserRole.resident,
      name: 'Ana Jean Atamosa Binggaan',
      barangay: 'Vito',
      barangayId: 'vito',
      birthDate: '2005-09-15',
    );

    await tester.pumpWidget(const MaterialApp(home: VerificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ana Jean Atamosa Binggaan'), findsWidgets);
    expect(find.text('Vito'), findsWidgets);
    // Should display formatted birth date locked, NOT "Tap to select birth date"
    expect(find.text('September 15, 2005'), findsWidgets);
    expect(find.text('Tap to select birth date'), findsNothing);
    // Age should be auto calculated and displayed
    expect(find.textContaining('years old'), findsWidgets);
  });

  testWidgets('verification screen automatically recovers and displays birthdate and age from cached signup data', (
    tester,
  ) async {
    AuthService.cacheBirthDateInMemory(
      uid: 'cached-user-uid',
      email: 'cached@example.com',
      name: 'Ana Jean Atamosa Binggaan',
      wireDate: '2004-05-12',
    );

    // Profile in Firestore is missing birthDate (empty/null)
    AuthService.currentUser = User(
      uid: 'cached-user-uid',
      email: 'cached@example.com',
      role: UserRole.resident,
      name: 'Ana Jean Atamosa Binggaan',
      barangay: 'Vito',
      barangayId: 'vito',
      birthDate: null,
    );

    await tester.pumpWidget(const MaterialApp(home: VerificationScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ana Jean Atamosa Binggaan'), findsWidgets);
    expect(find.text('Vito'), findsWidgets);
    // Should automatically display recovered birth date locked
    expect(find.text('May 12, 2004'), findsWidgets);
    expect(find.text('Tap to select birth date'), findsNothing);
    expect(find.textContaining('years old'), findsWidgets);
  });
}

