import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/features/settings/pages/settings_page.dart';
import 'package:esugid/forgot_password_screen.dart';
import 'package:esugid/pages/helpdesk_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

User resident(String id) =>
    User(uid: id, email: '$id@example.com', role: UserRole.resident, name: id);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AuthService.currentUser = resident('one');
  });
  tearDown(() => AuthService.currentUser = null);

  Future<void> openHelpdesk(
    WidgetTester tester, {
    required Stream<List<HelpdeskTicket>> Function(String) source,
    Future<void> Function(HelpdeskTicket)? save,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: HelpdeskPage(ticketsForUser: source, createTicket: save),
      ),
    );
    await tester.pump();
  }

  testWidgets('repeated logout activation opens one confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
    final button = find.ancestor(
      of: find.text('Log Out'),
      matching: find.byType(InkWell),
    );
    final onTap = tester.widget<InkWell>(button).onTap!;
    onTap();
    onTap();
    await tester.pumpAndSettle();
    expect(
      find.text('Log out of E-SUGID?', skipOffstage: false),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'password reset ignores stale callbacks and recovers from throws',
    (tester) async {
      final pending = Completer<String?>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordScreen(
            sendPasswordResetEmail: (email) {
              calls++;
              expect(email, 'person@example.com');
              return pending.future;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'person@example.com');
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(calls, 1);
      pending.completeError(StateError('private reset details'));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('private reset details'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).first)
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'helpdesk keeps its stream while submitting and preserves a new draft',
    (tester) async {
      final pending = Completer<void>();
      var streams = 0;
      var saves = 0;
      Stream<List<HelpdeskTicket>> source(String uid) {
        streams++;
        return Stream.value(<HelpdeskTicket>[]);
      }

      await openHelpdesk(
        tester,
        source: source,
        save: (ticket) {
          saves++;
          expect(ticket.subject, 'Initial subject');
          return pending.future;
        },
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Initial subject',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Initial message with details',
      );
      final submit = tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(saves, 1);
      expect(streams, 1);
      await tester.enterText(find.byType(TextFormField).at(0), 'Next subject');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Next subject'), findsOneWidget);
      expect(find.text('Initial message with details'), findsNothing);
      expect(streams, 1);
    },
  );

  testWidgets('helpdesk ignores a completed save after disposal', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openHelpdesk(
      tester,
      source: (_) => Stream.value(<HelpdeskTicket>[]),
      save: (_) => pending.future,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Test subject');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Test message with details',
    );
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed!();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('helpdesk exposes safe stream errors and retries the source', (
    tester,
  ) async {
    var calls = 0;
    Stream<List<HelpdeskTicket>> source(String uid) {
      calls++;
      return calls == 1
          ? Stream.error(
              FirebaseFunctionsException(
                code: 'unavailable',
                message: 'private transport details',
              ),
            )
          : Stream.value(<HelpdeskTicket>[]);
    }

    await openHelpdesk(tester, source: source);
    await tester.pumpAndSettle();
    expect(find.textContaining('private transport details'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No tickets yet'), findsOneWidget);
  });

  testWidgets('helpdesk replaces streams for account and source changes', (
    tester,
  ) async {
    final users = <String>[];
    Stream<List<HelpdeskTicket>> source(String uid) {
      users.add(uid);
      return Stream.value(<HelpdeskTicket>[]);
    }

    await openHelpdesk(tester, source: source);
    AuthService.currentUser = resident('two');
    await openHelpdesk(tester, source: source);
    expect(users, ['one', 'two']);
    var replacements = 0;
    await openHelpdesk(
      tester,
      source: (uid) {
        replacements++;
        expect(uid, 'two');
        return Stream.value(<HelpdeskTicket>[]);
      },
    );
    expect(replacements, 1);
  });
}
