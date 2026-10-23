import 'package:esugid/auth_service.dart';
import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/features/app_assistant/app_assistant_dock.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/services/concern_draft_store.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSubmissionRepository implements SubmissionRepository {
  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) => Stream.value([
    Submission(
      id: 'con-1',
      title: 'Streetlight Repair',
      description: 'Dark alley near chapel',
      category: 'Infrastructure',
      type: 'Complaint',
      userId: 'cris',
      date: DateTime(2026, 9, 8),
      department: 'Public Works',
      status: 'Under Review',
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ]);

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
  Future<List<Map<String, String>>> loadCategories() async => [
    {
      'id': 'drainage_flooding',
      'name': 'Drainage and Flooding',
      'example': 'Clogged canals',
    },
  ];
  late _MockSubmissionRepository repository;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    repository = _MockSubmissionRepository();
    AuthService.currentUser = User(
      uid: 'cris',
      email: 'cris@example.com',
      role: UserRole.resident,
      name: 'Cris',
      barangay: 'Cabcaban',
      verificationStatus: VerificationStatus.verified,
    );
  });
  tearDown(() => AuthService.currentUser = null);

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 480), const Size(390, 844)]) {
      testWidgets(
        'concern flow clears assistant and keeps validation visible: $brightness $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildESugidClayTheme(brightness),
              home: Scaffold(
                body: AppAssistantDock(
                  bottomInset: 94,
                  launcher: const Icon(Icons.auto_awesome_rounded),
                  child: ConcernCenterPage(
                    repository: repository,
                    categoryLoader: loadCategories,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('assistant-drag-target')), findsOneWidget);
          await tester.ensureVisible(find.text('Start Filing Concern'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Start Filing Concern'));
          await tester.pumpAndSettle();
          expect(find.text('Step 1 of 4'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final notice = find.byKey(const ValueKey('concern-validation-notice'));
          for (var step = 0; step < 4 && notice.evaluate().isEmpty; step++) {
            await tester.tap(find.text('Continue'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(notice, findsOneWidget);
          expect(find.byKey(const ValueKey('assistant-drag-target')), findsNothing);
          expect(tester.getRect(notice).bottom, lessThanOrEqualTo(size.height));
        },
      );
    }
  }

  testWidgets('ConcernCenterPage displays the minimal file.png onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcernCenterPage(
            repository: repository,
            categoryLoader: loadCategories,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tab Segmented Control
    expect(find.text('File a Concern'), findsWidgets);
    expect(find.textContaining('My Concerns'), findsWidgets);

    // Verify Hero Explanatory Texts and the two ways to file
    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Start Filing Concern'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-complaint')), findsOneWidget);
    expect(find.text('File a Complaint'), findsOneWidget);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/resident_dashboard/file.png' &&
            widget.fit == BoxFit.contain,
      ),
      findsOneWidget,
    );
    expect(find.text('Report community issues'), findsNothing);
    expect(find.text('Help improve your barangay'), findsNothing);
    expect(find.text('Track the status easily'), findsNothing);
    expect(find.text('Unfinished Drafts'), findsNothing);

    // Verify Primary Action Button
    expect(find.text('Start Filing Concern'), findsOneWidget);

    // Open the guided form.
    await tester.ensureVisible(find.text('Start Filing Concern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Filing Concern'));
    await tester.pumpAndSettle();

    expect(find.text('WHO SHOULD HANDLE THIS CONCERN?'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  testWidgets(
    'ConcernCenterPage segmented control switches between File a Concern and My Concerns',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcernCenterPage(
              repository: repository,
              categoryLoader: loadCategories,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'My Concerns' tab
      await tester.tap(find.textContaining('My Concerns').first);
      await tester.pumpAndSettle();

      // Verify My Concerns view elements
      expect(
        find.text('Track status and responses from municipal offices.'),
        findsOneWidget,
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Streetlight Repair'), findsOneWidget);
      expect(find.text('Unfinished Drafts'), findsOneWidget);
      expect(
        find.text('No unfinished drafts saved on device.'),
        findsOneWidget,
      );

      // Tap 'File a Concern' tab to return
      await tester.tap(find.text('File a Concern').first);
      await tester.pumpAndSettle();

      expect(find.text('Start Filing Concern'), findsOneWidget);
      expect(find.text('Unfinished Drafts'), findsNothing);
    },
  );

  testWidgets('My Concerns shows only intentionally saved drafts', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final store = ConcernDraftStore(preferences, 'cris');
    await store.save({
      'version': 7,
      'id': 'manual-draft',
      'manuallySaved': true,
      'createdAt': '2026-09-08T08:00:00.000',
      'updatedAt': '2026-09-08T09:00:00.000',
      'formStep': 0,
      'title': 'Manually saved concern',
      'description': 'Saved description',
      'location': 'Cabcaban',
      'category': 'Road Repair',
      'recipient': 'My Barangay Office',
    });
    await store.save({
      'id': 'old-auto-draft',
      'createdAt': '2026-09-08T08:00:00.000',
      'updatedAt': '2026-09-08T10:00:00.000',
      'formStep': 1,
      'title': 'Automatically created concern',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          repository: repository,
          categoryLoader: loadCategories,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('My Concerns').first);
    await tester.pumpAndSettle();

    expect(find.text('UNFINISHED DRAFT'), findsOneWidget);
    await tester.tap(find.text('UNFINISHED DRAFT'));
    await tester.pumpAndSettle();
    expect(find.text('Manually saved concern'), findsWidgets);
    expect(find.text('Automatically created concern'), findsNothing);
    expect(find.text('Resume Editing'), findsOneWidget);
    expect(find.byTooltip('Delete Draft'), findsOneWidget);

    await tester.tap(find.text('Resume Editing'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete Draft removes it immediately from Unfinished Drafts', (
    tester,
  ) async {
    final store = ConcernDraftStore(
      await SharedPreferences.getInstance(),
      'cris',
    );
    await store.save({
      'id': 'delete-me',
      'manuallySaved': true,
      'createdAt': '2026-09-08T08:00:00.000',
      'updatedAt': '2026-09-08T09:00:00.000',
      'formStep': 0,
      'title': 'Delete me',
      'recipient': 'My Barangay Office',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          repository: repository,
          categoryLoader: loadCategories,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('My Concerns').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('UNFINISHED DRAFT'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Draft'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this draft?'), findsOneWidget);
    expect(
      find.text('This unfinished concern will be permanently removed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No Saved Drafts Yet'), findsOneWidget);
    expect(store.list(), isEmpty);
  });

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'ConcernCenterPage fits without overflow on ${width.toInt()}px width',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConcernCenterPage(
                repository: repository,
                categoryLoader: loadCategories,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
