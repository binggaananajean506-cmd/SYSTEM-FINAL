import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth_service.dart';
import '../../../barili_barangays.dart';
import '../../../community_service.dart';
import '../domain/calendar_event.dart';

class CalendarValidationException implements Exception {
  const CalendarValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CalendarService {
  static final shared = CalendarService();
  final Map<String, Stream<Set<String>>> _savedStreams = {};
  final Map<String, Set<String>> _savedIds = {};
  CalendarService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const collectionName = 'calendar_events';
  static const _maximumLoadedEvents = 300;
  static const _maximumEventDuration = Duration(days: 14);

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection(collectionName);

  Future<CommunityPost?> fetchAnnouncementPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;
      return CommunityPost.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  Set<String> savedAnnouncementIds(String userId) =>
      _savedIds[userId] ?? const {};

  Stream<Set<String>> watchSavedAnnouncements(String userId) =>
      _savedStreams.putIfAbsent(
        userId,
        () => _firestore
            .collection('users')
            .doc(userId)
            .collection('calendar_entries')
            .snapshots()
            .map((snapshot) {
              final ids = snapshot.docs.map((doc) => doc.id).toSet();
              _savedIds[userId] = ids;
              return ids;
            })
            .asBroadcastStream(
              onCancel: (subscription) {
                subscription.cancel();
                _savedStreams.remove(userId);
              },
            ),
      );

  Future<CalendarEvent> announcementEvent(String announcementId) async {
    final doc = await _events
        .doc(
          sourceEventId(CalendarEventSourceType.announcement, announcementId),
        )
        .get(const GetOptions(source: Source.server));
    if (!doc.exists) {
      throw const CalendarValidationException(
        'The event schedule is not available yet. Please try again.',
      );
    }
    return CalendarEvent.fromDoc(doc);
  }

  Future<CalendarEvent> saveAnnouncementToCalendar(
    User user,
    String announcementId,
  ) async {
    if (!user.canUseInteractiveFeatures) {
      throw const CalendarValidationException('Verify your account first to add events to your calendar.');
    }
    final eventId = sourceEventId(
      CalendarEventSourceType.announcement,
      announcementId,
    );
    final entry = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('calendar_entries')
        .doc(eventId);
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(entry);
      final eventDoc = await transaction.get(_events.doc(eventId));
      if (!eventDoc.exists) {
        throw const CalendarValidationException(
          'The event schedule is being updated. Please try again.',
        );
      }
      final event = CalendarEvent.fromDoc(eventDoc);
      if (!event.isVisibleTo(userId: user.uid, barangay: user.barangay) ||
          event.isCancelled) {
        throw const CalendarValidationException(
          'This event is no longer available to add.',
        );
      }
      if (!existing.exists) {
        transaction.set(entry, {
          'userId': user.uid,
          'eventId': eventId,
          'sourceAnnouncementId': announcementId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return event;
    });
  }

  Future<void> removeAnnouncementFromCalendar(
    User user,
    String announcementId,
  ) async {
    final eventId = sourceEventId(
      CalendarEventSourceType.announcement,
      announcementId,
    );
    final entry = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('calendar_entries')
        .doc(eventId);
    await entry.delete();
  }

  static bool isAnnouncementSaved(
    Set<String>? savedIds,
    String announcementId,
  ) {
    if (savedIds == null || savedIds.isEmpty) return false;
    final eventId = sourceEventId(
      CalendarEventSourceType.announcement,
      announcementId,
    );
    return savedIds.contains(eventId);
  }

  static List<String> audienceKeysFor(User user) {
    final keys = <String>['municipality:barili', 'user:${user.uid}'];
    final barangay = canonicalBariliBarangay(user.barangay);
    if (barangay != null) keys.add('barangay:$barangay');
    return keys;
  }

  Stream<List<CalendarEvent>> fetchEventsForRange({
    required User user,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final queryStart = rangeStart.subtract(_maximumEventDuration);
    final queries = _visibleQueriesFor(user)
        .map(
          (query) => query
              .where(
                'startAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart),
              )
              .where('startAt', isLessThan: Timestamp.fromDate(rangeEnd))
              .orderBy('startAt')
              .limit(_maximumLoadedEvents),
        )
        .toList(growable: false);
    return _watchQueries(queries, (event) {
      return event.endAt.isAfter(rangeStart) &&
          event.isVisibleTo(userId: user.uid, barangay: user.barangay);
    });
  }

  Stream<List<CalendarEvent>> fetchUpcomingEvents({
    required User user,
    int limit = 3,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final fetchLimit = limit < 3 ? 12 : limit * 4;
    final queries = _visibleQueriesFor(user)
        .map(
          (query) => query
              .where(
                'startAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(current),
              )
              .orderBy('startAt')
              .limit(fetchLimit),
        )
        .toList(growable: false);
    return _watchQueries(queries, (event) {
      return event.status != CalendarEventStatus.cancelled &&
          event.status != CalendarEventStatus.completed &&
          event.isVisibleTo(userId: user.uid, barangay: user.barangay);
    }).map((events) => events.take(limit).toList(growable: false));
  }

  List<Query<Map<String, dynamic>>> _visibleQueriesFor(User user) {
    final queries = <Query<Map<String, dynamic>>>[
      _events.where(
        'visibility',
        isEqualTo: CalendarEventVisibility.public.value,
      ),
      _events
          .where('visibility', isEqualTo: CalendarEventVisibility.private.value)
          .where('targetUserIds', arrayContains: user.uid),
    ];
    final barangay = canonicalBariliBarangay(user.barangay);
    if (barangay != null) {
      queries.add(
        _events
            .where(
              'visibility',
              isEqualTo: CalendarEventVisibility.barangay.value,
            )
            .where('targetBarangay', isEqualTo: barangay),
      );
    }
    return queries;
  }

  Stream<List<CalendarEvent>> _watchQueries(
    List<Query<Map<String, dynamic>>> queries,
    bool Function(CalendarEvent event) include,
  ) {
    late final StreamController<List<CalendarEvent>> controller;
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      queries.length,
      null,
    );

    void emitWhenReady() {
      if (latest.any((snapshot) => snapshot == null)) return;
      final eventsById = <String, CalendarEvent>{};
      for (final snapshot
          in latest.whereType<QuerySnapshot<Map<String, dynamic>>>()) {
        for (final document in snapshot.docs) {
          try {
            final event = CalendarEvent.fromDoc(document);
            if (include(event)) eventsById[event.id] = event;
          } on FormatException {
            // Ignore malformed legacy records instead of failing the page.
          }
        }
      }
      controller.add(sortEvents(eventsById.values));
    }

    controller = StreamController<List<CalendarEvent>>(
      onListen: () {
        for (var index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots().listen((snapshot) {
              latest[index] = snapshot;
              emitWhenReady();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<String> createEvent(CalendarEvent event) async {
    validate(event, allowPast: false);
    final reference = event.id.trim().isEmpty
        ? _events.doc()
        : _events.doc(event.id);
    final normalized = event.copyWith(id: reference.id);
    await reference.set(normalized.toFirestore());
    return reference.id;
  }

  Future<void> updateEvent(CalendarEvent event) async {
    if (event.id.trim().isEmpty) {
      throw const CalendarValidationException('The event is missing its ID.');
    }
    validate(event, allowPast: event.status != CalendarEventStatus.scheduled);
    final data = event.toFirestore(
      createdAtValue: event.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(event.createdAt!),
    );
    await _events.doc(event.id).set(data, SetOptions(merge: true));
  }

  Future<void> cancelEvent(String eventId) async {
    final eventDoc = await _events.doc(eventId).get();
    final event = CalendarEvent.fromDoc(eventDoc);
    final batch = _firestore.batch();
    batch.update(_events.doc(eventId), {
      'status': CalendarEventStatus.cancelled.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (event.sourceType == CalendarEventSourceType.announcement) {
      batch.update(_firestore.collection('posts').doc(event.sourceId), {
        'eventCancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteEvent(String eventId) => _events.doc(eventId).delete();

  Future<String> syncSourceEvent(CalendarEvent event) async {
    if (event.sourceType == CalendarEventSourceType.manual ||
        event.sourceId.trim().isEmpty) {
      throw const CalendarValidationException(
        'A linked event requires a source type and source ID.',
      );
    }
    final documentId = sourceEventId(event.sourceType, event.sourceId);
    final linked = event.copyWith(id: documentId);
    validate(linked, allowPast: linked.status != CalendarEventStatus.scheduled);
    await _events
        .doc(documentId)
        .set(linked.toFirestore(), SetOptions(merge: true));
    return documentId;
  }

  static String sourceEventId(CalendarEventSourceType type, String sourceId) {
    final safeSource = sourceId.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return 'source_${type.value}_$safeSource';
  }

  static List<CalendarEvent> eventsForDay(
    Iterable<CalendarEvent> events,
    DateTime day,
  ) => sortEvents(events.where((event) => event.occursOn(day)));

  static List<CalendarEvent> sortEvents(Iterable<CalendarEvent> events) {
    final sorted = events.toList();
    sorted.sort((left, right) {
      final startComparison = left.startAt.compareTo(right.startAt);
      if (startComparison != 0) return startComparison;
      if (left.isImportant != right.isImportant) {
        return left.isImportant ? -1 : 1;
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return sorted;
  }

  static bool canCreateOfficialEvent(User user) =>
      user.isActive &&
      (user.role == UserRole.lgu || user.role == UserRole.barangay);

  static bool canManageEvent(User user, CalendarEvent event) {
    if (event.visibility == CalendarEventVisibility.private) {
      return event.sourceType == CalendarEventSourceType.manual &&
          event.createdBy == user.uid;
    }
    if (user.role == UserRole.lgu && user.isActive) return true;
    final userBarangay = canonicalBariliBarangay(user.barangay);
    return user.role == UserRole.barangay &&
        user.isActive &&
        event.visibility == CalendarEventVisibility.barangay &&
        userBarangay != null &&
        event.targetBarangay == userBarangay;
  }

  static void validate(CalendarEvent event, {required bool allowPast}) {
    final title = event.title.trim();
    final description = event.description.trim();
    final location = event.location.trim();
    if (title.isEmpty || title.length > 120) {
      throw const CalendarValidationException(
        'Enter an event title with no more than 120 characters.',
      );
    }
    if (description.length > 1200) {
      throw const CalendarValidationException(
        'Description must be 1,200 characters or fewer.',
      );
    }
    if (location.length > 200) {
      throw const CalendarValidationException(
        'Location must be 200 characters or fewer.',
      );
    }
    if (!event.endAt.isAfter(event.startAt)) {
      throw const CalendarValidationException(
        'End time must be after start time.',
      );
    }
    if (event.endAt.difference(event.startAt) > _maximumEventDuration) {
      throw const CalendarValidationException(
        'An event cannot exceed 14 days.',
      );
    }
    if (!allowPast &&
        event.status == CalendarEventStatus.scheduled &&
        (event.allDay ? event.endAt : event.startAt).isBefore(
          DateTime.now().subtract(const Duration(minutes: 1)),
        )) {
      throw const CalendarValidationException('Choose a future date and time.');
    }
    if (event.visibility == CalendarEventVisibility.barangay &&
        canonicalBariliBarangay(event.targetBarangay) == null) {
      throw const CalendarValidationException('Choose a valid barangay.');
    }
    if (event.visibility == CalendarEventVisibility.private &&
        event.targetUserIds.isEmpty) {
      throw const CalendarValidationException(
        'A private event needs an owner.',
      );
    }
  }
}
