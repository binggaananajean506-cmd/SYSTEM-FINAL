import 'package:esugid/auth_service.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OneConcernRepository implements SubmissionRepository {
  _OneConcernRepository(this.concern, {this.includeInActivity = true});

  final Submission concern;
  final bool includeInActivity;

  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value([if (includeInActivity) concern]);

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

Future<void> _openReportUpdates(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Report updates'));
  await tester.tap(find.text('Report updates'));
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
      barangayId: 'barili_vito',
      verifiedBarangayId: 'barili_vito',
      verificationStatus: VerificationStatus.verified,
    );
  });
  tearDown(() => AuthService.currentUser = null);

  testWidgets('new concern explains its status and the next update', (tester) async {
    await _openConcern(
      tester,
      _concern(status: 'new', history: []).copyWith(type: 'Concern'),
    );

    expect(find.text('Report updates'), findsOneWidget);
    await _openReportUpdates(tester);

    expect(find.text('What is happening now?'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('Report submitted'), findsWidgets);
    expect(
      find.text('No progress update has been posted yet.'),
      findsOneWidget,
    );
    expect(find.text('What happens next?'), findsOneWidget);
    expect(find.text('Your report is recorded in E-SUGID.'), findsOneWidget);
    expect(find.text('Office started handling your concern'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracking details remain readable on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final status in ['new', 'needs_information']) {
      final concern = _concern(status: status, history: []);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(status),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: ConcernDetailPage(
            concern: concern,
            repository: _OneConcernRepository(concern),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track Your Concern'), findsOneWidget);
      expect(find.text('Status Timeline'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Status: $status');
    }
  });

  testWidgets('information request tells the resident what action to take', (
    tester,
  ) async {
    await _openConcern(
      tester,
      _concern(
        status: 'needs_information',
        history: [
          {
            'status': 'needs_information',
            'reason': 'Please send a photo of the canal.',
            'visibility': 'public',
          },
        ],
      ).copyWith(type: 'Concern'),
    );

    await _openReportUpdates(tester);

    expect(find.text('Your response is needed'), findsOneWidget);
    expect(find.text('ACTION NEEDED'), findsOneWidget);
    expect(
      find.text('Read the request below, then tap Edit & Resubmit to send your response.'),
      findsOneWidget,
    );
    expect(find.text('More information requested'), findsOneWidget);
    expect(find.text('Edit & Resubmit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed concern shows the recorded reason', (tester) async {
    await _openConcern(
      tester,
      _concern(status: 'rejected', history: [
        {
          'status': 'rejected',
          'reason': 'This concern is outside the receiving office area.',
          'visibility': 'public',
        },
      ]),
    );

    await _openReportUpdates(tester);

    expect(find.text('This concern is closed'), findsOneWidget);
    expect(
      find.text('Recorded note: This concern is outside the receiving office area.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-progress concerns show the official progress note', (
    tester,
  ) async {
    await _openConcern(
      tester,
      _concern(status: 'being_handled', history: [_handled]),
    );
    expect(find.text('Official Progress Update'), findsOneWidget);
    // The note appears once, in the card; the updates show status and date.
    expect(
      find.text('Site inspection is scheduled for this concern.'),
      findsOneWidget,
    );
    expect(find.text('Report updates'), findsOneWidget);
    await _openReportUpdates(tester);
    expect(find.text('Office started handling your concern'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline separates the resident filing from official updates', (tester) async {
    await _openConcern(tester, _concern(status: 'being_handled', history: [
      {
        'status': 'new', 'action': 'submitted', 'actorType': 'resident',
        'performedBy': 'resident', 'actorId': 'resident',
        'date': '2026-10-05T13:16:00Z',
      },
      {
        ..._handled, 'actorId': 'staff-document-id-123456',
        'performedBy': 'staff-document-id-123456', 'actorName': 'Ana Jean Binggaan',
        'date': '2026-10-06T01:00:00Z',
      },
    ]));
    await _openReportUpdates(tester);
    expect(find.text('Filed by: Cris'), findsOneWidget);
    expect(find.text('Updated by: Ana Jean Binggaan'), findsOneWidget);
    expect(find.text('Handled by: resident'), findsNothing);
    expect(find.textContaining('staff-document-id-123456'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress card identifies the handling official and preserves their note', (tester) async {
    await _openConcern(tester, _concern(status: 'being_handled', history: [{
      ..._handled, 'actorId': 'captain-uid', 'actorName': 'Ana Jean Binggaan',
      'actorRole': 'barangay_captain',
    }]));
    expect(find.text('Handled by: Ana Jean Binggaan · Barangay Captain'), findsOneWidget);
    expect(find.text('Site inspection is scheduled for this concern.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final source in ['My Activity', 'My Barangay']) {
    testWidgets('$source concern details load the specific official when history is absent', (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final concern = _concern(status: 'being_handled', history: []);
      String? handlerCase;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ConcernCenterPage(
        repository: _OneConcernRepository(concern, includeInActivity: source == 'My Activity'),
        categoryLoader: () async => const [],
        publicConcernsLoader: (_) => Stream.value([concern.copyWith(
          userId: 'another-resident', handlingNote: 'Barangay Vito is actively handling this concern.',
        )]),
        concernHandlerLoader: (id) async {
          handlerCase = id;
          return {'name': 'Ana Jean Binggaan', 'role': 'barangay_captain'};
        },
      ))));
      await tester.pumpAndSettle();
      if (source == 'My Activity') {
        await tester.tap(find.textContaining('My Concerns').first);
      } else {
        await tester.tap(find.text('My Barangay').first);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Way agas').first);
      await tester.pumpAndSettle();
      if (source == 'My Barangay') {
        await tester.tap(find.text('View Progress & Details'));
        await tester.pumpAndSettle();
      }
      expect(handlerCase, 'con-1');
      expect(find.text('Handled by: Ana Jean Binggaan · Barangay Captain'), findsOneWidget);
      expect(find.text('Barangay Vito is actively handling this concern.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
    await _openReportUpdates(tester);
    expect(find.text('Official Progress Update'), findsNothing);
    expect(find.text('The concern was marked resolved'), findsOneWidget);
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
