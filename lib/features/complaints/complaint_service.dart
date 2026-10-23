import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

/// Must match COMPLAINT_TYPES in functions/complaint_helpers.js.
const complaintTypes = <String>[
  'Noise',
  'Boundary or property',
  'Unpaid debt',
  'Threats or harassment',
  'Animals',
  'Other',
];

/// Must match RESPONDENT_RELATIONSHIPS in functions/complaint_helpers.js.
const respondentRelationships = <String>[
  'Neighbor',
  'Relative',
  'Landlord or tenant',
  'Other',
];

/// Labels for how a complaint was closed (`closureOutcome`).
const complaintOutcomeLabels = <String, String>{
  'settled': 'Resolved',
  'referred': 'Closed — External referral recorded',
  'unsettled': 'Closed — Unsettled',
  'invalid': 'Invalid',
  'withdrawn': 'Withdrawn',
  'dismissed': 'Dismissed',
};

class ComplaintRequest {
  const ComplaintRequest({
    required this.respondentUnknown,
    required this.respondentName,
    required this.respondentDescription,
    required this.respondentAddress,
    required this.barangay,
    required this.barangayId,
    required this.relationship,
    required this.complaintType,
    required this.incidentDate,
    required this.description,
    required this.desiredOutcome,
    required this.witnesses,
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.submissionId,
    this.draftId,
    this.expectedVersion,
    this.removeAttachment = false,
  });

  final bool respondentUnknown;
  final String respondentName;
  final String respondentDescription;
  final String respondentAddress;

  /// The barangay where the respondent lives; the complaint goes there.
  final String barangay;
  final String barangayId;
  final String relationship;
  final String complaintType;
  final String incidentDate;
  final String description;
  final String desiredOutcome;
  final String witnesses;
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final String? submissionId;
  final String? draftId;
  final int? expectedVersion;
  final bool removeAttachment;

  Map<String, Object?> toCallableData({
    String? id,
    String? draftId,
  }) => {
    'id': id ?? submissionId ?? newComplaintReference(),
    'draftId': draftId ??
        this.draftId ??
        'complaint-${DateTime.now().microsecondsSinceEpoch}',
    'respondentUnknown': respondentUnknown,
    'respondentName': respondentUnknown ? '' : respondentName.trim(),
    'respondentDescription': respondentDescription.trim(),
    'respondentAddress': respondentAddress.trim(),
    'barangay': barangay,
    'barangayId': barangayId,
    'relationship': relationship,
    'complaintType': complaintType,
    'incidentDate': incidentDate.trim(),
    if (expectedVersion != null) 'expectedVersion': expectedVersion,
    'removeAttachment': removeAttachment,
    'description': description.trim(),
    'desiredOutcome': desiredOutcome.trim(),
    'witnesses': witnesses.trim(),
    if (attachmentUrl != null && attachmentUrl!.trim().isNotEmpty)
      'attachmentUrl': attachmentUrl!.trim(),
    if (attachmentStoragePath != null && attachmentStoragePath!.trim().isNotEmpty)
      'attachmentStoragePath': attachmentStoragePath!.trim(),
  };
}

class ComplaintException implements Exception {
  const ComplaintException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Files a complaint and returns its reference, e.g. BC-2026-104233.
typedef ComplaintSubmitter = Future<String> Function(ComplaintRequest request);

String newComplaintReference([Random? random]) {
  final number = 100000 + (random ?? Random()).nextInt(900000);
  return 'BC-${DateTime.now().year}-$number';
}

Future<String> submitComplaint(ComplaintRequest request) async {
  final id = request.submissionId ?? newComplaintReference();
  final draftId =
      request.draftId ?? 'complaint-${DateTime.now().microsecondsSinceEpoch}';
  try {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('submitComplaint')
        .call<Object?>(
          request.toCallableData(
            id: id,
            draftId: draftId,
          ),
        );
    final data = result.data;
    return data is Map ? '${data['id'] ?? id}' : id;
  } on FirebaseFunctionsException catch (error) {
    throw ComplaintException(
      error.message?.trim().isNotEmpty == true
          ? error.message!
          : 'Your complaint could not be sent. Try again.',
    );
  } catch (_) {
    throw const ComplaintException(
      'Your complaint could not be sent. Check your connection and try again.',
    );
  }
}
