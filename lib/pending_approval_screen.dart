import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'session_service.dart';

class PendingApprovalScreen extends StatelessWidget {
  final User? user;

  const PendingApprovalScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final account = user ?? AuthService.currentUser;
    final isPending = account?.accountStatus == AccountStatus.pendingApproval;
    final isRestricted = account?.isRestricted == true ||
        account?.restrictionStatus == 'active';
    final isSuspended = !isRestricted &&
        account?.accountStatus == AccountStatus.suspended;

    if (isRestricted) {
      return _buildRestrictedView(context, account);
    }

    if (isPending) {
      return _buildPendingApprovalView(context, account);
    }

    return _buildGenericUnavailableView(context, account, isSuspended);
  }

  /// Improved UI for restricted accounts displaying the reason for restriction,
  /// duration, authorizing official/office, and professional appeal instructions.
  Widget _buildRestrictedView(BuildContext context, User? account) {
    final String name = account?.name.trim().isNotEmpty == true
        ? account!.name.trim()
        : 'Resident';

    final String reason = account?.restrictionReason?.trim().isNotEmpty == true
        ? account!.restrictionReason!.trim()
        : (account?.statusReason?.trim().isNotEmpty == true
            ? account!.statusReason!.trim()
            : 'Violation of community reporting guidelines or policy requirements.');

    final DateTime? endDate = account?.restrictionEndDate;
    final bool hasEndDate = endDate != null;
    final String formattedEndDate = hasEndDate
        ? DateFormat('MMMM d, y · h:mm a').format(endDate.toLocal())
        : '';

    final String barangay = account?.barangay?.trim() ?? '';
    final String authorizingAuthority = account?.restrictedByOffice?.trim().isNotEmpty == true
        ? account!.restrictedByOffice!.trim()
        : barangay.isNotEmpty
            ? (barangay.toLowerCase().startsWith('barangay')
                ? '$barangay Officials'
                : 'Barangay $barangay Officials')
            : 'the authorizing official';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Restriction Shield / Lock Badge
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: context.colors.errorSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.border, width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.highlight.withValues(alpha: 0.12,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_person_rounded,
                      size: 46,
                      color: context.colors.error,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pill Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.errorSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.error),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: context.colors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ACCOUNT RESTRICTED',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: context.colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Headline
                  Text(
                    'Access Restricted',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Hi $name, your account is temporarily restricted from accessing E-Sugid.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: context.colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reason & Restriction Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: context.colors.errorSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.assignment_late_outlined,
                                size: 18,
                                color: context.colors.error,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Reason for Restriction',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.warningSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Text(
                            reason,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.colors.error,
                              height: 1.45,
                            ),
                          ),
                        ),
                        if (hasEndDate) ...[
                          const SizedBox(height: 14),
                          Divider(height: 1, color: context.colors.border),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 18,
                                color: context.colors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Restricted Until',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      formattedEndDate,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Once this period ends, you will automatically be able to log back into your account.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        color: context.colors.primaryGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contact Authorized Official Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colors.infoSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.contact_support_outlined,
                            size: 20,
                            color: context.colors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need Clarification or Want to Appeal?',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If you believe this restriction was made in error or wish to appeal this decision, please contact the $authorizingAuthority who restricted your account for assistance and review.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: context.colors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Back to Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      key: const ValueKey('restricted-back-to-login-button'),
                      onPressed: () async {
                        await SessionService.logout();
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(
                        'Back to Login',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: context.colors.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
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
  }

  /// Staff/Official registration awaiting approval
  Widget _buildPendingApprovalView(BuildContext context, User? account) {
    final requestedRole = account?.positionTitle?.trim().isNotEmpty == true
        ? account!.positionTitle!.trim()
        : 'Barangay Official';
    final assignment = account?.organizationName?.trim().isNotEmpty == true
        ? account!.organizationName!.trim()
        : account?.barangay?.trim().isNotEmpty == true
            ? 'Barangay ${account!.barangay!.trim()}'
            : 'Assignment not recorded';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: context.colors.warningSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.border, width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      size: 46,
                      color: context.colors.warning,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Account Awaiting Approval',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your $requestedRole account is currently being reviewed. You will be notified once a decision is made.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          context,
                          'Requested role', requestedRole,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          context,
                          'Barangay / organization', assignment,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(context, 'Status', 'Pending Review'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Divider(height: 1),
                        ),
                        _buildStatusItem(
                          context,
                          Icons.check_circle,
                          "Registration Received",
                          true,
                        ),
                        _buildStatusDivider(context, true),
                        _buildStatusItem(
                          context,
                          Icons.admin_panel_settings,
                          "Admin Review",
                          false,
                        ),
                        _buildStatusDivider(context, false),
                        _buildStatusItem(
                          context,
                          Icons.verified_user,
                          "Full Access",
                          false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () async {
                        await SessionService.logout();
                      },
                      style: FilledButton.styleFrom(
                        foregroundColor: context.colors.onAccent,

                        backgroundColor: context.colors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Back to Login',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  /// Generic fallback for suspended or inactive accounts
  Widget _buildGenericUnavailableView(
    BuildContext context,
    User? account,
    bool isSuspended,
  ) {
    final title = isSuspended ? 'Account Suspended' : 'Account Unavailable';
    final name = account?.name.trim().isNotEmpty == true
        ? account!.name.trim()
        : 'Resident';

    final String authorizingAuthority = account?.restrictedByOffice?.trim().isNotEmpty == true
        ? account!.restrictedByOffice!.trim()
        : account?.barangay?.trim().isNotEmpty == true
            ? 'Barangay ${account!.barangay!.trim()} Office'
            : 'Barili Municipal Office';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: context.colors.warningSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.border, width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 46,
                      color: context.colors.warning,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hi $name, this account cannot access E-Sugid at this time.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Text(
                      'For assistance and account review, please contact the $authorizingAuthority.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () async {
                        await SessionService.logout();
                      },
                      style: FilledButton.styleFrom(
                        foregroundColor: context.colors.onAccent,

                        backgroundColor: context.colors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Back to Login',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: context.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    IconData icon, String label, bool isDone,
  ) {
    return Row(
      children: [
        Icon(icon, color: isDone ? context.colors.primaryGreen
              : context.colors.textSecondary, size: 24,
        ),
        const SizedBox(width: 16),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
            color: isDone ? context.colors.textPrimary
                : context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDivider(BuildContext context, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
      height: 20,
      width: 2,
      color: isDone ? context.colors.brand : context.colors.surfaceAlt,
    );
  }
}
