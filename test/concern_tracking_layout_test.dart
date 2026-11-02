import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingRepository implements SubmissionRepository {
  const _TrackingRepository(this.concern);

  final Submission concern;

  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value([concern]);

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

Submission _concern(String status) => Submission(
  id: 'CON-2026-746040',
  title: 'Agas wael',
  description: 'Way agas sabado pa last week',
  category: 'Water Services',
  type: 'Concern',
  userId: 'resident-1',
  residentName: 'Maria Santos',
  barangay: 'Vito',
  location: 'Atbang Chuchu Diri Kauners',
  date: DateTime(2026, 10, 17, 20, 23),
  status: status,
  statusHistory: const [],
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'resident-1',
      email: 'maria@example.com',
      role: UserRole.resident,
      name: 'Maria Santos',
      barangay: 'Vito',
    );
  });
  tearDown(() => AuthService.currentUser = null);

  testWidgets(
    'submitted concern shows the reference layout and pending steps',
    (tester) async {
      final concern = _concern('new');
      await tester.pumpWidget(
        MaterialApp(
          home: ConcernDetailPage(
            concern: concern,
            repository: _TrackingRepository(concern),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track Your Concern'), findsOneWidget);
      expect(find.text('See the status of your report.'), findsOneWidget);
      expect(find.text('Water Services'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Agas wael'), findsOneWidget);
      expect(find.text('Status Timeline'), findsOneWidget);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Action in progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Report updates'), findsOneWidget);
      expect(find.text('PENDING'), findsNWidgets(3));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Report updates'));
      await tester.tap(find.text('Report updates'));
      await tester.pumpAndSettle();
      expect(find.text('Way agas sabado pa last week'), findsOneWidget);
      expect(find.text('Your report is recorded in E-SUGID.'), findsOneWidget);
    },
  );

  testWidgets('in progress concern marks action as current', (tester) async {
    final concern = _concern('being_handled');
    await tester.pumpWidget(
      MaterialApp(
        home: ConcernDetailPage(
          concern: concern,
          repository: _TrackingRepository(concern),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('Action in progress'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
