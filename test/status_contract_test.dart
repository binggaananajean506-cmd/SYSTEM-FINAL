import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/emergency_service.dart';
import 'package:esugid/submission_service.dart';

void main() {
  test('legacy emergency statuses normalize to canonical values', () {
    expect(normalizeEmergencyStatus('received'), 'acknowledged');
    expect(normalizeEmergencyStatus('dispatched'), 'responding');
    expect(normalizeEmergencyStatus('in progress'), 'responding');
    expect(normalizeEmergencyStatus(''), 'submitted');
  });

  test('emergency status transitions only move forward', () {
    expect(canTransitionEmergencyStatus('submitted', 'acknowledged'), isTrue);
    expect(canTransitionEmergencyStatus('acknowledged', 'responding'), isTrue);
    expect(canTransitionEmergencyStatus('acknowledged', 'resolved'), isTrue);
    expect(canTransitionEmergencyStatus('responding', 'resolved'), isTrue);
    expect(canTransitionEmergencyStatus('resolved', 'responding'), isFalse);
    expect(canTransitionEmergencyStatus('submitted', 'resolved'), isFalse);
  });

  test('new concern maps use the versioned scoped schema', () {
    final submission = Submission(
      id: 'CON-1',
      title: 'Street light',
      description: 'The street light is not working.',
      category: 'Electricity',
      status: 'pending',
      date: DateTime.utc(2026, 8, 15),
      type: 'Report',
      userId: 'resident-1',
      residentName: 'Juan Resident',
      barangay: 'Cabcaban',
      requestedAction: 'Please inspect the light.',
    );

    final map = submission.toMap();
    expect(map['schemaVersion'], 2);
    expect(map['status'], 'new');
    expect(map['userId'], 'resident-1');
    expect(map['residentId'], 'resident-1');
    expect(map['residentName'], 'Juan Resident');
    expect(map['barangay'], 'Cabcaban');
    expect(map['requestedAction'], 'Please inspect the light.');
  });
}
