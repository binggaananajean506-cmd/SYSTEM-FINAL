import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/semantic_colors.dart';
import '../../submission_service.dart';
import 'complaint_modals.dart';
import 'complaint_role_helper.dart';

/// A short case overview with detailed records available on demand.
class ComplaintTrackingView extends StatelessWidget {
  const ComplaintTrackingView({
    super.key,
    required this.complaint,
    this.onResubmit,
  });

  final Submission complaint;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hearing = complaint.activeComplaintHearing;
    final legacy = complaint.complaintNeedsConfirmation;
    final oldSchedule = complaint.schedule ?? complaint.summons;
    final hasSummons = complaint.summons != null;
    final isHearingScheduled =
        complaint.complaintWorkflowStatus == 'hearing_scheduled' ||
        hearing != null ||
        legacy;

    final historyResolution = complaint.publicStatusHistory.reversed.firstWhere(
      (entry) =>
          (entry['reason'] ?? entry['remarks'] ?? entry['note']) != null &&
          (entry['reason'] ?? entry['remarks'] ?? entry['note']).toString().trim().isNotEmpty &&
          const {'resolved', 'settled', 'unsettled', 'closed'}.contains(entry['status']?.toString().toLowerCase()),
      orElse: () => const <String, dynamic>{},
    );
    final historyReason = (historyResolution['reason'] ?? historyResolution['remarks'] ?? historyResolution['note'])?.toString().trim();
    final conclusion = complaint.resolutionSummary ??
        complaint.settlement?['agreementTerms']?.toString() ??
        complaint.unsettledRecord?['remarks']?.toString() ??
        historyReason;
    final workflowStatus = complaint.complaintWorkflowStatus;
    final needsInformation = const {'needs_information', 'awaiting_resident'}
        .contains(workflowStatus);
    final nextStep = _nextStepMessage(
      workflowStatus: workflowStatus,
      needsInformation: needsInformation,
      isHearingScheduled: isHearingScheduled,
    );
    final hearingDate = ComplaintRoleHelper.formatFriendlyDate(
      hearing?['date'] ?? oldSchedule?['date'] ?? oldSchedule?['appearanceDate'],
    );
    final hearingTime = ComplaintRoleHelper.formatFriendlyTime(
      hearing?['time'] ?? oldSchedule?['time'] ?? oldSchedule?['appearanceTime'],
    );
    final hearingPlace = (hearing?['venue'] ?? oldSchedule?['venue'] ??
            oldSchedule?['appearanceVenue'])
        ?.toString()
        .trim();
    final hearingSummary = [
      if (hearingDate != 'Date pending') hearingDate,
      if (hearingTime.isNotEmpty) hearingTime,
      if (hearingPlace?.isNotEmpty == true) hearingPlace!,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? colors.border.withValues(alpha: 0.12)
                  : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current status', style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              )),
              const SizedBox(height: 4),
              Text(complaint.complaintStatusLabel, style: GoogleFonts.outfit(
                fontSize: 19, fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              )),
              const SizedBox(height: 6),
              Text('Respondent: ${complaint.respondentDisplayName}',
                  style: GoogleFonts.outfit(
                    fontSize: 12, color: colors.textSecondary,
                  )),
              if (!complaint.complaintFinished &&
                  isHearingScheduled &&
                  complaint.complaintStatusLabel != 'Result Pending' &&
                  hearingSummary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  hearingSummary,
                  style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
              if (complaint.summons?['deliveryStatus'] == 'handed_to_tanod') ...[
                const SizedBox(height: 8),
                Text('Summons with the tanod. Delivery is not yet confirmed.',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5, color: colors.textSecondary,
                    )),
              ],
              if (isHearingScheduled || hasSummons) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showSummonsSheet(context, complaint),
                    icon: const Icon(Icons.description_outlined, size: 17),
                    label: const Text(
                      'View Summons Issued to Respondent',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: needsInformation ? colors.warningSurface : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next step', style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              )),
              const SizedBox(height: 5),
              Text(nextStep, style: GoogleFonts.outfit(
                fontSize: 13, color: colors.textPrimary, height: 1.4,
              )),
              if (needsInformation && onResubmit != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('complaint-resubmit'),
                  onPressed: onResubmit,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Update complaint'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: ExpansionTile(
            title: Text('Case details', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            )),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            children: [
              _buildNextStepCard(
                context,
                colors: colors,
                isDark: isDark,
                hearing: hearing,
                legacy: legacy,
                oldSchedule: oldSchedule,
                hasSummons: hasSummons,
                isHearingScheduled: isHearingScheduled,
              ),
              if (!needsInformation) ...[
                const SizedBox(height: 12),
                _buildWhatYouNeedToDoCard(
                  context,
                  colors: colors,
                  isDark: isDark,
                  isHearingScheduled: isHearingScheduled,
                  hearing: hearing,
                  oldSchedule: oldSchedule,
                ),
              ],
              if (complaint.complaintFinished && conclusion?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _buildConclusionCard(context, colors: colors, conclusion: conclusion!),
              ],
              if (hasSummons || complaint.hearings.isNotEmpty || complaint.externalUpdates.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildRecordsSummaryCard(context, colors: colors),
              ],
              if (!hasSummons && complaint.hearings.isEmpty && complaint.externalUpdates.isEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showFullHistorySheet(context, complaint),
                  icon: const Icon(Icons.history_rounded, size: 17),
                  label: const Text('View full history'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// NEXT STEP Card for scheduled hearing or current workflow state.
  Widget _buildNextStepCard(
    BuildContext context, {
    required ESugidColors colors,
    required bool isDark,
    required Map<String, dynamic>? hearing,
    required bool legacy,
    required Map<String, dynamic>? oldSchedule,
    required bool hasSummons,
    required bool isHearingScheduled,
  }) {
    // Dynamic Role Resolution - Always ROLE, never person name!
    final dynamicRole = isLuponRound(hearing?['number'] ?? complaint.summons?['hearingNumber'] ?? complaint.completedHearingCount + 1)
        ? 'Barangay Lupon'
        : ComplaintRoleHelper.resolveRole(
      actorId: hearing?['officerId']?.toString() ??
          complaint.summons?['issuedBy']?.toString(),
      actorRole: hearing?['officerRole']?.toString() ??
          complaint.summons?['actorRole']?.toString() ?? 'barangay_captain',
      actorName: hearing?['officerName']?.toString() ??
          complaint.summons?['assignedTanod']?.toString(),
      action: isHearingScheduled ? 'schedule' : complaint.status,
      status: complaint.status,
      submission: complaint,
    );

    String dateStr = 'Date pending';
    String timeStr = '';
    String placeStr = 'Barangay Hall of ${complaint.barangay ?? "Vito"}';

    if (hearing != null) {
      dateStr = ComplaintRoleHelper.formatFriendlyDate(hearing['date']);
      timeStr = ComplaintRoleHelper.formatFriendlyTime(hearing['time']);
      if (hearing['venue']?.toString().isNotEmpty == true) {
        placeStr = hearing['venue'].toString();
      }
    } else if (legacy && oldSchedule != null) {
      final rawDate = oldSchedule['date'] ??
          oldSchedule['appearanceDate'] ??
          oldSchedule['hearingDate'];
      dateStr = rawDate?.toString() ?? 'Date pending';
      final rawTime = oldSchedule['time'] ?? oldSchedule['appearanceTime'] ?? '';
      timeStr = rawTime.toString();
      final rawVenue = oldSchedule['venue'] ??
          oldSchedule['appearanceVenue'] ??
          oldSchedule['hearingPlace'];
      if (rawVenue != null && rawVenue.toString().isNotEmpty) {
        placeStr = rawVenue.toString();
      }
    } else if (hasSummons) {
      dateStr = ComplaintRoleHelper.formatFriendlyDate(
        complaint.summons!['appearanceDate'] ?? complaint.summons!['hearingDate'],
      );
      timeStr = ComplaintRoleHelper.formatFriendlyTime(
        complaint.summons!['appearanceTime'] ?? complaint.summons!['hearingTime'],
      );
      if (complaint.summons!['appearanceVenue']?.toString().isNotEmpty == true) {
        placeStr = complaint.summons!['appearanceVenue'].toString();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primaryGreen.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryGreen.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag: NEXT STEP
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: colors.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  complaint.complaintFinished ? 'CASE STATUS' : 'NEXT STEP',
                  style: GoogleFonts.outfit(
                    color: colors.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!complaint.complaintFinished && !legacy && hearing != null)
                Expanded(child: Text(
                  complaintHearingLabel(hearing['number']),
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )),
            ],
          ),
          const SizedBox(height: 12),

          // Main Title
          if (legacy)
            Text(
              'Previous schedule (awaiting confirmation)',
              style: GoogleFonts.outfit(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            )
          else if (isHearingScheduled)
            Text(
              'Your hearing is scheduled.',
              style: GoogleFonts.outfit(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            )
          else if (complaint.complaintFinished)
            Text(
              complaint.complaintStatusLabel,
              style: GoogleFonts.outfit(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            )
          else
            Text(
              _statusHeadline(complaint.complaintWorkflowStatus),
              style: GoogleFonts.outfit(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          const SizedBox(height: 14),

          // Details: Date, Time, Place, Handled by
          if (isHearingScheduled || (legacy && oldSchedule != null)) ...[
            _detailRow('Date', dateStr, colors),
            if (timeStr.isNotEmpty) _detailRow('Time', timeStr, colors),
            _detailRow('Place', placeStr, colors),
            _detailRow('Handled by', dynamicRole, colors, highlight: true),
          ] else ...[
            _detailRow('Handled by', dynamicRole, colors, highlight: true),
          ],

        ],
      ),
    );
  }

  /// "What you need to do" Card (Priority 6).
  Widget _buildWhatYouNeedToDoCard(
    BuildContext context, {
    required ESugidColors colors,
    required bool isDark,
    required bool isHearingScheduled,
    required Map<String, dynamic>? hearing,
    required Map<String, dynamic>? oldSchedule,
  }) {
    final status = complaint.complaintWorkflowStatus;

    if (status == 'needs_information' || status == 'awaiting_resident') {
      final reason = _extractReason(complaint);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.warningSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colors.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'What you need to do',
                  style: GoogleFonts.outfit(
                    color: colors.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The barangay requested additional information:',
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: GoogleFonts.poppins(
                color: colors.textPrimary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (onResubmit != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  key: const ValueKey('complaint-resubmit'),
                  onPressed: onResubmit,
                  icon: const Icon(Icons.edit_note_rounded, size: 19),
                  label: const Text('Update & Resubmit Complaint'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.warningSolid,
                    foregroundColor: colors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isHearingScheduled) {
      final date = ComplaintRoleHelper.formatFriendlyDate(
        hearing?['date'] ?? oldSchedule?['date'] ?? oldSchedule?['appearanceDate'],
      );
      final time = ComplaintRoleHelper.formatFriendlyTime(
        hearing?['time'] ?? oldSchedule?['time'] ?? oldSchedule?['appearanceTime'] ?? '09:00',
      );
      final place = (hearing?['venue'] ??
              oldSchedule?['venue'] ??
              oldSchedule?['appearanceVenue'] ??
              'Barangay Hall of ${complaint.barangay ?? "Vito"}')
          .toString();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  color: colors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'What you need to do',
                  style: GoogleFonts.outfit(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 12),
            _instructionBullet(
              'Attend on time',
              'Be at $place on $date at $time.',
              colors,
            ),
            const SizedBox(height: 8),
            _instructionBullet(
              'Bring a valid ID',
              'Have your government-issued ID ready for attendance.',
              colors,
            ),
            const SizedBox(height: 8),
            _instructionBullet(
              'Bring relevant evidence',
              'Bring any photos, documents, or witnesses related to your complaint.',
              colors,
            ),
          ],
        ),
      );
    }

    if (complaint.complaintFinished) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: colors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'What you need to do',
                  style: GoogleFonts.outfit(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              complaint.closureOutcome == 'cfa_issued' || complaint.status == 'cfa_issued'
                  ? 'The CFA has been issued. Contact the barangay office for your copy.'
                  : 'This case is closed. No further action is required from you.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    // Default under review / awaiting schedule state
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'What you need to do',
                style: GoogleFonts.outfit(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status == 'awaiting_cfa'
                ? 'All six rounds are recorded without settlement. The barangay office will review and issue the CFA.'
                : complaint.completedHearingCount == 3
                ? 'The three barangay rounds are complete. Wait for your lupon conciliation schedule.'
                : 'No action is needed right now. The barangay will update your case status here.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// Resolution / Conclusion Card for settled or closed complaints.
  Widget _buildConclusionCard(
    BuildContext context, {
    required ESugidColors colors,
    required String conclusion,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primaryGreen.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: colors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recorded Conclusion',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: colors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            conclusion,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// Records and activity summary card (shows tanod handoff, completed hearing outcomes, and external references).
  Widget _buildRecordsSummaryCard(BuildContext context, {required ESugidColors colors}) {
    final summons = complaint.summons;
    final assignedTanod = summons?['assignedTanod']?.toString() ?? 'Barangay Tanod';
    final hasTanod = summons?['deliveryStatus'] == 'handed_to_tanod';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feed_outlined, size: 18, color: colors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Case Records & Updates',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              )),
            ],
          ),
          const SizedBox(height: 10),
          if (summons != null) ...[
            Text(
              'Assigned tanod: $assignedTanod',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (hasTanod) ...[
              const SizedBox(height: 3),
              Text(
                'Handed to Barangay Tanod for delivery to the respondent.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Handoff to the tanod does not confirm service to the respondent.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          for (final session in complaint.hearings) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${complaintHearingLabel(session['number'])} · ${_hearingOutcomeLabel(session)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
          for (final update in complaint.externalUpdates) ...[
            if (update['reference']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Reference: ${update['reference']}',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: colors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showFullHistorySheet(context, complaint),
              icon: const Icon(Icons.history_rounded, size: 17),
              label: Text(
                'View Full History',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    ESugidColors colors, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.outfit(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: highlight ? colors.primaryGreen : colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionBullet(
    String title,
    String description,
    ESugidColors colors,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: colors.primaryGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colors.textPrimary,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _statusHeadline(String workflowStatus) => switch (workflowStatus) {
        'under_review' => 'Under review by the barangay.',
        'needs_information' => 'More information is needed.',
        'awaiting_next_schedule' => 'Waiting for next hearing schedule.',
        'awaiting_cfa' => 'Awaiting CFA issuance.',
        'hearing_scheduled' => 'Your hearing is scheduled.',
        'filed' => 'Complaint filed.',
        _ => 'Case in progress.',
      };

  String _extractReason(Submission item) {
    return item.publicStatusHistory.reversed
        .where(
          (entry) => const {'needs_information', 'awaiting_resident'}.contains(
            normalizeSubmissionStatus(entry['status']?.toString() ?? ''),
          ),
        )
        .map(
          (entry) =>
              (entry['reason'] ?? entry['note'])?.toString().trim() ?? '',
        )
        .firstWhere(
          (note) => note.isNotEmpty,
          orElse: () =>
              'The barangay needs additional details to continue reviewing your complaint.',
        );
  }

  String _nextStepMessage({
    required String workflowStatus,
    required bool needsInformation,
    required bool isHearingScheduled,
  }) {
    if (needsInformation) return _extractReason(complaint);
    if (complaint.complaintFinished) {
      return complaint.closureOutcome == 'cfa_issued' ||
              complaint.status == 'cfa_issued'
          ? 'Contact the barangay for your CFA copy.'
          : 'No further action is needed.';
    }
    if (complaint.complaintStatusLabel == 'Result Pending') {
      return 'Wait for the hearing result.';
    }
    if (isHearingScheduled) {
      return 'Attend your hearing. Bring your ID and evidence.';
    }
    if (workflowStatus == 'awaiting_cfa') {
      return 'Wait for the barangay to issue your CFA.';
    }
    if (complaint.completedHearingCount == 3) {
      return 'Wait for your next hearing schedule.';
    }
    return 'No action needed. Check back for updates.';
  }

  String _hearingOutcomeLabel(Map<String, dynamic> session) =>
      switch (session['status']) {
        'completed' => session['outcome'] == 'settled'
            ? 'Agreement reached'
            : 'No agreement',
        'not_held' => 'Not held',
        'cancelled' => 'Cancelled',
        _ => 'Scheduled',
      };
}
