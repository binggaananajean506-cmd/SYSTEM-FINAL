import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'barili_barangays.dart';
import 'firestore_converters.dart';
import 'services/announcement_image_cache.dart';
import 'features/calendar/data/calendar_service.dart';
import 'features/calendar/domain/calendar_event.dart';

class CommunityAlert {
  final String id;
  final String title;
  final String message;
  final String severity;
  final String category;
  final String alertType;
  final String instructions;
  final String sourceName;
  final String targetBarangay;
  final List<String> targetBarangays;
  final String visibility;
  final String status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? startAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;
  final String evacuationInfo;
  final String emergencyContacts;
  final int targetedCount;
  final int deliveredCount;
  final int openedCount;
  final int acknowledgedCount;
  final bool active;

  const CommunityAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    required this.alertType,
    required this.instructions,
    required this.sourceName,
    required this.targetBarangay,
    required this.targetBarangays,
    required this.visibility,
    required this.status,
    required this.createdAt,
    this.publishedAt,
    this.startAt,
    this.expiresAt,
    this.endedAt,
    this.evacuationInfo = '',
    this.emergencyContacts = '',
    this.targetedCount = 0,
    this.deliveredCount = 0,
    this.openedCount = 0,
    this.acknowledgedCount = 0,
    this.active = true,
  });

  String get normalizedSeverity => severity.trim().toLowerCase();
  bool get isEmergency =>
      normalizedSeverity == 'emergency' || normalizedSeverity == 'critical';
  bool get isCritical => isEmergency;
  int get awaitingAcknowledgementCount =>
      targetedCount > acknowledgedCount ? targetedCount - acknowledgedCount : 0;
  bool get isCurrentlyActive {
    final statusValue = status.toLowerCase();
    return active &&
        !const {
          'resolved',
          'ended',
          'expired',
          'cancelled',
        }.contains(statusValue) &&
        (startAt == null || !startAt!.isAfter(DateTime.now())) &&
        (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  }

  bool isVisibleTo(User? user) {
    if (visibility.toLowerCase() == 'public' ||
        targetBarangay == 'All Barangays') {
      return true;
    }
    final barangay = canonicalBariliBarangay(user?.barangay);
    if (barangay == null) return false;
    return targetBarangay == barangay || targetBarangays.contains(barangay);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity,
      'category': category,
      'alertType': alertType,
      'instructions': instructions,
      'sourceName': sourceName,
      'targetBarangay': targetBarangay,
      'targetBarangays': targetBarangays,
      'visibility': visibility,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'startAt': startAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'evacuationInfo': evacuationInfo,
      'emergencyContacts': emergencyContacts,
      'stats': {
        'targeted': targetedCount,
        'delivered': deliveredCount,
        'opened': openedCount,
        'acknowledged': acknowledgedCount,
      },
      'active': active,
    };
  }

  factory CommunityAlert.fromMap(Map<String, dynamic> map) {
    final stats = map['stats'] is Map
        ? Map<String, dynamic>.from(map['stats'] as Map)
        : const <String, dynamic>{};
    return CommunityAlert(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      severity: map['severity'] ?? 'Advisory',
      category: map['category'] ?? 'General',
      alertType:
          map['alertType']?.toString() ??
          map['category']?.toString() ??
          'Emergency',
      instructions: map['instructions']?.toString() ?? '',
      sourceName: map['sourceName']?.toString() ?? 'E-Sugid Emergency Center',
      targetBarangay: map['targetBarangay'] ?? 'All Barangays',
      targetBarangays: (map['targetBarangays'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      visibility: map['visibility']?.toString() ?? 'public',
      status: map['status']?.toString() ?? 'active',
      createdAt: dateTimeFromFirestore(map['createdAt']),
      publishedAt: nullableDateTimeFromFirestore(map['publishedAt']),
      startAt: nullableDateTimeFromFirestore(map['startAt']),
      expiresAt: nullableDateTimeFromFirestore(map['expiresAt']),
      endedAt: nullableDateTimeFromFirestore(
        map['endedAt'] ?? map['resolvedAt'] ?? map['cancelledAt'],
      ),
      evacuationInfo: map['evacuationInfo']?.toString() ?? '',
      emergencyContacts: map['emergencyContacts']?.toString() ?? '',
      targetedCount: (stats['targeted'] as num?)?.toInt() ?? 0,
      deliveredCount: (stats['delivered'] as num?)?.toInt() ?? 0,
      openedCount: (stats['opened'] as num?)?.toInt() ?? 0,
      acknowledgedCount: (stats['acknowledged'] as num?)?.toInt() ?? 0,
      active: map['active'] ?? true,
    );
  }
}

class TargetedPost {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String authorId;
  final String authorRole;
  final String authorPosition;
  final String authorBarangay;
  final String authorOrganizationName;
  final String publisherEntityId;
  final String publisherEntityType;
  final String publisherEntityName;
  final String targetAudience;
  final String targetBarangay;
  final String visibility;
  final List<String> targetBarangays;
  final String imageUrl;
  final String imageStoragePath;
  final String localImagePath;
  final DateTime createdAt;
  final String status;
  final String priority;
  final DateTime? priorityExpiresAt;
  final String category;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final bool notificationRequested;

  const TargetedPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorId,
    required this.authorRole,
    this.authorPosition = '',
    required this.authorBarangay,
    required this.authorOrganizationName,
    this.publisherEntityId = '',
    this.publisherEntityType = '',
    this.publisherEntityName = '',
    required this.targetAudience,
    required this.targetBarangay,
    this.visibility = 'public',
    this.targetBarangays = const [],
    this.imageUrl = '',
    this.imageStoragePath = '',
    this.localImagePath = '',
    required this.createdAt,
    this.status = 'pending',
    this.priority = 'regular',
    this.priorityExpiresAt,
    this.category = 'General',
    this.publishAt,
    this.expiresAt,
    this.notificationRequested = false,
  });

  Map<String, dynamic> toMap() {
    final canonicalTargets = targetBarangays
        .map(canonicalBariliBarangay)
        .whereType<String>()
        .toSet()
        .toList();
    final audienceKeys = visibility == 'public'
        ? const [bariliMunicipalityAudienceKey]
        : canonicalTargets.map((item) => 'barangay:$item').toList();
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorName': authorName,
      'authorId': authorId,
      'authorRole': authorRole,
      'authorPosition': authorPosition,
      'authorBarangay': authorBarangay,
      'authorOrganizationName': authorOrganizationName,
      'publisherEntityId': publisherEntityId,
      'publisherEntityType': publisherEntityType,
      'publisherEntityName': publisherEntityName,
      'targetAudience': targetAudience,
      'targetBarangay': targetBarangay,
      'visibility': visibility,
      'targetBarangays': canonicalTargets,
      'audienceKeys': audienceKeys,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt.toIso8601String(),
      'tag': authorRole == 'barangay' || authorRole.startsWith('barangay_')
          ? 'OFFICIAL'
          : authorRole == 'lgu' || authorRole == 'super_admin'
          ? 'OFFICIAL'
          : 'PARTNER',
      'status': status,
      'priority': priority,
      'priorityExpiresAt': priorityExpiresAt == null
          ? null
          : Timestamp.fromDate(priorityExpiresAt!),
      'category': category,
      'contentType': 'announcement',
      'schemaVersion': 2,
      'publishAt': publishAt == null ? null : Timestamp.fromDate(publishAt!),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'notificationRequested': notificationRequested,
    };
  }
}

