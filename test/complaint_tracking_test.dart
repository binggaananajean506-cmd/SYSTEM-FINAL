import 'package:esugid/features/complaints/complaint_modals.dart';
import 'package:esugid/features/complaints/complaint_tracking_view.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Submission complaint(Map<String, dynamic> fields) => Submission.fromMap({
  'id': 'BC-2026-100001',
  'kind': 'complaint',
  'category': 'Barangay Complaint',
  'status': 'under_review',
  'complaintTrackingVersion': 1,
  'workflowVersion': 4,
  'date': '2026-10-01T01:00:00Z',
  'complaint': {'respondentName': 'Juan Dela Cruz'},
  ...fields,
});

Future<void> openCaseDetails(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Case details'));
  await tester.tap(find.text('Case details'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('closed complaint shows a short overview before case details',
      (tester) async {
    final item = complaint({
      'status': 'closed',
      'closureOutcome': 'cfa_issued',
      'resolutionSummary': 'Certificate issued.',
      'summons': {'status': 'issued'},
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ComplaintTrackingView(complaint: item)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Current status'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Case details'), findsOneWidget);
    expect(find.text('View Summons Issued to Respondent'), findsOneWidget);
    expect(find.text('View summons'), findsNothing);
    expect(find.text('Case Records & Updates'), findsNothing);
    expect(find.text('Recorded Conclusion'), findsNothing);

    await tester.ensureVisible(find.text('Case details'));
    await tester.tap(find.text('Case details'));
    await tester.pumpAndSettle();
    expect(find.text('Certificate issued.'), findsOneWidget);
    expect(find.text('Case Records & Updates'), findsOneWidget);
    expect(find.text('View Summons Issued to Respondent'), findsOneWidget);
    await tester.ensureVisible(find.text('View Summons Issued to Respondent'));
    await tester.tap(find.text('View Summons Issued to Respondent'));
    await tester.pumpAndSettle();
    expect(find.byType(OfficialSummonsPage), findsOneWidget);
  });

  testWidgets('compact complaint overview fits a small phone and keeps actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var resubmissions = 0;
    final item = complaint({
      'status': 'needs_information',
      'statusHistory': [
        {'status': 'needs_information', 'reason': 'Send a clearer photo.'},
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ComplaintTrackingView(
            complaint: item,
            onResubmit: () => resubmissions++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Send a clearer photo.'), findsOneWidget);
    expect(find.text('Update complaint'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Update complaint'));
    expect(resubmissions, 1);
  });
  test('six rounds have separate barangay and lupon numbering', () {
    for (var number = 1; number <= 6; number++) {
      expect(complaintHearingLabel(number), '${number <= 3 ? 'Barangay' : 'Lupon'} Hearing ${(number - 1) % 3 + 1} of 3 · Round $number of 6');
    }
    final pending = complaint({'status': 'awaiting_cfa', 'legacyCompletedHearings': 6});
    expect(pending.complaintFinished, false);
    expect(pending.complaintStatusLabel, 'Awaiting CFA Issuance');
    final issued = complaint({'status': 'closed', 'closureOutcome': 'cfa_issued'});
    expect(issued.complaintFinished, true);
    expect(issued.complaintStatusLabel, 'Closed — CFA Issued');
    expect(complaint({'status': 'cfa_issued'}).complaintFinished, true);
  });
  testWidgets('resident sees lupon round and CFA pending without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = complaint({'status': 'hearing_scheduled', 'legacyCompletedHearings': 3,
      'hearings': [{'id': 'lupon-1', 'number': 4, 'status': 'scheduled', 'date': '2099-11-01', 'time': '09:00', 'venue': 'Barangay Hall'}]});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComplaintTrackingView(complaint: item)))));
    await openCaseDetails(tester);
    expect(find.text('Lupon Hearing 1 of 3 · Round 4 of 6'), findsOneWidget);
    expect(find.text('Barangay Lupon'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final pending = complaint({'status': 'awaiting_cfa', 'legacyCompletedHearings': 6});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComplaintTrackingView(complaint: pending)))));
    await openCaseDetails(tester);
    expect(find.text('Awaiting CFA issuance.'), findsOneWidget);
    expect(find.textContaining('All six rounds are recorded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resident distinguishes tanod handoff from service to the respondent', (tester) async {
    final item = complaint({'summons': {
      'appearanceDate': '2026-11-01', 'appearanceTime': '09:00',
      'assignedTanod': 'Pedro Reyes', 'status': 'issued', 'deliveryStatus': 'handed_to_tanod',
    }});
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComplaintTrackingView(complaint: item)))));
    expect(find.text('Summons with the tanod. Delivery is not yet confirmed.'), findsOneWidget);
    await openCaseDetails(tester);
    expect(find.text('Assigned tanod: Pedro Reyes'), findsOneWidget);
    expect(find.text('Handed to Barangay Tanod for delivery to the respondent.'), findsOneWidget);
    expect(find.text('Handoff to the tanod does not confirm service to the respondent.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('complaint status and workflow metadata survive parsing and copying', () {
    final item = complaint({});
    expect(item.status, 'under_review');
    expect(item.statusLabel, 'Under Review');
    expect(item.copyWith(description: 'Updated description').workflowVersion, 4);
    expect(item.toMap()['status'], 'under_review');
    expect(item.toMap()['kind'], 'complaint');
    expect(item.toMap()['workflowVersion'], 4);
    expect(Submission.fromMap({'status': 'under_review'}).status, 'being_handled');
  });
  test('passed appointments stay open and show result pending', () {
    final item = complaint({
      'status': 'hearing_scheduled',
      'hearings': [
        {'number': 1, 'status': 'scheduled', 'date': '2020-01-01', 'time': '09:00'},
      ],
    });
    expect(item.complaintStatusLabel, 'Result Pending');
    expect(item.complaintFinished, false);
    expect(item.completedHearingCount, 0);
  });
  testWidgets('past hearing asks the resident to wait for the result',
      (tester) async {
    final item = complaint({
      'status': 'hearing_scheduled',
      'hearings': [
        {'number': 1, 'status': 'scheduled', 'date': '2020-01-01', 'time': '09:00'},
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ComplaintTrackingView(complaint: item)),
    ));

    expect(find.text('Wait for the hearing result.'), findsOneWidget);
    expect(find.text('Attend your hearing. Bring your ID and evidence.'),
        findsNothing);
  });
  test('only completed hearings count; legacy summons never establish count', () {
    final item = complaint({
      'legacyCompletedHearings': 1,
      'hearings': [
        {'status': 'not_held', 'number': 2},
        {'status': 'cancelled', 'number': 2},
        {'status': 'completed', 'number': 2, 'outcome': 'no_agreement'},
      ],
    });
    expect(item.completedHearingCount, 2);
    final legacy = complaint({
      'complaintTrackingVersion': 0,
      'status': 'being_handled',
      'summons': {'summonsCount': 3},
    });
    expect(legacy.completedHearingCount, 0);
    expect(legacy.complaintNeedsConfirmation, true);
  });
  test('finished labels distinguish agreement, no agreement, invalid and withdrawn', () {
    for (final entry in {
      'settled': 'Resolved',
      'unsettled': 'Closed — Unsettled',
      'invalid': 'Invalid',
      'withdrawn': 'Withdrawn',
    }.entries) {
      final item = complaint({'status': 'closed', 'closureOutcome': entry.key});
      expect(item.statusLabel, entry.value);
      expect(concernMatchesFilter(item.status, ConcernListFilter.active), false);
    }
  });
  testWidgets('resident sees the conclusion, hearing attendance and external reference', (tester) async {
    final item = complaint({
      'status': 'closed', 'closureOutcome': 'unsettled',
      'resolutionSummary': 'No agreement was reached after the final hearing.',
      'hearings': [
        {'number': 3, 'status': 'completed', 'outcome': 'no_agreement',
          'date': '2026-10-09', 'time': '09:00', 'venue': 'Barangay Hall',
          'complainantAttendance': 'present', 'respondentAttendance': 'present'},
      ],
      'externalUpdates': [
        {'type': 'Office update', 'date': '2026-10-10', 'reference': 'Office-123', 'note': 'Offline records updated.'},
      ],
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ComplaintTrackingView(complaint: item)))));
    expect(find.text('Closed — Unsettled'), findsOneWidget);
    await openCaseDetails(tester);
    expect(find.text('No agreement was reached after the final hearing.'), findsOneWidget);
    expect(find.text('Barangay Hearing 3 of 3 · Round 3 of 6 · No agreement'), findsOneWidget);
    expect(find.text('Reference: Office-123'), findsOneWidget);
    expect(find.textContaining('Juan Dela Cruz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showSummonsSheet opens OfficialSummonsPage with Official Form KP-9 as initial view without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final item = complaint({
      'id': 'BC-2026-630019',
      'barangay': 'Vito',
      'title': 'Boundary or property',
      'residentName': 'Ana Jean Atamosa Binggaan',
      'status': 'hearing_scheduled',
      'complaint': {'respondentName': 'Ambot'},
      'summons': {
        'appearanceDate': '2026-10-13',
        'appearanceTime': '09:00',
        'hearingPlace': 'Barangay Hall of Vito',
        'hearingPurpose': 'Mediation regarding Boundary or property',
        'deliveryStatus': 'handed_to_tanod',
      },
      'hearings': [
        {
          'status': 'scheduled',
          'date': '2026-10-13',
          'time': '09:00',
          'venue': 'Barangay Hall of Vito',
        }
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSummonsSheet(context, item),
                child: const Text('Open Summons'),
              ),
            ),
          ),
        ),
      ),
    );

    // Click Open Summons
    await tester.tap(find.text('Open Summons'));
    await tester.pumpAndSettle();

    // Verify it opened OfficialSummonsPage
    expect(find.byType(OfficialSummonsPage), findsOneWidget);

    // Verify the FIRST view is the Official Form (KP Form 9)
    expect(find.text('OFFICE OF THE BARANGAY CAPTAIN'), findsOneWidget);
    expect(find.textContaining('Barangay Summons ·'), findsOneWidget);
    expect(find.text('S U M M O N S'), findsOneWidget);
    expect(find.text('BC-2026-630019'), findsOneWidget);

    // Switch to Hearing Notice tab
    await tester.tap(find.text('Hearing Notice').first);
    await tester.pumpAndSettle();

    // Verify Hearing Notice view is displayed
    expect(find.text('SCHEDULED HEARING'), findsOneWidget);
    expect(find.text('Case Parties'), findsOneWidget);

    // Switch back to Official Form tab
    await tester.tap(find.text('Official Form').first);
    await tester.pumpAndSettle();

    // Verify Official Form is displayed again
    expect(find.text('OFFICE OF THE BARANGAY CAPTAIN'), findsOneWidget);

    // Pop the page using back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Verify OfficialSummonsPage is closed
    expect(find.byType(OfficialSummonsPage), findsNothing);

    // Confirm no overflow errors occurred
    expect(tester.takeException(), isNull);
  });
}
