import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/semantic_colors.dart';
import '../../auth_service.dart';
import '../../submission_service.dart';
import 'complaint_role_helper.dart';

class ComplaintHistorySheet extends StatelessWidget {
  const ComplaintHistorySheet({super.key, required this.complaint});

  final Submission complaint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = complaint.publicStatusHistory;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: colors.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Full Case History',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close history',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text(
                      complaint.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _text(context, complaint.id, secondary: true),
                    const SizedBox(height: 20),
                    if (entries.isEmpty)
                      _text(context, 'No updates yet.', secondary: true),
                    for (final entry in entries) _historyEntry(context, entry),
                    if (complaint.description.trim().isNotEmpty ||
                        complaint.hearings.isNotEmpty ||
                        complaint.externalUpdates.isNotEmpty ||
                        complaint.resolutionSummary?.isNotEmpty == true)
                      _details(context, 'Case details', [
                        _text(
                          context,
                          'Respondent: ${complaint.respondentDisplayName}',
                        ),
                        if (complaint.description.trim().isNotEmpty)
                          _text(context, complaint.description.trim()),
                        for (final hearing in complaint.hearings) ...[
                          _text(
                            context,
                            'Hearing ${hearing['number'] ?? ''} · ${_hearingLabel(hearing)}',
                          ),
                          _text(
                            context,
                            [
                              ComplaintRoleHelper.formatFriendlyDate(
                                hearing['date'],
                              ),
                              ComplaintRoleHelper.formatFriendlyTime(
                                hearing['time'],
                              ),
                              hearing['venue']?.toString() ?? '',
                            ].where((part) => part.isNotEmpty).join(' · '),
                            secondary: true,
                          ),
                          if (_note(hearing).isNotEmpty)
                            _text(context, _note(hearing)),
                          if (hearing['complainantAttendance'] != null ||
                              hearing['respondentAttendance'] != null)
                            _text(
                              context,
                              'Attendance: Resident ${hearing['complainantAttendance'] ?? 'not recorded'}; '
                              'respondent ${hearing['respondentAttendance'] ?? 'not recorded'}',
                              secondary: true,
                            ),
                        ],
                        for (final update in complaint.externalUpdates) ...[
                          _text(
                            context,
                            '${update['type'] ?? 'Update'} · ${ComplaintRoleHelper.formatFriendlyDate(update['date'])}',
                          ),
                          if (update['reference']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true)
                            _text(context, 'Reference: ${update['reference']}'),
                          if (_note(update).isNotEmpty)
                            _text(context, _note(update)),
                        ],
                        if (complaint.resolutionSummary?.trim().isNotEmpty ==
                            true)
                          _text(
                            context,
                            'Outcome: ${complaint.resolutionSummary!.trim()}',
                          ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyEntry(BuildContext context, Map<String, dynamic> entry) {
    final colors = context.colors;
    final label = _entryLabel(entry);
    final date = _date(
      entry['date'] ?? entry['performedAt'] ?? entry['updatedAt'],
    );
    final viewer = AuthService.currentUser;
    final actor = ComplaintRoleHelper.historyActorLabel(
      entry,
      complaint,
      viewerId: viewer?.uid,
      viewerName: viewer?.name,
    );
    final note = _note(entry);
    String normalized(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: colors.primaryGreen,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 3),
                  _text(
                    context,
                    DateFormat(
                      'MMM d, y · h:mm a',
                    ).format(date.toUtc().add(const Duration(hours: 8))),
                    secondary: true,
                  ),
                ],
                const SizedBox(height: 3),
                _text(context, actor, secondary: true),
                if (note.isNotEmpty && normalized(note) != normalized(label))
                  _details(context, 'View details', [_text(context, note)]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(BuildContext context, String text, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 13,
            height: 1.4,
            color: secondary
                ? context.colors.textSecondary
                : context.colors.textPrimary,
          ),
        ),
      );

  Widget _details(BuildContext context, String title, List<Widget> children) =>
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        shape: const Border(),
        collapsedShape: const Border(),
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.primaryGreen,
          ),
        ),
        children: children,
      );

  static String _note(Map<String, dynamic> entry) {
    for (final key in ['remarks', 'note', 'reason', 'message', 'summary']) {
      final value = entry[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _entryLabel(Map<String, dynamic> entry) {
    final label = entry['label']?.toString().trim() ?? '';
    final status = entry['status']?.toString() ?? 'filed';
    final action = entry['action']?.toString() ?? '';
    if (label.toLowerCase().contains('handed to barangay tanod') ||
        status.contains('handed_to_tanod') ||
        action.contains('hand_to_tanod')) {
      return 'Given to Barangay Tanod';
    }
    if (label.toLowerCase() == 'official summons issued') {
      return 'Summons Issued';
    }
    // Recorded hearing and outcome labels contain information not in status alone.
    if (label.isNotEmpty) return label;
    return ComplaintRoleHelper.simplifyStatus(status, action: action);
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return value is String ? DateTime.tryParse(value) : null;
  }

  static String _hearingLabel(Map<String, dynamic> session) =>
      switch (session['status']) {
        'completed' =>
          session['outcome'] == 'settled'
              ? 'Agreement reached'
              : 'No agreement',
        'not_held' => 'Not held',
        'cancelled' => 'Cancelled',
        _ => 'Scheduled',
      };
}
