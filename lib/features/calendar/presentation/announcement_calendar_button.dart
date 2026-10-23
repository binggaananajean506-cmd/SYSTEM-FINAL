import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../auth_service.dart';
import '../../../community_service.dart';
import '../data/calendar_service.dart';
import 'calendar_page.dart';

/// Tactile 3D calendar icon button displayed next to the draft/bookmark button
/// on official announcement cards with a scheduled calendar event.
class AnnouncementCalendarCardButton extends StatefulWidget {
  final CommunityPost post;
  final CalendarService? calendarService;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double size;

  const AnnouncementCalendarCardButton({
    super.key,
    required this.post,
    this.calendarService,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.size = 38,
  });

  @override
  State<AnnouncementCalendarCardButton> createState() =>
      _AnnouncementCalendarCardButtonState();
}

class _AnnouncementCalendarCardButtonState
    extends State<AnnouncementCalendarCardButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  CalendarService get _calendarService =>
      widget.calendarService ?? CalendarService.shared;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.color ?? context.colors.primaryGreen;

    return StreamBuilder<Set<String>>(
      stream: user != null
          ? _calendarService.watchSavedAnnouncements(user.uid)
          : Stream.value(const <String>{}),
      initialData: user != null
          ? _calendarService.savedAnnouncementIds(user.uid)
          : const <String>{},
      builder: (context, snapshot) {
        final isSaved = CalendarService.isAnnouncementSaved(
          snapshot.data,
          widget.post.id,
        );

        return Semantics(
          button: true,
          label: isSaved
              ? 'Event saved in My Calendar. Tap to manage.'
              : 'Calendar options. Tap to choose whether to add this event.',
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) =>
                Transform.scale(scale: _scaleAnimation.value, child: child),
            child: Tooltip(
              message: isSaved ? 'In My Calendar' : 'Calendar options',
              child: GestureDetector(
                onTapDown: (_) => _scaleController.forward(),
                onTapUp: (_) => _scaleController.reverse(),
                onTapCancel: () => _scaleController.reverse(),
                onTap: () => showAnnouncementCalendarModal(
                  context,
                  post: widget.post,
                  calendarService: _calendarService,
                ),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: isSaved
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    context.colors.surfaceAlt,
                                    context.colors.surfaceAlt,
                                  ]
                                : [
                                    context.colors.surface,
                                    context.colors.surfaceAlt,
                                  ],
                          ),
                    border: Border.all(
                      color: isSaved
                          ? context.colors.primaryGreen.withValues(alpha: 0.6)
                          : isDark
                          ? context.colors.primaryGreen.withValues(alpha: 0.38)
                          : context.colors.primaryGreen.withValues(alpha: 0.40),
                      width: 1.1,
                    ),
                    boxShadow: [
                      // 3D Realistic Soft Ambient + Colored Glow Shadow
                      BoxShadow(
                        color: isSaved
                            ? context.colors.brandStrong.withValues(alpha: 0.42)
                            : isDark
                            ? context.colors.brandStrong.withValues(alpha: 0.35)
                            : context.colors.brandStrong.withValues(alpha: 0.15,
                              ),
                        blurRadius: isSaved ? 7 : 4,
                        offset: const Offset(0, 2),
                      ),
                      if (!isSaved && !isDark)
                        BoxShadow(
                          color: context.colors.highlight,
                          blurRadius: 2,
                          offset: Offset(0, -1),
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        isSaved
                            ? Icons.calendar_month_rounded
                            : Icons.event_note_rounded,
                        size: 20,
                        color: isSaved
                            ? context.colors.onAccent
                            : isDark
                            ? context.colors.primaryGreen
                            : baseColor,
                      ),
                      if (isSaved)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: context.colors.brand,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.primaryGreen,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.8,
                                  ),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows a visually stunning, classy 3D bottom sheet modal for the announcement's
/// community calendar event, giving residents the option to add or remove it from "My Calendar".
Future<void> showAnnouncementCalendarModal(
  BuildContext context, {
  required CommunityPost post,
  CalendarService? calendarService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.shadow.withValues(alpha: 0.55),
    builder: (modalContext) => _AnnouncementCalendarModalContent(
      post: post,
      calendarService: calendarService ?? CalendarService.shared,
    ),
  );
}

class _AnnouncementCalendarModalContent extends StatefulWidget {
  final CommunityPost post;
  final CalendarService calendarService;

  const _AnnouncementCalendarModalContent({
    required this.post,
    required this.calendarService,
  });

  @override
  State<_AnnouncementCalendarModalContent> createState() =>
      _AnnouncementCalendarModalContentState();
}

class _AnnouncementCalendarModalContentState
    extends State<_AnnouncementCalendarModalContent> {
  bool _busy = false;
  bool? _savedLocally;

  DateTime get _eventDate => widget.post.eventDate ?? widget.post.createdAt;
  DateTime? get _eventEndDate => widget.post.eventEndDate;

  String get _monthString =>
      DateFormat('MMM').format(_eventDate.toLocal()).toUpperCase();
  String get _dayString => DateFormat('d').format(_eventDate.toLocal());
  String get _weekdayYearString =>
      '${DateFormat('EEEE').format(_eventDate.toLocal()).toUpperCase()} · ${DateFormat('y').format(_eventDate.toLocal())}';

  String get _timeString {
    if (widget.post.isAllDayEvent) return 'All-day Event';
    final start = DateFormat('h:mm a').format(_eventDate.toLocal());
    if (_eventEndDate != null) {
      final end = DateFormat('h:mm a').format(_eventEndDate!.toLocal());
      return '$start – $end';
    }
    return start;
  }

  Future<void> _toggleCalendar(User user, bool isSaved) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final service = widget.calendarService;
      if (isSaved) {
        await service.removeAnnouncementFromCalendar(user, widget.post.id);
        if (!mounted) return;
        setState(() => _savedLocally = false);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
                    'Removed from your My Calendar.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
            kind: FeedbackKind.success,
          ),
        );
      } else {
        await service.saveAnnouncementToCalendar(user, widget.post.id);
        if (!mounted) return;
        setState(() => _savedLocally = true);
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
                    'Added to your personal My Calendar!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            error is CalendarValidationException
                ? error.message
                : 'Could not update your calendar. Please try again.',
            style: GoogleFonts.outfit(),
          ),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Glass Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.colors.shadow.withValues(alpha: 0.22)
                        : context.colors.shadow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Row: Badge & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.surfaceAlt,
                          context.colors.surfaceAlt,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: context.colors.primaryGreen.withValues(alpha: 0.4,
                        ),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.12,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: context.colors.primaryGreen,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "COMMUNITY CALENDAR EVENT",
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primaryGreen,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? context.colors.surfaceAlt.withValues(alpha: 0.08)
                          : context.colors.surfaceAlt,
                      foregroundColor: context.colors.textPrimary,
                      minimumSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3D Realistic Tear-Off Calendar Block & Title Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.surface, context.colors.surfaceAlt],
                  ),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? context.colors.brandStrong.withValues(alpha: 0.40)
                          : context.colors.brandStrong.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 3D Desk Calendar Tear-Off Block
                    _build3DDeskCalendarBlock(isDark),
                    const SizedBox(width: 16),

                    // Title & Organizer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.title,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: context.colors.brand,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.account_balance_rounded,
                                    size: 11,
                                    color: context.colors.onAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.post.authorBarangay.isNotEmpty
                                      ? "Barangay ${widget.post.authorBarangay}"
                                      : widget
                                            .post
                                            .publisherEntityName
                                            .isNotEmpty
                                      ? widget.post.publisherEntityName
                                      : widget.post.authorName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.primaryGreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail Tiles (Date/Time, Location)
              _buildDetailTile(
                icon: Icons.schedule_rounded,
                iconColor: context.colors.primaryGreen,
                title: "Date & Time",
                subtitle: "$_weekdayYearString\n$_timeString",
                isDark: isDark,
              ),
              if (widget.post.location.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDetailTile(
                  icon: Icons.location_on_rounded,
                  iconColor: context.colors.error,
                  title: "Location",
                  subtitle: widget.post.location,
                  isDark: isDark,
                ),
              ],
              const SizedBox(height: 16),

              // Reassuring Info Banner: Community Calendar vs My Calendar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? context.colors.surfaceAlt.withValues(alpha: 0.7)
                      : context.colors.surfaceAlt,
                  border: Border.all(
                    color: context.colors.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This event is already posted on the Community Calendar by your barangay officials. You can sync it to your personal 'My Calendar' so you get quick access and reminders.",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.primaryGreen,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Interactive 3D Action Section
              if (user != null)
                StreamBuilder<Set<String>>(
                  stream: widget.calendarService.watchSavedAnnouncements(
                    user.uid,
                  ),
                  initialData: widget.calendarService.savedAnnouncementIds(
                    user.uid,
                  ),
                  builder: (context, snapshot) {
                    final isSaved =
                        _savedLocally ??
                        CalendarService.isAnnouncementSaved(
                          snapshot.data,
                          widget.post.id,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSaved) ...[
                          // Saved status banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: context.colors.brand.withValues(alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.colors.primaryGreen.withValues(alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: context.colors.primaryGreen,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Event is in your personal My Calendar",
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3D "View in My Calendar" Primary Button
                          _build3DButton(
                            label: "View in My Calendar",
                            icon: Icons.calendar_month_rounded,
                            gradient: [
                              context.colors.primaryGreen,
                              context.colors.primaryGreen,
                            ],
                            shadowColor: context.colors.primaryGreen,
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CalendarPage(
                                    user: user),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Secondary "Remove from My Calendar" Text Button
                          Center(
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _toggleCalendar(user, true),
                              icon: _busy
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.colors.error,
                                      ),
                                    )
                                  : Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: context.colors.error,
                                    ),
                              label: Text(
                                _busy
                                    ? "Updating..."
                                    : "Remove from My Calendar",
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // 3D "Add to My Calendar" Primary Button
                          _build3DButton(
                            key: const ValueKey('add-announcement-to-calendar'),
                            label: _busy
                                ? "Adding to My Calendar..."
                                : "Add to My Calendar",
                            icon: _busy
                                ? Icons.hourglass_top_rounded
                                : Icons.add_circle_outline_rounded,
                            gradient: [
                              context.colors.primaryGreen,
                              context.colors.primaryGreen,
                            ],
                            shadowColor: context.colors.primaryGreen,
                            onTap: _busy
                                ? null
                                : () => _toggleCalendar(user, false),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton(
                              key: const ValueKey('calendar-not-now'),
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Text(
                                'Not now',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a realistic 3D desk-calendar tear-off block
  Widget _build3DDeskCalendarBlock(bool isDark) {
    return Container(
      width: 78,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.colors.surface,
        border: Border.all(
          color: isDark ? context.colors.primaryGreen : context.colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.45 : 0.12,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Red/Emerald Binder Bar with faux metallic loops
          Container(
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(
                colors: [context.colors.brand, context.colors.brand],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Metallic Binder Rings
                Positioned(left: 14, top: 2, child: _buildBinderRing()),
                Positioned(right: 14, top: 2, child: _buildBinderRing()),
                Text(
                  _monthString,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: context.colors.onAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Day Number Body
          Expanded(
            child: Center(
              child: Text(
                _dayString,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: context.colors.textPrimary,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: isDark
                          ? context.colors.primaryGreen.withValues(alpha: 0.6)
                          : context.colors.primaryGreen.withValues(alpha: 0.20),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinderRing() {
    return Container(
      width: 5,
      height: 7,
      decoration: BoxDecoration(
        color: context.colors.infoSurface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: context.colors.border, width: 0.8),
        boxShadow: [
          BoxShadow(color: context.colors.shadow.withValues(alpha: 0.2588), blurRadius: 1, offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surface.withValues(alpha: 0.5)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border,
          width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DButton({
    Key? key,
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required Color shadowColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: context.colors.onAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: context.colors.onAccent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
