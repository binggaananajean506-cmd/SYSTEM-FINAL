import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/calendar_event.dart';

extension CalendarEventPresentation on CalendarEventCategory {
  String get label => switch (this) {
    CalendarEventCategory.barangayEvent => 'Barangay Event',
    CalendarEventCategory.bayanihan => 'Bayanihan',
    CalendarEventCategory.announcement => 'Announcement',
    CalendarEventCategory.document => 'Document Schedule',
    CalendarEventCategory.marketplaceMeetup => 'Marketplace Meetup',
    CalendarEventCategory.emergency => 'Emergency Activity',
    CalendarEventCategory.personal => 'Personal Reminder',
  };

  IconData get icon => switch (this) {
    CalendarEventCategory.barangayEvent => Icons.account_balance_rounded,
    CalendarEventCategory.bayanihan => Icons.handshake_rounded,
    CalendarEventCategory.announcement => Icons.campaign_rounded,
    CalendarEventCategory.document => Icons.description_rounded,
    CalendarEventCategory.marketplaceMeetup => Icons.storefront_rounded,
    CalendarEventCategory.emergency => Icons.health_and_safety_rounded,
    CalendarEventCategory.personal => Icons.bookmark_rounded,
  };

  Color colorFor(BuildContext context) => switch (this) {
    CalendarEventCategory.barangayEvent => context.colors.primaryGreen,
    CalendarEventCategory.bayanihan => context.colors.success,
    CalendarEventCategory.announcement => context.colors.info,
    CalendarEventCategory.document => context.colors.purple,
    CalendarEventCategory.marketplaceMeetup => context.colors.warning,
    CalendarEventCategory.emergency => context.colors.error,
    CalendarEventCategory.personal => context.colors.textSecondary,
  };
}

extension CalendarEventStatusPresentation on CalendarEventStatus {
  String get label => switch (this) {
    CalendarEventStatus.scheduled => 'Scheduled',
    CalendarEventStatus.ongoing => 'Ongoing',
    CalendarEventStatus.completed => 'Completed',
    CalendarEventStatus.cancelled => 'Cancelled',
  };
}
