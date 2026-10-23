import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/onboarding_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Three clean onboarding pages lead directly to authentication', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () async => completed = true),
      ),
    );

    expect(find.text('Kasayuran nga klaro ug kasaligan.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ang matag barangay, konektado.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Serbisyo sa komunidad, duol kanimo.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('get-started-button')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip completes onboarding without showing registration terms', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () async => completed = true),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Terms & Privacy'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
