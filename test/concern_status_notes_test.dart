import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OneConcernRepository implements SubmissionRepository {
  _OneConcernRepository(this.concern);

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

Submission _concern({
  required String status,
  required List<Map<String, dynamic>> history,
}) {
  return Submission(
    id: 'con-1',
    title: 'Way agas',
    description: 'Duha ka buwan na sig baha diri',
    category: 'Drainage',
    type: 'Complaint',
    userId: 'cris',
    barangay: 'Vito',
    date: DateTime(2026, 10, 5),
    status: status,
    handlingNote: 'Site inspection is scheduled for this concern.',
    statusHistory: history,
    submittedAt: DateTime(2026, 10, 5, 21, 16),
    updatedAt: DateTime(2026, 10, 6, 9),
  );
}

const _handled = {
  'status': 'being_handled',
  'action': 'handle',
  'note': 'Site inspection is scheduled for this concern.',
  'reason': 'Site inspection is scheduled for this concern.',
  'visibility': 'public',
};

Future<void> _openConcern(WidgetTester tester, Submission concern) async {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConcernCenterPage(
          repository: _OneConcernRepository(concern),
          categoryLoader: () async => const [],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('My Concerns').first);
  await tester.pumpAndSettle();
  if (find.text('Way agas').evaluate().isEmpty &&
      find.text('Resolved').evaluate().isNotEmpty) {
    await tester.tap(find.text('Resolved').first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Way agas').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = User(
      uid: 'cris',
      email: 'cris@example.com',
      role: UserRole.resident,
      name: 'Cris',
      barangay: 'Vito',
      verificationStatus: VerificationStatus.verified,
    );
  });
  tearDown(() => AuthService.currentUser = null);

  testWidgets('in-progress concerns show the official progress note', (
    tester,
  ) async {
    await _openConcern(
      tester,
      _concern(status: 'being_handled', history: [_handled]),
    );
    expect(find.text('Official Progress Update'), findsOneWidget);
    // The note appears once, in the card; the timeline shows status and date.
    expect(
      find.text('Site inspection is scheduled for this concern.'),
      findsOneWidget,
    );
    expect(find.text('Status Timeline'), findsOneWidget);
    expect(find.text('In Progress'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolved concerns show the resolution, not a stale progress card', (
    tester,
  ) async {
    await _openConcern(
      tester,
      _concern(
        status: 'resolved',
        history: [
          _handled,
          {
            'status': 'resolved',
            'action': 'resolve',
            'note': 'Concern resolved: "Canal was cleared on Oct 6."',
            'reason': 'Canal was cleared on Oct 6.',
            'visibility': 'public',
          },
        ],
      ),
    );
    expect(find.text('Official Progress Update'), findsNothing);
    expect(find.text('Concern resolved'), findsOneWidget);
    expect(find.text('Canal was cleared on Oct 6.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('information requests show the official request without a progress card', (
    tester,
  ) async {
    await _openConcern(
      tester,
      _concern(
        status: 'needs_information',
        history: [
          _handled,
          {
            'status': 'needs_information',
            'action': 'request_information',
            'note': 'Additional information requested: Please send a photo of the canal.',
            'reason': 'Please send a photo of the canal.',
            'visibility': 'public',
          },
        ],
      ),
    );
    expect(find.text('More information is needed'), findsOneWidget);
    expect(find.text('Please send a photo of the canal.'), findsOneWidget);
    expect(find.text('Official Progress Update'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
