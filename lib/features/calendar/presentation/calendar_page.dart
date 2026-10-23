import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../auth_service.dart';
import '../../../core/widgets/async_error_view.dart';
import '../../../widgets/esugid_page_header.dart';
import '../../../widgets/community_post_widgets.dart';
import '../data/calendar_service.dart';
import '../domain/calendar_event.dart';
import 'calendar_event_details.dart';
import 'calendar_event_presentation.dart';

/// Retained for backward compatibility. E-SUGID now uses a single official Community Calendar.
@Deprecated('Retained for compatibility')
enum CalendarView { community, personal }

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    this.user,
    this.service,
    @Deprecated('Retained for compatibility') this.initialView = CalendarView.community,
  });

  final User? user;
  final CalendarService? service;
  @Deprecated('Retained for compatibility')
  final dynamic initialView;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final CalendarService _service;
  late final User? _user;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Stream<List<CalendarEvent>> _events;
  bool _openingDetails = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CalendarService.shared;
    _user = widget.user ?? AuthService.currentUser;
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    _events = _buildRangeStream(_focusedDay);
  }

  Stream<List<CalendarEvent>> _buildRangeStream(DateTime focusedDay) {
    final user = _user;
    if (user == null) return Stream.value(const []);
    final monthStart = DateTime(focusedDay.year, focusedDay.month);
    final rangeStart = DateTime(monthStart.year, monthStart.month - 1);
    final rangeEnd = DateTime(monthStart.year, monthStart.month + 2);
    return _service.fetchEventsForRange(
      user: user,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view the community calendar.')),
      );
    }
    return Scaffold(
      backgroundColor: context.colors.background,
      body: StreamBuilder<List<CalendarEvent>>(
        stream: _events,
        builder: (context, snapshot) {
          final allEvents = snapshot.data ?? const <CalendarEvent>[];
          final visibleEvents = allEvents
              .where((e) => e.visibility != CalendarEventVisibility.private)
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async {
              setState(
                () => _events = _buildRangeStream(_focusedDay));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                // Collapsible Header matching the rest of the application
                // Subtitle and Icon are removed as requested
                ESugidSliverPageHeader(
                  pinned: true,
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                  title: 'Community Calendar',
                  subtitle: null,
                  icon: null,
                  iconWidget: null,
                  sectionLabelWidget: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.primaryGreen.withValues(alpha: 0.45,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5.5,
                          height: 5.5,
                          decoration: BoxDecoration(
                            color: context.colors.brand,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5.5),
                        Text(
                          'COMMUNITY ACTIVITY HUB',
                          style: GoogleFonts.outfit(
                            color: context.colors.onBrandMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AsyncErrorView(
                      message: 'Calendar events could not be loaded.',
                      onRetry: () => setState(() {
                        _events = _buildRangeStream(_focusedDay);
                      }),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _calendarCard(visibleEvents),
                        const SizedBox(height: 20),
                        _selectedDayAgenda(visibleEvents, user),
                        const SizedBox(height: 24),
                        _rangeUpcoming(visibleEvents, user),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _calendarCard(List<CalendarEvent> events) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.border),
        boxShadow: ESugidClay.raisedShadows(depth: 0.62),
      ),
      child: TableCalendar<CalendarEvent>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2036, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: (day) => CalendarService.eventsForDay(events, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) {
          final monthChanged =
              focused.year != _focusedDay.year ||
              focused.month != _focusedDay.month;
          _focusedDay = focused;
          if (monthChanged) {
            setState(() => _events = _buildRangeStream(focused));
          }
        },
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        daysOfWeekHeight: 30,
        rowHeight: 50,
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: context.colors.primaryGreen,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: context.colors.primaryGreen,
          ),
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: context.colors.textPrimary,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.colors.textSecondary,
          ),
          weekendStyle: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.colors.textSecondary,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: context.colors.brand.withValues(alpha: 0.11),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: context.colors.primaryGreen,
            fontWeight: FontWeight.w800,
          ),
          selectedDecoration: BoxDecoration(
            color: context.colors.brand,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: context.colors.onAccent,
            fontWeight: FontWeight.w800,
          ),
          defaultTextStyle: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          weekendTextStyle: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          markersMaxCount: 4,
          markerSize: 6,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
          markerDecoration: BoxDecoration(
            color: context.colors.brand,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, dayEvents) {
            if (dayEvents.isEmpty) return null;
            return Positioned(
              bottom: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: dayEvents
                    .take(3)
                    .map(
                      (event) => Container(
                        width: 5.5,
                        height: 5.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        decoration: BoxDecoration(
                          color: event.isCancelled
                              ? context.colors.errorSolid
                              : event.category.colorFor(context),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (event.isCancelled
                                      ? context.colors.errorSolid
                                          : event.category.colorFor(context))
                                  .withValues(alpha: 0.4),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _selectedDayAgenda(List<CalendarEvent> events, User user) {
    final dayEvents = CalendarService.eventsForDay(events, _selectedDay);
    final count = dayEvents.length;
    final countText = count == 0
        ? 'No activities scheduled for this day.'
        : '$count ${count == 1 ? 'scheduled announcement' : 'scheduled announcements'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d').format(_selectedDay),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          countText,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: count == 0 ? context.colors.textSecondary
                : context.colors.primaryGreen,
          ),
        ),
        const SizedBox(height: 12),
        if (dayEvents.isEmpty)
          _emptyDay()
        else
          ...dayEvents.map(
            (event) => _agendaCard(
              event,
              user: user,
              onTap: () => _openEventDetails(event, user),
            ),
          ),
      ],
    );
  }

  Widget _emptyDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
        boxShadow: ESugidClay.raisedShadows(depth: 0.35),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 26,
              color: context.colors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No scheduled community activities or advisories for this date.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _agendaCard(
    CalendarEvent event, {
    required User user,
    required VoidCallback onTap,
  }) {
    final now = DateTime.now();
    final isPast = event.endAt.isBefore(now);
    final isOngoing = now.isAfter(event.startAt) && now.isBefore(event.endAt);
    final categoryColor = event.isCancelled
        ? context.colors.textSecondary
        : event.category.colorFor(context);

    final timeString = event.allDay
        ? 'All day'
        : (isSameMinute(event.startAt, event.endAt) ||
                event.endAt.difference(event.startAt).inMinutes <= 5)
            ? DateFormat('h:mm a').format(event.startAt)
            : '${DateFormat('h:mm a').format(event.startAt)} – ${DateFormat('h:mm a').format(event.endAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPast ? context.colors.surface : context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: event.isCancelled
              ? context.colors.error.withValues(alpha: 0.3)
              : isOngoing
                  ? context.colors.primaryGreen
              : context.colors.border,
          width: isOngoing ? 1.5 : 1.0,
        ),
        boxShadow: ESugidClay.raisedShadows(depth: isPast ? 0.25 : 0.55),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category & Status Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            event.category.icon,
                            size: 13,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            event.displayCategory,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: categoryColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (event.isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.errorSolid.withValues(alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: context.colors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'CANCELLED',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.colors.error,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else if (isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.colors.brand,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ONGOING',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.colors.primaryGreen,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isPast)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.disabledBackground.withValues(alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'COMPLETED',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  event.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: isPast
                        ? context.colors.textPrimary
                        : context.colors.textPrimary,
                    height: 1.25,
                    decoration:
                        event.isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 8),

                // Time Row
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: isPast
                          ? context.colors.textSecondary
                          : context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeString,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPast
                            ? context.colors.textSecondary
                            : context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),

                // Location Row (if available)
                if (event.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: context.colors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 10),

                // Bottom "View Details" action
                Row(
                  children: [
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primaryGreen,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: context.colors.primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rangeUpcoming(List<CalendarEvent> events, User user) {
    final now = DateTime.now();
    final upcoming = events
        .where(
          (event) =>
              event.startAt.isAfter(now) &&
              event.status != CalendarEventStatus.cancelled &&
              event.status != CalendarEventStatus.completed,
        )
        .take(5)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coming up',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...upcoming.map(
          (event) => _agendaCard(
            event,
            user: user,
            onTap: () => _openEventDetails(event, user),
          ),
        ),
      ],
    );
  }

  bool isSameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  Future<void> _openEventDetails(CalendarEvent event, User user) async {
    if (_openingDetails) return;
    setState(() => _openingDetails = true);

    try {
      if (event.sourceType == CalendarEventSourceType.announcement &&
          event.sourceId.isNotEmpty) {
        final post = await _service.fetchAnnouncementPost(event.sourceId);
        if (!mounted) return;
        if (post != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailsPage(
                post: post,
                imageHeroTag: 'calendar-${event.sourceId}',
                primaryGreen: context.colors.primaryGreen,
                deepGreen: context.colors.textPrimary,
              ),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      await showCalendarEventDetails(
        context,
        event: event,
        user: user,
        service: _service,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              'This announcement could not be opened. It may no longer be available.',
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingDetails = false);
    }
  }
}
