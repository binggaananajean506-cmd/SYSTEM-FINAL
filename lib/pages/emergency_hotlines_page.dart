import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_agency.dart';
import '../widgets/esugid_page_header.dart';
import 'agency_details_page.dart';

/// Emergency Hotlines directory page for E-SUGID.
/// Displays verified emergency response agencies for Barili, Cebu, and 911.
/// Each agency is represented by a single card with its official logo.
class EmergencyHotlinesPage extends StatefulWidget {
  const EmergencyHotlinesPage({super.key});

  @override
  State<EmergencyHotlinesPage> createState() => _EmergencyHotlinesPageState();
}

class _EmergencyHotlinesPageState extends State<EmergencyHotlinesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _dialNumber(BuildContext context, String number) async {
    final dialDigits = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: dialDigits);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open phone dialer for $number'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  void _onCallAgency(BuildContext context, EmergencyAgency agency) {
    if (agency.contactNumbers.length == 1) {
      _dialNumber(context, agency.contactNumbers.first.number);
      return;
    }

    // Multiple numbers: show quick bottom sheet to let user pick which line to dial
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border, width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: agency.logoAsset != null
                          ? Image.asset(
                              agency.logoAsset!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                agency.fallbackIcon,
                                size: 22,
                                color: context.colors.primaryGreen,
                              ),
                            )
                          : Icon(
                              agency.fallbackIcon,
                              size: 22,
                              color: context.colors.primaryGreen,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agency.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Select a contact line to call',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...agency.contactNumbers.map((contact) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: contact.isPrimary
                        ? (context.colors.surfaceAlt)
                        : (context.colors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: contact.isPrimary
                          ? context.colors.border.withValues(alpha: 0.6)
                          : (context.colors.border),
                      width: contact.isPrimary ? 1.4 : 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (context.colors.brandStrong)
                            .withValues(alpha: contact.isPrimary ? 0.08 : 0.03,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (contact.isPrimary ? context.colors.brand
                                    : context.colors.brand)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        contact.label.toLowerCase().contains('mobile')
                            ? Icons.phone_android_rounded
                            : Icons.phone_rounded,
                        color: context.colors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      contact.label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      contact.number,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(bottomSheetContext).pop();
                        _dialNumber(context, contact.number);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: context.colors.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                      label: const Text('Call'),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agencies = EmergencyAgency.verifiedAgencies;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          ESugidSliverPageHeader(
            pinned: true,
            showBackButton: true,
            onBack: () => Navigator.of(context).pop(),
            sectionLabelWidget: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.errorSolid.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.colors.error.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.colors.errorSolid,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.highlight,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DIRECT EMERGENCY ACCESS',
                    style: GoogleFonts.outfit(
                      color: context.colors.onBrandMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            title: 'Emergency Hotlines',
          ),

          // Reassurance / Active Dispatch Network Pill
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.surfaceAlt,
                      context.colors.surfaceAlt,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: (context.colors.brandStrong)
                          .withValues(alpha: 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.brand,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brandStrong,
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BARILI EMERGENCY NETWORK • 24/7 VERIFIED DISPATCH',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primaryGreen,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: context.colors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3D Staggered Cards List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final agency = agencies[index];
                  final double startInterval = (index * 0.08).clamp(0.0, 0.6);
                  final animation = CurvedAnimation(
                    parent: _animController,
                    curve: Interval(startInterval, 1.0, curve: Curves.easeOutCubic,
                  ),
                  );

                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: animation.value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - animation.value)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildAgencyCard(context, agency, isDark),
                  );
                },
                childCount: agencies.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgencyCard(
    BuildContext context,
    EmergencyAgency agency,
    bool isDark,
  ) {
    final isUrgent911 = agency.isUrgent911;

    // Card styling
    final surfaceGradient = isUrgent911
        ? ([context.colors.surface, context.colors.surface])
        : ([context.colors.surface, context.colors.surface]);

    final borderColor = isUrgent911
        ? context.colors.error.withValues(alpha: isDark ? 0.55 : 0.85)
        : (context.colors.textSecondary);

    final glowTint = isUrgent911 ? context.colors.error
        : context.colors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: surfaceGradient,
        ),
        border: Border.all(color: borderColor, width: isUrgent911 ? 1.6 : 1.3),
        boxShadow: [
          // 1. Specular top-edge highlight (creates 3D physical bevel reflection)
          BoxShadow(
            color: isDark
                ? (isUrgent911 ? context.colors.errorSolid
                      : context.colors.brandStrong)
                : context.colors.highlight.withValues(alpha: 0.95),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
          // 2. Crisp contact shadow
          BoxShadow(
            color: glowTint.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          // 3. Volumetric diffuse drop shadow
          BoxShadow(
            color: glowTint.withValues(alpha: isDark ? 0.38 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 9),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AgencyDetailsPage(agency: agency),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper Section: 3D Medallion + Name & Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Agency Logo Container (3D Jewel Medallion)
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isUrgent911
                              ? context.colors.error
                              : context.colors.border,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isUrgent911
                                    ? context.colors.errorSolid
                                        : context.colors.brandStrong)
                                .withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.04,
                            ),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: agency.logoAsset != null
                            ? Image.asset(
                                agency.logoAsset!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    _buildCardFallbackIcon(agency),
                              )
                            : _buildCardFallbackIcon(agency),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  agency.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.textPrimary,
                                    height: 1.22,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Live Illuminated Status Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isUrgent911
                                      ? context.colors.errorSurface
                                      : (context.colors.surfaceAlt),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUrgent911
                                        ? context.colors.error
                                        : (context.colors.border),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isUrgent911
                                              ? context.colors.highlight
                                                  : context.colors.brandStrong)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isUrgent911
                                            ? context.colors.errorSolid
                                            : context.colors.brand,
                                        boxShadow: [
                                          BoxShadow(
                                            color: isUrgent911
                                                ? context.colors.highlight
                                                : context.colors.brandStrong,
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isUrgent911 ? 'TOLL-FREE' : '24/7 ACTIVE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: isUrgent911
                                            ? context.colors.error
                                            : (context.colors.primaryGreen),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            agency.shortPurpose,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: context.colors.textSecondary,
                              height: 1.38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tactile Embossed Hotline Number Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent911
                        ? (context.colors.errorSurface) : (context.colors.surfaceAlt),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUrgent911
                          ? context.colors.border.withValues(alpha: isDark ? 0.35 : 0.8,
                            )
                          : (context.colors.border),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: (isUrgent911 ? context.colors.errorSolid
                                      : context.colors.brand)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.phone_in_talk_rounded,
                          size: 13,
                          color: isUrgent911 ? context.colors.error
                              : context.colors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isUrgent911
                              ? 'Direct Emergency Dispatch: 911'
                              : (agency.contactNumbers.length > 1
                                  ? '${agency.contactNumbers.length} Verified Lines Available'
                                  : agency.primaryNumber?.number ?? ''),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: isUrgent911
                                ? context.colors.error
                                : (context.colors.primaryGreen),
                          ),
                        ),
                      ),
                      if (agency.contactNumbers.length > 1)
                        Text(
                          'Multi-line',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Lower Section: 3D Physical Action Buttons
                Row(
                  children: [
                    // View Details Action Button (Frosted Ceramic Glass)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AgencyDetailsPage(agency: agency),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? context.colors.textSecondary
                              : context.colors.primaryGreen,
                          backgroundColor: isDark
                              ? context.colors.surfaceAlt.withValues(alpha: 0.55,
                                )
                              : context.colors.surfaceAlt,
                          side: BorderSide(
                            color: isDark
                                ? context.colors.primaryGreen
                                : context.colors.border,
                            width: 1.3,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                          shadowColor: context.colors.shadow.withValues(alpha: 0.05,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: Text(
                          'View Details',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Call Action Button (3D Physical Extrusion Push-Button)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isUrgent911
                              ? context.colors.errorSolid
                              : context.colors.brand, // 3D Bottom Lip
                          boxShadow: [
                            BoxShadow(
                              color: (isUrgent911
                                      ? context.colors.errorSolid
                                          : context.colors.brandStrong)
                                  .withValues(alpha: isDark ? 0.45 : 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 3.2,
                          ), // Reveals 3D extrusion lip!
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isUrgent911
                                  ? [
                                      context.colors.errorSolid,
                                      context.colors.errorSolid,
                                    ]
                                  : [
                                      context.colors.brand,
                                      context.colors.brand,
                                    ],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: context.colors.border.withValues(alpha: 0.35,
                                ),
                                width: 1.2,
                              ),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _onCallAgency(context, agency),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10.5,
                                  horizontal: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone_in_talk_rounded,
                                      size: 16.5,
                                      color: context.colors.onAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isUrgent911 ? 'Call 911' : 'Call',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
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
                        ),
                      ),
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

  Widget _buildCardFallbackIcon(EmergencyAgency agency) {
    final isUrgent911 = agency.isUrgent911;
    return Container(
      color: isUrgent911 ? context.colors.errorSurface
          : context.colors.surfaceAlt,
      child: Center(
        child: Icon(
          agency.fallbackIcon,
          size: 26,
          color: isUrgent911 ? context.colors.error
              : context.colors.primaryGreen,
        ),
      ),
    );
  }
}
