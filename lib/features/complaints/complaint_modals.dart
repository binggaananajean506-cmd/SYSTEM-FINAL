import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/semantic_colors.dart';
import '../../submission_service.dart';
import '../../services/barangay_logo_service.dart';
import '../../widgets/barangay_logo.dart';
import 'complaint_role_helper.dart';

/// Opens the complete Official Summons Notice page.
void showSummonsSheet(BuildContext context, Submission complaint) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => OfficialSummonsPage(complaint: complaint),
    ),
  );
}

class OfficialSummonsPage extends StatefulWidget {
  const OfficialSummonsPage({super.key, required this.complaint});

  final Submission complaint;

  @override
  State<OfficialSummonsPage> createState() => _OfficialSummonsPageState();
}

class _OfficialSummonsPageState extends State<OfficialSummonsPage> {
  // 0: Official Form (KP Form 9) as the FIRST view, 1: Hearing Notice
  int _selectedView = 0;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final trimmed = value.trim();
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      try {
        return DateFormat('yyyy-MM-dd').parse(trimmed);
      } catch (_) {}
      try {
        return DateFormat('MMM d, yyyy').parse(trimmed);
      } catch (_) {}
    }
    return null;
  }

  static String _formatOrdinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;
    final summons = complaint.summons ?? const <String, dynamic>{};
    final hearing = complaint.activeComplaintHearing;
    final caseIdentity = BarangayLogos.forSubmission(complaint);
    final caseBarangay = caseIdentity?.canonicalName ??
        caseIdentity?.name ?? complaint.barangay ?? 'Not specified';

    final date = ComplaintRoleHelper.formatFriendlyDate(
      hearing?['date'] ?? summons['appearanceDate'] ?? summons['hearingDate'],
    );
    final time = ComplaintRoleHelper.formatFriendlyTime(
      hearing?['time'] ?? summons['appearanceTime'] ?? summons['hearingTime'] ?? '09:00',
    );
    final venue = (hearing?['venue'] ??
            summons['appearanceVenue'] ??
            summons['hearingPlace'] ??
            'Barangay Hall of $caseBarangay')
        .toString();

    final tanodName = summons['assignedTanod']?.toString().trim();
    final displayTanod = (tanodName != null && tanodName.isNotEmpty)
        ? tanodName
        : 'Barangay Tanod on duty';

    final deliveryStatus = summons['deliveryStatus']?.toString() ?? 'handed_to_tanod';
    final deliveryText = switch (deliveryStatus) {
      'served' => 'Served to the respondent.',
      'received_by_family' => 'Left with a family member.',
      'refused' => 'Respondent refused to receive or sign.',
      _ => 'Handed to Barangay Tanod for delivery to the respondent.',
    };

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          color: colors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Official Summons',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Issued to Respondent • Barangay $caseBarangay • Case #${complaint.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                // Tab 0: Official Form (KP Form 9) - FIRST VIEW
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _selectedView = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _selectedView == 0 ? colors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedView == 0
                            ? [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 14,
                              color: _selectedView == 0 ? colors.primaryGreen : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Official Form (KP Form 9)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: _selectedView == 0 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedView == 0 ? colors.primaryGreen : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Tab 1: Hearing Notice
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _selectedView = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: _selectedView == 1 ? colors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _selectedView == 1
                            ? [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 14,
                              color: _selectedView == 1 ? colors.primaryGreen : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hearing Notice',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: _selectedView == 1 ? FontWeight.w800 : FontWeight.w600,
                                color: _selectedView == 1 ? colors.primaryGreen : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _selectedView == 0
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  // Official paper document
                  _OfficialSummonsPaperDoc(
                    complaint: complaint,
                    summons: summons,
                    hearing: hearing,
                    date: date,
                    time: time,
                    venue: venue,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _selectedView = 1),
                          icon: const Icon(Icons.event_note_rounded, size: 16),
                          label: Text(
                            'Hearing Notice',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primaryGreen,
                            foregroundColor: colors.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close Summons',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                children: [
                  // Scheduled hearing card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primaryGreen.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 16,
                              color: colors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SCHEDULED HEARING',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: colors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _infoLine('Date', date, colors),
                        _infoLine('Time', '$time (Philippine time)', colors),
                        _infoLine('Venue', venue, colors),
                        _infoLine('Handled by', 'Barangay Lupon', colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Parties Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Case Parties',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _infoLine('Complainant', complaint.residentName ?? 'Resident', colors),
                        _infoLine('Respondent', complaint.respondentDisplayName, colors),
                        _infoLine('Concern', complaint.title, colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Delivery Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summons Delivery Notice',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _infoLine('Assigned tanod', displayTanod, colors),
                        _infoLine('Delivery status', deliveryText, colors),
                        const SizedBox(height: 6),
                        Text(
                          'Handoff to the tanod does not confirm service to the respondent.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: colors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Direct launcher to official format
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedView = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.primaryGreen.withValues(alpha: isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primaryGreen.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: colors.primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.article_rounded,
                              color: colors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'View Official Format (KP Form No. 9)',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Official document from the Lupong Tagapamayapa',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: colors.primaryGreen,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Official Notice note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.primaryGreen.withValues(alpha: 0.08)
                          : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.gavel_rounded,
                          size: 16,
                          color: colors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Physical service, signed summons receipts, and legal paperwork are handled at the barangay hall. Please bring a valid ID and any witnesses or evidence on your hearing date.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: colors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryGreen,
                      foregroundColor: colors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close Summons',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Authentic bond-paper legal format of KP Form No. 9 matching the web portal.
class _OfficialSummonsPaperDoc extends StatelessWidget {
  const _OfficialSummonsPaperDoc({
    required this.complaint,
    required this.summons,
    required this.hearing,
    required this.date,
    required this.time,
    required this.venue,
  });

  final Submission complaint;
  final Map<String, dynamic> summons;
  final Map<String, dynamic>? hearing;
  final String date;
  final String time;
  final String venue;

  @override
  Widget build(BuildContext context) {
    final identity = BarangayLogos.forSubmission(complaint) ??
        BarangayLogoIdentity(id: complaint.barangayId, name: complaint.barangay);
    final bgy = (identity.canonicalName ?? identity.name ?? 'Not specified').toUpperCase();
    final complainant = (complaint.residentName?.trim().isNotEmpty == true
            ? complaint.residentName!
            : 'Complainant')
        .toUpperCase();
    final respondent = complaint.respondentDisplayName.toUpperCase();

    final rawAddress = summons['respondentAddress']?.toString() ??
        complaint.complaint['respondentAddress']?.toString() ??
        complaint.location ??
        'Barangay ${identity.canonicalName ?? identity.name ?? "Not specified"}';
    final respondentAddr = rawAddress.contains(bgy) ? rawAddress : '$rawAddress, $bgy';

    final category = complaint.category.trim().isNotEmpty ? complaint.category : 'Concern';
    final purpose = (summons['hearingPurpose']?.toString().trim().isNotEmpty == true)
        ? summons['hearingPurpose'].toString()
        : 'Mediation Regarding $category';
    final problemType = summons['hearingPurpose'] != null
        ? summons['hearingPurpose'].toString().replaceFirst(RegExp(r'^mediation\s+(regarding|on|for)\s+', caseSensitive: false), '')
        : complaint.title;

    var caseNo = complaint.id;
    if (!caseNo.startsWith('KP-')) {
      caseNo = 'KP-$caseNo';
    }

    // Parse hearing date parts
    final hearingDateRaw = hearing?['date'] ?? summons['appearanceDate'] ?? summons['hearingDate'];
    final hearingDate = _OfficialSummonsPageState._parseDate(hearingDateRaw);
    final hearingDayOrdinal = hearingDate != null
        ? _OfficialSummonsPageState._formatOrdinal(hearingDate.day)
        : date;
    final hearingMonth = hearingDate != null ? DateFormat('MMMM').format(hearingDate) : '';
    final hearingYear = hearingDate != null ? hearingDate.year.toString() : '';

    // Parse issue date parts
    final issueDateRaw = summons['issuedAt'] ??
        summons['createdAt'] ??
        hearing?['createdAt'] ??
        complaint.submittedAt ??
        complaint.date;
    final issueDate = _OfficialSummonsPageState._parseDate(issueDateRaw) ?? DateTime.now();
    final issueDayOrdinal = _OfficialSummonsPageState._formatOrdinal(issueDate.day);
    final issueMonth = DateFormat('MMMM').format(issueDate);
    final issueYear = issueDate.year.toString();
    final dateIssuedEnglish = DateFormat('MMMM d, yyyy').format(issueDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Republic Header
          Row(
            children: [
              Image.asset(
                BarangayLogos.municipalityAsset,
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'REPUBLIC OF THE PHILIPPINES',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Province of Cebu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    Text(
                      'MUNICIPALITY OF BARILI',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'BARANGAY $bgy',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'OFFICE OF THE LUPONG TAGAPAMAYAPA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              BarangayLogo(
                barangayId: identity.id,
                barangayName: identity.name,
                size: 42,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1.5, color: const Color(0xFF111827)),
          const SizedBox(height: 14),

          // Caption Grid: Complainant vs Respondent & Case Fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$complainant,',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Complainant/s',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '- against -',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$respondent,',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Respondent/s',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 88,
                color: const Color(0xFFE5E7EB),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BARANGAY CASE NO.:',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      caseNo,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'FOR:',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      purpose,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'DATE ISSUED:',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      dateIssuedEnglish,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Center(
            child: Text(
              'S U M M O N S',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // TO block
          Text(
            'TO: $respondent',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            respondentAddr,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 14),

          // Body text
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF1F2937),
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'You are hereby summoned to appear before me in person, together with your witnesses, on the ',
                ),
                TextSpan(
                  text: hearingDate != null
                      ? '$hearingDayOrdinal day of $hearingMonth, $hearingYear, at $time'
                      : '$date at $time',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(text: ' at the '),
                TextSpan(
                  text: venue,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(
                  text: ', then and there to answer to a complaint made before me by complainant ',
                ),
                TextSpan(
                  text: complainant,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(text: ' regarding '),
                TextSpan(
                  text: problemType,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(
                  text: ', a copy of which is attached hereto, for mediation/conciliation of your dispute with the complainant/s.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You are hereby warned that if you refuse or willfully fail to appear in obedience to this summons, you may be barred from filing any counterclaim arising from said complaint.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF1F2937),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'FAIL NOT or else face punishment as for contempt of court.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This $issueDayOrdinal day of $issueMonth, $issueYear.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 24),
          // Signature Block
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 190,
              child: Column(
                children: [
                  Container(height: 1, color: const Color(0xFF111827)),
                  const SizedBox(height: 5),
                  Text(
                    'Punong Barangay / Pangkat Chairman',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Signature over Printed Name',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          const SizedBox(height: 6),
          Text(
            'KP Form No. 9 - Summons for the Respondent',
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}


/// Opens the complete Activity & History log sheet for audit and technical details.
void showFullHistorySheet(BuildContext context, Submission complaint) {
  final colors = context.colors;
  final entries = complaint.publicStatusHistory;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.90,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: colors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Case History',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Complete activity logs, notes, and audit records',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textSecondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Case Header Summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Case #${complaint.id} • ${complaint.title}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Respondent: ${complaint.respondentDisplayName}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (complaint.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Filed description:',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complaint.description.trim(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Activity History (${entries.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No history records found.',
                        style: GoogleFonts.poppins(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...entries.map((entry) {
                      final rawStatus = entry['status']?.toString() ?? 'filed';
                      final label = entry['label']?.toString() ??
                          ComplaintRoleHelper.simplifyStatus(rawStatus, action: entry['action']?.toString());
                      final date = _parseDate(entry['date'] ?? entry['performedAt'] ?? entry['updatedAt']);
                      final officerName = (entry['actorName'] ?? entry['performedBy'] ?? entry['updatedBy'])?.toString().trim();
                      final remarks = (entry['remarks'] ?? entry['note'] ?? entry['reason'])?.toString().trim() ?? '';
                      final role = ComplaintRoleHelper.resolveRole(
                        actorId: entry['actorId']?.toString() ?? entry['performedBy']?.toString(),
                        actorRole: entry['actorRole']?.toString(),
                        actorName: officerName,
                        action: entry['action']?.toString(),
                        status: rawStatus,
                        submission: complaint,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    DateFormat('MMM d, y • h:mm a').format(date.toUtc().add(const Duration(hours: 8))),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            if (officerName != null && officerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Officer: $officerName ($role)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primaryGreen,
                                ),
                              ),
                            ],
                            if (remarks.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                remarks,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: colors.textPrimary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  if (complaint.hearings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Hearing Sessions (${complaint.hearings.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final session in complaint.hearings)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hearing ${session['number']} · ${_hearingLabel(session)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${session['date']} • ${session['time']} PHT • ${session['venue']}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                            if (session['summary'] != null || session['reason'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${session['summary'] ?? session['reason']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            if (session['complainantAttendance'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Attendance: Complainant ${session['complainantAttendance']} • Respondent ${session['respondentAttendance']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: colors.primaryGreen,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (complaint.externalUpdates.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'External Updates',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final update in complaint.externalUpdates)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${update['type']} • ${update['date']}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (update['reference']?.toString().isNotEmpty == true)
                              Text(
                                'Reference: ${update['reference']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: colors.primaryGreen,
                                ),
                              ),
                            if (update['note']?.toString().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${update['note']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (complaint.complaintFinished &&
                      complaint.resolutionSummary?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primaryGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded Conclusion',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: colors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            complaint.resolutionSummary!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryGreen,
                      foregroundColor: colors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close History',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoLine(String label, String value, ESugidColors colors) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _hearingLabel(Map<String, dynamic> session) => switch (session['status']) {
      'completed' => session['outcome'] == 'settled'
          ? 'Agreement reached'
          : 'No agreement',
      'not_held' => 'Not held',
      'cancelled' => 'Cancelled',
      _ => 'Scheduled',
    };
