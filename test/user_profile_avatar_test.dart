import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/widgets/user_profile_avatar.dart';

void main() {
  User resident({required VerificationStatus verificationStatus}) => User(
    uid: 'resident-1',
    email: 'ana@example.com',
    role: UserRole.resident,
    name: 'Ana Jean',
    verificationStatus: verificationStatus,
  );

  Widget subject(User user) => MaterialApp(
    home: Scaffold(
      body: Center(child: UserProfileAvatar(user: user, size: 48)),
    ),
  );

  testWidgets('uses initials when no profile photo is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(resident(verificationStatus: VerificationStatus.notVerified)),
    );

    expect(find.text('AJ'), findsOneWidget);
  });

  testWidgets('shows the badge only for a verified resident', (tester) async {
    await tester.pumpWidget(
      subject(resident(verificationStatus: VerificationStatus.verified)),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpWidget(
      subject(resident(verificationStatus: VerificationStatus.underReview)),
    );
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('does not badge verified non-resident accounts', (tester) async {
    final official = User(
      uid: 'official-1',
      email: 'official@example.com',
      role: UserRole.barangay,
      name: 'Barangay Official',
      verificationStatus: VerificationStatus.verified,
    );

    await tester.pumpWidget(subject(official));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
