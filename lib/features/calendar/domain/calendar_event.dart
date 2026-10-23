import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../firestore_converters.dart';

enum CalendarEventCategory {
  barangayEvent('barangay_event'),
  bayanihan('bayanihan'),
  announcement('announcement'),
  document('document'),
  marketplaceMeetup('marketplace_meetup'),
  emergency('emergency'),
  personal('personal');

  const CalendarEventCategory(this.value);
  final String value;

  static CalendarEventCategory? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final category in values) {
      if (category.value == normalized) return category;
    }
    return null;
  }
}

enum CalendarEventSourceType {
  manual('manual'),
  announcement('announcement'),
  bayanihan('bayanihan'),
  documentRequest('document_request'),
  marketplaceMeetup('marketplace_meetup'),
  emergency('emergency');

  const CalendarEventSourceType(this.value);
  final String value;

  static CalendarEventSourceType? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final source in values) {
      if (source.value == normalized) return source;
    }
    return null;
  }
}

enum CalendarEventVisibility {
  public('public'),
  barangay('barangay'),
  private('private');

  const CalendarEventVisibility(this.value);
  final String value;

  static CalendarEventVisibility? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final visibility in values) {
      if (visibility.value == normalized) return visibility;
    }
    return null;
  }
}

enum CalendarEventStatus {
  scheduled('scheduled'),
  ongoing('ongoing'),
  completed('completed'),
  cancelled('cancelled');

  const CalendarEventStatus(this.value);
  final String value;

