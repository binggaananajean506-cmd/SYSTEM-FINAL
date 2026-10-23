import 'package:esugid/auth_service.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/features/calendar/presentation/announcement_calendar_action.dart';
import 'package:esugid/features/saved_announcements/domain/offline_announcement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPost post({
  DateTime? start,
  DateTime? end,
  bool? allDay,
  bool? enabled,
  bool cancelled = false,
  String status = 'approved',
}) => CommunityPost(
  id: 'assembly',
  title: 'Barangay Assembly',
  content: 'September 15 at 7 AM',
  authorName: 'Official',
  authorId: 'official',
  authorRole: 'barangay',
  authorBarangay: 'Cabcaban',
  authorOrganizationName: '',
  targetAudience: 'All Residents',
  targetBarangay: 'Cabcaban',
  visibility: 'targeted',
  targetBarangays: const ['Cabcaban'],
  createdAt: DateTime(2026, 9, 1),
  status: status,
  tag: 'OFFICIAL',
  eventDate: start,
  eventEndDate: end,
  eventAllDay: allDay,
  hasSchedule: enabled,
  eventCancelled: cancelled,
  announcementType: 'event',
  location: 'Barangay Hall',
);

void main() {
  final day = DateTime(2026, 9, 15);
  test(
    'calendar eligibility uses structured dates, never description text',
    () {
      expect(post().hasCalendarSchedule, isFalse);
      expect(post(start: day).hasCalendarSchedule, isTrue);
      expect(post(start: day).isAllDayEvent, isTrue);
      expect(post(start: day, enabled: false).hasCalendarSchedule, isFalse);
      expect(post(start: day, cancelled: true).hasCalendarSchedule, isFalse);
      expect(post(start: day, status: 'draft').hasCalendarSchedule, isFalse);
      expect(post(start: day, allDay: false).hasCalendarSchedule, isFalse);
      expect(post(start: day, end: day).hasCalendarSchedule, isFalse);
      expect(
        post(
          start: day,
          end: day.subtract(const Duration(hours: 1)),
        ).hasCalendarSchedule,
        isFalse,
      );
      expect(
        post(
          start: day,
          end: day.add(const Duration(hours: 2)),
        ).hasCalendarSchedule,
        isTrue,
      );
      expect(
        post(
          start: day,
          end: day.add(const Duration(days: 15)),
        ).hasCalendarSchedule,
        isFalse,
      );
    },
  );

  test('dashboard and saved announcement caches retain schedule metadata', () {
    final original = post(
      start: day,
      end: day.add(const Duration(hours: 2)),
      allDay: false,
    );
    final cached = CommunityPost.fromLocalCache(original.toLocalCache());
    final offline = OfflineAnnouncement.fromLocal(
      OfflineAnnouncement.fromPost(
        userId: 'resident',
        post: original,
      ).toLocal(),
    ).toPost();
    for (final restored in [cached, offline]) {
      expect(restored.eventDate!.isAtSameMomentAs(original.eventDate!), isTrue);
      expect(
        restored.eventEndDate!.isAtSameMomentAs(original.eventEndDate!),
        isTrue,
      );
      expect(restored.eventAllDay, false);
      expect(restored.announcementType, 'event');
      expect(restored.hasCalendarSchedule, true);
    }
  });

  testWidgets(
    'date-only schedule stays compact and shows All day, not a fake time',
    (tester) async {
      AuthService.currentUser = null;
      tester.view.physicalSize = const Size(240, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCalendarAction(post: post(start: day)),
          ),
        ),
      );
      expect(find.textContaining('All day'), findsOneWidget);
      expect(find.textContaining('12:00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AnnouncementCalendarAction(post: post())),
        ),
      );
      expect(find.textContaining('All day'), findsNothing);
      expect(find.text('Add to Calendar'), findsNothing);
    },
  );

  testWidgets(
    'AnnouncementCalendarAction displays official community schedule and no manual add button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementCalendarAction(
              post: post(
                start: day,
                end: day.add(const Duration(hours: 3)),
              ),
            ),
          ),
        ),
      );
      expect(find.text('COMMUNITY CALENDAR'), findsOneWidget);
      expect(find.text('Auto-Scheduled'), findsOneWidget);
      expect(find.text('Add to Calendar'), findsNothing);
      expect(find.text('Add to My Calendar'), findsNothing);
    },
  );
}
