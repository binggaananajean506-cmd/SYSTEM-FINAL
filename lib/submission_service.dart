import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'firestore_converters.dart';

String normalizeSubmissionStatus(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );
  return switch (normalized) {
    '' ||
    'pending' ||
    'submitted' ||
    'resubmitted' ||
    'new' ||
    'received' ||
    'routed' ||
    'triaged' ||
    'acknowledged' => 'new',
    'assigned' ||
    'under_review' ||
    'being_reviewed' ||
    'reopened' ||
    'inprogress' ||
    'in_progress' ||
    'being_handled' =>
      'being_handled',
    'awaiting_resident' || 'needs_information' => 'needs_information',
    'resolved' || 'settled' || 'completed' => 'resolved',
    'rejected' || 'declined' || 'dismissed' => 'rejected',
    'closed' || 'withdrawn' || 'cancelled' || 'invalid' || 'unsettled' => 'closed',
    _ => normalized,
  };
}

String submissionStatusLabel(String value) {
  return switch (normalizeSubmissionStatus(value)) {
    'new' => 'Active',
    'being_handled' => 'In Progress',
    'needs_information' => 'Awaiting Information',
    'resolved' => 'Resolved',
    'rejected' => 'Rejected',
    'closed' => 'Closed',
    _ => 'In Progress',
  };
}

String complaintTrackingStatusLabel(String status) => switch (status) {
  'filed' || 'new' || 'submitted' => 'Filed',
  'under_review' || 'being_handled' => 'Under Review',
  'needs_information' || 'awaiting_resident' => 'Awaiting Resident Information',
  'hearing_scheduled' => 'Hearing Scheduled',
  'awaiting_cfa' => 'Awaiting CFA Issuance',
  'cfa_issued' => 'Closed — CFA Issued',
  'awaiting_next_schedule' || 'for_next_hearing' => 'Awaiting Next Schedule',
  'resolved' || 'settled' => 'Resolved',
  'unsettled' => 'Closed — Unsettled',
  'closed' => 'Closed',
  _ => status.replaceAll('_', ' '),
};

enum ConcernListFilter { all, active, resolved }

const complaintMaxHearingRounds = 6;
const complaintRoundsPerPhase = 3;
int complaintRoundNumber(dynamic value) => int.tryParse('$value') ?? 1;
bool isLuponRound(dynamic value) => complaintRoundNumber(value) > complaintRoundsPerPhase;
String complaintHearingLabel(dynamic value) {
  final number = complaintRoundNumber(value);
  final phaseNumber = (number - 1) % complaintRoundsPerPhase + 1;
  return '${isLuponRound(number) ? 'Lupon' : 'Barangay'} Hearing $phaseNumber of $complaintRoundsPerPhase · Round $number of $complaintMaxHearingRounds';
}

bool concernMatchesFilter(String status, ConcernListFilter filter) {
  final normalized = normalizeSubmissionStatus(status);
  return switch (filter) {
    ConcernListFilter.all => true,
    ConcernListFilter.active => !const {
      'resolved',
      'rejected',
      'closed',
      'cfa_issued',
    }.contains(normalized),
    ConcernListFilter.resolved => const {
      'resolved',
      'rejected',
      'closed',
      'cfa_issued',
    }.contains(normalized),
  };
}

class ResidentNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final bool read;
  final String severity;
  final String emergencyStatus;
  final bool acknowledged;
  final DateTime createdAt;
  final DateTime? readAt;
  final String route;
  final String relatedEntityType;
  final String priority;
  final Map<String, dynamic> metadata;

  const ResidentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.referenceId,
    required this.read,
    required this.createdAt,
    this.severity = '',
    this.emergencyStatus = '',
    this.acknowledged = false,
    this.readAt,
    this.route = '',
    this.relatedEntityType = '',
    this.priority = 'normal',
    this.metadata = const <String, dynamic>{},
  });

  bool get isEmergency => type == 'emergency_alert';

  String get displayMessage {
    if (!isEmergency) return message;
    if (acknowledged) return '$message\n✓ Acknowledged';
    if (const {'ended', 'cancelled', 'expired'}.contains(emergencyStatus)) {
      return '$message\nEmergency $emergencyStatus';
    }
    return '$message\nNot acknowledged';
  }

  factory ResidentNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final navigation = data['navigation'] is Map
        ? Map<String, dynamic>.from(data['navigation'] as Map)
        : const <String, dynamic>{};
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : const <String, dynamic>{};
    return ResidentNotification(
      id: document.id,
      title: data['title']?.toString() ?? 'Concern update',
      message: data['message']?.toString() ?? '',
      type: data['type']?.toString() ?? 'concern_update',
      referenceId: data['referenceId']?.toString(),
      read: data['read'] == true || data['isRead'] == true,
      severity: data['severity']?.toString() ?? '',
      emergencyStatus: data['emergencyStatus']?.toString() ?? '',
      acknowledged: data['acknowledged'] == true,
      createdAt: dateTimeFromFirestore(data['createdAt']),
      readAt: nullableDateTimeFromFirestore(data['readAt']),
      route: data['route']?.toString() ?? navigation['route']?.toString() ?? '',
      relatedEntityType: data['relatedEntityType']?.toString() ?? '',
      priority: data['priority']?.toString() ?? 'normal',
      metadata: metadata,
    );
  }
}

class Submission {
  final int schemaVersion;
  final String id;
  final String title;
  final String description;
  final String category;
  final String? categoryId;
  final String? organizationSector;
  final String visibility;
  final int reporterCount;
  final String? joinConcernId;
  final List<String> reporterIds;
  final bool joinedByCurrentUser;
  final String? customCategory;
  final String status;
  final DateTime date;
  final String type; // 'Complaint' or 'Report'
  final String? customConcernType;
  final String? department;
  final String? recipientType;
  final String? recipientId;
  final String? customRecipient;
  final String? userId;
  final String? createdBy;
  final String? residentName;
  final String? originalReporterName;
  final String? originalReporterPhotoUrl;
  final String? reporterName;
  final List<Map<String, dynamic>> reporters;
  final String? barangay;
  final String? barangayId;
  /// Optional receiving-office identity on stored concern/case documents.
  final String? receivingBarangayId;
  final String? receivingBarangayName;
  final String? location;
  final String? incidentDate;
  final String? requestedAction;
  final String? contactPreference;
  final bool anonymous;
  final String? draftId;
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final String? handlingNote;
  final String? handledBy;
  final String? handledByName;
  final String? handledByRole;
  final List<Map<String, dynamic>> statusHistory;
  final List<Map<String, dynamic>> residentResponses;