  static CalendarEventStatus? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final status in values) {
      if (status.value == normalized) return status;
    }
    return null;
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.category,
    this.categoryName = '',
    required this.location,
    required this.createdBy,
    required this.sourceType,
    required this.sourceId,
    required this.visibility,
    required this.targetBarangay,
    required this.targetUserIds,
    required this.audienceKeys,
    required this.status,
    required this.isImportant,
    required this.organizerName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final CalendarEventCategory category;
  final String categoryName;
  final String location;
  final String createdBy;
  final CalendarEventSourceType sourceType;
  final String sourceId;
  final CalendarEventVisibility visibility;
  final String targetBarangay;
  final List<String> targetUserIds;
  final List<String> audienceKeys;
  final CalendarEventStatus status;
  final bool isImportant;
  final String organizerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayCategory => categoryName.trim().isNotEmpty
      ? categoryName.trim()
      : (category == CalendarEventCategory.announcement
          ? 'Community Activity'
          : category.value.replaceAll('_', ' ').toUpperCase());

  bool get isCommunity => visibility != CalendarEventVisibility.private;
  bool get isCancelled => status == CalendarEventStatus.cancelled;

  bool occursOn(DateTime localDay) {
    final dayStart = DateTime(localDay.year, localDay.month, localDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return startAt.isBefore(dayEnd) && endAt.isAfter(dayStart);
  }

  bool isVisibleTo({required String userId, String? barangay}) {
    return switch (visibility) {
      CalendarEventVisibility.public => true,
      CalendarEventVisibility.barangay =>
        targetBarangay.trim().toLowerCase() == barangay?.trim().toLowerCase(),
      CalendarEventVisibility.private => targetUserIds.contains(userId),
    };
  }

  Map<String, dynamic> toFirestore({
    Object? createdAtValue,
    Object? updatedAtValue,
  }) {
    return {
      'id': id,
      'title': title.trim(),
      'description': description.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'allDay': allDay,
      'category': category.value,
      'location': location.trim(),
      'createdBy': createdBy,
      'sourceType': sourceType.value,
      'sourceId': sourceId,
      'visibility': visibility.value,
      'targetBarangay': targetBarangay,
      'targetUserIds': targetUserIds,
      'audienceKeys': audienceKeys,
      'status': status.value,
      'isImportant': isImportant,
      'organizerName': organizerName.trim(),
      'createdAt':
          createdAtValue ??
          (createdAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(createdAt!)),
      'updatedAt': updatedAtValue ?? FieldValue.serverTimestamp(),
    };
  }

  factory CalendarEvent.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return CalendarEvent.fromMap(document.data() ?? const {}, id: document.id);
  }

  static CalendarEventCategory? _parseCategory(Object? value) {
    if (value == null) return CalendarEventCategory.announcement;
    final parsed = CalendarEventCategory.tryParse(value);
    if (parsed != null) return parsed;
    final normalized = value.toString().trim().toLowerCase();
    return switch (normalized) {
      'event' || 'barangay' || 'activity' => CalendarEventCategory.barangayEvent,
      'announcements' => CalendarEventCategory.announcement,
      'meetup' => CalendarEventCategory.marketplaceMeetup,
      'job' || 'bayanihan_job' => CalendarEventCategory.bayanihan,
      'doc' || 'document_request' => CalendarEventCategory.document,
      _ => null,
    };
  }

  static CalendarEventSourceType? _parseSourceType(Object? value) {
    if (value == null) return CalendarEventSourceType.announcement;
    final parsed = CalendarEventSourceType.tryParse(value);
    if (parsed != null) return parsed;
    final normalized = value.toString().trim().toLowerCase();
    return switch (normalized) {
      'announcements' => CalendarEventSourceType.announcement,
      'job' || 'bayanihan_job' => CalendarEventSourceType.bayanihan,
      'doc' || 'document_request' => CalendarEventSourceType.documentRequest,
      'meetup' => CalendarEventSourceType.marketplaceMeetup,
      _ => null,
    };
  }

  static CalendarEventVisibility? _parseVisibility(Object? value) {
    if (value == null) return CalendarEventVisibility.public;
    final parsed = CalendarEventVisibility.tryParse(value);
    if (parsed != null) return parsed;
    final normalized = value.toString().trim().toLowerCase();
    return switch (normalized) {
      'all' || 'everyone' => CalendarEventVisibility.public,
      'brgy' || 'community' => CalendarEventVisibility.barangay,
      'only_me' || 'user' => CalendarEventVisibility.private,
      _ => null,
    };
  }

  static CalendarEventStatus? _parseStatus(Object? value) {
    if (value == null) return CalendarEventStatus.scheduled;
    final parsed = CalendarEventStatus.tryParse(value);
    if (parsed != null) return parsed;
    final normalized = value.toString().trim().toLowerCase();
    return switch (normalized) {
      'active' || 'pending' || 'upcoming' || 'open' => CalendarEventStatus.scheduled,
      'in_progress' || 'happening' => CalendarEventStatus.ongoing,
      'done' || 'finished' || 'resolved' => CalendarEventStatus.completed,
      'canceled' || 'archived' => CalendarEventStatus.cancelled,
      _ => null,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    final category = _parseCategory(map['category']);
    if (category == null) {
      throw FormatException('Invalid calendar event category: ${map['category']}');
    }
    final sourceType = _parseSourceType(map['sourceType']);
    if (sourceType == null) {
      throw FormatException('Invalid calendar event sourceType: ${map['sourceType']}');
    }
    final visibility = _parseVisibility(map['visibility']);
    if (visibility == null) {
      throw FormatException('Invalid calendar event visibility: ${map['visibility']}');
    }
    final status = _parseStatus(map['status']);
    if (status == null) {
      throw FormatException('Invalid calendar event status: ${map['status']}');
    }
    final startAt = dateTimeFromFirestore(map['startAt']);
    final endAt = dateTimeFromFirestore(map['endAt']);
    if (!endAt.isAfter(startAt)) {
      throw const FormatException('Calendar event end must follow its start.');
    }
    return CalendarEvent(
      id: id ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      startAt: startAt,
      endAt: endAt,
      allDay: map['allDay'] == true,
      category: category,
      categoryName: map['categoryName']?.toString() ??
          map['displayCategory']?.toString() ??
          '',
      location: map['location']?.toString() ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      sourceType: sourceType,
      sourceId: map['sourceId']?.toString() ?? '',
      visibility: visibility,
      targetBarangay: map['targetBarangay']?.toString() ?? '',
      targetUserIds: (map['targetUserIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      audienceKeys: (map['audienceKeys'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      status: status,
      isImportant: map['isImportant'] == true,
      organizerName: map['organizerName']?.toString() ?? '',
      createdAt: nullableDateTimeFromFirestore(map['createdAt']),
      updatedAt: nullableDateTimeFromFirestore(map['updatedAt']),
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    CalendarEventCategory? category,
    String? categoryName,
    String? location,
    String? createdBy,
    CalendarEventSourceType? sourceType,
    String? sourceId,
    CalendarEventVisibility? visibility,
    String? targetBarangay,
    List<String>? targetUserIds,
    List<String>? audienceKeys,
    CalendarEventStatus? status,
    bool? isImportant,
    String? organizerName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      visibility: visibility ?? this.visibility,
      targetBarangay: targetBarangay ?? this.targetBarangay,
      targetUserIds: targetUserIds ?? this.targetUserIds,
      audienceKeys: audienceKeys ?? this.audienceKeys,
      status: status ?? this.status,
      isImportant: isImportant ?? this.isImportant,
      organizerName: organizerName ?? this.organizerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
