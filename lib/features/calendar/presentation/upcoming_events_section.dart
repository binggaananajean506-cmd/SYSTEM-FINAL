import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../auth_service.dart';
import '../data/calendar_service.dart';
import '../domain/calendar_event.dart';
import 'calendar_event_details.dart';
import 'calendar_event_presentation.dart';

class UpcomingEventsSection extends StatelessWidget {
  const UpcomingEventsSection({
    super.key,
    required this.user,
    required this.onViewCalendar,
    this.service,
  });

  final User user;
  final VoidCallback onViewCalendar;
  final CalendarService? service;

  @override
  Widget build(BuildContext context) {
    final calendarService = service ?? CalendarService();
    return StreamBuilder<List<CalendarEvent>>(
      stream: calendarService.fetchUpcomingEvents(user: user, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)) {
          if (snapshot.hasError) return const SizedBox.shrink();
          return const _UpcomingSkeleton();
        }
        final events = snapshot.data ?? const <CalendarEvent>[];
        if (events.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
            boxShadow: ESugidClay.raisedShadows(depth: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: context.colors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UPCOMING',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                        Text(
                          'Community calendar',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onViewCalendar,
                    child: const Text('View Calendar →'),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ...events.map(
                (event) => _UpcomingRow(
                  event: event,
                  onTap: () => showCalendarEventDetails(
                    context,
                    event: event,
                    user: user,
                    service: calendarService,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.event, required this.onTap});
  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: event.category.colorFor(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(event.startAt).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: event.category.colorFor(context),
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(event.startAt),
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    event.allDay
                        ? 'All day • ${event.category.label}'
                        : '${DateFormat('h:mm a').format(event.startAt)} • ${event.category.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSkeleton extends StatelessWidget {
  const _UpcomingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
