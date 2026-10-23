import 'package:esugid/auth_service.dart';
import 'package:esugid/features/complaints/complaint_service.dart';
import 'package:esugid/pages/complaint_form_page.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OneCaseRepository implements SubmissionRepository {
  _OneCaseRepository(this.item);

  final Submission item;
  final replies = <String>[];

  @override
  Future<Submission> addSubmission(Submission submission) async => submission;

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      Stream.value([item]);

  @override
  Future<Submission> resubmitConcern(Submission submission) async => submission;

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async => replies.add(message);
}

Submission _complaint({
  required String status,
  Map<String, dynamic>? summons,
  String? closureOutcome,
  List<Map<String, dynamic>> history = const [],
}) {
  return Submission.fromMap({
    'id': 'BC-2026-104233',
    'kind': 'complaint',
    'title': 'Noise complaint',
    'description': 'Loud karaoke past midnight almost every night.',
    'category': 'Barangay Complaint',
    'type': 'Noise',
    'visibility': 'private',
    'status': status,
    'userId': 'cris',
    'barangay': 'Vito',
    'location': 'Sitio Cagay',
    'date': DateTime(2026, 10, 5, 21, 16).toIso8601String(),
    'incidentDate': 'October 5, 2026',
    'complaint': {
      'respondentName': 'Juan Dela Cruz',
      'respondentAddress': 'Sitio Cagay',
      'relationship': 'Neighbor',
      'desiredOutcome': 'Stop the karaoke after 10 PM',
    },
    'summons': ?summons,
    'closureOutcome': ?closureOutcome,
    'statusHistory': [
      {'status': 'new', 'action': 'submitted', 'note': 'Complaint filed.'},
      ...history,
    ],
  });
}