  /// 'concern' for service reports, 'complaint' for disputes with a person.
  final String kind;

  /// Complaint details: respondent, relationship, type and desired outcome.
  final Map<String, dynamic> complaint;

  /// The barangay summons once issued: hearing date, time and venue.
  final Map<String, dynamic>? summons;

  /// How a complaint ended: settled, referred, withdrawn or dismissed.
  final String? closureOutcome;

  /// Active hearing, mediation, or conciliation schedule.
  final Map<String, dynamic>? schedule;

  /// Past and current session schedules.
  final List<Map<String, dynamic>> schedules;

  /// Amicable settlement details if settled.
  final Map<String, dynamic>? settlement;

  /// Unsettled record if conciliation did not reach agreement.
  final Map<String, dynamic>? unsettledRecord;

  bool get isComplaint =>
      kind == 'complaint' ||
      category.toLowerCase().contains('complaint') ||
      categoryId == 'barangay_complaint' ||
      complaint.isNotEmpty ||
      id.startsWith('BC-');

  String get displayReporterName {
    final orig = originalReporterName?.trim();
    if (orig != null && orig.isNotEmpty && orig.toLowerCase() != 'resident') {
      return orig;
    }
    final rep = reporterName?.trim();
    if (rep != null && rep.isNotEmpty && rep.toLowerCase() != 'resident') {
      return rep;
    }
    final res = residentName?.trim();
    if (res != null && res.isNotEmpty && res.toLowerCase() != 'resident') {
      return res;
    }
    return 'Resident';
  }

  /// Deduplicated list of other residents who joined or reported the same concern.
  List<String> get otherReporterNames {
    final orig = displayReporterName.toLowerCase();
    final list = <String>[];
    for (final r in reporters) {
      final name = (r['name'] ?? r['reporterName'] ?? '').toString().trim();
      if (name.isNotEmpty &&
          name.toLowerCase() != 'resident' &&
          name.toLowerCase() != orig) {
        if (!list.contains(name)) list.add(name);
      }
    }
    return list;
  }

  /// Completed hearing attempts count; cancelled and not-held appointments do not.
  final List<Map<String, dynamic>> hearings;
  final List<Map<String, dynamic>> externalUpdates;
  final int complaintTrackingVersion;
  final int workflowVersion;
  final int legacyCompletedHearings;
  final String? resolutionSummary;

  int get completedHearingCount => legacyCompletedHearings +
      hearings.where((hearing) => hearing['status'] == 'completed').length;

  Map<String, dynamic>? get activeComplaintHearing {
    for (final hearing in hearings) {
      if (hearing['status'] == 'scheduled') return hearing;
    }
    return null;
  }

  bool get complaintFinished => const {
    'resolved', 'closed', 'settled', 'unsettled', 'invalid', 'withdrawn', 'dismissed', 'rejected', 'cfa_issued',
  }.contains(status);

  bool get complaintNeedsConfirmation => complaintTrackingVersion == 0 &&
      !complaintFinished && (summons != null || schedule != null || schedules.isNotEmpty ||
      const {'summons_issued', 'hearing_scheduled', 'mediation', 'final_conciliation', 'for_next_hearing'}.contains(status));

  String get complaintWorkflowStatus {
    return switch (status) {
      'new' || 'submitted' => 'filed',
      'being_handled' || 'in_review' => 'under_review',
      'awaiting_resident' => 'needs_information',
      'for_next_hearing' || 'next_hearing' => 'awaiting_next_schedule',
      _ => status,
    };
  }

  String get complaintStatusLabel {
    if (complaintFinished) {
      return switch (closureOutcome ?? status) {
        'settled' || 'resolved' => 'Resolved',
        'unsettled' => 'Closed — Unsettled',
        'cfa_issued' => 'Closed — CFA Issued',
        'invalid' => 'Invalid',
        'withdrawn' => 'Withdrawn',
        'dismissed' || 'rejected' => 'Dismissed (previous record)',
        'referred' => 'Closed — External referral recorded',
        _ => 'Closed',
      };
    }
    if (complaintNeedsConfirmation) return 'Previous Record — Awaiting Confirmation';
    final hearing = activeComplaintHearing;
    if (hearing != null) {
      final start = DateTime.tryParse("${hearing['date']}T${hearing['time']}:00+08:00");
      if (start != null && !DateTime.now().isBefore(start)) return 'Result Pending';
    }
    return complaintTrackingStatusLabel(complaintWorkflowStatus);
  }

  String get respondentDisplayName {
    final name = complaint['respondentName']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'Name not given';
  }


  Submission({
    this.schemaVersion = 2,
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.categoryId,
    this.organizationSector,
    this.visibility = 'public',
    this.reporterCount = 1,
    this.joinConcernId,
    this.reporterIds = const [],
    this.joinedByCurrentUser = false,
    this.customCategory,
    required this.status,
    required this.date,
    required this.type,
    this.customConcernType,
    this.department,
    this.recipientType,
    this.recipientId,
    this.customRecipient,
    this.userId,
    this.createdBy,
    this.residentName,
    this.originalReporterName,
    this.originalReporterPhotoUrl,
    this.reporterName,
    this.reporters = const [],
    this.barangay,
    this.barangayId,
    this.receivingBarangayId,
    this.receivingBarangayName,
    this.location,
    this.incidentDate,
    this.requestedAction,
    this.contactPreference,
    this.anonymous = false,
    this.draftId,
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.submittedAt,
    this.updatedAt,
    this.handlingNote,
    this.handledBy,
    this.handledByName,
    this.handledByRole,
    List<Map<String, dynamic>>? statusHistory,
    List<Map<String, dynamic>>? residentResponses,
    this.kind = 'concern',
    this.complaint = const {},
    this.summons,
    this.closureOutcome,
    this.schedule,
    this.schedules = const [],
    this.settlement,
    this.unsettledRecord,
    this.hearings = const [],
    this.externalUpdates = const [],
    this.complaintTrackingVersion = 0,
    this.workflowVersion = 0,
    this.legacyCompletedHearings = 0,
    this.resolutionSummary,
  }) : statusHistory =
           statusHistory ??
           [
             {
               'status': status,
               'note': 'Submission received',
               'date': date.toIso8601String(),
             },
           ],
       residentResponses = residentResponses ?? const [];


