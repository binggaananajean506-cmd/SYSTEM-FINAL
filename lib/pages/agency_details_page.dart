import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_agency.dart';
import '../widgets/esugid_page_header.dart';

/// Detailed view of a verified emergency agency showing grouped numbers,
/// verified badge, location with maps action, and official web page.
class AgencyDetailsPage extends StatefulWidget {
  const AgencyDetailsPage({
    super.key,
    required this.agency});

  final EmergencyAgency agency;

  @override
  State<AgencyDetailsPage> createState() => _AgencyDetailsPageState();
}

class _AgencyDetailsPageState extends State<AgencyDetailsPage>
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

  Future<void> _callNumber(BuildContext context, String number) async {
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

  Future<void> _viewLocation(BuildContext context, String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open map navigation.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  Future<void> _visitOfficialPage(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open official page link.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  Widget _buildAnimatedSection({
    required int index,
    required Widget child}) {
    final start = (index * 0.10).clamp(0.0, 0.7);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, animChild) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - animation.value) * 18),
            child: animChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agency = widget.agency;
    final is911 = agency.isUrgent911;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          // Collapsible Header matching the rest of the application
          // Note: Subtitle and Icon are intentionally removed as requested
          ESugidSliverPageHeader(
            pinned: true,
            showBackButton: true,
            onBack: () => Navigator.of(context).pop(),
            title: agency.name,
            subtitle: null,
            icon: null,
            iconWidget: null,
            sectionLabelWidget: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: (is911
                        ? context.colors.errorSolid : context.colors.brand)
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (is911
                          ? context.colors.error
                              : context.colors.primaryGreen)
                      .withValues(alpha: 0.45),
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
                      color: is911
                          ? context.colors.errorSolid
                          : context.colors.brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: is911
                              ? context.colors.highlight
                              : context.colors.brandStrong,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5.5),
                  Text(
                    is911 ? 'NATIONAL DIRECTORY' : 'VERIFIED DIRECTORY',
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

          // Content sections with GPU-accelerated staggered entrance
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Hero Identity Plinth
                _buildAnimatedSection(
                  index: 0,
                  child: _buildHeroCard(context, isDark),
                ),
                const SizedBox(height: 16),

                // 2. Grouped Contact Numbers Section
                _buildAnimatedSection(
                  index: 1,
                  child: _buildContactNumbersSection(context, isDark),
                ),

                // 3. Location Section (Hidden if empty) - Warm Amber Geo Theme
                if (agency.address != null &&
                    agency.address!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAnimatedSection(
                    index: 2,
                    child: _buildLocationSection(context, isDark),
                  ),
                ],

                // 4. Official Social Media / Web Page (Hidden if empty) - Royal Sapphire Theme
                if (agency.officialPageUrl != null &&
                    agency.officialPageUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAnimatedSection(
                    index: 3,
                    child: _buildOfficialPageSection(context, isDark),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, bool isDark) {
    final agency = widget.agency;
    final is911 = agency.isUrgent911;
    final themeColor = is911
        ? context.colors.error
        : (agency.id == 'pnp'
            ? context.colors.info
              : (agency.id == 'bfp'
                ? context.colors.error
                    : context.colors.primaryGreen));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : (is911
                  ? context.colors.border
                    : context.colors.border.withValues(alpha: 0.9)),
          width: 1.4,
        ),
        boxShadow: [
          // Specular top edge highlight
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.05 : 0.9,
            ),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // Soft ambient colored glow matching agency theme
          BoxShadow(
            color: themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          // Grounding contact drop shadow
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.35 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3D Raised Jewel Logo Medallion
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: agency.logoAsset != null
                  ? Image.asset(
                      agency.logoAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _buildFallbackIcon(themeColor),
                    )
                  : _buildFallbackIcon(themeColor),
            ),
          ),
          const SizedBox(height: 14),

          // Agency Name
          Text(
            agency.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Illuminated Live Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5.5),
            decoration: BoxDecoration(
              color: is911
                  ? (isDark ? context.colors.errorSolid
                        : context.colors.errorSurface) : (context.colors.surfaceAlt),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: is911
                    ? context.colors.error : context.colors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (is911
                          ? context.colors.highlight
                              : context.colors.brandStrong)
                      .withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: is911
                        ? context.colors.errorSolid
                        : context.colors.brand,
                    boxShadow: [
                      BoxShadow(
                        color: is911
                            ? context.colors.highlight
                            : context.colors.brandStrong,
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6.5),
                Text(
                  agency.verifiedLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: is911
                        ? context.colors.error
                        : context.colors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(Color themeColor) {
    return Container(
      color: themeColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          widget.agency.fallbackIcon,
          size: 38,
          color: themeColor),
      ),
    );
  }

  Widget _buildContactNumbersSection(BuildContext context, bool isDark) {
    final agency = widget.agency;
    final is911 = agency.isUrgent911;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.9),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.05 : 0.8,
            ),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: is911
                      ? context.colors.errorSurface
                      : context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.phone_in_talk_rounded,
                    size: 18,
                    color: is911
                        ? context.colors.error
                        : context.colors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Emergency Contact Numbers',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grouped numbers list with 3D tactile slots
          ...agency.contactNumbers.map((contact) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? context.colors.surfaceAlt
                    : (contact.isPrimary
                        ? context.colors.surfaceAlt
                          : context.colors.surface),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: contact.isPrimary
                      ? (is911
                          ? context.colors.border : context.colors.border)
                          : (context.colors.border),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Circular line icon medallion
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: is911
                          ? context.colors.errorSurface
                          : context.colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        contact.label.toLowerCase().contains('mobile')
                            ? Icons.phone_android_rounded
                            : (contact.label.toLowerCase().contains('landline')
                                ? Icons.phone_rounded
                                : Icons.sos_rounded),
                        size: 19,
                        color: is911
                            ? context.colors.error
                            : context.colors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Phone digits & label
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact.number,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isDark
                                ? context.colors.error
                                : (is911
                                    ? context.colors.error
                                      : context.colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3D Physical Push Button
                  GestureDetector(
                    onTap: () => _callNumber(context, contact.number),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: is911
                              ? [
                                  context.colors.errorSolid,
                                  context.colors.errorSolid,
                                ]
                              : [context.colors.brand, context.colors.brand],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          // 3D bottom extrusion ledge
                          BoxShadow(
                            color: is911
                                ? context.colors.errorSolid
                                : context.colors.brandStrong,
                            offset: const Offset(0, 3.2),
                            blurRadius: 0,
                          ),
                          // Drop glow
                          BoxShadow(
                            color: (is911
                                    ? context.colors.errorSolid
                                        : context.colors.brandStrong)
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.call_rounded,
                            size: 15,
                            color: context.colors.onAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Call',
                            style: GoogleFonts.poppins(
                              color: context.colors.onAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Station Address / Location Section with a dedicated Warm Topaz / Amber Geo Theme
  Widget _buildLocationSection(BuildContext context, bool isDark) {
    final agency = widget.agency;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.75),
          width: 1.3,
        ),
        boxShadow: [
          // Specular top highlight
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.05 : 0.8,
            ),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // Warm amber ambient glow
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.16 : 0.07,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          // Contact grounding shadow
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Amber Map Pin Medallion
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.warningSurface,
                      context.colors.warningSolid,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.highlight.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: context.colors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Station Address / Location',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            agency.address!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // 3D Tactile "View Location" Amber Action Button
          GestureDetector(
            onTap: () => _viewLocation(
              context,
              agency.mapQuery ?? agency.address!),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.warningSurface,
                    context.colors.warningSurface,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  // 3D bottom extrusion ledge
                  BoxShadow(
                    color: isDark
                        ? context.colors.warningSolid
                        : context.colors.warningSolid.withValues(alpha: 0.35),
                    offset: const Offset(0, 2.8),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: context.colors.warningSolid.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 17,
                    color: context.colors.warning,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'View Location',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.warning,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Official Page / Social Section with a dedicated Royal Sapphire / Cobalt Theme
  Widget _buildOfficialPageSection(BuildContext context, bool isDark) {
    final agency = widget.agency;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.8),
          width: 1.3,
        ),
        boxShadow: [
          // Specular top highlight
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.05 : 0.8,
            ),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // Royal sapphire ambient glow
          BoxShadow(
            color: context.colors.infoSolid.withValues(alpha: isDark ? 0.16 : 0.07,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          // Contact grounding shadow
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Royal Sapphire Globe Medallion
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.infoSurface,
                      context.colors.infoSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.infoSolid.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.public_rounded,
                    size: 19,
                    color: context.colors.info,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Official Page / Social',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            agency.officialPageName ?? agency.officialPageUrl!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // 3D Tactile "Visit Official Page" Sapphire Action Button
          GestureDetector(
            onTap: () => _visitOfficialPage(
              context,
              agency.officialPageUrl!),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.infoSurface,
                    context.colors.infoSurface,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  // 3D bottom extrusion ledge
                  BoxShadow(
                    color: isDark
                        ? context.colors.infoSolid
                        : context.colors.infoSolid.withValues(alpha: 0.35),
                    offset: const Offset(0, 2.8),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: context.colors.infoSolid.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 17,
                    color: context.colors.info,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Visit Official Page',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.info,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
