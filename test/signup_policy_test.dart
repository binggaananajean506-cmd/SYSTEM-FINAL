import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/signup_screen.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Sign Up is disabled until registration policies are accepted', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();

    final policyCheckbox = find.byKey(const ValueKey('signup-policy-checkbox'));
    await tester.scrollUntilVisible(
      policyCheckbox,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final signUpButtonFinder = find.byKey(const ValueKey('signup-submit-button'));
    expect(tester.widget<InkWell>(signUpButtonFinder).onTap, isNull);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Cookies Policy'), findsOneWidget);

    await tester.tap(policyCheckbox);
    await tester.pump();

    expect(
      tester.widget<InkWell>(signUpButtonFinder).onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resident signup uses clipped content and no redundant fields', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-content-clip')), findsOneWidget);
    expect(find.text('ID number'), findsNothing);
    expect(find.text('Home address'), findsNothing);
    expect(find.text('Barangay'), findsOneWidget);
    expect(find.text('Birth date'), findsNothing);
    expect(find.text('Contact number'), findsNothing);
    expect(
      find.byKey(const ValueKey('signup-contact-number-field')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('barangay selector supports search and selection', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();

    final barangaySelector = find.byKey(const ValueKey('signup-barangay-selector'));
    await tester.scrollUntilVisible(
      barangaySelector,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(barangaySelector);
    await tester.pumpAndSettle();

    expect(find.text('Select your barangay'), findsOneWidget);
    expect(find.text('Choose from 42 Barili barangays'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('barangay-search-field')),
      'Vito',
    );
    await tester.pumpAndSettle();
    final vitoOption = find.widgetWithText(InkWell, 'Vito');
    expect(vitoOption, findsOneWidget);

    await tester.tap(vitoOption);
    await tester.pumpAndSettle();

    expect(find.text('Vito'), findsOneWidget);
    expect(find.text('Select your barangay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed birthdays format as MM/DD/YYYY and reject impossible dates', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();

    final dob = find.byKey(const ValueKey('signup-dob-field'));
    await tester.scrollUntilVisible(
      dob,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(dob, '05141998');
    await tester.pump();
    expect(find.text('05/14/1998'), findsOneWidget);
    final today = DateTime.now();
    final birthdayPassed = today.month > 5 || (today.month == 5 && today.day >= 14);
    final age = today.year - 1998 - (birthdayPassed ? 0 : 1);
    expect(find.text('$age'), findsOneWidget);

    await tester.enterText(dob, '5555555');
    await tester.pump();
    expect(find.text('55/55/555'), findsOneWidget);
    expect(find.text('$age'), findsNothing);

    await tester.enterText(dob, '02302000');
    await tester.pump();
    expect(find.text('02/30/2000'), findsOneWidget);
    expect(find.text('26'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('signup requires age 15 and accepts the exact birthday boundary', (
    WidgetTester tester,
  ) async {
    usePhoneSize(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
    await tester.pumpAndSettle();
    final dob = find.byKey(const ValueKey('signup-dob-field'));
    await tester.scrollUntilVisible(
      dob,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final today = DateTime.now();
    String birthday(DateTime date) =>
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}${date.year}';
    final fifteenthBirthday = DateTime(today.year - 15, today.month, today.day);
    await tester.enterText(
      dob,
      birthday(fifteenthBirthday.add(const Duration(days: 1))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Must be at least 15 years old to sign up.'), findsOneWidget);
    await tester.enterText(dob, birthday(fifteenthBirthday));
    await tester.pumpAndSettle();
    expect(find.text('Must be at least 15 years old to sign up.'), findsNothing);
    expect(find.text('15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
