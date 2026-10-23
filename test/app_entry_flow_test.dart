import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/main.dart';
import 'package:esugid/app_launch_preferences.dart';

void main() {
  testWidgets('A first launch begins with onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ESugidApp(themeMode: ThemeMode.light));
    await tester.pump();
    expect(find.text('Kasayuran nga klaro ug kasaligan.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const ESugidApp(
        themeMode: ThemeMode.light,
        initialLaunchState: AppLaunchState(
          onboardingCompleted: true,
          permissionSetupCompleted: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kasayuran nga klaro ug kasaligan.'), findsNothing);
    expect(find.text('Allow app access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
