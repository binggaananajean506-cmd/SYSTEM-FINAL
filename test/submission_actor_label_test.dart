import 'package:esugid/submission_actor_label.dart';
import 'package:esugid/submission_service.dart';
import 'package:flutter_test/flutter_test.dart';

const owner = 'resident-document-id-123456';
const officer = 'staff-document-id-123456';

Submission report({bool anonymous = false}) => Submission.fromMap({
  'id': 'CON-2026-913415',
  'kind': 'concern',
  'userId': owner,
  'residentName': 'Cris Resident',
  'anonymous': anonymous,
  'status': 'being_handled',
  'date': '2026-10-05T13:16:00Z',
});

void main() {
  test(
    'a public legacy filing uses the owner name only for their own action',
    () {
      const entry = {
        'status': 'new',
        'action': 'submitted',
        'actorId': 'resident',
        'performedBy': 'resident',
        'actorType': 'resident',
      };
      expect(
        submissionTimelineActorLabel(
          entry,
          report(),
          viewerId: owner,
          viewerName: 'Cris Resident',
        ),
        'Filed by: Cris Resident',
      );
    },
  );

  test('official updates consistently use the explicit staff name', () {
    expect(
      submissionTimelineActorLabel({
        'status': 'being_handled',
        'action': 'handle',
        'actorId': officer,
        'performedBy': officer,
        'actorName': 'Ana Jean Binggaan',
      }, report()),
      'Updated by: Ana Jean Binggaan',
    );
  });

  test('missing staff names never expose document IDs', () {
    expect(
      submissionTimelineActorLabel({
        'status': 'being_handled',
        'actorRole': officer,
      }, report()),
      'Updated by: Official',
    );
    expect(
      submissionTimelineActorLabel({
        'status': 'being_handled',
        'actorId': officer,
        'performedBy': officer,
        'actorName': officer,
      }, report()),
      'Updated by: Official',
    );
    expect(
      submissionTimelineActorLabel({
        'status': 'being_handled',
        'actorId': officer,
        'actorRole': 'barangay_secretary',
      }, report()),
      'Updated by: Barangay Secretary',
    );
  });

  test(
    'legacy full names remain readable without treating identifiers as names',
    () {
      expect(
        submissionTimelineActorLabel({
          'status': 'being_handled',
          'performedBy': 'Ana Jean Binggaan',
        }, report()),
        'Updated by: Ana Jean Binggaan',
      );
      expect(
        submissionTimelineActorLabel({
          'status': 'being_handled',
          'actorId': 'custom staff identifier',
          'performedBy': 'custom staff identifier',
        }, report()),
        'Updated by: Official',
      );
    },
  );

  test('anonymous resident names remain hidden from other viewers', () {
    expect(
      submissionTimelineActorLabel(
        {
          'status': 'new',
          'action': 'submitted',
          'actorId': owner,
          'actorType': 'resident',
          'actorName': 'Cris Resident',
        },
        report(anonymous: true),
        viewerId: 'other-resident',
      ),
      'Filed by: Resident',
    );
  });

  test('a resident response is an update rather than a second filing', () {
    expect(
      submissionTimelineActorLabel(
        {
          'status': 'being_handled',
          'action': 'resident_response',
          'actorId': owner,
          'actorType': 'resident',
        },
        report(),
        viewerId: owner,
        viewerName: 'Cris Resident',
      ),
      'Updated by: Cris Resident',
    );
    expect(
      submissionTimelineActorLabel(
        {
          'status': 'new',
          'action': 'resident_joined',
          'actorId': 'resident',
          'actorType': 'resident',
        },
        report(),
        viewerId: owner,
        viewerName: 'Cris Resident',
      ),
      'Updated by: Resident',
    );
  });

  test('synthetic status rows do not invent an updater', () {
    expect(
      submissionTimelineActorLabel({'status': 'being_handled'}, report()),
      '',
    );
    expect(
      submissionTimelineActorLabel({
        'status': 'being_handled',
        'actorId': 'system',
      }, report()),
      'Updated by: System',
    );
  });
}
