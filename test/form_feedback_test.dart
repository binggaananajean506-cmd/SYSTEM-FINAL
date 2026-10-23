import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/features/complaints/complaint_service.dart';
import 'package:esugid/pages/complaint_form_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'resident',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident',
      barangay: 'Vito',
      verificationStatus: VerificationStatus.verified,
    );
  });
  tearDown(() => AuthService.currentUser = null);

  for (final brightness in Brightness.values) {
    testWidgets(
      'complaint reveals an off-screen error and recovers in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var attempts = 0;
        final complaint = Submission.fromMap({
          'id': 'BC-2026-100001',
          'kind': 'complaint',
          'type': 'Noise',
          'category': 'Barangay Complaint',
          'description': 'short',
          'date': DateTime(2026, 10, 5).toIso8601String(),
          'complaint': {
            'respondentName': 'Juan Dela Cruz',
            'relationship': 'Neighbor',
          },
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ComplaintFormPage(
              existingComplaint: complaint,
              submit: (_) async {
                attempts++;
                throw const ComplaintException(
                  'Your complaint could not be sent. Please try again.',
                );
              },
            ),
          ),
        );
        final submit = find.byKey(const ValueKey('complaint-submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(attempts, 0);
        final notice = find.byKey(
          const ValueKey('complaint-validation-notice'),
        );
        expect(notice.hitTestable(), findsOneWidget);
        expect(find.textContaining('at least 10 characters'), findsWidgets);
        final details = find.byKey(const ValueKey('complaint-details'));
        expect(tester.getRect(details).top, greaterThanOrEqualTo(60));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(notice.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: details, matching: find.byType(TextField)),
              )
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await tester.enterText(
          details,
          'The neighbor plays loud music late at night.',
        );
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(attempts, 1);
        expect(
          find.text('Your complaint could not be sent. Please try again.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        expect(
          tester.widget<TextFormField>(details).controller!.text,
          contains('loud music'),
        );
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'action messages wrap, replace stale results and retain actions in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late BuildContext page;
        var undo = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                page = context;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        );
        final messenger = ScaffoldMessenger.of(page);
        messenger.showAppSnackBar(
          AppSnackBar(content: Text('Old result'), kind: FeedbackKind.success),
        );
        await tester.pumpAndSettle();
        messenger.showAppSnackBar(
          AppSnackBar(
            content: const Text(
              'Your changes were saved successfully. You can undo this action if needed.',
            ),
            kind: FeedbackKind.success,
            action: SnackBarAction(label: 'Undo', onPressed: () => undo = true),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Old result'), findsNothing);
        expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(undo, isTrue);
        messenger.showAppSnackBar(
          AppSnackBar(
            content: Text('Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Please try again.'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
