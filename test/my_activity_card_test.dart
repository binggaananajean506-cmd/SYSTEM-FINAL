import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/my_activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ActivityRepository implements SubmissionRepository {
  final items = [
    Submission(
      id: 'concern-1',
      title: 'Repair the streetlight',
      description: 'The streetlight near the chapel is broken.',
      category: 'Infrastructure',
      type: 'Concern',
      userId: 'resident',
      date: DateTime(2026, 10, 1),
      status: 'being_handled',
    ),
    Submission(
      id: 'BC-1',
      title: 'Noise complaint',
      description: 'Loud karaoke late at night.',
      category: 'Barangay Complaint',
      type: 'Noise',
      userId: 'resident',
      date: DateTime(2026, 10, 1),
      status: 'under_review',
      complaintTrackingVersion: 1,
    ),
  ];

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value(items);

  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Future<Submission> resubmitConcern(Submission submission) async => submission;

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async {}
}

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
    for (final width in [288.0, 358.0, 568.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('activity card fits $brightness, $width, scale $scale', (
          tester,
        ) async {
          final colors = brightness == Brightness.dark
              ? ESugidColors.dark
              : ESugidColors.light;
          var taps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildESugidClayTheme(brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: MyActivityCard(
                        title: 'A very long concern or complaint title',
                        category: 'Infrastructure and drainage improvements',
                        categoryColor: colors.warning,
                        statusLabel: 'Previous Record — Awaiting Confirmation',
                        statusColor: colors.warning,
                        onTap: () => taps++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('PREVIOUS RECORD — AWAITING CONFIRMATION'),
            findsOneWidget,
          );
          await tester.tap(find.text('Track →'));
          expect(taps, 1);
        });
      }
    }

    testWidgets(
      'both activity tabs use compact tracking cards in $brightness',
      (tester) async {
        // Leave room for the existing draft banner's test-font fallback.
        // Compact widths and enlarged text are covered directly above.
        tester.view.physicalSize = const Size(600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ConcernCenterPage(
              initialCenterTab: 1,
              initialActivitySubTab: 0,
              repository: _ActivityRepository(),
              categoryLoader: () async => const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MyActivityCard), findsOneWidget);
        expect(find.text('Repair the streetlight'), findsOneWidget);
        expect(find.text('IN PROGRESS'), findsOneWidget);
        expect(
          tester.getSize(find.byType(MyActivityCard)).height,
          lessThan(90),
        );

        await tester.tap(find.byKey(const ValueKey('activity-tab-complaints')));
        await tester.pumpAndSettle();
        expect(find.byType(MyActivityCard), findsOneWidget);
        expect(find.text('Noise complaint'), findsOneWidget);
        expect(find.text('UNDER REVIEW'), findsOneWidget);
        await tester.ensureVisible(find.text('Track →'));
        await tester.tap(find.text('Track →'));
        await tester.pumpAndSettle();
        expect(find.byType(MyActivityCard), findsNothing);
        expect(find.text('Noise complaint'), findsWidgets);
        expect(tester.takeException(), isNull);

        // Reopen the concern list and verify the same tracking action.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ConcernCenterPage(
              initialCenterTab: 1,
              initialActivitySubTab: 0,
              repository: _ActivityRepository(),
              categoryLoader: () async => const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Track →'));
        await tester.tap(find.text('Track →'));
        await tester.pumpAndSettle();
        expect(find.byType(MyActivityCard), findsNothing);
        expect(find.text('Repair the streetlight'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tracking card supports keyboard and full accessible text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildESugidClayTheme(Brightness.dark),
        home: Scaffold(
          body: MyActivityCard(
            title: 'Long title that must remain available to screen readers',
            category: 'Infrastructure',
            categoryColor: ESugidColors.dark.warning,
            statusLabel: 'In Progress',
            statusColor: ESugidColors.dark.primaryGreen,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'Long title that must remain available to screen readers, '
        'Infrastructure, In Progress. Track activity',
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });
}
