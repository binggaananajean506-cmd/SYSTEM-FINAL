# Announcement calendar integration

## Behavior and data

- The web composer is one page: message, recipients, and publishing options. It has one visible type choice (Announcement, Public advisory, Event / activity), with event dates beside the message and Preview/Send available without step navigation.
- There is no separate category input. New saves use `Events` for event/activity posts and `General` otherwise. Existing `scheduled_activity` posts open as Event / activity. Publishing times, audience permissions, notification preferences, and calendar validation still use the existing services.

- Announcement types: `general`, `advisory`, `event`, `scheduled_activity`.
- Event/activity types require a schedule; other types have an optional schedule toggle.
- Structured fields on `posts/{postId}`: `announcementType`, `addToCalendar`, `eventStartAt`, `eventEndAt`, `eventAllDay`, `eventLocation`, `calendarEventId`. `eventCancelled` preserves an explicit calendar cancellation.
- No dates are inferred from announcement descriptions. Missing/invalid schedules, unpublished/unavailable sources and cancelled events have no Add to Calendar action.
- Date-only schedules are all-day items. The end is exclusive (the following midnight), not a fabricated meeting time. Backend normalization uses Barili/Manila (+08:00).
- Timed events require explicit start/end values, with an end after the start and a maximum duration of 14 days.
- Calendar event descriptions are short excerpts; the complete announcement remains unchanged.

## Linking and duplicate prevention

The existing shared record remains `calendar_events/source_announcement_{postId}`, with `sourceType: announcement` and `sourceId: postId`.

A resident saves only a relationship at `users/{uid}/calendar_entries/source_announcement_{postId}`:

- `userId`
- `eventId`
- `sourceAnnouncementId`
- `createdAt`

The transaction reads the source and deterministic link before writing. Repeated taps reuse the same record; no event metadata is copied into a disconnected personal event. Added ✓ opens the existing event. Saved links filter the existing calendar stream into **My Calendar**.

The backend transaction reads the latest original announcement, avoiding stale schedule writes from out-of-order trigger deliveries. Title, date/time, location and description updates flow into the shared event. Cancelled, unpublished, deleted or unscheduled announcements cancel the linked event. Explicit calendar cancellation also marks the original announcement. Existing saved links remain, showing the shared cancelled record when still within the resident's permitted audience.

Firestore rules restrict links to their owner and require a readable public/same-barangay, non-cancelled announcement event. Link updates are disallowed. Calendar authorization checks retain their role/scope restrictions; normalized role whitespace and inexpensive shape checks avoid rejecting valid legacy staff profiles.

## Files

- `admin_web/index.html`, `admin_web/app.js`, `admin_web/app.bundle.js`: composer controls, validation and rebuilt bundle.
- `lib/home_screen.dart`: existing Flutter official composer.
- `lib/community_service.dart`: structured metadata, eligibility and linked publication.
- `lib/widgets/community_post_widgets.dart`: compact scheduled announcement UI.
- `lib/features/calendar/data/calendar_service.dart`: saved relationships and cancellation.
- `lib/features/calendar/presentation/announcement_calendar_action.dart`: Add/Added interaction.
- `lib/features/calendar/presentation/calendar_page.dart`: My Calendar saved announcements.
- `lib/features/calendar/presentation/calendar_event_details.dart`: source label, View Announcement and all-day date rendering.
- `lib/features/saved_announcements/domain/offline_announcement.dart`: preserve schedule metadata in existing offline storage.
- `functions/index.js`, `functions/announcement_schedule.js`, `functions/package.json`: source synchronization and test registration.
- `firestore.rules`: saved-link access and calendar validation.
- `test/announcement_calendar_test.dart`, `test/calendar_event_test.dart`, `functions/announcement_schedule.test.js`, `rules_tests/firestore.rules.test.mjs`: regression tests.

## Activation and manual test

These changes require deploying the updated backend/rules/hosting and rebuilding the Flutter app. No production deployment was performed for this implementation.

```powershell
firebase.cmd deploy --only "functions,firestore:rules,hosting" --project e-sugid
C:\flutter\bin\flutter.bat run
```

1. Publish a General Announcement with no schedule. Confirm no calendar action appears.
2. Publish an Event with a future date and All day enabled. Confirm no time was invented.
3. Publish a timed Scheduled Activity with a location. Check required-date and end-before-start validation.
4. As a resident in the target barangay, tap Add to Calendar. Confirm Added ✓ and one entry in Calendar → My Calendar. Tap Added ✓ again to open its details.
5. Check Source: Community Announcement and View Announcement opens the exact original post.
6. Edit the original announcement's title, schedule and location. Confirm the saved calendar item updates after synchronization, without another Add action.
7. Cancel the event, archive the announcement or remove its optional schedule. Confirm the linked calendar event shows Cancelled rather than its old schedule as active.
8. Sign in as another resident. Saved state must be independent; another barangay must not be able to save a targeted event.

Existing calendar audience limits (municipality-wide or one barangay per event) and bounded range queries are retained. Existing legacy date-only announcements need a source edit/resave if no shared calendar event has previously been created; deploying a trigger does not backfill historical records. Live device/end-to-end publishing still needs the manual checks above.
