import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esugid/features/calendar/data/calendar_service.dart';
import 'package:esugid/features/calendar/domain/calendar_event.dart';

CalendarEvent event({
  String id = 'event-1',
  DateTime? startAt,
  DateTime? endAt,
  CalendarEventVisibility visibility = CalendarEventVisibility.public,
  List<String> targetUserIds = const [],
  List<String> audienceKeys = const ['municipality:barili'],
  CalendarEventStatus status = CalendarEventStatus.scheduled,
}) {
  final start = startAt ?? DateTime(2026, 9, 12, 7);
  return CalendarEvent(
    id: id,
    title: 'Community Cleanup',
    description: 'Cleanup along the barangay road.',
    startAt: start,
    endAt: endAt ?? start.add(const Duration(hours: 2)),
    allDay: false,
    category: CalendarEventCategory.bayanihan,
    location: 'Barangay Hall',
    createdBy: 'official-1',
    sourceType: CalendarEventSourceType.bayanihan,
    sourceId: 'request-1',
    visibility: visibility,
    targetBarangay: '',
    targetUserIds: targetUserIds,
    audienceKeys: audienceKeys,
    status: status,
    isImportant: false,
    organizerName: 'Barangay Cabcaban',
  );
}

void main() {
  group('CalendarEvent', () {
    test('today all-day event is valid and excludes the following day', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final allDay = event(
        startAt: today,
        endAt: today.add(const Duration(days: 1)),
      ).copyWith(allDay: true);
      expect(
        () => CalendarService.validate(allDay, allowPast: false),
        returnsNormally,
      );
      expect(allDay.occursOn(today), isTrue);
      expect(allDay.occursOn(today.add(const Duration(days: 1))), isFalse);
    });
    test(
      'serializes dates as Firestore timestamps and parses typed values',
      () {
        final original = event();
        final map = original.toFirestore(
          createdAtValue: Timestamp.fromDate(DateTime(2026, 8, 30)),
          updatedAtValue: Timestamp.fromDate(DateTime(2026, 8, 31)),
        );

        expect(map['startAt'], isA<Timestamp>());
        expect(map['endAt'], isA<Timestamp>());
        final restored = CalendarEvent.fromMap(map, id: original.id);
        expect(restored.title, original.title);
        expect(restored.startAt, original.startAt);
        expect(restored.category, CalendarEventCategory.bayanihan);
        expect(restored.sourceType, CalendarEventSourceType.bayanihan);
      },
    );

    test('rejects invalid statuses and categories while parsing', () {
      final map = event().toFirestore(
        createdAtValue: Timestamp.now(),
        updatedAtValue: Timestamp.now(),
      );
      expect(
        () => CalendarEvent.fromMap({...map, 'status': 'removed'}),
        throwsFormatException,
      );
      expect(
        () => CalendarEvent.fromMap({...map, 'category': 'meeting-ish'}),
        throwsFormatException,
      );
    });

    test('includes multi-day and cancelled events on the selected day', () {
      final multiDay = event(
        startAt: DateTime(2026, 9, 12, 22),
        endAt: DateTime(2026, 9, 13, 8),
        status: CalendarEventStatus.cancelled,
      );

      expect(multiDay.occursOn(DateTime(2026, 9, 12)), isTrue);
      expect(multiDay.occursOn(DateTime(2026, 9, 13)), isTrue);
      expect(
        CalendarService.eventsForDay([multiDay], DateTime(2026, 9, 13)),
        contains(multiDay),
      );
    });

    test('sorts upcoming events by start time', () {
      final later = event(id: 'later', startAt: DateTime(2026, 9, 15, 9));
      final earlier = event(id: 'earlier', startAt: DateTime(2026, 9, 12, 9));
      expect(
        CalendarService.sortEvents([later, earlier]).map((item) => item.id),
        ['earlier', 'later'],
      );
    });

    test('separates community, barangay, and private visibility', () {
      expect(
        event().isVisibleTo(userId: 'resident', barangay: 'Poblacion'),
        isTrue,
      );
      final barangayEvent = event().copyWith(
        visibility: CalendarEventVisibility.barangay,
        targetBarangay: 'Cabcaban',
        audienceKeys: const ['barangay:Cabcaban'],
      );
      expect(
        barangayEvent.isVisibleTo(userId: 'resident', barangay: 'Cabcaban'),
        isTrue,
      );
      expect(
        barangayEvent.isVisibleTo(userId: 'resident', barangay: 'Poblacion'),
        isFalse,
      );
      final privateEvent = event(
        visibility: CalendarEventVisibility.private,
        targetUserIds: const ['resident'],
        audienceKeys: const ['user:resident'],
      );
      expect(privateEvent.isVisibleTo(userId: 'resident'), isTrue);
      expect(privateEvent.isVisibleTo(userId: 'other'), isFalse);
    });

    test('source event IDs are deterministic and prevent duplicates', () {
      final first = CalendarService.sourceEventId(
        CalendarEventSourceType.announcement,
        'POST-123',
      );
      final second = CalendarService.sourceEventId(
        CalendarEventSourceType.announcement,
        'POST-123',
      );
      expect(first, second);
      expect(first, 'source_announcement_POST-123');
    });

    test('rejects a past scheduled event and an invalid time range', () {
      final past = event(
        startAt: DateTime.now().subtract(const Duration(hours: 2)),
        endAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(
        () => CalendarService.validate(past, allowPast: false),
        throwsA(isA<CalendarValidationException>()),
      );
      final invalidRange = event().copyWith(endAt: DateTime(2026, 9, 12, 6));
      expect(
        () => CalendarService.validate(invalidRange, allowPast: true),
        throwsA(isA<CalendarValidationException>()),
      );
    });
  });
}