class CommunityPost {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String authorId;
  final String authorRole;
  final String authorPosition;
  final String authorBarangay;
  final String authorOrganizationName;
  final String authorPhotoUrl;
  final String publisherEntityId;
  final String publisherEntityType;
  final String publisherEntityName;
  final String targetAudience;
  final String targetBarangay;
  final String visibility;
  final List<String> targetBarangays;
  final String imageUrl;
  final String imageStoragePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String tag;
  final String priority;
  final DateTime? priorityExpiresAt;
  final String category;
  final String customCategory;
  final DateTime? publishAt;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final bool? eventAllDay;
  final bool? hasSchedule;
  final bool eventCancelled;
  final String announcementType;
  final DateTime? expiresAt;
  final String location;
  final String calendarEventId;
  final Map<String, String> cta;
  final String localImagePath;
  final bool sourceUnavailable;

  const CommunityPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorId,
    required this.authorRole,
    this.authorPosition = '',
    required this.authorBarangay,
    required this.authorOrganizationName,
    this.authorPhotoUrl = '',
    this.publisherEntityId = '',
    this.publisherEntityType = '',
    this.publisherEntityName = '',
    required this.targetAudience,
    required this.targetBarangay,
    required this.visibility,
    required this.targetBarangays,
    this.imageUrl = '',
    this.imageStoragePath = '',
    required this.createdAt,
    DateTime? updatedAt,
    required this.status,
    required this.tag,
    this.priority = 'regular',
    this.priorityExpiresAt,
    this.category = 'General',
    this.customCategory = '',
    this.publishAt,
    this.eventDate,
    this.eventEndDate,
    this.eventAllDay,
    this.hasSchedule,
    this.eventCancelled = false,
    this.announcementType = 'general',
    this.expiresAt,
    this.location = '',
    this.calendarEventId = '',
    this.cta = const {},
    this.localImagePath = '',
    this.sourceUnavailable = false,
  }) : updatedAt = updatedAt ?? createdAt;

  bool get isAllDayEvent => eventAllDay ?? eventEndDate == null;

  bool get hasCalendarSchedule =>
      !sourceUnavailable &&
      ['approved', 'published'].contains(status.toLowerCase()) &&
      hasSchedule != false &&
      !eventCancelled &&
      eventDate != null &&
      eventDate!.year >= 2000 &&
      (isAllDayEvent ||
          (eventEndDate != null &&
              eventEndDate!.isAfter(eventDate!) &&
              eventEndDate!.difference(eventDate!) <=
                  const Duration(days: 14)));

  bool isExpiredAt(DateTime now) {
    final normalized = status.toLowerCase();
    if (normalized == 'expired' || normalized == 'archived') {
      return true;
    }
    if (expiresAt != null && now.isAfter(expiresAt!)) {
      return true;
    }
    if (eventEndDate != null) {
      if (now.isAfter(eventEndDate!)) return true;
    } else if (eventDate != null) {
      final endOfEventDay = DateTime(
        eventDate!.year,
        eventDate!.month,
        eventDate!.day,
        23,
        59,
        59,
        999,
      );
      if (now.isAfter(endOfEventDay)) return true;
    }
    return false;
  }

  bool isPinnedAt(DateTime now) {
    final normalized = priority.toLowerCase();
    return (normalized == 'urgent' || normalized == 'emergency') &&
        priorityExpiresAt != null &&
        priorityExpiresAt!.isAfter(now);
  }

  int priorityRankAt(DateTime now) {
    if (!isPinnedAt(now)) return 0;
    return priority.toLowerCase() == 'emergency' ? 2 : 1;
  }

  bool get showsImportantBadge => priority.toLowerCase() == 'important';

  String get displayCategory =>
      customCategory.trim().isNotEmpty ? customCategory.trim() : category;

  String get displayPublisher {
    final entity = publisherEntityName.trim();
    if (entity.isNotEmpty && entity.toLowerCase() != 'anajean') {
      return entity;
    }

    final role = authorRole.toLowerCase();
    if (role == 'partner' || role == 'organization') {
      final org = authorOrganizationName.trim();
      if (org.isNotEmpty) return org;
      return 'Partner Organization';
    }

    final isBarangay = role == 'barangay' || role.startsWith('barangay_');
    var barangay = authorBarangay.trim();
    if (barangay.isEmpty && isBarangay && targetBarangay != 'All Barangays') {
      barangay = targetBarangay.trim();
    }
    if (isBarangay && barangay.isNotEmpty) {
      final cleaned = barangay.replaceFirst(
        RegExp(r'^barangay\s+', caseSensitive: false),
        '',
      );
      return 'Barangay $cleaned';
    }

    if (authorOrganizationName.trim().isNotEmpty &&
        authorOrganizationName.toLowerCase() != 'anajean') {
      return authorOrganizationName.trim();
    }

    final author = authorName.trim();
    final isEmailOrStaffAccount =
        author.contains('@') ||
        author.toLowerCase() == 'anajean' ||
        author.toLowerCase() == 'admin';

    if (role == 'mayor') {
      return 'Office of the Municipal Mayor';
    }
    if (role == 'lgu' ||
        role == 'super_admin' ||
        role == 'admin' ||
        isEmailOrStaffAccount) {
      return 'LGU IT DEPARTMENT';
    }
    if (author.isNotEmpty && !isEmailOrStaffAccount) {
      return author;
    }
    return tag.toUpperCase() == 'OFFICIAL'
        ? 'Official Authority'
        : 'Community Partner';
  }

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final authorRole = data['authorRole']?.toString() ?? '';
    var publisherName = data['publisherEntityName']?.toString().trim() ?? '';
    if (publisherName.isEmpty) {
      final dept = data['department']?.toString().trim() ?? '';
      if (dept.isNotEmpty) {
        publisherName = dept.toLowerCase().startsWith('lgu')
            ? dept
            : 'LGU $dept';
      }
    }
    var rawAuthorName = data['authorName']?.toString().trim() ?? '';
    final isEmailOrStaffAccount =
        rawAuthorName.contains('@') ||
        rawAuthorName.toLowerCase() == 'anajean' ||
        rawAuthorName.toLowerCase() == 'admin';

    if (isEmailOrStaffAccount || rawAuthorName.isEmpty) {
      if (publisherName.isNotEmpty &&
          publisherName.toLowerCase() != 'anajean') {
        rawAuthorName = publisherName;
      } else if (authorRole == 'lgu' ||
          authorRole == 'super_admin' ||
          authorRole == 'admin' ||
          authorRole.isEmpty) {
        rawAuthorName = 'LGU IT DEPARTMENT';
        if (publisherName.isEmpty) {
          publisherName = 'LGU IT DEPARTMENT';
        }
      } else {
        rawAuthorName = 'Official';
      }
    }
    if (publisherName.isEmpty &&
        (authorRole == 'lgu' ||
            authorRole == 'super_admin' ||
            authorRole == 'admin')) {
      publisherName = 'LGU IT DEPARTMENT';
    }

    return CommunityPost(
      id: data['id']?.toString() ?? doc.id,
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      authorName: rawAuthorName,
      authorId: data['authorId']?.toString() ?? '',
      authorRole: authorRole,
      authorPosition: data['authorPosition']?.toString() ?? '',
      authorBarangay: data['authorBarangay']?.toString() ?? '',
      authorOrganizationName: data['authorOrganizationName']?.toString() ?? '',
      authorPhotoUrl: data['authorPhotoUrl']?.toString().trim() ??
          data['authorProfilePhotoUrl']?.toString().trim() ??
          data['publisherPhotoUrl']?.toString().trim() ??
          data['photoUrl']?.toString().trim() ??
          data['avatarUrl']?.toString().trim() ??
          '',
      publisherEntityId: data['publisherEntityId']?.toString() ?? '',
      publisherEntityType: data['publisherEntityType']?.toString() ?? '',
      publisherEntityName: publisherName,
      targetAudience: data['targetAudience']?.toString() ?? 'All Residents',
      targetBarangay: data['targetBarangay']?.toString() ?? 'All Barangays',
      visibility:
          data['visibility']?.toString() ??
          ((data['targetBarangay']?.toString() ?? 'All Barangays') ==
                  'All Barangays'
              ? 'public'
              : 'targeted'),
      targetBarangays: (data['targetBarangays'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      imageUrl: data['imageUrl']?.toString() ?? '',
      imageStoragePath: data['imageStoragePath']?.toString() ?? '',
      localImagePath: (data['localImagePath']?.toString().isNotEmpty == true)
          ? data['localImagePath'].toString()
          : (AnnouncementImageCache.getCachedPathSync(data['imageUrl']?.toString()) ?? ''),
      createdAt: dateTimeFromFirestore(data['timestamp'] ?? data['createdAt']),
      updatedAt: dateTimeFromFirestore(
        data['updatedAt'] ?? data['timestamp'] ?? data['createdAt'],
      ),
      status: data['status']?.toString() ?? 'pending',
      tag:
          data['tag']?.toString() ??
          (authorRole == 'barangay' || authorRole.startsWith('barangay_')
              ? 'OFFICIAL'
              : authorRole == 'lgu' || authorRole == 'super_admin'
              ? 'OFFICIAL'
              : 'PARTNER'),
      priority: data['priority']?.toString().toLowerCase() ?? 'regular',
      priorityExpiresAt: nullableDateTimeFromFirestore(
        data['priorityExpiresAt'],
      ),
      category: data['category']?.toString() ?? 'General',
      customCategory: data['customCategory']?.toString() ?? '',
      eventDate: nullableDateTimeFromFirestore(
        data['eventStartAt'] ?? data['eventDate'],
      ),
      eventEndDate: nullableDateTimeFromFirestore(
        data['eventEndAt'] ?? data['eventEndDate'],
      ),
      eventAllDay: data['eventAllDay'] as bool?,
      hasSchedule:
          (data['hasSchedule'] as bool?) ?? (data['addToCalendar'] as bool?),
      eventCancelled: data['eventCancelled'] == true,
      announcementType: data['announcementType']?.toString() ?? 'general',
      expiresAt: nullableDateTimeFromFirestore(data['expiresAt']),
      location: (data['eventLocation'] ?? data['location'])?.toString() ?? '',
      calendarEventId: data['calendarEventId']?.toString() ?? '',
      cta: (data['cta'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Map<String, dynamic> toLocalCache() => {
    'id': id,
    'title': title,
    'content': content,
    'authorName': authorName,
    'authorId': authorId,
    'authorRole': authorRole,
    'authorPosition': authorPosition,
    'authorBarangay': authorBarangay,
    'authorOrganizationName': authorOrganizationName,
    'authorPhotoUrl': authorPhotoUrl,
    'publisherEntityId': publisherEntityId,
    'publisherEntityType': publisherEntityType,
    'publisherEntityName': publisherEntityName,
    'targetAudience': targetAudience,
    'targetBarangay': targetBarangay,
    'visibility': visibility,
    'targetBarangays': targetBarangays,
    'imageUrl': imageUrl,
    'imageStoragePath': imageStoragePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    'tag': tag,
    'priority': priority,
    'priorityExpiresAt': priorityExpiresAt?.toIso8601String(),
    'category': category,
    'customCategory': customCategory,
    'publishAt': publishAt?.toIso8601String(),
    'eventDate': eventDate?.toIso8601String(),
    'eventEndDate': eventEndDate?.toIso8601String(),
    'eventAllDay': eventAllDay,
    'hasSchedule': hasSchedule,
    'eventCancelled': eventCancelled,
    'announcementType': announcementType,
    'expiresAt': expiresAt?.toIso8601String(),
    'location': location,
    'calendarEventId': calendarEventId,
    'cta': cta,
    'localImagePath': localImagePath,
  };

  factory CommunityPost.fromLocalCache(Map<String, dynamic> map) {
    DateTime requiredDate(String key) =>
        DateTime.parse(map[key]?.toString() ?? '');
    DateTime? optionalDate(String key) {
      final value = map[key]?.toString();
      return value == null || value.isEmpty ? null : DateTime.parse(value);
    }

    final authorRole = map['authorRole']?.toString() ?? '';
    var publisherName = map['publisherEntityName']?.toString().trim() ?? '';
    if (publisherName.isEmpty) {
      final dept = map['department']?.toString().trim() ?? '';
      if (dept.isNotEmpty) {
        publisherName = dept.toLowerCase().startsWith('lgu')
            ? dept
            : 'LGU $dept';
      }
    }
    var rawAuthorName = map['authorName']?.toString().trim() ?? '';
    final isEmailOrStaffAccount =
        rawAuthorName.contains('@') ||
        rawAuthorName.toLowerCase() == 'anajean' ||
        rawAuthorName.toLowerCase() == 'admin';

    if (isEmailOrStaffAccount || rawAuthorName.isEmpty) {
      if (publisherName.isNotEmpty &&
          publisherName.toLowerCase() != 'anajean') {
        rawAuthorName = publisherName;
      } else if (authorRole == 'lgu' ||
          authorRole == 'super_admin' ||
          authorRole == 'admin' ||
          authorRole.isEmpty) {
        rawAuthorName = 'LGU IT DEPARTMENT';
        if (publisherName.isEmpty) {
          publisherName = 'LGU IT DEPARTMENT';
        }
      } else {
        rawAuthorName = 'Official';
      }
    }
    if (publisherName.isEmpty &&
        (authorRole == 'lgu' ||
            authorRole == 'super_admin' ||
            authorRole == 'admin')) {
      publisherName = 'LGU IT DEPARTMENT';
    }

    return CommunityPost(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      authorName: rawAuthorName,
      authorId: map['authorId']?.toString() ?? '',
      authorRole: authorRole,
      authorPosition: map['authorPosition']?.toString() ?? '',
      authorBarangay: map['authorBarangay']?.toString() ?? '',
      authorOrganizationName: map['authorOrganizationName']?.toString() ?? '',
      authorPhotoUrl: map['authorPhotoUrl']?.toString().trim() ?? '',
      publisherEntityId: map['publisherEntityId']?.toString() ?? '',
      publisherEntityType: map['publisherEntityType']?.toString() ?? '',
      publisherEntityName: publisherName,
      targetAudience: map['targetAudience']?.toString() ?? 'All Residents',
      targetBarangay: map['targetBarangay']?.toString() ?? 'All Barangays',
      visibility: map['visibility']?.toString() ?? 'public',
      targetBarangays: (map['targetBarangays'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      imageUrl: map['imageUrl']?.toString() ?? '',
      imageStoragePath: map['imageStoragePath']?.toString() ?? '',
      createdAt: requiredDate('createdAt'),
      updatedAt: optionalDate('updatedAt'),
      status: map['status']?.toString() ?? 'approved',
      tag: map['tag']?.toString() ?? 'OFFICIAL',
      priority: map['priority']?.toString() ?? 'regular',
      priorityExpiresAt: optionalDate('priorityExpiresAt'),
      category: map['category']?.toString() ?? 'General',
      customCategory: map['customCategory']?.toString() ?? '',
      publishAt: optionalDate('publishAt'),
      eventDate: optionalDate('eventDate') ?? optionalDate('eventStartAt'),
      eventEndDate: optionalDate('eventEndDate') ?? optionalDate('eventEndAt'),
      eventAllDay: map['eventAllDay'] as bool?,
      hasSchedule:
          (map['hasSchedule'] as bool?) ?? (map['addToCalendar'] as bool?),
      eventCancelled: map['eventCancelled'] == true,
      announcementType: map['announcementType']?.toString() ?? 'general',
      expiresAt: optionalDate('expiresAt'),
      location: (map['location'] ?? map['eventLocation'])?.toString() ?? '',
      calendarEventId: map['calendarEventId']?.toString() ?? '',
      cta: (map['cta'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      localImagePath: map['localImagePath']?.toString().isNotEmpty == true
          ? map['localImagePath'].toString()
          : (AnnouncementImageCache.getCachedPathSync(map['imageUrl']?.toString()) ?? ''),
    );
  }

  CommunityPost copyWith({
    String? id,
    String? title,
    String? content,
    String? authorName,
    String? authorId,
    String? authorRole,
    String? authorPosition,
    String? authorBarangay,
    String? authorOrganizationName,
    String? authorPhotoUrl,
    String? publisherEntityId,
    String? publisherEntityType,
    String? publisherEntityName,
    String? targetAudience,
    String? targetBarangay,
    String? visibility,
    List<String>? targetBarangays,
    String? imageUrl,
    String? imageStoragePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? tag,
    String? priority,
    DateTime? priorityExpiresAt,
    String? category,
    String? customCategory,
    DateTime? publishAt,
    DateTime? eventDate,
    DateTime? eventEndDate,
    bool? eventAllDay,
    bool? hasSchedule,
    bool? eventCancelled,
    String? announcementType,
    DateTime? expiresAt,
    String? location,
    String? calendarEventId,
    Map<String, String>? cta,
    String? localImagePath,
    bool? sourceUnavailable,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      authorRole: authorRole ?? this.authorRole,
      authorPosition: authorPosition ?? this.authorPosition,
      authorBarangay: authorBarangay ?? this.authorBarangay,
      authorOrganizationName:
          authorOrganizationName ?? this.authorOrganizationName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      publisherEntityId: publisherEntityId ?? this.publisherEntityId,
      publisherEntityType: publisherEntityType ?? this.publisherEntityType,
      publisherEntityName: publisherEntityName ?? this.publisherEntityName,
      targetAudience: targetAudience ?? this.targetAudience,
      targetBarangay: targetBarangay ?? this.targetBarangay,
      visibility: visibility ?? this.visibility,
      targetBarangays: targetBarangays ?? this.targetBarangays,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      tag: tag ?? this.tag,
      priority: priority ?? this.priority,
      priorityExpiresAt: priorityExpiresAt ?? this.priorityExpiresAt,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
      publishAt: publishAt ?? this.publishAt,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      eventAllDay: eventAllDay ?? this.eventAllDay,
      hasSchedule: hasSchedule ?? this.hasSchedule,
      eventCancelled: eventCancelled ?? this.eventCancelled,
      announcementType: announcementType ?? this.announcementType,
      expiresAt: expiresAt ?? this.expiresAt,
      location: location ?? this.location,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      cta: cta ?? this.cta,
      localImagePath: localImagePath ?? this.localImagePath,
      sourceUnavailable: sourceUnavailable ?? this.sourceUnavailable,
    );
  }

  Map<String, dynamic> get matchData {
    return {
      'authorId': authorId,
      'targetAudience': targetAudience,
      'targetBarangay': targetBarangay,
      'visibility': visibility,
      'targetBarangays': targetBarangays,
    };
  }
}

class HelpdeskTicket {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  const HelpdeskTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'subject': subject,
      'message': message,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HelpdeskTicket.fromMap(Map<String, dynamic> map) {
    return HelpdeskTicket(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      subject: map['subject'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'Open',
      createdAt: dateTimeFromFirestore(map['createdAt']),
    );
  }
}

class CommunityPostSnapshot {
  const CommunityPostSnapshot({required this.posts, required this.isFromCache});

  final List<CommunityPost> posts;
  final bool isFromCache;
}

class CommunityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Stream<List<CommunityAlert>>> _alertStreams = {};
  static final Map<String, Stream<List<CommunityAlert>>> _alertHistoryStreams =
      {};
  static final Map<String, Stream<List<CommunityPost>>> _approvedPostStreams =
      {};
  static final Map<String, Stream<List<CommunityPost>>> _publicPostStreams = {};
  static final Map<String, Stream<List<CommunityPost>>> _barangayPostStreams =
      {};
  static final Map<String, Stream<List<CommunityPost>>> _authorPostStreams = {};
  static final Map<String, List<CommunityPost>> _latestBarangayPosts = {};

  static List<CommunityPost>? latestBarangayPosts(String? rawBarangay) {
    final barangay = canonicalBariliBarangay(rawBarangay);
    if (barangay == null) return null;
    final cached = _latestBarangayPosts[barangay.toLowerCase()];
    return cached != null ? List<CommunityPost>.unmodifiable(cached) : null;
  }

  static void clearBarangayStream(String? rawBarangay) {
    final barangay = canonicalBariliBarangay(rawBarangay);
    if (barangay == null) {
      _barangayPostStreams.clear();
      return;
    }
    final prefix = '${barangay.toLowerCase()}|';
    _barangayPostStreams.removeWhere((k, _) => k.startsWith(prefix));
  }

  static void clearCaches() {
    _alertStreams.clear();
    _alertHistoryStreams.clear();
    _approvedPostStreams.clear();
    _publicPostStreams.clear();
    _barangayPostStreams.clear();
    _authorPostStreams.clear();
    _latestBarangayPosts.clear();
  }

  static Stream<List<CommunityAlert>> alertsForUser(User? user) {
    return _firestore
        .collection('alerts')
        .where('active', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final alerts =
              snapshot.docs
                  .map((doc) => CommunityAlert.fromMap(doc.data()))
                  .where(
                    (alert) =>
                        alert.isVisibleTo(user) && alert.isCurrentlyActive,
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return alerts;
        });
  }

  static Stream<List<CommunityAlert>> alertHistoryForUser(User? user) {
    return _firestore.collection('alerts').limit(100).snapshots().map((
      snapshot,
    ) {
      final alerts =
          snapshot.docs
              .map((doc) => CommunityAlert.fromMap(doc.data()))
              .where(
                (alert) => alert.isVisibleTo(user) && !alert.isCurrentlyActive,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return alerts;
    });
  }

  /// Forces a server read while the live alert streams keep their last
  /// snapshot visible in the UI.
  static Future<List<CommunityAlert>> fetchAlertsFromServer(User? user) async {
    final snapshot = await _firestore
        .collection('alerts')
        .limit(100)
        .get(const GetOptions(source: Source.server));
    final alerts =
        snapshot.docs
            .map((doc) => CommunityAlert.fromMap(doc.data()))
            .where((alert) => alert.isVisibleTo(user))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return alerts;
  }

  static Future<void> createTargetedPost(
    TargetedPost post, {
    CalendarEvent? linkedCalendarEvent,
    String announcementType = 'general',
  }) async {
    if (linkedCalendarEvent == null) {
      await _firestore.collection('posts').doc(post.id).set({
        ...post.toMap(),
        'announcementType': announcementType,
        'addToCalendar': false,
      });
      return;
    }

    final eventId = CalendarService.sourceEventId(
      CalendarEventSourceType.announcement,
      post.id,
    );
    final event = linkedCalendarEvent.copyWith(id: eventId);
    CalendarService.validate(event, allowPast: false);
    final batch = _firestore.batch();
    batch.set(_firestore.collection('posts').doc(post.id), {
      ...post.toMap(),
      'addToCalendar': true,
      'announcementType': announcementType,
      'eventAllDay': event.allDay,
      'calendarEventId': eventId,
      'eventStartAt': Timestamp.fromDate(event.startAt),
      'eventEndAt': Timestamp.fromDate(event.endAt),
      'eventLocation': event.location,
    });
    batch.set(
      _firestore.collection(CalendarService.collectionName).doc(eventId),
      event.toFirestore(),
    );
    await batch.commit();
  }

  static Future<void> extendPostUrgency(
    String postId,
    DateTime expiresAt,
  ) async {
    await _firestore.collection('posts').doc(postId).update({
      'priorityExpiresAt': Timestamp.fromDate(expiresAt),
    });
  }

  static Future<void> endPostUrgency(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'priority': 'regular',
      'priorityExpiresAt': null,
    });
  }

  static List<CommunityPost> sortPostsForFeed(
    Iterable<CommunityPost> source, {
    DateTime? now,
    bool includeExpired = false,
  }) {
    final current = now ?? DateTime.now();
    final posts = source.where((post) {
      if (!includeExpired && post.isExpiredAt(current)) {
        return false;
      }
      return true;
    }).toList();
    posts.sort((a, b) {
      final rankComparison = b
          .priorityRankAt(current)
          .compareTo(a.priorityRankAt(current));
      if (rankComparison != 0) return rankComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
    return posts;
  }

  static List<CommunityPost> sortPostsByNewest(Iterable<CommunityPost> source) {
    final posts = source.toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  static Stream<List<CommunityPost>> approvedPostsForUser(
    User user, {
    int? limit,
  }) {
    final key = [
      user.uid,
      user.role.name,
      user.barangay?.trim().toLowerCase() ?? '',
      limit?.toString() ?? 'all',
    ].join('|');
    return _approvedPostStreams.putIfAbsent(key, () {
      if (user.role == UserRole.lgu) {
        return _firestore
            .collection('posts')
            .where('status', isEqualTo: 'approved')
            .snapshots()
            .map(
              (snapshot) =>
                  _limitPosts(snapshot.docs.map(CommunityPost.fromDoc), limit),
            )
            .asBroadcastStream(
              onCancel: (sub) {
                sub.cancel();
                _approvedPostStreams.remove(key);
              },
            );
      }

      final publicPosts = _firestore
          .collection('announcement_feeds')
          .doc(bariliMunicipalityAudienceKey)
          .collection('posts')
          .snapshots()
          .map((snapshot) => snapshot.docs.map(CommunityPost.fromDoc).toList());
      final barangay = canonicalBariliBarangay(user.barangay);
      final targetedPosts = barangay == null
          ? Stream<List<CommunityPost>>.value(const [])
          : _firestore
                .collection('announcement_feeds')
                .doc('barangay:$barangay')
                .collection('posts')
                .snapshots()
                .map(
                  (snapshot) {
                    final posts =
                        snapshot.docs.map(CommunityPost.fromDoc).toList();
                    _latestBarangayPosts[barangay.toLowerCase()] = posts;
                    return posts;
                  },
                );

      return _combineApprovedPostStreams(
        publicPosts,
        targetedPosts,
        limit,
        onCancelCombined: () {
          _approvedPostStreams.remove(key);
        },
      );
    });
  }

  /// Municipality-wide announcements intended for the public Community
  /// Bulletin. Targeted barangay posts are intentionally excluded.
  static Stream<List<CommunityPost>> publicPosts({int? limit}) {
    final key = limit?.toString() ?? 'all';
    return _publicPostStreams.putIfAbsent(
      key,
      () => _firestore
          .collection('announcement_feeds')
          .doc(bariliMunicipalityAudienceKey)
          .collection('posts')
          .snapshots()
          .map(
            (snapshot) =>
                _limitPosts(snapshot.docs.map(CommunityPost.fromDoc), limit),
          )
          .asBroadcastStream(
            onCancel: (sub) {
              sub.cancel();
              _publicPostStreams.remove(key);
            },
          ),
    );
  }

  static Stream<CommunityPostSnapshot> publicPostSnapshots({int? limit}) {
    return _firestore
        .collection('announcement_feeds')
        .doc(bariliMunicipalityAudienceKey)
        .collection('posts')
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => CommunityPostSnapshot(
            posts: _limitPosts(snapshot.docs.map(CommunityPost.fromDoc), limit),
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  static Future<CommunityPost?> fetchPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists && doc.data() != null) {
        return CommunityPost.fromDoc(doc);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<CommunityPost>> fetchPublicPostsFromServer({
    int? limit,
  }) async {
    final snapshot = await _firestore
        .collection('announcement_feeds')
        .doc(bariliMunicipalityAudienceKey)
        .collection('posts')
        .get(const GetOptions(source: Source.server));
    return _limitPosts(snapshot.docs.map(CommunityPost.fromDoc), limit);
  }

  static Future<List<CommunityPost>> fetchApprovedPostsForUserFromServer(
    User user, {
    int? limit,
  }) async {
    if (user.role == UserRole.lgu) {
      final snapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'approved')
          .get(const GetOptions(source: Source.server));
      return _limitPosts(snapshot.docs.map(CommunityPost.fromDoc), limit);
    }
    final publicPosts = await fetchPublicPostsFromServer();
    final barangay = canonicalBariliBarangay(user.barangay);
    if (barangay == null) {
      return _limitPosts(publicPosts, limit);
    }
    final targetedSnapshot = await _firestore
        .collection('announcement_feeds')
        .doc('barangay:$barangay')
        .collection('posts')
        .get(const GetOptions(source: Source.server));
    final targetedPosts = targetedSnapshot.docs
        .map(CommunityPost.fromDoc)
        .toList();
    _latestBarangayPosts[barangay.toLowerCase()] = targetedPosts;
    final byId = <String, CommunityPost>{
      for (final post in publicPosts) post.id: post,
      for (final post in targetedPosts) post.id: post,
    };
    return _limitPosts(byId.values, limit);
  }

  static Future<List<CommunityPost>> fetchPostsForAuthorFromServer(
    String authorId,
  ) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: authorId)
        .limit(100)
        .get(const GetOptions(source: Source.server));
    return sortPostsForFeed(snapshot.docs.map(CommunityPost.fromDoc));
  }

  /// Announcements delivered specifically to the resident's registered
  /// barangay. Public municipality-wide posts remain in Community Bulletin.
  static Stream<List<CommunityPost>> barangayPostsForUser(
    User user, {
    int? limit,
  }) {
    final barangay = canonicalBariliBarangay(user.barangay);
    if (barangay == null) return Stream.value(const <CommunityPost>[]);

    final key = '${barangay.toLowerCase()}|${limit?.toString() ?? 'all'}';
    return _barangayPostStreams.putIfAbsent(
      key,
      () => _firestore
          .collection('announcement_feeds')
          .doc('barangay:$barangay')
          .collection('posts')
          .snapshots()
          .map((snapshot) {
            final posts = _limitPosts(
              snapshot.docs.map(CommunityPost.fromDoc),
              limit,
            );
            _latestBarangayPosts[barangay.toLowerCase()] = posts;
            return posts;
          })
          .asBroadcastStream(
            onCancel: (sub) {
              sub.cancel();
              _barangayPostStreams.remove(key);
            },
          ),
    );
  }

  static List<CommunityPost> _limitPosts(
    Iterable<CommunityPost> source,
    int? limit,
  ) {
    final posts = sortPostsForFeed(source);
    return limit == null || posts.length <= limit
        ? posts
        : posts.take(limit).toList();
  }

  static Stream<List<CommunityPost>> _combineApprovedPostStreams(
    Stream<List<CommunityPost>> publicPosts,
    Stream<List<CommunityPost>> targetedPosts,
    int? limit, {
    void Function()? onCancelCombined,
  }) {
    late StreamController<List<CommunityPost>> controller;
    StreamSubscription<List<CommunityPost>>? publicSubscription;
    StreamSubscription<List<CommunityPost>>? targetedSubscription;
    var latestPublic = <CommunityPost>[];
    var latestTargeted = <CommunityPost>[];

    void emit() {
      final byId = <String, CommunityPost>{
        for (final post in latestPublic) post.id: post,
        for (final post in latestTargeted) post.id: post,
      };
      controller.add(_limitPosts(byId.values, limit));
    }

    controller = StreamController<List<CommunityPost>>.broadcast(
      onListen: () {
        publicSubscription = publicPosts.listen((posts) {
          latestPublic = posts;
          emit();
        }, onError: controller.addError);
        targetedSubscription = targetedPosts.listen((posts) {
          latestTargeted = posts;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await publicSubscription?.cancel();
        await targetedSubscription?.cancel();
        onCancelCombined?.call();
      },
    );
    return controller.stream;
  }

  static Stream<List<CommunityPost>> postsForAuthor(String authorId) {
    return _authorPostStreams.putIfAbsent(
      authorId,
      () => _firestore
          .collection('posts')
          .where('authorId', isEqualTo: authorId)
          .snapshots()
          .map((snapshot) {
            final posts = sortPostsForFeed(
              snapshot.docs.map(CommunityPost.fromDoc),
            );
            return posts;
          })
          .asBroadcastStream(
            onCancel: (sub) {
              sub.cancel();
              _authorPostStreams.remove(authorId);
            },
          ),
    );
  }

  static bool postMatchesUser(Map<String, dynamic> data, User? user) {
    final audience = data['targetAudience'] ?? 'All Residents';
    final barangay = data['targetBarangay'] ?? 'All Barangays';
    final visibility =
        data['visibility']?.toString() ??
        (barangay == 'All Barangays' ? 'public' : 'targeted');
    final targetBarangays =
        (data['targetBarangays'] as List<dynamic>? ?? const [])
            .map((item) => canonicalBariliBarangay(item.toString()))
            .whereType<String>()
            .map((item) => item.toLowerCase())
            .toList();
    if (user == null) {
      return visibility == 'public' || barangay == 'All Barangays';
    }
    if (data['authorId']?.toString() == user.uid || user.role == UserRole.lgu) {
      return true;
    }
    final roleMatch =
        audience == 'All Residents' ||
        audience == 'Everyone' ||
        audience == user.role.name ||
        audience.toString().toLowerCase().contains(user.role.name);
    final userBarangay = canonicalBariliBarangay(user.barangay)?.toLowerCase();
    final singleTargetBarangay = canonicalBariliBarangay(
      barangay.toString(),
    )?.toLowerCase();
    final barangayMatch =
        visibility == 'public' ||
        barangay == 'All Barangays' ||
        (userBarangay != null &&
            userBarangay.isNotEmpty &&
            (targetBarangays.contains(userBarangay) ||
                singleTargetBarangay == userBarangay));
    return roleMatch && barangayMatch;
  }

  static Future<void> createHelpdeskTicket(HelpdeskTicket ticket) async {
    await _firestore
        .collection('helpdesk_tickets')
        .doc(ticket.id)
        .set(ticket.toMap());
    await _firestore
        .collection('helpdesk_tickets')
        .doc(ticket.id)
        .collection('messages')
        .add({
          'senderId': ticket.userId,
          'message': ticket.message,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  static Stream<List<HelpdeskTicket>> ticketsForUser(String userId) {
    return _firestore
        .collection('helpdesk_tickets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final tickets =
              snapshot.docs
                  .map((doc) => HelpdeskTicket.fromMap(doc.data()))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  static Stream<int> civicPoints(String userId) {
    return _firestore.collection('civic_points').doc(userId).snapshots().map((
      doc,
    ) {
      return doc.data()?['points'] ?? 0;
    });
  }

  static String departmentFor(
    String text, {
    String fallback = 'Mayor\'s Office',
  }) {
    final value = text.toLowerCase();
    if (_hasAny(value, ['garbage', 'trash', 'basura', 'waste', 'collection'])) {
      return 'CENRO';
    }
    if (_hasAny(value, [
      'road',
      'pothole',
      'bridge',
      'streetlight',
      'drainage',
    ])) {
      return 'Engineering Office';
    }
    if (_hasAny(value, [
      'noise',
      'fight',
      'threat',
      'fire',
      'crime',
      'accident',
    ])) {
      return 'Public Safety';
    }
    if (_hasAny(value, [
      'clinic',
      'medicine',
      'health',
      'medical',
      'sanitation',
    ])) {
      return 'Municipal Health Office';
    }
    if (_hasAny(value, ['water', 'electric', 'power', 'leak'])) {
      return 'General Services';
    }
    if (_hasAny(value, ['tree', 'river', 'flood', 'environment'])) {
      return 'MENRO';
    }
    return fallback;
  }

  static String claimCodeFor(String id) {
    final cleaned = id.replaceAll('-', '').toUpperCase();
    final suffix = cleaned.length > 6
        ? cleaned.substring(cleaned.length - 6)
        : cleaned;
    return 'CLAIM-$suffix';
  }

  static bool _hasAny(String value, List<String> words) {
    return words.any(value.contains);
  }
}
