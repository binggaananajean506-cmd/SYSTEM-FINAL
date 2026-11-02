import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/features/explore/data/barili_place_search_service.dart';
import 'package:esugid/features/complaints/complaint_history_sheet.dart';
import 'package:esugid/features/explore/domain/explore_place.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/pages/explore_barili_page.dart';
import 'package:esugid/pages/officials_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/community_post_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubmissionRepo implements SubmissionRepository {
  _FakeSubmissionRepo(this.submissions);
  final List<Submission> submissions;

  @override
  Future<Submission> addSubmission(Submission s) async => s;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value(submissions);

  @override
  Future<Submission> resubmitConcern(Submission s) async => s;

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async {}
}

class _DummyPlaceProvider implements BariliPlaceProvider {
  @override
  Future<List<ExplorePlaceSuggestion>> search(String query) async => const [];

  @override
  Future<ExplorePlace> loadPlace(ExplorePlaceSuggestion suggestion) async =>
      ExplorePlace(
        id: suggestion.providerId,
        name: suggestion.name,
        category: suggestion.category,
        formattedAddress: suggestion.formattedAddress,
        summary: suggestion.formattedAddress,
        description: 'Test description',
        position: suggestion.position,
        photos: const [],
        sourceLabel: 'OpenStreetMap',
        sourceUrl: suggestion.sourceUrl,
      );

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'user-cris',
      email: 'cris@example.com',
      role: UserRole.resident,
      name: 'Cris Marco',
      barangay: 'Vito',
    );
  });

  group('Back Navigation Tests', () {
    testWidgets(
      'Report -> My Barangay -> Concern Card -> Details -> Back returns to My Barangay',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final publicConcerns = [
          Submission(
            id: 'brgy-con-1',
            title: 'Water Pipe Leak in Purok 2',
            description: 'Major leak on the main street',
            category: 'Water Services',
            type: 'Concern',
            userId: 'resident-juan',
            barangay: 'Vito',
            originalReporterName: 'Juan dela Cruz',
            reporterCount: 2,
            reporters: [
              {'id': 'resident-juan', 'name': 'Juan dela Cruz', 'isOriginal': true},
              {'id': 'user-cris', 'name': 'Cris Marco'},
            ],
            date: DateTime(2026, 10, 20),
            status: 'being_handled',
            handlingNote: 'Maintenance crew dispatched.',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: ConcernCenterPage(
                initialCenterTab: 2, // My Barangay tab
                repository: _FakeSubmissionRepo(publicConcerns),
                categoryLoader: () async => const [],
                publicConcernsLoader: (barangayId) => Stream.value(publicConcerns),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify we are on My Barangay tab
        expect(find.text('Water Pipe Leak in Purok 2'), findsOneWidget);
        expect(find.textContaining('Public reports in Barangay Vito'), findsOneWidget);

        // Tap the concern card to open details bottom sheet
        await tester.tap(find.text('Water Pipe Leak in Purok 2'));
        await tester.pumpAndSettle();

        // Tap 'View Progress & Details' button inside bottom sheet
        expect(find.text('View Progress & Details'), findsOneWidget);
        await tester.tap(find.text('View Progress & Details'));
        await tester.pumpAndSettle();

        // Verify ConcernDetailPage is pushed on Navigator
        expect(find.byType(ConcernDetailPage), findsOneWidget);
        expect(find.text('Back to Center'), findsOneWidget);

        // Perform back navigation via in-app Back button
        await tester.tap(find.text('Back to Center'));
        await tester.pumpAndSettle();

        // Verify we returned directly to My Barangay tab, NOT a black screen, NOT another tab!
        expect(find.byType(ConcernDetailPage), findsNothing);
        expect(find.text('Water Pipe Leak in Purok 2'), findsOneWidget);
        expect(find.textContaining('Public reports in Barangay Vito'), findsOneWidget);
      },
    );

    testWidgets(
      'Report -> My Activity -> Concern Details -> Back returns to My Activity',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final userConcerns = [
          Submission(
            id: 'my-con-1',
            title: 'Broken Streetlamp',
            description: 'Dark corner at Purok 1',
            category: 'Electricity',
            type: 'Concern',
            userId: 'user-cris',
            barangay: 'Vito',
            date: DateTime(2026, 10, 15),
            status: 'being_handled',
            handlingNote: 'Electrician scheduled.',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: ConcernCenterPage(
                initialCenterTab: 1, // My Activity tab
                repository: _FakeSubmissionRepo(userConcerns),
                categoryLoader: () async => const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the concern card and tap it
        expect(find.text('Broken Streetlamp'), findsOneWidget);
        await tester.tap(find.text('Broken Streetlamp'));
        await tester.pumpAndSettle();

        // Verify ConcernDetailPage is pushed on stack
        expect(find.byType(ConcernDetailPage), findsOneWidget);

        // Simulate Android system back gesture / pop
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        // Verify returned to My Activity tab without black screen
        expect(find.byType(ConcernDetailPage), findsNothing);
        expect(find.text('Broken Streetlamp'), findsOneWidget);
      },
    );

    testWidgets(
      'Complaint Details -> Back returns to Complaint Activity list',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final userComplaints = [
          Submission(
            id: 'BC-2026-001',
            title: 'Boundary dispute with neighbor',
            description: 'Fence encroaches property line',
            category: 'Boundary',
            type: 'Complaint',
            userId: 'user-cris',
            barangay: 'Vito',
            date: DateTime(2026, 10, 10),
            status: 'being_handled',
            handlingNote: 'Mediation hearing scheduled.',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: ConcernCenterPage(
                initialCenterTab: 1, // My Activity tab
                initialActivitySubTab: 1, // Complaints sub-tab
                repository: _FakeSubmissionRepo(userComplaints),
                categoryLoader: () async => const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Boundary dispute with neighbor'), findsOneWidget);
        await tester.tap(find.text('Boundary dispute with neighbor'));
        await tester.pumpAndSettle();

        // Detail page opened
        expect(find.byType(ConcernDetailPage), findsOneWidget);

        // Tap in-app Back button
        await tester.tap(find.text('Back to Center'));
        await tester.pumpAndSettle();

        // Returned safely to complaints list
        expect(find.byType(ConcernDetailPage), findsNothing);
        expect(find.text('Boundary dispute with neighbor'), findsOneWidget);
      },
    );

    testWidgets(
      'Announcement Details -> Back returns to Announcement feed',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Clear current user so SavedAnnouncementButton doesn't trigger remote Firestore call in unit test
        AuthService.currentUser = null;

        final post = CommunityPost(
          id: 'ann-1',
          title: 'Typhoon Advisory Warning',
          content: 'Signal No. 1 raised in Cebu. Please take necessary precautions.',
          authorName: 'Barangay Vito Disaster Team',
          authorId: 'vito-captain',
          authorRole: 'barangay_captain',
          authorBarangay: 'Vito',
          authorOrganizationName: 'Barangay Vito',
          targetAudience: 'All Residents',
          targetBarangay: 'All Barangays',
          targetBarangays: const [],
          visibility: 'public',
          tag: 'OFFICIAL',
          status: 'published',
          createdAt: DateTime(2026, 10, 25),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => ModernPostCard.openPostDetails(ctx, post, 'hero-ann-1'),
                    child: const Text('Open Announcement'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Announcement'));
        await tester.pumpAndSettle();

        expect(find.byType(PostDetailsPage), findsOneWidget);
        expect(find.text('Typhoon Advisory Warning'), findsOneWidget);

        // Pop via Navigator (simulating Android system back)
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        expect(find.byType(PostDetailsPage), findsNothing);
        expect(find.text('Open Announcement'), findsOneWidget);
      },
    );

    testWidgets(
      'Service detail pages (OfficialsPage, ExploreBariliPage) -> Back returns smoothly',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          ctx,
                          MaterialPageRoute<void>(builder: (_) => const OfficialsPage()),
                        ),
                        child: const Text('Open Officials'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          ctx,
                          MaterialPageRoute<void>(
                            builder: (_) => ExploreBariliPage(
                              placeProvider: _DummyPlaceProvider(),
                            ),
                          ),
                        ),
                        child: const Text('Open Explore'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open Officials
        await tester.tap(find.text('Open Officials'));
        await tester.pumpAndSettle();
        expect(find.byType(OfficialsPage), findsOneWidget);

        // System back
        var navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(OfficialsPage), findsNothing);
        expect(find.text('Open Officials'), findsOneWidget);

        // 2. Open Explore
        await tester.tap(find.text('Open Explore'));
        await tester.pumpAndSettle();
        expect(find.byType(ExploreBariliPage), findsOneWidget);

        // System back
        navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(ExploreBariliPage), findsNothing);
        expect(find.text('Open Explore'), findsOneWidget);
      },
    );

    testWidgets(
      'ConcernCenterPage in-page back button returns from My Barangay to tab 0',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: ConcernCenterPage(
                initialCenterTab: 2, // My Barangay
                repository: _FakeSubmissionRepo([]),
                categoryLoader: () async => const [],
                publicConcernsLoader: (_) => Stream.value([]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header back button on My Barangay
        expect(find.textContaining('Public reports in Barangay Vito'), findsOneWidget);
        final backButton = find.byIcon(Icons.arrow_back_rounded);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Transitioned safely to tab 0 without black screen
        expect(find.text('How can we help?'), findsOneWidget);
      },
    );

    testWidgets('complaint details show history only when requested',
        (tester) async {
      final complaint = Submission(
        id: 'BC-2026-TRACK',
        title: 'Boundary dispute',
        description: 'Fence overlaps the property line.',
        category: 'Barangay Complaint',
        type: 'Complaint',
        userId: 'user-cris',
        barangay: 'Vito',
        date: DateTime(2026, 10, 10),
        status: 'being_handled',
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildESugidClayTheme(Brightness.light),
        home: ConcernDetailPage(
          concern: complaint,
          repository: _FakeSubmissionRepo([complaint]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Current status'), findsOneWidget);
      expect(find.text('Case details'), findsOneWidget);
      expect(find.text('View full history'), findsNothing);

      await tester.ensureVisible(find.text('Case details'));
      await tester.tap(find.text('Case details'));
      await tester.pumpAndSettle();
      expect(find.text('View full history'), findsOneWidget);
      await tester.ensureVisible(find.text('View full history'));
      await tester.tap(find.text('View full history'));
      await tester.pumpAndSettle();
      expect(find.byType(ComplaintHistorySheet), findsOneWidget);
    });
  });
}
