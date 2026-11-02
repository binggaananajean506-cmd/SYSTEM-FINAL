import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/semantic_colors.dart';
import '../../submission_service.dart';
import '../../barili_barangays.dart';
import '../../services/barangay_logo_service.dart';
import '../../widgets/barangay_logo.dart';
import 'complaint_role_helper.dart';
import 'complaint_history_sheet.dart';

/// Opens the complete Official Summons Notice page.
void showSummonsSheet(BuildContext context, Submission complaint) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => OfficialSummonsPage(complaint: complaint),
    ),
  );
}

class OfficialSummonsPage extends StatefulWidget {
  const OfficialSummonsPage({super.key, required this.complaint, this.officialsLoader});

  final Submission complaint;
  final Future<Map<String, dynamic>> Function(String caseId)? officialsLoader;

  @override
  State<OfficialSummonsPage> createState() => _OfficialSummonsPageState();
}

class _OfficialSummonsPageState extends State<OfficialSummonsPage> {
  // 0: Official Form, 1: Hearing Notice.
  int _selectedView = 0;
  Map<String, dynamic> _loadedOfficials = const {};
  int _officialsRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadOfficials();
  }

  Future<void> _loadOfficials() async {
    final request = ++_officialsRequest;
    final complaint = widget.complaint;
    final expected = bariliBarangayId(BarangayLogos.forSubmission(complaint)?.canonicalName);
    if (expected == null) return;
    final stored = complaint.summons?['officials'];
    if (stored is Map && stored['barangayId'] == expected
        && stored['captainName']?.toString().trim().isNotEmpty == true
        && stored['secretaryName']?.toString().trim().isNotEmpty == true) {
      return;
    }
    try {
      final loader = widget.officialsLoader;
      final data = loader != null ? await loader(complaint.id)
          : Map<String, dynamic>.from((await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable('getSummonsOfficials', options: HttpsCallableOptions(timeout: const Duration(seconds: 10)))
              .call<Map>({'submissionId': complaint.id})).data);
      if (mounted && request == _officialsRequest && data['barangayId'] == expected) {
        setState(() => _loadedOfficials = data);
      }
    } catch (_) {
      // Missing official records stay blank; never substitute the viewing user.
    }
  }

  @override
  void didUpdateWidget(covariant OfficialSummonsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaint.id != widget.complaint.id) {
      _loadedOfficials = const {};
      _loadOfficials();
    }
  }

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
    final expectedId = bariliBarangayId(caseIdentity?.canonicalName);
    final storedOfficials = summons['officials'];
    final officials = <String, dynamic>{..._loadedOfficials};
    if (storedOfficials is Map && storedOfficials['barangayId'] == expectedId) {
      for (final field in ['captainName', 'secretaryName']) {
        if (storedOfficials[field]?.toString().trim().isNotEmpty == true) {
          officials[field] = storedOfficials[field];
        }
      }
    }

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
        : 'Not yet assigned';

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
                              'Official Form',
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
                    officials: officials,
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
                        _infoLine('Hearing', complaintHearingLabel(hearing?['number'] ?? summons['hearingNumber'] ?? summons['summonsCount']), colors),
                        _infoLine('Handled by', isLuponRound(hearing?['number'] ?? summons['hearingNumber'] ?? summons['summonsCount']) ? 'Barangay Lupon' : 'Punong Barangay', colors),
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
                                  'View Official Form',
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

/// Summons layout shared with the web preview and printed document.
class _OfficialSummonsPaperDoc extends StatelessWidget {
  const _OfficialSummonsPaperDoc({
    required this.complaint,
    required this.summons,
    required this.hearing,
    required this.date,
    required this.time,
    required this.venue,
    required this.officials,
  });

  final Submission complaint;
  final Map<String, dynamic> summons;
  final Map<String, dynamic>? hearing;
  final String date;
  final String time;
  final String venue;
  final Map<String, dynamic> officials;

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
    final round = summons['hearingNumber'] ?? hearing?['number'] ?? summons['summonsCount'];
    final office = isLuponRound(round) ? 'Office of the Lupong Tagapamayapa' : 'Office of the Barangay Captain';

    final category = complaint.category.trim().isNotEmpty ? complaint.category : 'Concern';
    final purpose = (summons['hearingPurpose']?.toString().trim().isNotEmpty == true)
        ? summons['hearingPurpose'].toString()
        : 'Mediation Regarding $category';

    final caseNo = complaint.id;

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
    final rawTanod = summons['assignedTanod']?.toString().trim() ?? '';
    final tanod = RegExp(r'^(?:barangay )?tanod(?: on duty)?$', caseSensitive: false)
        .hasMatch(rawTanod) ? '' : rawTanod;

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
              BarangayLogo(
                key: const ValueKey('summons-barangay-seal'),
                barangayId: identity.id,
                barangayName: identity.name,
                size: 42,
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
                      office.toUpperCase(),
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
              Image.asset(
                BarangayLogos.municipalityAsset,
                key: const ValueKey('summons-municipal-seal'),
                width: 42,
                height: 42,
                fit: BoxFit.contain,
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
                      'SERIES OF:',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      issueYear,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'FOR INVITATION:',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      round == null ? '________' : '${(complaintRoundNumber(round) - 1) % complaintRoundsPerPhase + 1} of $complaintRoundsPerPhase',
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

          // Body text
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF1F2937),
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: 'You are hereby summoned to appear before the $office on the ',
                ),
                TextSpan(
                  text: hearingDate != null
                      ? '$hearingDayOrdinal day of $hearingMonth, $hearingYear, at $time'
                      : '$date at $time',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(text: ' at '),
                TextSpan(
                  text: venue,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const TextSpan(
                  text: ', regarding the above-captioned case.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Respondent summoned: $respondent',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Reason / Subject: $purpose',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF1F2937),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Given this $issueDayOrdinal day of $issueMonth, $issueYear at ${identity.canonicalName ?? identity.name ?? "the barangay"}, Barili, Cebu, Philippines.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _signature('Prepared by:', officials['secretaryName']?.toString() ?? '', 'Barangay Secretary')),
              const SizedBox(width: 18),
              Expanded(child: _signature('Noted by:', officials['captainName']?.toString() ?? '', 'Barangay Captain')),
            ],
          ),
          const SizedBox(height: 28),
          Center(child: SizedBox(width: 190, child: _signature('Serve by:', tanod, 'Barangay Tanod'))),

          const SizedBox(height: 18),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          const SizedBox(height: 6),
          Text(
            'Barangay Summons · ${identity.canonicalName ?? identity.name ?? ""} · $caseNo',
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

  Widget _signature(String label, String name, String role) => Column(
    children: [
      Text(label, textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black)),
      const SizedBox(height: 22),
      Text(name.trim().isEmpty ? '____________________' : name.trim(),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline, color: Colors.black)),
      Text(role, textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 10, color: Colors.black)),
    ],
  );
}


/// Opens a compact resident timeline with optional case details.
void showFullHistorySheet(BuildContext context, Submission complaint) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ComplaintHistorySheet(complaint: complaint),
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
