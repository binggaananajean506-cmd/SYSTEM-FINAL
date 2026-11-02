import 'features/complaints/complaint_role_helper.dart';
import 'submission_service.dart';

/// Names come from display fields, never an account/document identifier.
String submissionTimelineActorLabel(
  Map<String, dynamic> entry,
  Submission submission, {
  String? viewerId,
  String? viewerName,
}) {
  String text(dynamic value) => value?.toString().trim() ?? '';
  String first(List<dynamic> values) => values
      .map(text)
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final actorId = first([
    entry['actorId'],
    entry['performedBy'],
    entry['updatedBy'],
  ]);
  final role = first([
    entry['actorRole'],
    entry['actorType'],
    entry['role'],
  ]).toLowerCase();
  final action = text(entry['action']).toLowerCase();
  final status = text(entry['status']).toLowerCase();
  final filing =
      const [
        'submitted',
        'submit_concern',
        'submit_complaint',
        'file_complaint',
        'complaint_filed',
      ].contains(action) ||
      (action.isEmpty &&
          const [
            'new',
            'submitted',
            'filed',
            'active',
            'pending',
          ].contains(status));
  final primaryOwner =
      viewerId?.isNotEmpty == true &&
      (viewerId == submission.userId || viewerId == submission.createdBy);
  final actorIsOwner =
      actorId.isNotEmpty &&
      (actorId == submission.userId || actorId == submission.createdBy);
  final resident =
      filing ||
      actorIsOwner ||
      actorId.toLowerCase() == 'resident' ||
      const ['resident', 'complainant'].contains(role);
  final identifiers = {
    actorId,
    text(entry['performedBy']),
    text(entry['updatedBy']),
    text(submission.userId),
    text(submission.createdBy),
    text(viewerId),
  }..remove('');
  const placeholders = {
    'resident',
    'complainant',
    'authorized official',
    'official',
    'system',
  };
  String? name(dynamic value) {
    final candidate = text(value);
    if (candidate.isEmpty ||
        identifiers.contains(candidate) ||
        placeholders.contains(candidate.toLowerCase())) {
      return null;
    }
    return candidate;
  }

  var displayName =
      name(entry['actorName']) ??
      name(entry['performedByName']) ??
      name(entry['updatedByName']);
  // Older history sometimes saved a person's full name in performedBy.
  if (displayName == null) {
    final legacy = first([entry['performedBy'], entry['updatedBy']]);
    if (legacy.contains(RegExp(r'\s')) &&
        !placeholders.contains(legacy.toLowerCase()) &&
        !{
          text(entry['actorId']),
          text(submission.userId),
          text(submission.createdBy),
          text(viewerId),
        }.contains(legacy)) {
      displayName = legacy;
    }
  }
  if (resident) {
    final ownAction = actorId == viewerId || (filing && primaryOwner);
    if (submission.anonymous && !ownAction) displayName = null;
    if (displayName == null && ownAction) displayName = name(viewerName);
    if (displayName == null &&
        (filing || actorIsOwner) &&
        !submission.anonymous) {
      displayName = name(submission.residentName);
    }
    return '${filing ? 'Filed' : 'Updated'} by: ${displayName ?? 'Resident'}';
  }
  if (actorId.isEmpty && displayName == null && role.isEmpty) return '';
  final formattedRole = ComplaintRoleHelper.formatRole(role);
  final roleLabel = switch (role) {
    'super_admin' => 'Administrator',
    'lgu' => 'LGU Department Staff',
    'mayor' => 'Municipal Mayor',
    'organization' => 'Organization Staff',
    'official' || 'authorized official' => 'Official',
    'system' => 'System',
    '' => actorId.toLowerCase() == 'system' ? 'System' : 'Official',
    _ => formattedRole == role ? 'Official' : formattedRole,
  };
  return 'Updated by: ${displayName ?? roleLabel}';
}
