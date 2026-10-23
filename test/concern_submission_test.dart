import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concern submission serializes canonical workflow data', () {
    final submission = Submission(
      id: 'CON-2026-100001',
      title: 'Road concern',
      description: 'Damaged road near the public market.',
      category: 'Road Repair',
      status: 'Pending',
      date: DateTime(2026, 7, 28),
      type: 'Complaint',
      department: 'Municipal Engineering Office',
      userId: 'resident-1',
      location: 'Public Market',
      incidentDate: '2026-07-27T00:00:00.000',
      requestedAction: 'Inspect and repair the damaged section.',
      anonymous: false,
      attachmentUrl: 'https://example.com/photo.jpg',
    );

    final data = submission.toMap();
    expect(data['requestedAction'], contains('repair'));
    expect(data, isNot(contains('contactPreference')));
    expect(data['attachmentUrl'], isNotEmpty);
    expect(data['anonymous'], isFalse);
    expect(data['status'], 'new');
    expect(data['date'], isA<Timestamp>());
  });

  test('legacy concern statuses normalize to the canonical workflow', () {
    expect(normalizeSubmissionStatus('Pending'), 'new');
    expect(normalizeSubmissionStatus('Under Review'), 'being_handled');
    expect(normalizeSubmissionStatus('Being Reviewed'), 'being_handled');
    expect(normalizeSubmissionStatus('In Progress'), 'being_handled');
    expect(normalizeSubmissionStatus('Needs Information'), 'needs_information');
    expect(normalizeSubmissionStatus('Closed'), 'closed');
    expect(submissionStatusLabel('triaged'), 'Active');
    expect(submissionStatusLabel('under_review'), 'In Progress');
    expect(submissionStatusLabel('assigned'), 'In Progress');
    expect(submissionStatusLabel('awaiting_resident'), 'Awaiting Information');
    expect(submissionStatusLabel('rejected'), 'Rejected');
    expect(submissionStatusLabel('closed'), 'Closed');
  });

  test('concern filters follow the resident-facing workflow', () {
    expect(concernMatchesFilter('submitted', ConcernListFilter.active), isTrue);
    expect(
      concernMatchesFilter('awaiting_resident', ConcernListFilter.active),
      isTrue,
    );
    expect(concernMatchesFilter('resolved', ConcernListFilter.active), isFalse);
    expect(
      concernMatchesFilter('resolved', ConcernListFilter.resolved),
      isTrue,
    );
    expect(
      concernMatchesFilter('rejected', ConcernListFilter.resolved),
      isTrue,
    );
  });

  test('resident timeline excludes internal administrator notes', () {
    final submission = Submission(
      id: 'CON-2026-100002',
      title: 'Drainage concern',
      description: 'Drainage is blocked.',
      category: 'Drainage',
      status: 'in_progress',
      date: DateTime(2026, 8, 4),
      type: 'Complaint',
      userId: 'resident-1',
      statusHistory: [
        {
          'status': 'submitted',
          'note': 'Submission received',
          'visibility': 'public',
        },
        {
          'status': 'assigned',
          'note': 'Internal assignment note',
          'visibility': 'internal',
        },
      ],
    );

    expect(submission.publicStatusHistory, hasLength(1));
    expect(submission.publicStatusHistory.single['status'], 'submitted');
  });

  test('grouped concerns associate with both original and joined reporters', () {
    const christianId = 'christian-jay-uid';
    const anaJeanId = 'ana-jean-uid';
    const thirdPartyId = 'other-resident-uid';

    final groupedSubmissionMap = {
      'id': 'CON-2026-GROUPED',
      'title': 'Same Street Drainage Concern',
      'description': 'Water overflowing on main street.',
      'category': 'Drainage',
      'status': 'being_handled',
      'date': Timestamp.now(),
      'type': 'Complaint',
      'userId': christianId,
      'createdBy': christianId,
      'reporterIds': [christianId, anaJeanId],
      'reporterCount': 2,
    };

    // When Christian views the submission:
    final christianView = Submission.fromMap(
      groupedSubmissionMap,
      viewerId: christianId,
    );
    expect(christianView.userId, christianId);
    expect(christianView.isAssociatedWithUser(christianId), isTrue);
    expect(christianView.reporterIds, contains(christianId));
    expect(christianView.reporterIds, contains(anaJeanId));

    // When Ana Jean views the submission:
    final anaJeanView = Submission.fromMap(
      groupedSubmissionMap,
      viewerId: anaJeanId,
    );
    expect(anaJeanView.joinedByCurrentUser, isTrue);
    expect(anaJeanView.isAssociatedWithUser(anaJeanId), isTrue);
    expect(anaJeanView.reporterIds, contains(anaJeanId));

    // For an unrelated third party:
    expect(christianView.isAssociatedWithUser(thirdPartyId), isFalse);
    expect(anaJeanView.isAssociatedWithUser(thirdPartyId), isFalse);
  });
}
