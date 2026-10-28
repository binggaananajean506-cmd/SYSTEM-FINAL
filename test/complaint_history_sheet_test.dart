import 'package:esugid/auth_service.dart';
import 'package:esugid/features/complaints/complaint_modals.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const residentId = 'residentDocumentId123456789';
const staffId = 'staffDocumentId123456789';
const longNote =
    'The summons was prepared for the hearing at the barangay hall. '
    'Please bring your documents and arrive before the scheduled time.';

Submission historyComplaint({String? residentName = 'Ana Resident'}) =>
    Submission.fromMap({
      'id': 'BC-2026-630019',
      'kind': 'complaint',
      'title': 'Boundary or property complaint',
      'userId': residentId,
      'residentName': residentName,
      'status': 'under_review',
      'date': '2026-10-12T01:00:00Z',
      'description': 'The original filing description.',
      'complaint': {'respondentName': 'Juan Dela Cruz'},
      'statusHistory': [
        {
          'status': 'filed',
          'actorId': residentId,
          'performedBy': residentId,
          'date': '2026-10-12T01:00:00Z',
          'note': 'Complaint filed.',
        },
        {
          'status': 'under_review',
          'actorId': staffId,
          'actorRole': 'barangay_secretary',
          'actorName': 'Maria Santos',
          'date': '2026-10-12T02:00:00Z',
          'note': longNote,
        },
        {
          'status': 'under_review',
          'actorId': 'private-actor',
          'note': 'Internal audit note',
          'visibility': 'internal',
        },
      ],
    });

Future<void> openHistory(
  WidgetTester tester,
  Submission complaint, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showFullHistorySheet(context, complaint),
                child: const Text('Open history'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open history'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets(
    'history shows resident and officer names instead of document IDs',
    (tester) async {
      await openHistory(tester, historyComplaint());
      expect(find.text('Filed by Ana Resident'), findsOneWidget);
      expect(find.text('Maria Santos · Barangay Secretary'), findsOneWidget);
      expect(find.textContaining(residentId), findsNothing);
      expect(find.textContaining(staffId), findsNothing);
      expect(find.textContaining('Officer: Ana Resident'), findsNothing);
      expect(find.text('Internal audit note'), findsNothing);
    },
  );

  testWidgets(
    'history starts with a short timeline and expands long notes on request',
    (tester) async {
      await openHistory(tester, historyComplaint());
      expect(
        find.text('Complete activity logs, notes, and audit records'),
        findsNothing,
      );
      expect(find.text('Filed description:'), findsNothing);
      expect(find.text('Complaint filed.'), findsNothing);
      expect(find.text(longNote), findsNothing);
      await tester.tap(find.text('View details').first);
      await tester.pumpAndSettle();
      expect(find.text(longNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy filing uses the signed-in resident name when its snapshot is missing',
    (tester) async {
      AuthService.currentUser = User(
        uid: residentId,
        email: 'resident@example.com',
        role: UserRole.resident,
        name: 'Ana Current Name',
      );
      await openHistory(tester, historyComplaint(residentName: null));
      expect(find.text('Filed by Ana Current Name'), findsOneWidget);
      expect(find.textContaining(residentId), findsNothing);
    },
  );

  testWidgets(
    'unknown historical actors never display their document ID as a name',
    (tester) async {
      final item = historyComplaint().copyWith(
        statusHistory: [
          {
            'status': 'under_review',
            'actorId': staffId,
            'performedBy': staffId,
            'actorName': staffId,
            'actorRole': 'barangay_secretary',
            'date': '2026-10-12T02:00:00Z',
          },
        ],
      );
      await openHistory(tester, item);
      expect(find.text('Barangay Secretary'), findsOneWidget);
      expect(find.textContaining(staffId), findsNothing);
    },
  );

  testWidgets('history fits a small phone with large accessibility text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openHistory(tester, historyComplaint(), scale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('View details').first, 140);
    await tester.tap(find.text('View details').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history keeps outcome details and does not confuse tanod handoff with service',
    (tester) async {
      final item = historyComplaint().copyWith(
        statusHistory: [
          {
            'status': 'hearing_scheduled',
            'label': 'Summons Handed to Barangay Tanod',
            'action': 'notify_summons',
            'actorName': 'Maria Santos',
            'actorRole': 'barangay_secretary',
          },
          {
            'status': 'closed',
            'label': 'Closed — Unsettled',
            'actorName': 'Maria Santos',
            'actorRole': 'barangay_secretary',
          },
        ],
      );
      await openHistory(tester, item);
      expect(find.text('Given to Barangay Tanod'), findsOneWidget);
      expect(find.text('Summons Delivered'), findsNothing);
      expect(find.text('Closed — Unsettled'), findsOneWidget);
    },
  );
}
