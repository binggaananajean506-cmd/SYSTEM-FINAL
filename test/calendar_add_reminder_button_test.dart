import 'package:esugid/auth_service.dart';
import 'package:esugid/features/calendar/data/calendar_service.dart';
import 'package:esugid/features/calendar/domain/calendar_event.dart';
import 'package:esugid/features/calendar/presentation/calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalendarService implements CalendarService {
  _FakeCalendarService({this.events = const []});
  final List<CalendarEvent> events;

  @override
  Set<String> savedAnnouncementIds(String userId) => const <String>{};

  @override
  Stream<Set<String>> watchSavedAnnouncements(String userId) =>
      Stream.value(const <String>{});

  @override
  Stream<List<CalendarEvent>> fetchEventsForRange({
    required User user,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      Stream.value(events);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final residentUser = User(
    uid: 'resident_1',
    name: 'Resident One',
    email: 'resident@barili.gov.ph',
    role: UserRole.resident,
    verificationStatus: VerificationStatus.verified,
  );

  testWidgets('Community Calendar has official header, no My Calendar tab, and no Add reminder for residents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          user: residentUser,
          service: _FakeCalendarService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify official header
    expect(find.text('COMMUNITY ACTIVITY HUB'), findsOneWidget);
    expect(find.text('Community Calendar'), findsOneWidget);
    expect(
      find.text('Official schedules, activities, and advisories in your community.'),
      findsNothing,
    );

    // Verify personal calendar, add reminder, and new event features are completely removed
    expect(find.text('My Calendar'), findsNothing);
    expect(find.text('Add reminder'), findsNothing);
    expect(find.text('New event'), findsNothing);
    expect(find.byIcon(Icons.alarm_add_rounded), findsNothing);

    // Empty state
    expect(
      find.text('No scheduled community activities or advisories for this date.'),
      findsOneWidget,
    );
  });

  testWidgets('Community Calendar displays scheduled announcement cards with View Details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 8);
    final event = CalendarEvent(
      id: 'event-power',
      title: 'Scheduled Power Interruption',
      description: 'Power maintenance affecting selected areas.',
      startAt: today,
      endAt: today.add(const Duration(hours: 8)),
      allDay: false,
      category: CalendarEventCategory.announcement,
      categoryName: 'Utility Advisory',
      location: 'Barangay Cabcaban',
      createdBy: 'official-1',
      sourceType: CalendarEventSourceType.announcement,
      sourceId: 'post-power-1',
      visibility: CalendarEventVisibility.public,
      targetBarangay: '',
      targetUserIds: const [],
      audienceKeys: const ['municipality:barili'],
      status: CalendarEventStatus.scheduled,
      isImportant: false,
      organizerName: 'Barangay Cabcaban',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          user: residentUser,
          service: _FakeCalendarService(events: [event]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scheduled Power Interruption'), findsWidgets);
    expect(find.text('Utility Advisory'), findsWidgets);
    expect(find.text('Barangay Cabcaban'), findsWidgets);
    expect(find.text('View Details'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