Future<void> _openCase(
  WidgetTester tester,
  _OneCaseRepository repository, {
  ComplaintSubmitter? complaintSubmitter,
}) async {
  tester.view.physicalSize = const Size(412, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConcernCenterPage(
          repository: repository,
          categoryLoader: () async => const [],
          complaintSubmitter: complaintSubmitter ?? submitComplaint,
        ),
      ),
    ),
  );
  if (find.textContaining('My Activity').evaluate().isNotEmpty) {
    await tester.tap(find.textContaining('My Activity').first);
  } else {
    await tester.tap(find.textContaining('My Concerns').first);
  }
  await tester.pumpAndSettle();
  if (find.text('Noise complaint').evaluate().isEmpty &&
      find.text('Finished').evaluate().isNotEmpty) {
    await tester.tap(find.text('Finished').first);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Noise complaint').first);
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

  testWidgets('complaint form requires the essentials and sends them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ComplaintRequest? sent;
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => ComplaintFormPage(
                        submit: (request) async {
                          sent = request;
                          return 'BC-2026-104233';
                        },
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Nothing is sent until the problem type and required fields are given.
    await tester.tap(find.byKey(const ValueKey('complaint-submit')));
    await tester.pumpAndSettle();
    expect(sent, isNull);
    expect(find.text('Choose the type of problem.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('complaint-type-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complaint-type-Noise')).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('complaint-respondent-name')),
      'Juan Dela Cruz',
    );
    await tester.enterText(
      find.byKey(const ValueKey('complaint-when')),
      'Most nights since Sep 20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('complaint-details')),
      'Loud karaoke past midnight almost every night.',
    );
    await tester.tap(find.byKey(const ValueKey('complaint-submit')));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.respondentName, 'Juan Dela Cruz');
    expect(sent!.complaintType, 'Noise');
    expect(sent!.barangay, 'Vito');
    expect(sent!.barangayId, isNotEmpty);
    expect(sent!.relationship, 'Neighbor');
    expect(popped, 'BC-2026-104233');
  });

  testWidgets('a summoned complaint shows the hearing and the respondent', (
    tester,
  ) async {
    await _openCase(
      tester,
      _OneCaseRepository(
        _complaint(
          status: 'being_handled',
          summons: {
            'appearanceDate': 'Tuesday, October 14, 2026',
            'appearanceTime': '9:00 AM',
            'appearanceVenue': 'Barangay Vito Hall',
          },
        ),
      ),
    );
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Previous schedule (awaiting confirmation)'), findsOneWidget);
    expect(find.text('MEDIATION HEARING'), findsNothing);
    expect(find.text('Tuesday, October 14, 2026'), findsOneWidget);
    expect(find.text('Barangay Vito Hall'), findsOneWidget);
    expect(find.text('Official Progress Update'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an information request opens the complaint form to update and resubmit', (
    tester,
  ) async {
    ComplaintRequest? submittedRequest;
    final repository = _OneCaseRepository(
      _complaint(
        status: 'needs_information',
        history: [
          {
            'status': 'needs_information',
            'action': 'request_information',
            'reason': 'What is the exact location of the house?',
            'visibility': 'public',
          },
        ],
      ),
    );
    await _openCase(
      tester,
      repository,
      complaintSubmitter: (request) async {
        submittedRequest = request;
        return 'BC-2026-104233';
      },
    );
    expect(find.text('Edit & Resubmit'), findsNothing);
    expect(find.byKey(const ValueKey('complaint-resubmit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complaint-resubmit')));
    await tester.pumpAndSettle();

    expect(find.text('File a Complaint'), findsOneWidget);
    expect(find.text('What is the exact location of the house?'), findsOneWidget);
    expect(find.text('Resubmit Complaint'), findsOneWidget);
    expect(find.byKey(const ValueKey('complaint-add-photo')), findsOneWidget);

    await tester.tap(find.text('Resubmit Complaint'));
    await tester.pumpAndSettle();

    expect(submittedRequest, isNotNull);
    expect(submittedRequest!.submissionId, 'BC-2026-104233');
    expect(find.textContaining('updated and resubmitted successfully'), findsOneWidget);
  });

  testWidgets('a closed complaint names its outcome', (tester) async {
    await _openCase(
      tester,
      _OneCaseRepository(
        _complaint(
          status: 'resolved',
          closureOutcome: 'settled',
          history: [
            {
              'status': 'resolved',
              'action': 'resolve',
              'outcome': 'settled',
              'reason': 'Juan agreed to stop the karaoke after 10 PM.',
              'visibility': 'public',
            },
          ],
        ),
      ),
    );
    expect(find.text('Resolved'), findsWidgets);
    expect(
      find.text('Juan agreed to stop the karaoke after 10 PM.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'complaint form review button allows reviewing details before submitting',
    (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ComplaintRequest? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplaintFormPage(
                        submit: (request) async {
                          sent = request;
                          return 'BC-2026-999999';
                        },
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('complaint-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('complaint-type-Noise')).last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('complaint-respondent-name')),
        'Maria Clara',
      );
      await tester.enterText(
        find.byKey(const ValueKey('complaint-when')),
        'Last night around 11 PM',
      );
      await tester.enterText(
        find.byKey(const ValueKey('complaint-details')),
        'Loud dog barking and disturbance all night long.',
      );

      // Tap Review button
      await tester.tap(find.byKey(const ValueKey('complaint-review')));
      await tester.pumpAndSettle();

      // Verify Review modal contents
      expect(find.text('Review Your Complaint'), findsOneWidget);
      expect(find.text('Maria Clara'), findsWidgets);
      expect(find.text('Noise'), findsWidgets);
      expect(
        find.text('Loud dog barking and disturbance all night long.'),
        findsWidgets,
      );
      expect(find.text('Confirm & Submit'), findsOneWidget);
      expect(find.text('Edit Details'), findsOneWidget);

      // Submit from Review modal
      await tester.tap(find.byKey(const ValueKey('complaint-confirm-submit')));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.respondentName, 'Maria Clara');
    },
  );

  testWidgets(
    'complaint form specific location and date options appear in review and request, outlined items removed',
    (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ComplaintRequest? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintFormPage(
              submit: (request) async {
                sent = request;
                return 'BC-2026-888888';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check specific location field exists
      expect(find.byKey(const ValueKey('complaint-location')), findsOneWidget);
      // Ensure the outlined items are removed
      expect(find.byKey(const ValueKey('complaint-track-my-complaints-button')), findsNothing);
      expect(find.byKey(const ValueKey('complaint-view-my-complaints-card-button')), findsNothing);
      expect(find.text('Already filed a complaint?'), findsNothing);
      expect(find.text('Yesterday (Gahapon)'), findsNothing);
      expect(find.text('Select Date & Time'), findsNothing);
      expect(find.text('Tap the calendar icon to pick date & time, or select below.'), findsNothing);
      expect(find.text('State the purok, sitio, street, or landmark where it took place.'), findsNothing);

      // Select problem type
      await tester.tap(find.byKey(const ValueKey('complaint-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('complaint-type-Noise')).last);
      await tester.pumpAndSettle();

      // Enter details and when
      await tester.enterText(
        find.byKey(const ValueKey('complaint-respondent-name')),
        'Pedro Penduko',
      );
      await tester.enterText(
        find.byKey(const ValueKey('complaint-when')),
        'Yesterday 10:00 PM',
      );
      await tester.pumpAndSettle();

      // Enter specific location in barangay (e.g. Purok Manga)
      await tester.enterText(
        find.byKey(const ValueKey('complaint-location')),
        'Purok Manga',
      );
      await tester.enterText(
        find.byKey(const ValueKey('complaint-details')),
        'Very loud noise during midnight.',
      );

      // Open review
      await tester.tap(find.byKey(const ValueKey('complaint-review')));
      await tester.pumpAndSettle();

      expect(find.text('Review Your Complaint'), findsOneWidget);
      expect(find.text('Purok Manga, Barangay Vito'), findsWidgets);
      // Ensure stepper dots are absent
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Confirm & submit
      await tester.tap(find.byKey(const ValueKey('complaint-confirm-submit')));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      expect(sent!.respondentAddress, 'Purok Manga, Barangay Vito');
      expect(sent!.description, contains('Purok Manga'));
    },
  );

  testWidgets(
    'ConcernCenterPage separates concerns and complaints under My Activity tab',
    (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _OneCaseRepository(
        _complaint(
          status: 'hearing_scheduled',
          history: const [
            {'status': 'hearing_scheduled', 'action': 'scheduled', 'note': 'First hearing set.'},
          ],
          summons: {
            'hearingDate': DateTime(2026, 10, 15, 14, 0).toIso8601String(),
            'hearingPlace': 'Barangay Hall',
            'officerName': 'Captain Cruz',
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConcernCenterPage(
              repository: repository,
              categoryLoader: () async => const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'My Activity'
      expect(find.textContaining('My Activity'), findsWidgets);
      await tester.tap(find.textContaining('My Activity').first);
      await tester.pumpAndSettle();

      // Verify sub-tabs 'My Concerns' and 'My Complaints' exist
      expect(find.byKey(const ValueKey('activity-tab-concerns')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-tab-complaints')), findsOneWidget);

      // Switch to My Concerns tab
      await tester.tap(find.byKey(const ValueKey('activity-tab-concerns')));
      await tester.pumpAndSettle();

      // Since the mock repository only has a complaint, My Concerns shows empty state
      expect(find.text('No active concerns'), findsOneWidget);

      // Switch back to My Complaints tab
      await tester.tap(find.byKey(const ValueKey('activity-tab-complaints')));
      await tester.pumpAndSettle();

      // Complaint is now visible under My Complaints
      expect(find.text('Noise complaint'), findsOneWidget);
    },
  );

  testWidgets(
    'complaint form displays photo evidence section and does not overflow on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ComplaintRequest? submittedRequest;
      final existing = _complaint(
        status: 'needs_information',
        history: [
          {
            'status': 'needs_information',
            'action': 'request_information',
            'reason': 'Please attach a photo or evidence of the incident.',
            'visibility': 'public',
          },
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintFormPage(
              existingComplaint: existing,
              requestReason: 'Please attach a photo or evidence of the incident.',
              submit: (request) async {
                submittedRequest = request;
                return 'BC-2026-104233';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow occurred on 320px width
      expect(tester.takeException(), isNull);

      // Verify header and requested banner
      expect(find.text('File a Complaint'), findsOneWidget);
      expect(find.text('Information Requested by Barangay'), findsOneWidget);
      expect(find.text('Please attach a photo or evidence of the incident.'), findsOneWidget);

      // Verify Photo & Evidence Section 5 exists
      expect(find.text('Photo & Evidence (optional)'), findsOneWidget);
      expect(find.byKey(const ValueKey('complaint-add-photo')), findsOneWidget);

      // Verify Resubmit Complaint button is visible
      expect(find.text('Resubmit Complaint'), findsOneWidget);

      // Open Review
      await tester.tap(find.byKey(const ValueKey('complaint-review')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Resubmit Complaint'), findsOneWidget);

      // Confirm and submit
      await tester.tap(find.byKey(const ValueKey('complaint-confirm-submit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(submittedRequest, isNotNull);
      expect(submittedRequest!.submissionId, 'BC-2026-104233');
    },
  );
  testWidgets('checking I dont know their name disables and clears Their name field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComplaintFormPage(
            submit: (request) async => 'BC-2026-104233',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameFieldFinder = find.byKey(const ValueKey('complaint-respondent-name'));
    final unknownBoxFinder = find.byKey(const ValueKey('complaint-name-unknown'));

    // 1. Initially enabled
    TextFormField field = tester.widget<TextFormField>(nameFieldFinder);
    expect(field.enabled, isTrue);

    // Enter name
    await tester.enterText(nameFieldFinder, 'Jaldine');
    await tester.pumpAndSettle();
    expect(find.text('Jaldine'), findsOneWidget);

    // 2. Check "I don't know their name"
    await tester.tap(unknownBoxFinder);
    await tester.pumpAndSettle();

    // 3. Field is disabled, cleared, and shows name not known hint
    field = tester.widget<TextFormField>(nameFieldFinder);
    expect(field.enabled, isFalse);
    expect(find.text('Jaldine'), findsNothing);
    expect(find.text('(Name not known)'), findsOneWidget);

    // 4. Uncheck re-enables the field
    await tester.tap(unknownBoxFinder);
    await tester.pumpAndSettle();

    field = tester.widget<TextFormField>(nameFieldFinder);
    expect(field.enabled, isTrue);
  });
}
