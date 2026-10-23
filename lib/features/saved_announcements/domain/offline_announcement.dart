import '../../../community_service.dart';

class OfflineAnnouncement {
  final String announcementId;
  final String userId;
  final String title;
  final String content;
  final String category;
  final DateTime publishedAt;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final bool? eventAllDay;
  final bool? hasSchedule;
  final bool eventCancelled;
  final String announcementType;
  final String location;
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
  final String status;
  final String tag;
  final String priority;
  final DateTime? priorityExpiresAt;
  final DateTime? expiresAt;
  final Map<String, String> cta;
  final String networkImageUrl;
  final String localImagePath;
  final DateTime sourceUpdatedAt;
  final DateTime savedAt;
  final DateTime lastSyncedAt;
  final bool sourceUnavailable;

  const OfflineAnnouncement({
    required this.announcementId,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.publishedAt,
    this.eventDate,
    this.eventEndDate,
    this.eventAllDay,
    this.hasSchedule,
    this.eventCancelled = false,
    this.announcementType = 'general',
    required this.location,
    required this.authorName,
    required this.authorId,
    required this.authorRole,
    required this.authorPosition,
    required this.authorBarangay,
    required this.authorOrganizationName,
    required this.publisherEntityId,
    required this.publisherEntityType,
    required this.publisherEntityName,
    required this.targetAudience,
    required this.targetBarangay,
    required this.visibility,
    required this.targetBarangays,
    required this.status,
    required this.tag,
    required this.priority,
    this.priorityExpiresAt,
    this.expiresAt,
    required this.cta,
    required this.networkImageUrl,
    required this.localImagePath,
    required this.sourceUpdatedAt,
    required this.savedAt,
    required this.lastSyncedAt,
    this.sourceUnavailable = false,
  });

  factory OfflineAnnouncement.fromPost({
    required String userId,
    required CommunityPost post,
    DateTime? savedAt,
    DateTime? lastSyncedAt,
    String localImagePath = '',
  }) {
    final now = DateTime.now().toUtc();
    return OfflineAnnouncement(
      announcementId: post.id,
      userId: userId,
      title: post.title,
      content: post.content,
      category: post.displayCategory,
      publishedAt: post.createdAt,
      eventDate: post.eventDate,
      eventEndDate: post.eventEndDate,
      eventAllDay: post.eventAllDay,
      hasSchedule: post.hasSchedule,
      eventCancelled: post.eventCancelled,
      announcementType: post.announcementType,
      location: post.location,
      authorName: post.authorName,
      authorId: post.authorId,
      authorRole: post.authorRole,
      authorPosition: post.authorPosition,
      authorBarangay: post.authorBarangay,
      authorOrganizationName: post.authorOrganizationName,
      publisherEntityId: post.publisherEntityId,
      publisherEntityType: post.publisherEntityType,
      publisherEntityName: post.publisherEntityName,
      targetAudience: post.targetAudience,
      targetBarangay: post.targetBarangay,
      visibility: post.visibility,
      targetBarangays: List.unmodifiable(post.targetBarangays),
      status: post.status,
      tag: post.tag,
      priority: post.priority,
      priorityExpiresAt: post.priorityExpiresAt,
      expiresAt: post.expiresAt,
      cta: Map.unmodifiable(post.cta),
      networkImageUrl: post.imageUrl,
      localImagePath: localImagePath,
      sourceUpdatedAt: post.updatedAt,
      savedAt: savedAt ?? now,
      lastSyncedAt: lastSyncedAt ?? now,
    );
  }

  CommunityPost toPost() {
    return CommunityPost(
      id: announcementId,
      title: title,
      content: content,
      authorName: authorName,
      authorId: authorId,
      authorRole: authorRole,
      authorPosition: authorPosition,
      authorBarangay: authorBarangay,
      authorOrganizationName: authorOrganizationName,
      publisherEntityId: publisherEntityId,
      publisherEntityType: publisherEntityType,
      publisherEntityName: publisherEntityName,
      targetAudience: targetAudience,
      targetBarangay: targetBarangay,
      visibility: visibility,
      targetBarangays: targetBarangays,
      imageUrl: networkImageUrl,
      localImagePath: localImagePath,
      createdAt: publishedAt,
      updatedAt: sourceUpdatedAt,
      status: sourceUnavailable ? 'unavailable' : status,
      tag: tag,
      priority: priority,
      priorityExpiresAt: priorityExpiresAt,
      category: category,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      eventAllDay: eventAllDay,
      hasSchedule: hasSchedule,
      eventCancelled: eventCancelled,
      announcementType: announcementType,
      expiresAt: expiresAt,
      location: location,
      cta: cta,
      sourceUnavailable: sourceUnavailable,
    );
  }

