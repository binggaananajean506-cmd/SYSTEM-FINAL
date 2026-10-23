import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/email_otp_verification_screen.dart';

void main() {
  setUp(() {
    AuthService.currentUser = User(
      uid: 'user-123',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Juan Dela Cruz',
      barangay: 'Poblacion',
      barangayId: 'poblacion',
      emailOtpRequired: true,
      emailOtpVerified: false,
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('OTP verification screen allows typing into code boxes and focuses properly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EmailOtpVerificationScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.text('VERIFY CODE'), findsOneWidget);

    final inputFinder = find.byKey(const ValueKey('otp-code-input-field'));
    expect(inputFinder, findsOneWidget);

    // Tap on the OTP boxes
    await tester.tap(inputFinder);
    await tester.pump();

    // Type 6 digits into the field
    await tester.enterText(inputFinder, '654321');
    await tester.pump();

    // The individual digits should now be rendered visually in the boxes
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
