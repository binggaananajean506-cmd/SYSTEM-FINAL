import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../community_service.dart';
import '../../../app/theme/app_colors.dart';

class AnnouncementCalendarAction extends StatelessWidget {
  const AnnouncementCalendarAction({super.key, required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    if (!post.hasCalendarSchedule || post.eventDate == null) {
      return const SizedBox.shrink();
    }

    final eventDate = post.eventDate!.toLocal();
    final dateStr = DateFormat('EEEE, MMMM d, y').format(eventDate);
    final timeStr = post.isAllDayEvent
        ? 'All day'
        : post.eventEndDate != null
            ? '${DateFormat('h:mm a').format(eventDate)} – ${DateFormat('h:mm a').format(post.eventEndDate!.toLocal())}'
            : DateFormat('h:mm a').format(eventDate);

    final locationStr = post.location.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 12,
                          color: context.colors.onAccent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'COMMUNITY CALENDAR',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onAccent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-Scheduled',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date & Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: context.colors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Location if present
          if (locationStr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: context.colors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locationStr,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 14,
                  color: context.colors.primaryGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Residents will receive an automatic reminder before this schedule.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