  OfflineAnnouncement copyWith({
    String? localImagePath,
    DateTime? lastSyncedAt,
    bool? sourceUnavailable,
  }) {
    return OfflineAnnouncement(
      announcementId: announcementId,
      userId: userId,
      title: title,
      content: content,
      category: category,
      publishedAt: publishedAt,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      eventAllDay: eventAllDay,
      hasSchedule: hasSchedule,
      eventCancelled: eventCancelled,
      announcementType: announcementType,
      location: location,
      authorName: authorName,
      authorId: authorId,
      authorRole: authorRole,
      authorPosition: authorPosition,
      authorBarangay: authorBarangay,
      authorOrganizationName: authorOrganizationName,
      publisherEntityId: publisherEntityId,
      publisherEntityType: publisherEntityType,
      publisherEntityName: publisherEntityName,
      targetAudience: targetAudience,
      targetBarangay: targetBarangay,
      visibility: visibility,
      targetBarangays: targetBarangays,
      status: status,
      tag: tag,
      priority: priority,
      priorityExpiresAt: priorityExpiresAt,
      expiresAt: expiresAt,
      cta: cta,
      networkImageUrl: networkImageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      sourceUpdatedAt: sourceUpdatedAt,
      savedAt: savedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      sourceUnavailable: sourceUnavailable ?? this.sourceUnavailable,
    );
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      title,
      content,
      category,
      location,
    ].join(' ').toLowerCase().contains(normalized);
  }

  Map<String, dynamic> toLocal() => {
    'announcementId': announcementId,
    'userId': userId,
    'title': title,
    'content': content,
    'category': category,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'eventDate': eventDate?.toUtc().toIso8601String(),
    'eventEndDate': eventEndDate?.toIso8601String(),
    'eventAllDay': eventAllDay,
    'hasSchedule': hasSchedule,
    'eventCancelled': eventCancelled,
    'announcementType': announcementType,
    'location': location,
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
    'targetBarangays': targetBarangays,
    'status': status,
    'tag': tag,
    'priority': priority,
    'priorityExpiresAt': priorityExpiresAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'cta': cta,
    'networkImageUrl': networkImageUrl,
    'localImagePath': localImagePath,
    'sourceUpdatedAt': sourceUpdatedAt.toUtc().toIso8601String(),
    'savedAt': savedAt.toUtc().toIso8601String(),
    'lastSyncedAt': lastSyncedAt.toUtc().toIso8601String(),
    'sourceUnavailable': sourceUnavailable,
  };

  factory OfflineAnnouncement.fromLocal(Map<String, dynamic> map) {
    DateTime requiredDate(String key) =>
        DateTime.parse(map[key].toString()).toUtc();
    DateTime? optionalDate(String key) {
      final value = map[key]?.toString() ?? '';
      return value.isEmpty ? null : DateTime.tryParse(value)?.toUtc();
    }

    return OfflineAnnouncement(
      announcementId: map['announcementId'].toString(),
      userId: map['userId'].toString(),
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      publishedAt: requiredDate('publishedAt'),
      eventDate: optionalDate('eventDate'),
      eventEndDate: optionalDate('eventEndDate'),
      eventAllDay: map['eventAllDay'] as bool?,
      hasSchedule: map['hasSchedule'] as bool?,
      eventCancelled: map['eventCancelled'] == true,
      announcementType: map['announcementType']?.toString() ?? 'general',
      location: map['location']?.toString() ?? '',
      authorName: map['authorName']?.toString().toLowerCase() == 'anajean' || map['authorName']?.toString().contains('@') == true
          ? (map['publisherEntityName']?.toString().isNotEmpty == true
              ? map['publisherEntityName']!.toString()
              : 'LGU IT DEPARTMENT')
          : (map['authorName']?.toString() ?? 'Official'),
      authorId: map['authorId']?.toString() ?? '',
      authorRole: map['authorRole']?.toString() ?? '',
      authorPosition: map['authorPosition']?.toString() ?? '',
      authorBarangay: map['authorBarangay']?.toString() ?? '',
      authorOrganizationName: map['authorOrganizationName']?.toString() ?? '',
      publisherEntityId: map['publisherEntityId']?.toString() ?? '',
      publisherEntityType: map['publisherEntityType']?.toString() ?? '',
      publisherEntityName: map['publisherEntityName']?.toString().isNotEmpty == true
          ? map['publisherEntityName']!.toString()
          : (map['authorRole']?.toString() == 'lgu' || map['authorRole']?.toString() == 'super_admin' ? 'LGU IT DEPARTMENT' : ''),
      targetAudience: map['targetAudience']?.toString() ?? 'All Residents',
      targetBarangay: map['targetBarangay']?.toString() ?? 'All Barangays',
      visibility: map['visibility']?.toString() ?? 'public',
      targetBarangays: (map['targetBarangays'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      status: map['status']?.toString() ?? 'approved',
      tag: map['tag']?.toString() ?? 'OFFICIAL',
      priority: map['priority']?.toString() ?? 'regular',
      priorityExpiresAt: optionalDate('priorityExpiresAt'),
      expiresAt: optionalDate('expiresAt'),
      cta: (map['cta'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      networkImageUrl: map['networkImageUrl']?.toString() ?? '',
      localImagePath: map['localImagePath']?.toString() ?? '',
      sourceUpdatedAt: requiredDate('sourceUpdatedAt'),
      savedAt: requiredDate('savedAt'),
      lastSyncedAt: requiredDate('lastSyncedAt'),
      sourceUnavailable: map['sourceUnavailable'] == true,
    );
  }
}
