import 'package:esugid/app/theme/esugid_clay_theme.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:esugid/widgets/my_activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubmissionRepository implements SubmissionRepository {
  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value(const []);

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
      uid: 'resident-1',
      email: 'resident@example.com',
      role: UserRole.resident,
      name: 'Resident One',
      barangay: 'Poblacion',
      barangayId: 'barili_poblacion',
      verifiedBarangayId: 'barili_poblacion',
      verificationStatus: VerificationStatus.verified,
    );
  });

  tearDown(() => AuthService.currentUser = null);

  group('MyActivityCard public concern reporter display', () {
    testWidgets(
      'displays original reporter, same concern count, and View Reporters when count > 1',
      (tester) async {
        var viewReportersTapped = false;
        var trackTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: MyActivityCard(
                title: 'Broken streetlamp near basketball court',
                category: 'Infrastructure',
                categoryColor: Colors.amber,
                statusLabel: 'In Progress',
                statusColor: Colors.green,
                originalReporter: 'Maria Santos',
                isPublicBarangay: true,
                reporterCount: 7,
                onViewReporters: () => viewReportersTapped = true,
                onTap: () => trackTapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Originally reported by Maria Santos'), findsOneWidget);
        expect(
          find.text('7 residents reported'),
          findsOneWidget,
        );
        expect(find.text('View Reporters'), findsOneWidget);
        expect(find.text('Track →'), findsOneWidget);

        await tester.tap(find.text('View Reporters'));
        expect(viewReportersTapped, isTrue);

        viewReportersTapped = false;
        await tester.tap(find.text('7 residents reported'));
        expect(viewReportersTapped, isTrue);

        await tester.tap(find.text('Track →'));
        expect(trackTapped, isTrue);
      },
    );

    testWidgets(
      'displays 1 reporter and hides View Reporters when count is 1',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.dark),
            home: Scaffold(
              body: MyActivityCard(
                title: 'Uncollected garbage',
                category: 'Sanitation',
                categoryColor: Colors.blue,
                statusLabel: 'Under Review',
                statusColor: Colors.orange,
                originalReporter: 'Juan dela Cruz',
                isPublicBarangay: true,
                photoUrl: 'https://example.com/juan.jpg',
                reporterCount: 1,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Originally reported by Juan dela Cruz'),
          findsOneWidget,
        );
        expect(find.text('1 reporter'), findsOneWidget);
        expect(find.text('View Reporters'), findsNothing);
        expect(find.text('Track →'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      },
    );

    testWidgets(
      'does not display generic Resident as the person name',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: Scaffold(
              body: MyActivityCard(
                title: 'Way agas',
                category: 'Water Services',
                categoryColor: Colors.blue,
                statusLabel: 'In Progress',
                statusColor: Colors.green,
                originalReporter: 'Resident',
                reporterCount: 1,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Originally reported by Resident'), findsNothing);
        expect(find.text('Resident'), findsNothing);
      },
    );
  });

  group('ConcernCenterPage My Barangay public concern reporters integration', () {
    testWidgets(
      'renders public concern cards with reporter metadata and opens clean bottom sheet',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final publicConcerns = [
          Submission(
            id: 'concern-multi',
            title: 'Flooding in Purok 4 canal',
            description: 'Private description should never leak',
            category: 'Infrastructure',
            type: 'Concern',
            userId: 'maria-uid',
            originalReporterName: 'Maria Santos',
            originalReporterPhotoUrl: 'https://example.com/maria.jpg',
            reporterCount: 3,
            reporters: [
              {'id': 'maria-uid', 'name': 'Maria Santos', 'photoUrl': 'https://example.com/maria.jpg', 'isOriginal': true},
              {'id': 'pedro-uid', 'name': 'Pedro Penduko', 'photoUrl': 'https://example.com/pedro.jpg'},
              {'id': 'ana-uid', 'name': 'Ana Reyes'},
            ],
            date: DateTime(2026, 10, 20),
            status: 'being_handled',
          ),
          Submission(
            id: 'concern-single',
            title: 'Pothole on Main Street',
            description: 'Private pothole detail',
            category: 'Roads',
            type: 'Concern',
            userId: 'juan-uid',
            originalReporterName: 'Juan dela Cruz',
            reporterCount: 1,
            reporters: [
              {'id': 'juan-uid', 'name': 'Juan dela Cruz', 'isOriginal': true},
            ],
            date: DateTime(2026, 10, 21),
            status: 'under_review',
          ),
        ];

        Future<Map<String, dynamic>> mockReportersLoader(
          String concernId,
        ) async {
          if (concernId == 'concern-multi') {
            return {
              'originalReporter': {
                'id': 'maria-uid',
                'name': 'Maria Santos',
                'photoUrl': 'https://example.com/maria.jpg',
                'isOriginal': true,
              },
              'reporters': [
                {'id': 'pedro-uid', 'name': 'Pedro Penduko', 'photoUrl': 'https://example.com/pedro.jpg'},
                {'id': 'ana-uid', 'name': 'Ana Reyes'},
              ],
              'count': 3,
            };
          }
          return {
            'originalReporter': {
              'id': 'juan-uid',
              'name': 'Juan dela Cruz',
              'isOriginal': true,
            },
            'reporters': <Map<String, dynamic>>[],
            'count': 1,
          };
        }

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: ConcernCenterPage(
              initialCenterTab: 2, // My Barangay tab
              repository: _FakeSubmissionRepository(),
              categoryLoader: () async => const [],
              publicConcernsLoader: (barangayId) =>
                  Stream.value(publicConcerns),
              publicConcernReportersLoader: mockReportersLoader,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify multi-reporter card
        expect(find.text('Flooding in Purok 4 canal'), findsOneWidget);
        expect(
          find.text('Originally reported by Maria Santos'),
          findsOneWidget,
        );
        expect(
          find.text('Also reported by Pedro Penduko, Ana Reyes'),
          findsOneWidget,
        );
        expect(
          find.text('3 residents reported'),
          findsOneWidget,
        );
        expect(find.text('View Reporters'), findsOneWidget);

        // 2. Verify single-reporter card
        expect(find.text('Pothole on Main Street'), findsOneWidget);
        expect(
          find.text('Originally reported by Juan dela Cruz'),
          findsOneWidget,
        );
        expect(find.text('1 reporter'), findsOneWidget);

        // 3. Tap "View Reporters" on the multi-reporter card
        await tester.tap(find.text('View Reporters'));
        await tester.pumpAndSettle();

        // 4. Verify bottom sheet modal contents
        expect(find.text('Residents Reporting This Concern'), findsOneWidget);
        expect(find.text('ORIGINAL REPORTER'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Maria Santos'),
          ),
          findsOneWidget,
        );
        expect(find.text('Original reporter'), findsWidgets);

        expect(find.text('Residents with the same concern'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(find.text('Pedro Penduko'), findsWidgets);
        expect(find.text('Ana Reyes'), findsWidgets);
        expect(find.text('Same concern'), findsWidgets);

        // 5. Verify NO private details leaked
        expect(find.text('Private description should never leak'), findsNothing);
        expect(find.text('maria-uid'), findsNothing);
        expect(find.text('pedro-uid'), findsNothing);
        expect(find.text('resident@example.com'), findsNothing);

        // 6. Close bottom sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Residents Reporting This Concern'), findsNothing);
      },
    );

    testWidgets(
      'bottom sheet falls back safely to concern reporters data if remote loader fails',
      (tester) async {
        final concern = Submission(
          id: 'fallback-concern',
          title: 'Damaged water pipe',
          description: 'Pipe leaking along roadside',
          category: 'Utilities',
          type: 'Concern',
          userId: 'user-orig',
          originalReporterName: 'Aling Nena',
          originalReporterPhotoUrl: 'https://example.com/nena.jpg',
          reporterCount: 2,
          reporters: [
            {'id': 'user-orig', 'name': 'Aling Nena', 'isOriginal': true},
            {'id': 'user-joined', 'name': 'Mang Jose'},
          ],
          date: DateTime(2026, 10, 25),
          status: 'under_review',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.dark),
            home: ConcernCenterPage(
              initialCenterTab: 2,
              repository: _FakeSubmissionRepository(),
              categoryLoader: () async => const [],
              publicConcernsLoader: (barangayId) => Stream.value([concern]),
              publicConcernReportersLoader: (id) async {
                throw Exception('Simulated network failure');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Damaged water pipe'), findsOneWidget);
        expect(find.text('Originally reported by Aling Nena'), findsOneWidget);
        expect(find.text('2 residents reported'), findsOneWidget);
        expect(find.text('View Reporters'), findsOneWidget);

        await tester.tap(find.text('View Reporters'));
        await tester.pumpAndSettle();

        expect(find.text('Residents Reporting This Concern'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Aling Nena'),
          ),
          findsOneWidget,
        );
        expect(find.text('Mang Jose'), findsWidgets);
        expect(find.text('Residents with the same concern'), findsOneWidget);
      },
    );

    testWidgets(
      'does not invent residents for a concern title with no joined reporters',
      (tester) async {
        final concern = Submission(
          id: 'real-water-concern',
          title: 'Way agas',
          description: 'No water since morning',
          category: 'Water Services',
          type: 'Concern',
          userId: 'actual-reporter',
          originalReporterName: 'Actual Reporter',
          reporterCount: 2,
          date: DateTime.now(),
          status: 'new',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: ConcernCenterPage(
              initialCenterTab: 2,
              repository: _FakeSubmissionRepository(),
              categoryLoader: () async => const [],
              publicConcernsLoader: (_) => Stream.value([concern]),
              publicConcernReportersLoader: (_) async => {
                'originalReporter': {
                  'id': 'actual-reporter',
                  'name': 'Actual Reporter',
                  'isOriginal': true,
                },
                'reporters': <Map<String, dynamic>>[],
                'count': 2,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.people_alt_rounded));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Actual Reporter'),
          ),
          findsOneWidget,
        );
        expect(find.text('Carlo Mendoza'), findsNothing);
        expect(
          find.text('No other residents have linked to this report yet.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ConcernDetailPage tapping reporter count chip opens Residents Reporting This Concern bottom sheet',
      (tester) async {
        final concern = Submission(
          id: 'detail-concern',
          title: 'Water pipe leak in Purok 2',
          description: 'Water leak along the main highway',
          category: 'Water Services',
          type: 'Concern',
          userId: 'ana-uid',
          originalReporterName: 'Ana Jean Atamosa Binggaan',
          originalReporterPhotoUrl: 'https://example.com/ana.jpg',
          reporterCount: 2,
          reporters: [
            {'id': 'ana-uid', 'name': 'Ana Jean Atamosa Binggaan', 'photoUrl': 'https://example.com/ana.jpg', 'isOriginal': true},
            {'id': 'juan-uid', 'name': 'Juan Dela Cruz', 'photoUrl': 'https://example.com/juan.jpg'},
          ],
          date: DateTime(2026, 9, 30, 18, 34),
          status: 'resolved',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: ConcernDetailPage(
              concern: concern,
              repository: _FakeSubmissionRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Concern Details page displays reporter count chip
        await tester.ensureVisible(find.text('Report updates'));
        await tester.tap(find.text('Report updates'));
        await tester.pumpAndSettle();
        final countChipFinder = find.text('2 residents reported');
        expect(countChipFinder, findsOneWidget);

        // Tap the reporter count chip
        await tester.ensureVisible(countChipFinder);
        await tester.tap(countChipFinder);
        await tester.pumpAndSettle();

        // Verify bottom sheet opened
        expect(find.text('Residents Reporting This Concern'), findsOneWidget);
        expect(find.text('ORIGINAL REPORTER'), findsOneWidget);
        expect(find.text('Ana Jean Atamosa Binggaan'), findsWidgets);
        expect(find.text('Original reporter'), findsWidgets);
        expect(find.text('Residents with the same concern'), findsOneWidget);
        expect(find.text('Juan Dela Cruz'), findsOneWidget);
        expect(find.text('Same concern'), findsOneWidget);
      },
    );

    testWidgets(
      'matches exact UI mockup with relative time, chips, and modal layout',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockConcern = Submission(
          id: 'agas-wael-1',
          title: 'Agas wael',
          description: 'Water leak issue in the barangay',
          category: 'Water Services',
          type: 'Concern',
          userId: 'marie-uid',
          originalReporterName: 'Marie Santos',
          originalReporterPhotoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
          reporterCount: 4,
          reporters: [
            {
              'id': 'marie-uid',
              'name': 'Marie Santos',
              'photoUrl': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
              'timeAgo': '2 days ago',
              'isOriginal': true,
            },
            {
              'id': 'juan-uid',
              'name': 'Juan Dela Cruz',
              'photoUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
              'timeAgo': '3 days ago',
              'isOriginal': false,
            },
            {
              'id': 'ana-uid',
              'name': 'Ana Marie Lopez',
              'photoUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80',
              'timeAgo': '1 day ago',
              'isOriginal': false,
            },
            {
              'id': 'carlo-uid',
              'name': 'Carlo Mendoza',
              'photoUrl': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=150&q=80',
              'timeAgo': '4 days ago',
              'isOriginal': false,
            },
          ],
          date: DateTime.now().subtract(const Duration(days: 2)),
          status: 'new',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildESugidClayTheme(Brightness.light),
            home: ConcernCenterPage(
              initialCenterTab: 2, // My Barangay tab
              repository: _FakeSubmissionRepository(),
              categoryLoader: () async => const [],
              publicConcernsLoader: (barangayId) =>
                  Stream.value([mockConcern]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify card UI elements matching mockup
        expect(find.text('Marie Santos'), findsOneWidget);
        expect(find.text('2 days ago'), findsOneWidget);
        expect(find.text('Agas wael'), findsOneWidget);
        expect(find.text('4 residents reported'), findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);
        expect(find.text('Track →'), findsOneWidget);
        expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

        // 2. Tap the "4 residents reported" chip
        await tester.tap(find.text('4 residents reported'));
        await tester.pumpAndSettle();

        // 3. Verify bottom sheet modal matching mockup
        expect(find.text('Residents Reporting This Concern'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Original reporter card
        expect(find.text('Original Reporter'), findsOneWidget);

        // Other residents section heading and items
        expect(
          find.text('Other Residents with the Same Concern'),
          findsOneWidget,
        );
        expect(find.text('Juan Dela Cruz'), findsOneWidget);
        expect(find.text('Ana Marie Lopez'), findsOneWidget);
        expect(find.text('Carlo Mendoza'), findsOneWidget);
        expect(find.text('Same Concern'), findsWidgets);
      },
    );
  });
}
