import 'package:esugid/features/complaints/complaint_modals.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Submission caseRecord({Map<String, dynamic>? officials, String tanod = ''}) =>
    Submission.fromMap({
      'id': 'BC-2026-900001',
      'kind': 'complaint',
      'title': 'Boundary dispute',
      'description': 'A boundary concern.',
      'residentName': 'Test Complainant',
      'date': '2026-10-19T01:00:00Z',
      'status': 'hearing_scheduled',
      'receivingBarangayId': 'barili_pangpang',
      'barangayId': 'barili_vito',
      'barangay': 'Vito',
      'complaint': {'respondentName': 'Test Respondent'},
      'summons': {
        'issuedAt': '2026-10-20T01:00:00Z',
        'appearanceDate': '2026-11-01',
        'appearanceTime': '09:00',
        'appearanceVenue': 'Pangpang Barangay Hall',
        'assignedTanod': tanod,
        'officials': officials,
        'summonsCount': 1,
        'hearingPurpose': 'Boundary dispute mediation',
      },
    });

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('lupon summons uses the lupon office and first invitation of the second phase', (tester) async {
    final item = caseRecord();
    await tester.pumpWidget(MaterialApp(home: OfficialSummonsPage(
      complaint: Submission.fromMap({...item.toMap(), 'summons': {...item.summons!, 'hearingNumber': 4, 'summonsCount': 4, 'phase': 'lupon', 'phaseNumber': 1}}),
      officialsLoader: (_) async => {'barangayId': 'barili_pangpang', 'captainName': 'Captain Name', 'secretaryName': 'Secretary Name'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('OFFICE OF THE LUPONG TAGAPAMAYAPA'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('OFFICE OF THE BARANGAY CAPTAIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 600.0]) {
    testWidgets(
      'summons follows reference and database case officials at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? requested;
        await tester.pumpWidget(
          MaterialApp(
            home: OfficialSummonsPage(
              complaint: caseRecord(tanod: 'Barangay Tanod on duty'),
              officialsLoader: (id) async {
                requested = id;
                return {
                  'barangayId': 'barili_pangpang',
                  'captainName': 'Pangpang Captain',
                  'secretaryName': 'Pangpang Secretary',
                };
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requested, 'BC-2026-900001');
        expect(find.text('Pangpang Captain'), findsOneWidget);
        expect(find.text('Pangpang Secretary'), findsOneWidget);
        expect(find.text('Prepared by:'), findsOneWidget);
        expect(find.text('Noted by:'), findsOneWidget);
        expect(find.text('Serve by:'), findsOneWidget);
        expect(find.text('Barangay Tanod on duty'), findsNothing);
        expect(find.text('BARANGAY PANGPANG'), findsOneWidget);
        expect(find.text('Respondent summoned: TEST RESPONDENT'), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('summons-barangay-seal')))
              .dx,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('summons-municipal-seal')),
                )
                .dx,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'issued official snapshots are preserved and manual tanod names are retained',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialSummonsPage(
            complaint: caseRecord(
              tanod: 'Pedro Reyes',
              officials: {
                'barangayId': 'barili_pangpang',
                'captainName': 'Issued Captain',
                'secretaryName': 'Issued Secretary',
              },
            ),
            officialsLoader: (_) => throw StateError(
              'A complete issued snapshot does not need a lookup',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Issued Captain'), findsOneWidget);
      expect(find.text('Issued Secretary'), findsOneWidget);
      expect(find.text('Pedro Reyes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('official names from another barangay are never substituted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialSummonsPage(
          complaint: caseRecord(),
          officialsLoader: (_) async => {
            'barangayId': 'barili_vito',
            'captainName': 'Wrong Captain',
            'secretaryName': 'Wrong Secretary',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wrong Captain'), findsNothing);
    expect(find.text('Wrong Secretary'), findsNothing);
    expect(find.text('____________________'), findsNWidgets(3));
  });
}
