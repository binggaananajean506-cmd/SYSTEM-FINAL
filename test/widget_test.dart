import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/auth_service.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:esugid/login_screen.dart';
import 'package:esugid/signup_screen.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Maayong pag-abot!'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.byKey(const ValueKey('google-login-button')), findsNothing);
    expect(find.text('Log in to your account'), findsNothing);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    final link = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Create account'),
        matching: find.byType(TextButton),
      ),
    );
    expect(
      link.style!.foregroundColor!.resolve({}),
      ESugidColors.light.onAccent,
    );
  });

  testWidgets('Create account opens resident registration directly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('JOIN E-SUGID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login screen shows an invalid email error under the field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'resident@invalid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      '123',
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Incorrect password. Please try again.'), findsNothing);
    expect(
      find.text('The email address and password are incorrect.'),
      findsNothing,
    );
  });

  testWidgets('Common email typo offers a tappable inline correction', (
    WidgetTester tester,
  ) async {
    var loginCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          loginHandler: (_, _) async {
            loginCalls++;
            return const LoginResult.success();
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'jine@gmail.con',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'password',
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(loginCalls, 0);
    expect(
      find.text(
        'Check your email address. Did you mean jine@gmail.com?',
        findRichText: true,
      ),
      findsOneWidget,
    );
    final emailField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-email-field')),
    );
    final border = emailField.decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, ESugidColors.light.error);

    await tester.tap(find.byKey(const ValueKey('login-email-suggestion')));
    await tester.pumpAndSettle();

    expect(emailField.controller!.text, 'jine@gmail.com');
    expect(
      find.text(
        'Check your email address. Did you mean jine@gmail.com?',
        findRichText: true,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(loginCalls, 1);
  });

  testWidgets('Login screen explains required fields clearly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(
      find.text('The email address and password are incorrect.'),
      findsNothing,
    );
  });

  testWidgets('Editing a field clears only that field error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'resident@example.com',
    );
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsNothing);
    expect(find.text('Password is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'correct-length',
    );
    await tester.pumpAndSettle();

    expect(find.text('Password is required.'), findsNothing);
  });

  testWidgets('Account-not-found errors belong only to the email field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          loginHandler: (_, _) async =>
              const LoginResult.failure(LoginFailureType.accountNotFound),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'missing@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'password',
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Account not found.'), findsOneWidget);
    expect(find.text('Incorrect password. Please try again.'), findsNothing);

    final emailField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-email-field')),
    );
    final border = emailField.decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, ESugidColors.light.error);
  });

  testWidgets('Wrong password keeps the email and refocuses password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          loginHandler: (_, _) async =>
              const LoginResult.failure(LoginFailureType.incorrectPassword),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'resident@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'wrong-password',
    );
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-email-field')),
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-password-field')),
    );

    expect(emailField.controller!.text, 'resident@example.com');
    expect(passwordField.controller!.text, isEmpty);
    expect(passwordField.focusNode!.hasFocus, isTrue);
    expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
    expect(find.text('Account not found.'), findsNothing);
  });

  testWidgets('Password eye is inline and toggles password visibility', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    var passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-password-field')),
    );

    expect(passwordField.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey('login-password-field')),
    );
    expect(passwordField.obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('Login disables repeated taps and shows progress text', (
    WidgetTester tester,
  ) async {
    final result = Completer<LoginResult>();
    var loginCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          loginHandler: (_, _) {
            loginCalls++;
            return result.future;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'resident@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'password',
    );
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(loginCalls, 1);
    expect(find.text('Logging in...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(loginCalls, 1);

    result.complete(const LoginResult.failure(LoginFailureType.network));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to connect. Check your internet connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('Login screen remains usable on a compact phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Maayong pag-abot!'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
