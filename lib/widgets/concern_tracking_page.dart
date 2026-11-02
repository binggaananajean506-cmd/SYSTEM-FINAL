import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../app/theme/semantic_colors.dart';
import '../auth_service.dart';
import '../submission_service.dart';

/// The resident's at-a-glance view of a concern. Detailed history stays behind
/// the updates row so the current status is easy to scan on a small phone.
class ConcernTrackingPage extends StatefulWidget {
  const ConcernTrackingPage({
    super.key,
    required this.concern,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onBack,
    required this.onCopyReference,
    required this.updatesContent,
    this.actionContent,
  });

  final Submission concern;
  final IconData categoryIcon;
  final Color categoryColor;
  final VoidCallback onBack;
  final VoidCallback onCopyReference;
  final Widget updatesContent;
  final Widget? actionContent;

  @override
  State<ConcernTrackingPage> createState() => _ConcernTrackingPageState();
}

class _ConcernTrackingPageState extends State<ConcernTrackingPage> {
  bool _showUpdates = false;

  @override
  Widget build(BuildContext context) {
    final concern = widget.concern;
    final colors = context.colors;
    final status = normalizeSubmissionStatus(concern.status);
    final reporterName =
        concern.displayReporterName == 'Resident' &&
            AuthService.currentUser?.uid == concern.userId
        ? AuthService.currentUser!.name
        : concern.displayReporterName;
    final location = [
      if (concern.location?.trim().isNotEmpty == true) concern.location!.trim(),
      if (concern.barangay?.trim().isNotEmpty == true)
        concern.barangay!.trim().toLowerCase().startsWith('barangay ')
            ? concern.barangay!.trim()
            : 'Brgy. ${concern.barangay!.trim()}',
    ].join(', ');
    final statusLabel = switch (status) {
      'new' => 'Submitted',
      'needs_information' => 'Action needed',
      _ => submissionStatusLabel(status),
    };
    final (statusBackground, statusForeground) = switch (status) {
      'needs_information' => (colors.warningSurface, colors.warning),
      'rejected' || 'closed' => (colors.errorSurface, colors.error),
      'being_handled' => (colors.infoSurface, colors.info),
      _ => (colors.successSurface, colors.primaryGreen),
    };

    return SafeArea(
      key: ValueKey('concern-status-${concern.id}'),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: colors.textPrimary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Back to Center',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _pill(
                    statusLabel.toUpperCase(),
                    statusBackground,
                    statusForeground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track Your Concern',
                        style: GoogleFonts.outfit(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'See the status of your report.',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _reportCard(reporterName, location),
                      const SizedBox(height: 20),
                      Text(
                        'Status Timeline',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _timeline(status),
                      if (widget.actionContent != null) ...[
                        const SizedBox(height: 12),
                        widget.actionContent!,
                      ],
                      const SizedBox(height: 12),
                      _updatesCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(String reporterName, String location) {
    final concern = widget.concern;
    final colors = context.colors;
    final currentUser = AuthService.currentUser;
    final photoUrl = currentUser?.uid == concern.userId
        ? currentUser?.profilePhotoUrl?.trim()
        : null;
    final initials = reporterName.trim().split(RegExp(r'\s+'));
    final avatarLabel = initials
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: _pill(
                  concern.category,
                  widget.categoryColor.withValues(alpha: 0.1),
                  widget.categoryColor,
                  icon: widget.categoryIcon,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: InkWell(
                  onTap: widget.onCopyReference,
                  borderRadius: BorderRadius.circular(7),
                  child: _pill(
                    '#${concern.id}',
                    colors.surfaceAlt,
                    colors.textSecondary,
                    icon: Icons.copy_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: colors.successSurface,
                foregroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: Text(
                  avatarLabel,
                  style: GoogleFonts.outfit(
                    color: colors.primaryGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      timeago.format(concern.date),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            concern.title,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: colors.border),
          _metadataRow(
            Icons.location_on_outlined,
            location.isEmpty ? 'Location not provided' : location,
          ),
          Divider(height: 1, color: colors.border),
          _metadataRow(
            Icons.calendar_today_outlined,
            DateFormat('MMM d, y · h:mm a').format(concern.date),
          ),
        ],
      ),
    );
  }

  Widget _metadataRow(IconData icon, String value) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(String status) {
    final rawStatus = widget.concern.status.trim().toLowerCase();
    final isReviewing = const {
      'assigned',
      'under_review',
      'being_reviewed',
    }.contains(rawStatus);
    final isWorking = status == 'being_handled' && !isReviewing;
    final isResolved = status == 'resolved';
    final isClosed = status == 'closed' || status == 'rejected';
    final steps = <({String label, String state})>[
      (label: 'Report submitted', state: 'completed'),
      (
        label: 'Under review',
        state: isResolved || isWorking
            ? 'completed'
            : isReviewing || status == 'needs_information'
            ? 'current'
            : 'pending',
      ),
      (
        label: 'Action in progress',
        state: isResolved
            ? 'completed'
            : isWorking
            ? 'current'
            : 'pending',
      ),
      (
        label: isClosed
            ? status == 'rejected'
                  ? 'Declined'
                  : 'Closed'
            : 'Resolved',
        state: isResolved
            ? 'completed'
            : isClosed
            ? 'current'
            : 'pending',
      ),
    ];

    return _card(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _timelineStep(
              label: steps[i].label,
              state: steps[i].state,
              isLast: i == steps.length - 1,
              date: i == 0 ? widget.concern.date : null,
            ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required String label,
    required String state,
    required bool isLast,
    DateTime? date,
  }) {
    final colors = context.colors;
    final completed = state == 'completed';
    final current = state == 'current';
    final activeColor = colors.primaryGreen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? activeColor : colors.surface,
                  border: Border.all(
                    color: completed || current ? activeColor : colors.border,
                    width: 1.5,
                  ),
                ),
                child: completed
                    ? Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: colors.onAccent,
                      )
                    : null,
              ),
              if (!isLast)
                Container(width: 1.5, height: 32, color: colors.border),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('MMM d, y · h:mm a').format(date),
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        _pill(
          state.toUpperCase(),
          completed
              ? colors.successSurface
              : current
              ? colors.infoSurface
              : colors.surfaceAlt,
          completed
              ? activeColor
              : current
              ? colors.info
              : colors.textSecondary,
        ),
      ],
    );
  }

  Widget _updatesCard() {
    final colors = context.colors;
    return _card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showUpdates = !_showUpdates),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: colors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report updates',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Your progress and updates',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showUpdates
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_showUpdates) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 14),
            widget.updatesContent,
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill(
    String label,
    Color background,
    Color foreground, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
