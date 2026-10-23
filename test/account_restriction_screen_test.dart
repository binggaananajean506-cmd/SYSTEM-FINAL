import 'package:esugid/auth_service.dart';
import 'package:esugid/pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('restricted account displays reason, end date, and proper authorizing official contact wording', (tester) async {
    final restrictedUser = User(
      uid: 'user_123',
      email: 'christian@example.com',
      name: 'Christian Jay Jr.',
      role: UserRole.resident,
      barangay: 'Cabcaban',
      restrictionStatus: 'active',
      restrictionReason: 'Multiple false emergency alerts reported in violation of policy.',
      restrictionEndDate: DateTime(2026, 10, 15, 17, 0),
      restrictedByOffice: 'Barangay Cabcaban Office',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PendingApprovalScreen(user: restrictedUser),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and greeting
    expect(find.text('Access Restricted'), findsOneWidget);
    expect(find.text('ACCOUNT RESTRICTED'), findsOneWidget);
    expect(find.textContaining('Christian Jay Jr.'), findsOneWidget);

    // Verify Reason for Restriction is displayed clearly
    expect(find.text('Reason for Restriction'), findsOneWidget);
    expect(find.text('Multiple false emergency alerts reported in violation of policy.'), findsOneWidget);

    // Verify Restriction End Date and auto-restore note
    expect(find.text('Restricted Until'), findsOneWidget);
    expect(find.textContaining('October 15, 2026'), findsOneWidget);
    expect(find.textContaining('automatically be able to log back into your account'), findsOneWidget);

    // Verify proper contact wording with authorizing authority
    expect(find.text('Need Clarification or Want to Appeal?'), findsOneWidget);
    expect(
      find.textContaining('please contact the Barangay Cabcaban Office who restricted your account'),
      findsOneWidget,
    );

    // Verify Back to Login button
    expect(find.text('Back to Login'), findsOneWidget);
  });

  testWidgets('restricted account with no custom office falls back to barangay officials', (tester) async {
    final restrictedUser = User(
      uid: 'user_456',
      email: 'faith@example.com',
      name: 'Faith',
      role: UserRole.resident,
      barangay: 'Poblacion',
      restrictionStatus: 'active',
      statusReason: 'Spam submissions',
      restrictionEndDate: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PendingApprovalScreen(user: restrictedUser),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Restricted'), findsOneWidget);
    expect(find.text('Reason for Restriction'), findsOneWidget);
    expect(find.text('Spam submissions'), findsOneWidget);
    expect(
      find.textContaining('please contact the Barangay Poblacion Officials who restricted your account'),
      findsOneWidget,
    );
  });
}
