import 'package:esugid/auth_service.dart';
import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/services/concern_draft_store.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SubmissionRepository implements SubmissionRepository {
  final attempts = <Submission>[];

  @override
  Future<Submission> addSubmission(Submission submission) async {
    attempts.add(submission);
    return submission;
  }

  @override
  Future<Submission> resubmitConcern(Submission submission) async {
    attempts.add(submission);
    return submission;
  }

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async {}

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      const Stream.empty();
}

void main() {
  Future<List<Map<String, String>>> loadCategories() async => [
    {
      'id': 'drainage',
      'name': 'Drainage',
      'example': 'Clogged canals, flooding',
      'sector': 'public',
    },
    {
      'id': 'private_school_education',
      'name': 'School & Education',
      'sector': 'private',
    },
  ];
  Future<List<Map<String, String>>> loadOrganizations(
    String categoryId,
    String sector,
  ) async => sector == 'private'
      ? [
          {'id': 'sta-ana-academy', 'name': 'Sta. Ana Academy'},
        ]
      : [
          {'id': 'drainage-office', 'name': 'Drainage Office'},
        ];
  Future<List<Map<String, dynamic>>> noSimilar(Submission _) async => [];

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'cris',
      email: 'cris@example.com',
      role: UserRole.resident,
      name: 'Cris',
      barangay: 'Cabcaban',
      barangayId: 'cabcaban',
      accountStatus: AccountStatus.active,
      verificationStatus: VerificationStatus.verified,
    );
  });

  tearDown(() => AuthService.currentUser = null);

  Future<void> fillRequiredDetails(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drainage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drainage Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Blocked drainage');
    await tester.enterText(
      find.byType(TextField).at(1),
      'The roadside drainage is blocked after heavy rain.',
    );
    await tester.enterText(
      find.byType(TextField).at(2),
      'Near Cabcaban Elementary School',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public Report'));
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Review Concern'));
    await tester.tap(find.text('Review Concern'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmAndSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Submit Concern'));
    await tester.tap(find.text('Submit Concern'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'concern validation reveals the description and clears after correction in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _SubmissionRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(brightness),
            home: ConcernCenterPage(
              formOnly: true,
              repository: repository,
              categoryLoader: loadCategories,
              organizationLoader: loadOrganizations,
              similarConcernChecker: noSimilar,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await fillRequiredDetails(tester);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await tester.pumpAndSettle();
        final description = find.byWidgetPredicate(
          (widget) => widget is TextField && widget.maxLines == 4,
        );
        await tester.enterText(description, 'short');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        final notice = find.byKey(const ValueKey('concern-validation-notice'));
        expect(notice.hitTestable(), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(notice.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextField>(description).decoration!.errorText,
          contains('at least 10 characters'),
        );
        expect(
          tester.widget<TextField>(description).focusNode!.hasFocus,
          isTrue,
        );
        expect(repository.attempts, isEmpty);
        await tester.enterText(
          description,
          'The roadside drainage is blocked after heavy rain.',
        );
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        expect(
          tester.widget<TextField>(description).decoration!.errorText,
          isNull,
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Review Concern'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'resident concern details and review fit ${width.toInt()}px with an organization picker',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: ConcernCenterPage(
              formOnly: true,
              categoryLoader: loadCategories,
              organizationLoader: loadOrganizations,
              similarConcernChecker: noSimilar,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Step 1 of 4'), findsOneWidget);
        expect(find.text('Barangay'), findsOneWidget);
        expect(find.text('LGU Department'), findsOneWidget);
        expect(find.text('Organization'), findsOneWidget);
        expect(find.text('Review'), findsNothing);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Where should we send your concern?'), findsNothing);
        expect(find.text('Municipal Office'), findsNothing);
        expect(find.text('Partner Organization'), findsNothing);
        expect(tester.takeException(), isNull);

        await fillRequiredDetails(tester);
        await openReview(tester);
        expect(find.textContaining('Step 4 of 4'), findsOneWidget);
        expect(find.text('Receiving Office'), findsWidgets);
        expect(find.text('Public in Cabcaban'), findsWidgets);
        expect(find.text('Drainage Office'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('explicit Save draft preserves the unfinished concern', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: noSimilar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    final store = ConcernDraftStore(
      await SharedPreferences.getInstance(),
      'cris',
    );
    expect(store.list(), hasLength(1));
    expect(store.list().single['recipientType'], 'organization');
    expect(store.list().single['organizationSector'], 'public');
    expect(store.list().single.containsKey('submissionReference'), isFalse);
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets(
    'concern type alone cannot continue without an active organization',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConcernCenterPage(
            formOnly: true,
            categoryLoader: loadCategories,
            organizationLoader: (_, _) async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organization').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Public Agency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Public Agency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drainage').last);
      await tester.pumpAndSettle();
      expect(find.text('No Organization Available'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Select an active organization before continuing.'),
        findsOneWidget,
      );
      expect(find.textContaining('Step 2 of 4'), findsOneWidget);
    },
  );

  testWidgets('switching organization sectors clears the previous recipient', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organization').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Private Organization').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Private Organization').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Drainage'), findsNothing);
    await tester.tap(find.text('School & Education').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sta. Ana Academy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Sta. Ana Academy'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Public Agency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('School & Education'), findsNothing);
    expect(find.text('Sta. Ana Academy'), findsNothing);
    expect(find.text('Select concern type'), findsOneWidget);
  });

  testWidgets('leaving unsaved details does not create a draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: noSimilar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barangay').last);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    final store = ConcernDraftStore(
      await SharedPreferences.getInstance(),
      'cris',
    );
    expect(store.list(), isEmpty);
  });

  testWidgets(
    'submitted concern uses the resident barangay without a selector',
    (tester) async {
      final repository = _SubmissionRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ConcernCenterPage(
            formOnly: true,
            repository: repository,
            categoryLoader: loadCategories,
            organizationLoader: loadOrganizations,
            similarConcernChecker: noSimilar,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillRequiredDetails(tester);
      await openReview(tester);
      await confirmAndSubmit(tester);

      expect(repository.attempts, hasLength(1));
      final submission = repository.attempts.single;
      expect(submission.barangay, 'Cabcaban');
      expect(submission.barangayId, 'barili_cabcaban');
      expect(submission.categoryId, 'drainage');
      expect(submission.visibility, 'public');
      expect(submission.department, 'Drainage Office');
      expect(submission.recipientType, 'organization');
      expect(submission.recipientId, 'drainage-office');
      expect(find.text('Concern Submitted Successfully'), findsOneWidget);
    },
  );

  testWidgets('a possible match joins only after the resident chooses it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _SubmissionRepository();
    Submission? checkedConcern;
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          repository: repository,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (concern) async {
            checkedConcern = concern;
            return [
              {
                'id': 'CON-2026-000001',
                'title': 'Blocked drainage',
                'category': 'Drainage',
                'date': '2026-09-27',
                'dateLabel': 'Incident date',
                'description': 'The canal near the school is blocked.',
                'location': 'Near Cabcaban Elementary School',
                'department': 'Barangay Cabcaban',
                'status': 'being_handled',
                'reporterCount': 3,
              },
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    expect(tester.takeException(), isNull);
    await openReview(tester);

    expect(checkedConcern?.categoryId, 'drainage');
    expect(checkedConcern?.location, 'Near Cabcaban Elementary School');
    expect(find.text('Similar Concern Found'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Incident date: September 27, 2026'), findsOneWidget);
    expect(find.text('The canal near the school is blocked.'), findsOneWidget);
    expect(find.text('Receiving office: Barangay Cabcaban'), findsOneWidget);
    expect(find.text('3 residents reported this'), findsOneWidget);
    expect(find.text('This Is Different'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('I Have the Same Concern'));
    await tester.pumpAndSettle();
    expect(repository.attempts, hasLength(1));
    expect(repository.attempts.single.joinConcernId, 'CON-2026-000001');
    expect(repository.attempts.single.department, 'Barangay Cabcaban');
    expect(find.text('Report Added to Existing Concern'), findsOneWidget);
  });

  testWidgets('Different Concern continues with a new report', (tester) async {
    final repository = _SubmissionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          repository: repository,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (_) async => [
            {'id': 'CON-2026-000001', 'title': 'Blocked drainage'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    await openReview(tester);
    await tester.tap(find.text('This Is Different'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Step 4 of 4'), findsOneWidget);
    expect(find.textContaining('Join CON-'), findsNothing);
    await confirmAndSubmit(tester);
    expect(repository.attempts.single.joinConcernId, isNull);
  });

  testWidgets('Different Concern shows the next same-day candidate', (
    tester,
  ) async {
    final repository = _SubmissionRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          repository: repository,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (_) async => [
            {'id': 'CON-2026-000001', 'title': 'Drainage near the market'},
            {'id': 'CON-2026-000002', 'title': 'Drainage near the school'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    await openReview(tester);
    expect(find.text('Possible concern 1 of 2'), findsOneWidget);
    await tester.tap(find.text('This Is Different'));
    await tester.pumpAndSettle();
    expect(find.text('Possible concern 2 of 2'), findsOneWidget);
    expect(find.text('Drainage near the school'), findsOneWidget);
    await tester.tap(find.text('I Have the Same Concern'));
    await tester.pumpAndSettle();
    expect(repository.attempts, hasLength(1));
    expect(repository.attempts.single.joinConcernId, 'CON-2026-000002');
    expect(find.text('Report Added to Existing Concern'), findsOneWidget);
  });

  testWidgets('failed similarity check allows review, submission, and retry', (
    tester,
  ) async {
    final repository = _SubmissionRepository();
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          repository: repository,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (_) async {
            checks++;
            throw StateError('Similarity service unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    await openReview(tester);

    expect(find.textContaining('Step 4 of 4'), findsOneWidget);
    expect(
      find.text(
        'Similar concerns could not be checked. You can still submit a new concern.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    await confirmAndSubmit(tester);
    expect(repository.attempts.single.joinConcernId, isNull);
  });

  testWidgets('retry can find a match after an initial check failure', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (_) async {
            if (checks++ == 0) throw StateError('Temporary outage');
            return [
              {'id': 'CON-2026-000002', 'title': 'Blocked drainage'},
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    await openReview(tester);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Similar Concern Found'), findsOneWidget);
    await tester.tap(find.text('I Have the Same Concern'));
    await tester.pumpAndSettle();
    expect(find.text('Join CON-2026-000002'), findsOneWidget);
    expect(find.textContaining('could not be checked'), findsNothing);
  });

  testWidgets('private concerns skip the public similarity check', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: (_) async {
            checks++;
            return [];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fillRequiredDetails(tester);
    await tester.tap(find.text('Private Report'));
    await tester.pumpAndSettle();
    await openReview(tester);
    expect(find.textContaining('Step 4 of 4'), findsOneWidget);
    expect(checks, 0);
  });

  testWidgets('saved draft keeps selections and asks for fresh review', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: noSimilar,
          draft: const {
            'version': 8,
            'id': 'saved-review',
            'createdAt': '2026-09-07T08:00:00Z',
            'updatedAt': '2026-09-07T08:00:00Z',
            'formStep': 2,
            'title': 'Road drainage issue',
            'description': 'The roadside drainage remains blocked.',
            'location': 'Purok 2',
            'category': 'Drainage',
            'categoryId': 'drainage',
            'organizationSector': 'public',
            'handlerType': 'organization',
            'orgBranch': 'public',
            'recipientId': 'drainage-office',
            'recipient': 'Drainage Office',
            'visibility': 'private',
            'barangay': 'Vito',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 4'), findsOneWidget);
    expect(find.text('Organization'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Drainage'), findsWidgets);
    expect(find.text('Drainage Office'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unverified resident remains blocked from submission', (
    tester,
  ) async {
    AuthService.currentUser = User(
      uid: 'unverified-cris',
      email: 'unverified@example.com',
      role: UserRole.resident,
      name: 'Unverified Cris',
      barangay: 'Cabcaban',
      verificationStatus: VerificationStatus.notVerified,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernCenterPage(
          formOnly: true,
          categoryLoader: loadCategories,
          organizationLoader: loadOrganizations,
          similarConcernChecker: noSimilar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resident verification required'), findsOneWidget);
    expect(find.text('Verify Residency'), findsOneWidget);
    expect(find.text('Receiving Office'), findsNothing);
  });
}
