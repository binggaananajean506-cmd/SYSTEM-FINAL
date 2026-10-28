import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../submission_service.dart';

/// Helper for resident complaint tracking views.
///
/// Ensures role-based displays, simplified status timeline mapping,
/// and friendly date/time formatting for non-tech-savvy residents.
class ComplaintRoleHelper {
  ComplaintRoleHelper._();

  /// History IDs identify actors; only explicit name fields are display names.
  static String historyActorLabel(
    Map<String, dynamic> entry,
    Submission submission, {
    String? viewerId,
    String? viewerName,
  }) {
    String text(dynamic value) => value?.toString().trim() ?? '';
    final actorId = text(entry['actorId']).isNotEmpty
        ? text(entry['actorId'])
        : text(entry['performedBy']).isNotEmpty
        ? text(entry['performedBy'])
        : text(entry['updatedBy']);
    final identifiers = {
      actorId,
      text(entry['performedBy']),
      text(entry['updatedBy']),
      text(submission.userId),
      text(submission.createdBy),
      text(viewerId),
    }..remove('');
    String? displayName(dynamic value) {
      final name = text(value);
      return name.isEmpty || identifiers.contains(name) ? null : name;
    }

    final status = text(entry['status']).toLowerCase();
    final action = text(entry['action']).toLowerCase();
    final filing =
        ['filed', 'new', 'submitted'].contains(status) ||
        [
          'file_complaint',
          'complaint_filed',
          'submit_complaint',
        ].contains(action);
    final rawRole = text(entry['actorRole'] ?? entry['actorType']);
    final complainant = actorId.isNotEmpty
        ? actorId == submission.userId || actorId == submission.createdBy
        : filing &&
              (rawRole.isEmpty ||
                  ['resident', 'complainant'].contains(rawRole.toLowerCase()));
    final role = complainant
        ? 'Resident'
        : rawRole.isNotEmpty && !identifiers.contains(rawRole)
        ? formatRole(rawRole)
        : fallbackRole(action: action, status: status);
    var name =
        displayName(entry['actorName']) ??
        displayName(entry['performedByName']) ??
        displayName(entry['updatedByName']);
    if (name == null && complainant) {
      name = displayName(submission.residentName);
    }
    if (name == null &&
        viewerId?.isNotEmpty == true &&
        (actorId == viewerId ||
            (complainant && submission.isAssociatedWithUser(viewerId)))) {
      name = displayName(viewerName);
    }
    if (role == 'Resident') {
      return '${filing ? 'Filed' : 'Updated'} by ${name ?? 'Resident'}';
    }
    return name == null ? role : '$name · $role';
  }

  static final Map<String, String> _roleCache = {};

  /// Resolves the role dynamically from the authorized user's account or entry.
  ///
  /// IMPORTANT: Always returns the official ROLE (e.g., "Barangay Official",
  /// "Barangay Lupon", "Barangay Tanod", "Punong Barangay"), NEVER the person's name.
  static String resolveRole({
    String? actorId,
    String? actorRole,
    String? actorName,
    String? action,
    String? status,
    Submission? submission,
  }) {
    // 1. If actor is the resident complainant who filed it
    if (submission != null && actorId != null && actorId.isNotEmpty) {
      if (submission.userId == actorId || submission.createdBy == actorId) {
        return 'Resident';
      }
    }

    // 2. Check memory cache for previously fetched user roles
    if (actorId != null &&
        actorId.isNotEmpty &&
        _roleCache.containsKey(actorId)) {
      return _roleCache[actorId]!;
    }

    // 3. If actorRole was directly passed from backend event
    if (actorRole != null && actorRole.trim().isNotEmpty) {
      final formatted = formatRole(actorRole);
      if (actorId != null && actorId.isNotEmpty) {
        _roleCache[actorId] = formatted;
      }
      return formatted;
    }

    // 4. Trigger background fetch for the authorized user's Firestore document
    if (actorId != null && actorId.trim().isNotEmpty && actorId.length >= 10) {
      _fetchUserRole(actorId.trim());
    }

    // 5. Fallback based on actor name hints, workflow status, or action
    return fallbackRole(action: action, status: status, actorName: actorName);
  }