  Map<String, dynamic> toMap() {
    final effectiveUserId = userId ?? createdBy;
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      if (categoryId != null) 'categoryId': categoryId,
      if (organizationSector != null) 'organizationSector': organizationSector,
      'visibility': visibility,
      if (joinConcernId != null) 'joinConcernId': joinConcernId,
      if (reporterIds.isNotEmpty) 'reporterIds': reporterIds,
      if (customCategory != null && customCategory!.trim().isNotEmpty)
        'customCategory': customCategory!.trim(),
      if (originalReporterName != null && originalReporterName!.trim().isNotEmpty)
        'originalReporterName': originalReporterName!.trim(),
      if (originalReporterPhotoUrl != null && originalReporterPhotoUrl!.trim().isNotEmpty)
        'originalReporterPhotoUrl': originalReporterPhotoUrl!.trim(),
      if (reporterName != null && reporterName!.trim().isNotEmpty)
        'reporterName': reporterName!.trim(),
      if (reporters.isNotEmpty) 'reporters': reporters,
      'status': isComplaint ? status : normalizeSubmissionStatus(status),
      'date': Timestamp.fromDate(date),
      'type': type,
      if (customConcernType != null && customConcernType!.trim().isNotEmpty)
        'customConcernType': customConcernType!.trim(),
      'department': department,
      if (recipientType != null) 'recipientType': recipientType,
      if (recipientId != null && recipientId!.trim().isNotEmpty)
        'recipientId': recipientId!.trim(),
      if (customRecipient != null && customRecipient!.trim().isNotEmpty)
        'customRecipient': customRecipient!.trim(),
      'userId': effectiveUserId,
      'residentId': effectiveUserId,
      'createdBy': createdBy ?? effectiveUserId,
      'residentName': residentName,
      'barangay': barangay,
      if (barangayId != null && barangayId!.trim().isNotEmpty)
        'barangayId': barangayId!.trim(),
      if (receivingBarangayId != null)
        'receivingBarangayId': receivingBarangayId,
      if (receivingBarangayName != null)
        'receivingBarangayName': receivingBarangayName,
      'location': location,
      'incidentDate': incidentDate,
      'requestedAction': requestedAction,
      if (contactPreference?.trim().isNotEmpty == true)
        'contactPreference': contactPreference,
      'anonymous': anonymous,
      if (draftId != null) 'draftId': draftId,
      'attachmentUrl': attachmentUrl,
      'attachmentStoragePath': attachmentStoragePath,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': Timestamp.fromDate(updatedAt ?? date),
      if (handlingNote != null && handlingNote!.trim().isNotEmpty)
        'handlingNote': handlingNote!.trim(),
      if (handledBy != null) 'handledBy': handledBy,
      if (handledByName != null) 'handledByName': handledByName,
      if (handledByRole != null) 'handledByRole': handledByRole,
      'statusHistory': statusHistory,
      'residentResponses': residentResponses,
      'kind': kind,
      if (isComplaint) ...{
        'complaint': complaint, 'hearings': hearings, 'externalUpdates': externalUpdates,
        'complaintTrackingVersion': complaintTrackingVersion,
        'workflowVersion': workflowVersion,
        'legacyCompletedHearings': legacyCompletedHearings,
        'closureOutcome': closureOutcome, 'resolutionSummary': resolutionSummary,
        if (summons != null) 'summons': summons,
      },
      if (schedule != null) 'schedule': schedule,
      if (schedules.isNotEmpty) 'schedules': schedules,
      if (settlement != null) 'settlement': settlement,
      if (unsettledRecord != null) 'unsettledRecord': unsettledRecord,
    };
  }

  factory Submission.fromMap(
    Map<String, dynamic> map, {
    String? id,
    String? viewerId,
  }) {
    final rawStatus = map['status']?.toString() ?? 'submitted';
    final status = map['kind'] == 'complaint' || (map['id'] ?? id ?? '').toString().startsWith('BC-')
        ? rawStatus : normalizeSubmissionStatus(rawStatus);
    final date = dateTimeFromFirestore(map['date']);
    final origReporterMap = map['originalReporter'] is Map
        ? Map<String, dynamic>.from(map['originalReporter'] as Map)
        : null;
    final effectiveUserId =
        (map['userId'] ?? map['residentId'] ?? map['createdBy'] ?? origReporterMap?['id'])?.toString();
    final reporterIdsList = (map['reporterIds'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final effectiveId = (map['id'] as String?)?.trim().isNotEmpty == true
        ? (map['id'] as String).trim()
        : (id?.trim().isNotEmpty == true ? id!.trim() : '');
    final rawHandlingNote = (map['handlingNote'] as String?)?.trim();
    final rawProgressNote = (map['progressNote'] as String?)?.trim();
    String? historyNote;
    if (map['statusHistory'] is List) {
      for (final item in (map['statusHistory'] as List).reversed) {
        if (item is Map) {
          final noteVal = (item['note'] ?? item['reason'] ?? item['remarks'] ?? item['message'])?.toString().trim();
          if (noteVal != null && noteVal.isNotEmpty && noteVal != 'Submission received') {
            historyNote = noteVal;
            break;
          }
        }
      }
    }
    final resolvedHandlingNote = (rawHandlingNote != null && rawHandlingNote.isNotEmpty)
        ? rawHandlingNote
        : (rawProgressNote != null && rawProgressNote.isNotEmpty)
            ? rawProgressNote
            : historyNote;

    return Submission(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      id: effectiveId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      categoryId: map['categoryId']?.toString(),
      organizationSector: map['organizationSector']?.toString(),
      visibility: map['visibility']?.toString() ?? 'public',
      reporterCount: (map['reporterCount'] as num?)?.toInt() ?? 1,
      joinConcernId: map['joinConcernId']?.toString(),
      reporterIds: reporterIdsList,
      joinedByCurrentUser:
          viewerId != null &&
          viewerId.isNotEmpty &&
          effectiveUserId != viewerId &&
          reporterIdsList.contains(viewerId),
      customCategory: map['customCategory'] as String?,
      status: status,
      date: date,
      type: map['type'] ?? 'Report',
      customConcernType: map['customConcernType'] as String?,
      department: map['department'],
      recipientType: map['recipientType'] as String?,
      recipientId: map['recipientId'] as String?,
      customRecipient: map['customRecipient'] as String?,
      userId: effectiveUserId,
      createdBy: map['createdBy']?.toString() ?? effectiveUserId,
      residentName: map['residentName'],
      originalReporterName: (map['originalReporterName'] ??
              origReporterMap?['name'] ??
              (map['originalReporter'] is! Map ? map['originalReporter'] : null) ??
              map['reporterName'] ??
              map['submitterName'] ??
              (map['residentName']?.toString().toLowerCase() != 'resident'
                  ? map['residentName']
                  : null))
          ?.toString()
          .trim(),
      originalReporterPhotoUrl: (map['originalReporterPhotoUrl'] ??
              origReporterMap?['photoUrl'] ??
              map['reporterPhotoUrl'] ??
              map['profilePhotoUrl'] ??
              map['photoUrl'])
          ?.toString()
          .trim(),
      reporterName: (map['reporterName'] ??
              map['originalReporterName'] ??
              map['submitterName'] ??
              map['residentName'])
          ?.toString()
          .trim(),
      reporters: (map['reporters'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          (map['linkedReporters'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          (map['reporterNames'] as List<dynamic>?)
              ?.map((item) => item.toString().trim())
              .where((name) => name.isNotEmpty && name.toLowerCase() != 'resident')
              .map((name) => {'name': name})
              .toList() ??
          const <Map<String, dynamic>>[],
      barangay: map['barangay'],
      barangayId: map['barangayId'] as String?,
      receivingBarangayId: map['receivingBarangayId']?.toString(),
      receivingBarangayName: map['receivingBarangayName']?.toString(),
      location: map['location'],
      incidentDate: map['incidentDate'],
      requestedAction: map['requestedAction'],
      contactPreference: map['contactPreference'],
      anonymous: map['anonymous'] ?? false,
      draftId: map['draftId'] as String?,
      attachmentUrl: map['attachmentUrl'],
      attachmentStoragePath: map['attachmentStoragePath'],
      submittedAt: nullableDateTimeFromFirestore(map['submittedAt']) ?? date,
      updatedAt: nullableDateTimeFromFirestore(map['updatedAt']),
      handlingNote: resolvedHandlingNote,
      handledBy: map['handledBy']?.toString(),
      handledByName: map['handledByName']?.toString(),
      handledByRole: map['handledByRole']?.toString(),
      statusHistory:
          (map['statusHistory'] as List<dynamic>?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          [
            {
              'status': status,
              'note': 'Submission received',
              'date': date.toIso8601String(),
            },
          ],
      residentResponses:
          (map['residentResponses'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      kind: map['kind']?.toString() == 'complaint' ? 'complaint' : 'concern',
      complaint: map['complaint'] is Map
          ? Map<String, dynamic>.from(map['complaint'] as Map)
          : const {},
      summons: map['summons'] is Map
          ? Map<String, dynamic>.from(map['summons'] as Map)
          : null,
      closureOutcome: map['closureOutcome']?.toString(),
      hearings: (map['hearings'] as List? ?? const []).whereType<Map>().map((h) => Map<String, dynamic>.from(h)).toList(),
      externalUpdates: (map['externalUpdates'] as List? ?? const []).whereType<Map>().map((h) => Map<String, dynamic>.from(h)).toList(),
      complaintTrackingVersion: (map['complaintTrackingVersion'] as num?)?.toInt() ?? 0,
      workflowVersion: (map['workflowVersion'] as num?)?.toInt() ?? 0,
      legacyCompletedHearings: (map['legacyCompletedHearings'] as num?)?.toInt() ?? 0,
      resolutionSummary: map['resolutionSummary']?.toString(),
      schedule: map['schedule'] is Map
          ? Map<String, dynamic>.from(map['schedule'] as Map)
          : null,
      schedules: (map['schedules'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      settlement: map['settlement'] is Map
          ? Map<String, dynamic>.from(map['settlement'] as Map)
          : null,
      unsettledRecord: map['unsettledRecord'] is Map
          ? Map<String, dynamic>.from(map['unsettledRecord'] as Map)
          : null,
    );
  }


  String get statusLabel => isComplaint ? complaintStatusLabel : submissionStatusLabel(status);

  List<Map<String, dynamic>> get publicStatusHistory => statusHistory
      .where((entry) => entry['visibility']?.toString() != 'internal')
      .toList(growable: false);

  DateTime get lastUpdatedAt => updatedAt ?? date;

  bool isAssociatedWithUser(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    return userId == currentUserId ||
        createdBy == currentUserId ||
        reporterIds.contains(currentUserId);
  }

  Submission copyWith({
    int? schemaVersion,
    String? id,
    String? title,
    String? description,
    String? category,
    String? categoryId,
    String? organizationSector,
    String? visibility,
    int? reporterCount,
    String? joinConcernId,
    List<String>? reporterIds,
    bool? joinedByCurrentUser,
    String? customCategory,
    String? status,
    DateTime? date,
    String? type,
    String? customConcernType,
    String? department,
    String? recipientType,
    String? recipientId,
    String? customRecipient,
    String? userId,
    String? createdBy,
    String? residentName,
    String? originalReporterName,
    String? reporterName,
    List<Map<String, dynamic>>? reporters,
    String? barangay,
    String? barangayId,
    String? receivingBarangayId,
    String? receivingBarangayName,
    String? location,
    String? incidentDate,
    String? requestedAction,
    String? contactPreference,
    bool? anonymous,
    String? draftId,
    String? attachmentUrl,
    String? attachmentStoragePath,
    DateTime? submittedAt,
    DateTime? updatedAt,
    String? handlingNote,
    String? handledBy,
    String? handledByName,
    String? handledByRole,
    List<Map<String, dynamic>>? statusHistory,
    List<Map<String, dynamic>>? residentResponses,
    Map<String, dynamic>? schedule,
    List<Map<String, dynamic>>? schedules,
    Map<String, dynamic>? settlement,
    Map<String, dynamic>? unsettledRecord,
  }) {
    return Submission(
      kind: kind,
      complaint: complaint,
      summons: summons,
      closureOutcome: closureOutcome,
      hearings: hearings,
      externalUpdates: externalUpdates,
      complaintTrackingVersion: complaintTrackingVersion,
      workflowVersion: workflowVersion,
      legacyCompletedHearings: legacyCompletedHearings,
      resolutionSummary: resolutionSummary,
      schedule: schedule ?? this.schedule,
      schedules: schedules ?? this.schedules,
      settlement: settlement ?? this.settlement,
      unsettledRecord: unsettledRecord ?? this.unsettledRecord,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      organizationSector: organizationSector ?? this.organizationSector,
      visibility: visibility ?? this.visibility,
      reporterCount: reporterCount ?? this.reporterCount,
      joinConcernId: joinConcernId ?? this.joinConcernId,
      reporterIds: reporterIds ?? this.reporterIds,
      joinedByCurrentUser: joinedByCurrentUser ?? this.joinedByCurrentUser,
      customCategory: customCategory ?? this.customCategory,
      status: status ?? this.status,
      date: date ?? this.date,
      type: type ?? this.type,
      customConcernType: customConcernType ?? this.customConcernType,
      department: department ?? this.department,
      recipientType: recipientType ?? this.recipientType,
      recipientId: recipientId ?? this.recipientId,
      customRecipient: customRecipient ?? this.customRecipient,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      residentName: residentName ?? this.residentName,
      originalReporterName: originalReporterName ?? this.originalReporterName,
      reporterName: reporterName ?? this.reporterName,
      reporters: reporters ?? this.reporters,
      barangay: barangay ?? this.barangay,
      barangayId: barangayId ?? this.barangayId,
      receivingBarangayId: receivingBarangayId ?? this.receivingBarangayId,
      receivingBarangayName: receivingBarangayName ?? this.receivingBarangayName,
      location: location ?? this.location,
      incidentDate: incidentDate ?? this.incidentDate,
      requestedAction: requestedAction ?? this.requestedAction,
      contactPreference: contactPreference ?? this.contactPreference,
      anonymous: anonymous ?? this.anonymous,
      draftId: draftId ?? this.draftId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentStoragePath: attachmentStoragePath ?? this.attachmentStoragePath,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      handlingNote: handlingNote ?? this.handlingNote,
      handledBy: handledBy ?? this.handledBy,
      handledByName: handledByName ?? this.handledByName,
      handledByRole: handledByRole ?? this.handledByRole,
      statusHistory: statusHistory ?? this.statusHistory,
      residentResponses: residentResponses ?? this.residentResponses,
    );
  }
}


abstract interface class SubmissionRepository {
  Stream<List<Submission>> submissionsForUser(String userId);

  Future<Submission> addSubmission(Submission submission);

  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl,
    String attachmentStoragePath,
  });

  Future<Submission> resubmitConcern(Submission submission);
}

class FirebaseSubmissionRepository implements SubmissionRepository {
  const FirebaseSubmissionRepository();

  @override
  Stream<List<Submission>> submissionsForUser(String userId) =>
      SubmissionService.submissionsForUser(userId);

  @override
  Future<Submission> addSubmission(Submission submission) =>
      SubmissionService.addSubmission(submission);

  @override
  Future<Submission> resubmitConcern(Submission submission) =>
      SubmissionService.resubmitConcern(submission);

  @override
  Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) => SubmissionService.addResidentInformation(
    submissionId: submissionId,
    userId: userId,
    message: message,
    attachmentUrl: attachmentUrl,
    attachmentStoragePath: attachmentStoragePath,
  );
}

class SubmissionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<List<Map<String, String>>> concernCategories() async {
    final response =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable('getConcernCategories')
            .call<Map<String, dynamic>>({'organizationSectors': true});
    final categories = response.data['categories'];
    if (categories is! List) {
      throw StateError('Concern categories are unavailable.');
    }
    return categories
        .whereType<Map>()
        .map(
          (item) => {
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'example': item['example']?.toString() ?? '',
            'sector': item['sector']?.toString() ?? '',
          },
        )
        .where((item) => item['id']!.isNotEmpty)
        .toList(growable: false);
  }

  static final Map<String, List<Map<String, String>>> _concernOrganizationsCache = {};

  static Future<List<Map<String, String>>> concernOrganizations(
    String categoryId,
    String organizationSector,
  ) async {
    final cacheKey = '$categoryId:$organizationSector';
    if (_concernOrganizationsCache.containsKey(cacheKey)) {
      return _concernOrganizationsCache[cacheKey]!;
    }

    try {
      final response = await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('listConcernOrganizations').call<Map<String, dynamic>>({
        'categoryId': categoryId,
        'organizationSector': organizationSector,
      }).timeout(const Duration(seconds: 4));

      final orgs = (response.data['organizations'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => {
              'id': item['id']?.toString() ?? '',
              'name': item['name']?.toString() ?? '',
            },
          )
          .where((item) => item['id']!.isNotEmpty)
          .toList(growable: false);

      if (orgs.isNotEmpty) {
        _concernOrganizationsCache[cacheKey] = orgs;
      }
      return orgs;
    } catch (_) {
      if (_concernOrganizationsCache.containsKey(cacheKey)) {
        return _concernOrganizationsCache[cacheKey]!;
      }
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> similarPublicConcerns(
    Submission submission,
  ) async {
    final response =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable('findSimilarPublicConcerns')
            .call<Map<String, dynamic>>({
              'categoryId': submission.categoryId,
              'organizationSector': submission.organizationSector,
              'barangay': submission.barangay,
              'barangayId': submission.barangayId,
              'incidentDate': submission.incidentDate,
              'location': submission.location,
            });
    return (response.data['matches'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<Submission> addSubmission(Submission submission) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('submitConcern');
    final response = await callable.call<Map<String, dynamic>>({
      'id': submission.id,
      'title': submission.title,
      'description': submission.description,
      'category': submission.category,
      'categoryId': submission.categoryId,
      'organizationSector': submission.organizationSector,
      'recipientType': submission.recipientType,
      if (submission.recipientType != 'barangay')
        'organizationId': submission.recipientId,
      'visibility': submission.visibility,
      'joinConcernId': submission.joinConcernId,
      'barangay': submission.barangay,
      'barangayId': submission.barangayId,
      'customCategory': submission.customCategory,
      'concernType': submission.type,
      'customConcernType': submission.customConcernType,
      'residentName': submission.residentName,
      'location': submission.location,
      'incidentDate': submission.incidentDate,
      'requestedAction': submission.requestedAction,
      'draftId': submission.draftId,
      'attachmentUrl': submission.attachmentUrl,
      'attachmentStoragePath': submission.attachmentStoragePath,
    });
    final route = response.data;
    return Submission(
      schemaVersion: submission.schemaVersion,
      id: route['id']?.toString() ?? submission.id,
      title: submission.title,
      description: submission.description,
      category: submission.category,
      categoryId: submission.categoryId,
      organizationSector: submission.organizationSector,
      visibility: submission.visibility,
      reporterCount:
          (route['reporterCount'] as num?)?.toInt() ?? submission.reporterCount,
      joinConcernId: route['joined'] == true ? route['id']?.toString() : null,
      customCategory: submission.customCategory,
      status: normalizeSubmissionStatus(submission.status),
      date: submission.date,
      type: submission.type,
      customConcernType: submission.customConcernType,
      department: route['department']?.toString() ?? submission.department,
      recipientType:
          route['recipientType']?.toString() ?? submission.recipientType,
      recipientId: route['recipientId']?.toString() ?? submission.recipientId,
      customRecipient: submission.customRecipient,
      userId: submission.userId,
      createdBy: submission.createdBy ?? submission.userId,
      residentName: submission.residentName,
      barangay: route['barangay']?.toString() ?? submission.barangay,
      barangayId: route['barangayId']?.toString() ?? submission.barangayId,
      location: submission.location,
      incidentDate: submission.incidentDate,
      requestedAction: submission.requestedAction,
      contactPreference: submission.contactPreference,
      anonymous: submission.anonymous,
      draftId: submission.draftId,
      attachmentUrl: submission.attachmentUrl,
      attachmentStoragePath: submission.attachmentStoragePath,
      submittedAt: submission.submittedAt,
      updatedAt: submission.updatedAt,
      statusHistory: submission.statusHistory,
      residentResponses: submission.residentResponses,
    );
  }

  static Future<Submission> resubmitConcern(Submission submission) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('resubmitConcern');
    final response = await callable.call<Map<String, dynamic>>({
      'id': submission.id,
      'submissionId': submission.id,
      'title': submission.title,
      'description': submission.description,
      'category': submission.category,
      'categoryId': submission.categoryId,
      'organizationSector': submission.organizationSector,
      'concernType': submission.type,
      'customConcernType': submission.customConcernType,
      'location': submission.location,
      'incidentDate': submission.incidentDate,
      'visibility': submission.visibility,
      'attachmentUrl': submission.attachmentUrl,
      'attachmentStoragePath': submission.attachmentStoragePath,
    });
    final route = response.data;
    return submission.copyWith(
      id: route['id']?.toString() ?? submission.id,
      status: 'new',
      updatedAt: DateTime.now(),
    );
  }

  static Future<void> addResidentInformation({
    required String submissionId,
    required String userId,
    required String message,
    String attachmentUrl = '',
    String attachmentStoragePath = '',
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.length < 3 || trimmedMessage.length > 1000) {
      throw ArgumentError(
        'Additional information must be 3 to 1000 characters.',
      );
    }

    final reference = _firestore.collection('submissions').doc(submissionId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Concern not found.');
      }
      if ((data['userId'] ?? data['residentId'])?.toString() != userId) {
        throw StateError('You cannot update this concern.');
      }
      if (normalizeSubmissionStatus(data['status']?.toString() ?? '') !=
          'needs_information') {
        throw StateError('This concern is not waiting for more information.');
      }

      final now = Timestamp.now();
      const resumeStatus = 'being_handled';
      transaction.update(reference, {
        'status': resumeStatus,
        'updatedAt': now,
        'updatedBy': userId,
        'residentResponses': FieldValue.arrayUnion([
          {
            'message': trimmedMessage,
            'attachmentUrl': attachmentUrl,
            'attachmentStoragePath': attachmentStoragePath,
            'userId': userId,
            'date': now,
          },
        ]),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': resumeStatus,
            'action': 'resident_information_provided',
            'note': 'Resident provided the requested information.',
            'date': now,
            'performedBy': userId,
            'performedAt': now,
            'visibility': 'public',
            'actorType': 'resident',
            'actorId': userId,
          },
        ]),
      });
    });
  }

  static Stream<List<Submission>> submissionsForUser(String userId) {
    late StreamController<List<Submission>> controller;
    StreamSubscription? ownSubscription;
    StreamSubscription? joinedSubscription;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> own = [];
    List<QueryDocumentSnapshot<Map<String, dynamic>>> joined = [];
    var joinedFailed = false;

    void emit() {
      final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final document in own) document.id: document,
        for (final document in joined) document.id: document,
      };
      final submissions =
          documents.values
              .map(
                (document) =>
                    Submission.fromMap(document.data(), id: document.id, viewerId: userId),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
      controller.add(submissions);
    }

    // Fetches joined concerns from server as a one-shot fallback when the real-time
    // listener fails (e.g., permission error, missing index). This ensures that
    // co-reported concerns still appear in "My Concerns" even if live updates stop.
    Future<void> fetchJoinedFallback() async {
      try {
        final snapshot = await _firestore
            .collection('submissions')
            .where('reporterIds', arrayContains: userId)
            .limit(50)
            .get(const GetOptions(source: Source.server));
        joined = snapshot.docs;
        emit();
      } catch (err) {
        debugPrint('[SubmissionService] joined fallback fetch also failed: $err');
        // Keep joined as-is so own submissions are still shown.
      }
    }

    controller = StreamController<List<Submission>>(
      onListen: () {
        void listenOwnFallback() {
          ownSubscription = _firestore
              .collection('submissions')
              .where('userId', isEqualTo: userId)
              .limit(50)
              .snapshots()
              .listen((snapshot) {
                own = snapshot.docs;
                emit();
              }, onError: (err) {
                debugPrint('[SubmissionService] own query fallback error: $err');
                own = [];
                emit();
              });
        }

        try {
          ownSubscription = _firestore
              .collection('submissions')
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true)
              .limit(50)
              .snapshots()
              .listen((snapshot) {
                own = snapshot.docs;
                emit();
              }, onError: (err) {
                debugPrint('[SubmissionService] own query error with orderBy, trying fallback: $err');
                listenOwnFallback();
              });
        } catch (_) {
          listenOwnFallback();
        }
        joinedSubscription = _firestore
            .collection('submissions')
            .where('reporterIds', arrayContains: userId)
            .limit(50)
            .snapshots()
            .listen((snapshot) {
              joinedFailed = false;
              joined = snapshot.docs;
              emit();
            }, onError: (error) {
              debugPrint('[SubmissionService] joined query error — will fetch from server: $error');
              if (!joinedFailed) {
                joinedFailed = true;
                // Attempt a one-shot server fetch so joined concerns still appear.
                fetchJoinedFallback();
              }
            });
      },
      onCancel: () async {
        await ownSubscription?.cancel();
        await joinedSubscription?.cancel();
      },
    );
    return controller.stream;
  }


  static Future<List<Submission>> fetchSubmissionsForUserFromServer(
    String userId,
  ) async {
    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await _firestore
          .collection('submissions')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(50)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      try {
        snapshot = await _firestore
            .collection('submissions')
            .where('userId', isEqualTo: userId)
            .limit(50)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        snapshot = null;
      }
    }
    QuerySnapshot<Map<String, dynamic>>? joined;
    try {
      joined = await _firestore
          .collection('submissions')
          .where('reporterIds', arrayContains: userId)
          .limit(50)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      joined = null;
    }
    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      if (snapshot != null) for (final document in snapshot.docs) document.id: document,
      if (joined != null) for (final document in joined.docs) document.id: document,
    };
    return documents.values
        .map(
          (document) => Submission.fromMap(document.data(), id: document.id, viewerId: userId),
        )
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Stream<List<Submission>> publicConcernsForBarangay(String barangayId) {
    return _firestore
        .collection('public_concern_summaries')
        .where('barangayId', isEqualTo: barangayId)
        .where('visibility', isEqualTo: 'public')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((document) => Submission.fromMap(document.data(), id: document.id))
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  static Stream<List<ResidentNotification>> notificationsForUser(
    String userId,
  ) {
    // Return a fresh Firestore listener for each StreamBuilder. A cached
    // broadcast stream does not replay its latest snapshot to late listeners;
    // the header bell consumed the first event and left the inbox waiting on a
    // blank screen until another notification changed in Firestore.
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ResidentNotification.fromDoc)
              .toList(growable: false),
        );
  }

  static Future<List<ResidentNotification>> fetchNotificationsFromServer(
    String userId,
  ) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map(ResidentNotification.fromDoc)
        .toList(growable: false);
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markNotificationsRead(
    Iterable<String> notificationIds,
  ) async {
    final ids = notificationIds.toSet().where((id) => id.isNotEmpty).toList();
    for (var offset = 0; offset < ids.length; offset += 400) {
      final batch = _firestore.batch();
      for (final id in ids.skip(offset).take(400)) {
        batch.update(_firestore.collection('notifications').doc(id), {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  static String formatRelativeTime(DateTime? date, {String? defaultTimeAgo}) {
    if (defaultTimeAgo != null && defaultTimeAgo.trim().isNotEmpty) {
      return defaultTimeAgo.trim();
    }
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    }
    final years = (diff.inDays / 365).floor();
    return '$years ${years == 1 ? "year" : "years"} ago';
  }

  static final Map<String, Map<String, String>> _userProfileCache = {};

  /// Retrieves a cached user profile ({'name': ..., 'photoUrl': ...}) if available in memory.
  static Map<String, String>? getCachedUserProfile(String uid) {
    final clean = uid.trim();
    return _userProfileCache[clean];
  }

  /// Resolves the actual user profile (name and profile photo) from Firestore.
  static Future<Map<String, String>> resolveUserProfile(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return const {'name': '', 'photoUrl': ''};
    final cached = _userProfileCache[cleanUid];
    if (cached != null && (cached['name']?.isNotEmpty == true || cached['photoUrl']?.isNotEmpty == true)) {
      return cached;
    }
    try {
      final doc = await _firestore.collection('users').doc(cleanUid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? '').toString().trim();
        final photo = (data['profilePhotoUrl'] ?? data['photoUrl'] ?? data['avatarUrl'] ?? '').toString().trim();
        final profile = {'name': name, 'photoUrl': photo};
        _userProfileCache[cleanUid] = profile;
        return profile;
      }
    } catch (_) {}
    return const {'name': '', 'photoUrl': ''};
  }

  /// Fetches sanitized public concern reporters in batch for multiple concerns.
  static Future<Map<String, Map<String, dynamic>>> getPublicConcernReportersBatch(
    List<String> concernIds,
  ) async {
    final cleanIds = concernIds.where((id) => id.trim().isNotEmpty).toList();
    if (cleanIds.isEmpty) return const {};
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('getPublicConcernReporters');
      final result = await callable.call<Map<String, dynamic>>({
        'concernIds': cleanIds,
      });
      final raw = result.data['results'];
      if (raw is Map) {
        final Map<String, Map<String, dynamic>> mapped = {};
        for (final entry in raw.entries) {
          final val = Map<String, dynamic>.from(entry.value as Map);
          if (!val.containsKey('joinedReporters') && val.containsKey('reporters')) {
            val['joinedReporters'] = val['reporters'];
          }
          if (!val.containsKey('totalCount') && val.containsKey('count')) {
            val['totalCount'] = val['count'];
          }
          // Cache user profile for original reporter if available
          final orig = val['originalReporter'];
          if (orig is Map) {
            final uid = (orig['id'] ?? '').toString().trim();
            final name = (orig['name'] ?? '').toString().trim();
            final photo = (orig['photoUrl'] ?? '').toString().trim();
            if (uid.isNotEmpty && name.isNotEmpty && name.toLowerCase() != 'resident') {
              _userProfileCache[uid] = {'name': name, 'photoUrl': photo};
            }
          }
          mapped[entry.key.toString()] = val;
        }
        return mapped;
      }
    } catch (_) {}
    return const {};
  }

  /// Fetches the sanitized public concern reporters list.
  /// Deduplicates entries and excludes private details (no contact, email, address, evidence).
  static Future<Map<String, dynamic>> getPublicConcernReporters(
    String concernId, {
    Submission? fallbackSubmission,
  }) async {
    Map<String, dynamic>? result;

    // 1. Try Firebase Cloud Functions callable 'getPublicConcernReporters'
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('getPublicConcernReporters');
      final res = await callable.call<Map<String, dynamic>>({
        'concernId': concernId,
      });
      final data = res.data;
      if (data.isNotEmpty) {
        result = Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    // 2. Try direct Firestore read on submissions/{concernId}/reports
    if (result == null) {
      try {
        final reportsSnap = await _firestore
            .collection('submissions')
            .doc(concernId)
            .collection('reports')
            .get();
        if (reportsSnap.docs.isNotEmpty) {
          final List<Map<String, dynamic>> joined = [];
          final Set<String> seenIds = {};
          if (fallbackSubmission?.userId != null &&
              fallbackSubmission!.userId!.isNotEmpty) {
            seenIds.add(fallbackSubmission.userId!);
          }
          for (final doc in reportsSnap.docs) {
            final data = doc.data();
            final id = (data['reporterId'] ?? doc.id).toString().trim();
            if (id.isNotEmpty && seenIds.contains(id)) continue;
            if (id.isNotEmpty) seenIds.add(id);
            joined.add({
              'id': id,
              'name': (data['reporterName'] ?? 'Resident').toString().trim(),
              'photoUrl': (data['reporterPhotoUrl'] ?? data['profilePhotoUrl'] ?? data['photoUrl'] ?? '').toString().trim(),
              'isOriginal': false,
            });
          }
          result = {
            'concernId': concernId,
            'originalReporter': {
              'id': fallbackSubmission?.userId ?? '',
              'name': fallbackSubmission?.displayReporterName ?? 'Resident',
              'photoUrl': fallbackSubmission?.originalReporterPhotoUrl ?? '',
              'isOriginal': true,
            },
            'reporters': joined,
            'joinedReporters': joined,
            'count': 1 + joined.length,
            'totalCount': 1 + joined.length,
          };
        }
      } catch (_) {}
    }

    // 3. Try reading public_concern_summaries doc
    if (result == null) {
      try {
        final doc = await _firestore
            .collection('public_concern_summaries')
            .doc(concernId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final origName = (data['originalReporterName'] ??
                  data['reporterName'] ??
                  data['submitterName'] ??
                  fallbackSubmission?.displayReporterName ??
                  'Resident')
              .toString()
              .trim();
          final origPhoto = (data['originalReporterPhotoUrl'] ??
                  data['reporterPhotoUrl'] ??
                  fallbackSubmission?.originalReporterPhotoUrl ??
                  '')
              .toString()
              .trim();
          final origId = (data['userId'] ?? fallbackSubmission?.userId ?? '').toString().trim();

          final rawReporters = data['reporters'];
          final List<Map<String, dynamic>> list = (rawReporters is List)
              ? rawReporters.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
              : <Map<String, dynamic>>[];

          final orig = list.firstWhere(
            (r) => r['isOriginal'] == true,
            orElse: () => {
              'id': origId,
              'name': origName,
              'photoUrl': origPhoto,
              'isOriginal': true,
            },
          );
          if ((orig['photoUrl'] == null || orig['photoUrl'].toString().isEmpty) && origPhoto.isNotEmpty) {
            orig['photoUrl'] = origPhoto;
          }
          final joined = list.where((r) => r['isOriginal'] != true).toList();
          final total = (data['reporterCount'] as num?)?.toInt() ?? (1 + joined.length);
          result = {
            'concernId': concernId,
            'originalReporter': orig,
            'reporters': joined,
            'joinedReporters': joined,
            'count': total,
            'totalCount': total,
          };
        }
      } catch (_) {}
    }

    // 4. In-memory fallback from fallbackSubmission
    if (result == null) {
      final origName = fallbackSubmission?.displayReporterName ?? 'Resident';
      final origPhoto = fallbackSubmission?.originalReporterPhotoUrl ?? '';
      final joined = fallbackSubmission?.reporters
              .where((r) => r['isOriginal'] != true)
              .toList() ??
          const <Map<String, dynamic>>[];
      final total = fallbackSubmission != null && fallbackSubmission.reporterCount > 1
          ? fallbackSubmission.reporterCount
          : (1 + joined.length);
      result = {
        'concernId': concernId,
        'originalReporter': {
          'id': fallbackSubmission?.userId ?? '',
          'name': origName,
          'photoUrl': origPhoto,
          'isOriginal': true,
        },
        'reporters': joined,
        'joinedReporters': joined,
        'count': total,
        'totalCount': total,
      };
    }

    // Ensure profile resolution and deduplication
    final origMap = result['originalReporter'] is Map
        ? Map<String, dynamic>.from(result['originalReporter'] as Map)
        : <String, dynamic>{'name': 'Resident', 'isOriginal': true};
    final origId = (origMap['id'] ?? fallbackSubmission?.userId ?? '').toString().trim();
    var origName = (origMap['name'] ?? '').toString().trim();
    var origPhoto = (origMap['photoUrl'] ?? '').toString().trim();

    if (origId.isNotEmpty && (origName.isEmpty || origName.toLowerCase() == 'resident' || origPhoto.isEmpty)) {
      final userProfile = await resolveUserProfile(origId);
      if (userProfile['name']?.isNotEmpty == true && (origName.isEmpty || origName.toLowerCase() == 'resident')) {
        origName = userProfile['name']!;
        origMap['name'] = origName;
      }
      if (userProfile['photoUrl']?.isNotEmpty == true && origPhoto.isEmpty) {
        origPhoto = userProfile['photoUrl']!;
        origMap['photoUrl'] = origPhoto;
      }
    }
    result['originalReporter'] = origMap;

    final rawJoined = (result['reporters'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        (result['joinedReporters'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        <Map<String, dynamic>>[];

    final seenIds = <String>{};
    final seenNames = <String>{};
    if (origId.isNotEmpty) seenIds.add(origId);
    if (origName.isNotEmpty && origName.toLowerCase() != 'resident') {
      seenNames.add(origName.toLowerCase());
    }

    final dedupedJoined = <Map<String, dynamic>>[];
    for (final item in rawJoined) {
      final id = (item['id'] ?? item['reporterId'] ?? '').toString().trim();
      var name = (item['name'] ?? item['reporterName'] ?? '').toString().trim();
      var photo = (item['photoUrl'] ?? item['profilePhotoUrl'] ?? '').toString().trim();

      if (id.isNotEmpty && (name.isEmpty || name.toLowerCase() == 'resident' || photo.isEmpty)) {
        final userProfile = await resolveUserProfile(id);
        if (userProfile['name']?.isNotEmpty == true && (name.isEmpty || name.toLowerCase() == 'resident')) {
          name = userProfile['name']!;
        }
        if (userProfile['photoUrl']?.isNotEmpty == true && photo.isEmpty) {
          photo = userProfile['photoUrl']!;
        }
      }

      if (id.isNotEmpty && seenIds.contains(id)) continue;
      if (name.isNotEmpty && name.toLowerCase() != 'resident' && seenNames.contains(name.toLowerCase())) continue;
      if (id.isNotEmpty) seenIds.add(id);
      if (name.isNotEmpty && name.toLowerCase() != 'resident') seenNames.add(name.toLowerCase());

      dedupedJoined.add({
        'id': id,
        'name': name.isNotEmpty ? name : 'Resident',
        'photoUrl': photo,
        'isOriginal': false,
      });
    }

    result['reporters'] = dedupedJoined;
    result['joinedReporters'] = dedupedJoined;
    result['count'] = 1 + dedupedJoined.length;
    result['totalCount'] = 1 + dedupedJoined.length;

    return result;
  }
}
