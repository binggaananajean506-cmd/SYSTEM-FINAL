import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../auth_service.dart';
import '../../../community_service.dart';
import '../../../widgets/community_post_widgets.dart';
import '../../../core/errors/user_facing_error.dart';
import '../data/calendar_service.dart';
import '../domain/calendar_event.dart';
import 'calendar_event_editor.dart';
import 'calendar_event_presentation.dart';

Future<void> showCalendarEventDetails(
  BuildContext context, {
  required CalendarEvent event,
  required User user,
  required CalendarService service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _CalendarEventDetailsSheet(event: event, user: user, service: service),
  );
}

class _CalendarEventDetailsSheet extends StatefulWidget {
  const _CalendarEventDetailsSheet({
    required this.event,
    required this.user,
    required this.service,
  });

  final CalendarEvent event;
  final User user;
  final CalendarService service;

  @override
  State<_CalendarEventDetailsSheet> createState() =>
      _CalendarEventDetailsSheetState();
}

class _CalendarEventDetailsSheetState
    extends State<_CalendarEventDetailsSheet> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final canManage = CalendarService.canManageEvent(widget.user, event);
    final categoryColor = event.category.colorFor(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(event.category.icon, color: categoryColor),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.outfit(
                                fontSize: 23,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                color: context.colors.textPrimary,
                                decoration: event.isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                _pill(event.category.label, categoryColor),
                                _pill(
                                  event.status.label,
                                  event.isCancelled
                                      ? context.colors.errorSolid
                                      : context.colors.brand,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (event.isCancelled) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: context.colors.errorSolid.withValues(alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            color: context.colors.error,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This activity was cancelled. It remains visible so residents can see the update.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _fact(
                    Icons.calendar_month_rounded,
                    'Date',
                    _dateLabel(event),
                  ),
                  _fact(
                    Icons.schedule_rounded,
                    'Time',
                    event.allDay
                        ? 'All day'
                        : '${DateFormat('h:mm a').format(event.startAt)} – ${DateFormat('h:mm a').format(event.endAt)}',
                  ),
                  if (event.location.isNotEmpty)
                    _fact(
                      Icons.location_on_outlined,
                      'Location',
                      event.location,
                    ),
                  if (event.organizerName.isNotEmpty)
                    _fact(
                      Icons.account_balance_outlined,
                      'Organizer',
                      event.organizerName,
                    ),
                  if (event.sourceType == CalendarEventSourceType.announcement)
                    _fact(
                      Icons.campaign_outlined,
                      'Source',
                      'Community Announcement',
                    ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'About this activity',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      event.description,
                      style: GoogleFonts.outfit(
                        height: 1.55,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (_hasSourceAction(event)) ...[
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => _openSource(event),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(_sourceActionLabel(event)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                  if (canManage) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _working ? null : _edit,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        if (!event.isCancelled) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _working ? null : _cancel,
                              icon: const Icon(Icons.event_busy_outlined),
                              label: const Text('Cancel event'),
                              style: FilledButton.styleFrom(
                                foregroundColor: context.colors.onAccent,
                                backgroundColor: context.colors.errorSolid
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.user.role == UserRole.lgu) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _working ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Permanently delete event'),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.error,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.primaryGreen),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textSecondary,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(CalendarEvent event) {
    final start = DateFormat('EEEE, MMMM d, y').format(event.startAt);
    final displayEnd = event.allDay
        ? event.endAt.subtract(const Duration(microseconds: 1))
        : event.endAt;
    final sameDay =
        event.startAt.year == displayEnd.year &&
        event.startAt.month == displayEnd.month &&
        event.startAt.day == displayEnd.day;
    return sameDay
        ? start
        : '$start – ${DateFormat('MMMM d, y').format(displayEnd)}';
  }

  bool _hasSourceAction(CalendarEvent event) =>
      event.sourceId.isNotEmpty &&
      (event.sourceType == CalendarEventSourceType.announcement ||
          event.sourceType == CalendarEventSourceType.bayanihan);

  String _sourceActionLabel(CalendarEvent event) =>
      event.sourceType == CalendarEventSourceType.bayanihan
      ? 'View Bayanihan activity'
      : 'View Announcement';

  Future<void> _openSource(CalendarEvent event) async {
    if (event.sourceType == CalendarEventSourceType.announcement) {
      if (_working) return;
      setState(() => _working = true);
      try {
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(event.sourceId)
            .get();
        if (!mounted) return;
        if (!doc.exists ||
            !['approved', 'published'].contains(doc.data()?['status'])) {
          throw StateError('Announcement is no longer available.');
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailsPage(
              post: CommunityPost.fromDoc(doc),
              imageHeroTag: 'calendar-${event.sourceId}',
              primaryGreen: context.colors.primaryGreen,
              deepGreen: context.colors.textPrimary,
            ),
          ),
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
        if (mounted) setState(() => _working = false);
      }
      return;
    }
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      event.sourceType == CalendarEventSourceType.bayanihan ? '/jobs' : '/home',
      arguments: event.sourceType == CalendarEventSourceType.bayanihan
          ? event.sourceId
          : null,
    );
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEventEditorPage(
          user: widget.user,
          service: widget.service,
          personal: widget.event.visibility == CalendarEventVisibility.private,
          event: widget.event,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'The event will remain visible with a Cancelled label so people understand the schedule changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.service.cancelEvent(widget.event.id));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete event?'),
        content: const Text(
          'This cannot be undone. Cancelling is safer for events residents may already have seen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: context.colors.onAccent,

              backgroundColor: context.colors.errorSolid,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.service.deleteEvent(widget.event.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              userFacingError(
                error,
                fallback: 'The event could not be updated. Try again.',
              ),
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