  static void _fetchUserRole(String userId) {
    if (_roleCache.containsKey(userId)) return;
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .then((doc) {
            if (!doc.exists || doc.data() == null) return;
            final data = doc.data()!;
            final posTitle = data['positionTitle']?.toString().trim();
            final staffRole = (data['staffRole'] ?? data['role'])
                ?.toString()
                .trim();
            final chosen = (posTitle != null && posTitle.isNotEmpty)
                ? posTitle
                : (staffRole ?? '');
            final resolved = formatRole(chosen);
            _roleCache[userId] = resolved;
          })
          .catchError((_) {
            // Silently preserve offline/rule fallback
          });
    } catch (_) {}
  }

  /// Normalizes any raw role or designation string into standard resident-facing role names.
  static String formatRole(String rawRole) {
    final lower = rawRole.trim().toLowerCase();
    if (lower.isEmpty) return 'Barangay Official';

    if (lower.contains('lupon')) return 'Barangay Lupon';
    if (lower.contains('tanod')) return 'Barangay Tanod';
    if (lower.contains('vice') && lower.contains('captain')) {
      return 'Barangay Vice Captain';
    }
    if (lower.contains('captain') || lower.contains('punong')) {
      return 'Punong Barangay';
    }
    if (lower.contains('secretary')) return 'Barangay Secretary';
    if (lower.contains('councilor') || lower.contains('kagawad')) {
      return 'Barangay Councilor';
    }
    if (lower.contains('treasurer')) return 'Barangay Treasurer';
    if (lower == 'resident' || lower == 'complainant') return 'Resident';
    if (lower == 'super_admin' ||
        lower == 'admin' ||
        lower == 'lgu' ||
        lower.contains('official')) {
      return 'Barangay Official';
    }
    if (lower.contains('barangay')) return 'Barangay Official';

    // Capitalize custom positions like "Mediation Officer"
    return rawRole.trim();
  }

  /// Safe context-based fallback based on the complaint process step.
  static String fallbackRole({
    String? action,
    String? status,
    String? actorName,
  }) {
    final act = (action ?? '').toLowerCase();
    final st = (status ?? '').toLowerCase();
    final name = (actorName ?? '').toLowerCase();

    // If actorName contained role keywords (e.g. "Barangay Tanod on duty")
    if (name.contains('tanod')) return 'Barangay Tanod';
    if (name.contains('lupon')) return 'Barangay Lupon';
    if (name.contains('captain') || name.contains('punong')) {
      return 'Punong Barangay';
    }
    if (name.contains('secretary')) return 'Barangay Secretary';
    if (name.contains('councilor') || name.contains('kagawad')) {
      return 'Barangay Councilor';
    }

    if (act.contains('tanod') ||
        act.contains('deliver') ||
        st.contains('tanod') ||
        st.contains('deliver')) {
      return 'Barangay Tanod';
    }
    if (act.contains('hearing') ||
        act.contains('mediation') ||
        act.contains('schedule') ||
        st.contains('hearing')) {
      return 'Barangay Lupon';
    }
    if (act.contains('summons') || st.contains('summons')) {
      return 'Barangay Official';
    }
    if (act.contains('filed') ||
        act.contains('submit') ||
        st.contains('filed') ||
        st.contains('new')) {
      return 'Resident';
    }
    return 'Barangay Official';
  }

  /// Maps technical timeline status strings into simplified, resident-friendly titles.
  static String simplifyStatus(
    String rawStatus, {
    String? action,
    String? label,
  }) {
    final s = rawStatus.toLowerCase().trim();
    final a = (action ?? '').toLowerCase().trim();
    final l = (label ?? '').toLowerCase().trim();

    if (l.contains('handed to barangay tanod') ||
        l.contains('summons delivered') ||
        s.contains('summons_delivered') ||
        s.contains('handed_to_tanod') ||
        a.contains('hand_to_tanod') ||
        a.contains('deliver')) {
      return 'Summons Delivered';
    }

    if (l.contains('official summons issued') ||
        l.contains('summons issued') ||
        s.contains('summons_issued') ||
        a.contains('issue_summons')) {
      return 'Summons Issued';
    }

    if (l.contains('hearing scheduled') ||
        s.contains('hearing_scheduled') ||
        s.contains('mediation') ||
        a.contains('schedule')) {
      return 'Hearing Scheduled';
    }

    if (l.contains('under review') ||
        s.contains('under_review') ||
        s.contains('being_handled') ||
        s.contains('in_review') ||
        a.contains('review')) {
      return 'Under Review';
    }

    if (l.contains('filed') ||
        s.contains('filed') ||
        s.contains('new') ||
        s.contains('submitted') ||
        a.contains('submit')) {
      return 'Complaint Filed';
    }

    if (s.contains('needs_information') ||
        s.contains('awaiting_resident') ||
        a.contains('request_information')) {
      return 'Information Requested';
    }

    if (s.contains('resolved') ||
        s.contains('settled') ||
        a.contains('resolve')) {
      return 'Complaint Resolved';
    }

    if (s.contains('unsettled') ||
        s.contains('closed') ||
        a.contains('close')) {
      return 'Case Closed';
    }

    if (s.contains('awaiting_next_schedule') ||
        s.contains('for_next_hearing')) {
      return 'Awaiting Next Schedule';
    }

    return label?.isNotEmpty == true
        ? label!
        : complaintTrackingStatusLabel(rawStatus);
  }

  /// Friendly, short date format (e.g. "Oct 13, 2026").
  static String formatFriendlyDate(dynamic rawDate) {
    if (rawDate == null) return 'Date pending';
    if (rawDate is DateTime) {
      return DateFormat('MMM d, y').format(rawDate);
    }
    if (rawDate is Timestamp) {
      return DateFormat('MMM d, y').format(rawDate.toDate());
    }
    final text = rawDate.toString().trim();
    if (text.isEmpty) return 'Date pending';
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return DateFormat('MMM d, y').format(parsed);
    }
    return text;
  }

  /// Friendly, short time format (e.g. "9:00 AM").
  static String formatFriendlyTime(dynamic rawTime) {
    if (rawTime == null) return '';
    final text = rawTime.toString().trim();
    if (text.isEmpty) return '';
    if (text.toUpperCase().contains('AM') ||
        text.toUpperCase().contains('PM')) {
      return text;
    }
    final parts = text.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        final period = hour >= 12 ? 'PM' : 'AM';
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final m = minute.toString().padLeft(2, '0');
        return '$h:$m $period';
      }
    }
    return text;
  }
}
