import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/semantic_colors.dart';

/// Service shortcuts, with navigation and access checks owned by the page.
class ServicesDirectory extends StatelessWidget {
  const ServicesDirectory({
    super.key,
    required this.onBayanihan,
    required this.onMarket,
    required this.onEmergency,
    required this.onOfficials,
    required this.onMap,
    required this.onCalendar,
    required this.onWeather,
    required this.onOrganizations,
    required this.onExplore,
  });

  final VoidCallback onBayanihan;
  final VoidCallback onMarket;
  final VoidCallback onEmergency;
  final VoidCallback onOfficials;
  final VoidCallback onMap;
  final VoidCallback onCalendar;
  final VoidCallback onWeather;
  final VoidCallback onOrganizations;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _FeaturedShortcut(
                title: 'Bayanihan Works',
                subtitle: 'Join and support\ncommunity projects',
                onTap: onBayanihan,
              ),
              _FeaturedShortcut(
                title: 'Local Market',
                subtitle: 'Find and support\nlocal products',
                market: true,
                onTap: onMarket,
              ),
            ];
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.45) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards.first, const SizedBox(height: 10), cards.last],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards.first),
                  const SizedBox(width: 10),
                  Expanded(child: cards.last),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ServiceRow(
          title: 'Emergency & Safety',
          subtitle: 'Report incidents and get help',
          icon: Icons.notifications_active_rounded,
          iconColor: colors.error,
          iconBgColor: colors.errorSurface,
          emergency: true,
          onTap: onEmergency,
        ),
        _ServiceRow(
          title: 'Municipal Officials',
          subtitle: 'See local officials and their offices',
          icon: Icons.account_balance_rounded,
          iconColor: colors.primaryGreen,
          iconBgColor: colors.surfaceAlt,
          onTap: onOfficials,
        ),
        _ServiceRow(
          title: 'Town Map',
          subtitle: 'Explore important places',
          icon: Icons.location_on_rounded,
          iconColor: colors.info,
          iconBgColor: colors.infoSurface,
          onTap: onMap,
        ),
        _ServiceRow(
          title: 'Town Calendar',
          subtitle: 'See upcoming events and activities',
          icon: Icons.calendar_month_rounded,
          iconColor: colors.primaryGreen,
          iconBgColor: colors.surfaceAlt,
          onTap: onCalendar,
        ),
        _ServiceRow(
          title: 'Weather',
          subtitle: 'Check the latest weather updates',
          icon: Icons.wb_cloudy_rounded,
          iconColor: colors.primaryGreen,
          iconBgColor: colors.surfaceAlt,
          onTap: onWeather,
        ),
        _ServiceRow(
          title: 'Private Organizations',
          subtitle: 'See accredited organizations',
          icon: Icons.groups_rounded,
          iconColor: colors.purple,
          iconBgColor: colors.purpleSurface,
          onTap: onOrganizations,
        ),
        _ServiceRow(
          title: 'Explore Barili',
          subtitle: 'Discover places and tourist spots',
          icon: Icons.explore_rounded,
          iconColor: colors.warning,
          iconBgColor: colors.warningSurface,
          onTap: onExplore,
        ),
      ],
    );
  }
}

class _FeaturedShortcut extends StatelessWidget {
  const _FeaturedShortcut({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.market = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool market;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = market ? colors.warning : colors.primaryGreen;
    final solid = market ? colors.warningSolid : colors.brand;
    final foreground = dark ? colors.onAccent : colors.textPrimary;

    final imagePath = market
        ? 'assets/images/resident_dashboard/market_hero_3d.jpg'
        : 'assets/images/resident_dashboard/bayanihan_hero_3d.jpg';

    final actionLabel = market ? 'Shop Now' : 'Join In';
    final actionIcon =
        market ? Icons.storefront_rounded : Icons.volunteer_activism_rounded;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: dark ? 0.35 : 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: dark ? 0.3 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      solid.withValues(alpha: 0.35),
                      market ? colors.warningSurface : colors.brandStrong,
                    ]
                  : [
                      market
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF0FDF4),
                      colors.surface,
                    ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: dark ? 0.6 : 0.45),
              width: 1.4,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            splashColor: accent.withValues(alpha: 0.15),
            highlightColor: accent.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Title Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: solid,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          market
                              ? Icons.shopping_cart_rounded
                              : Icons.handshake_rounded,
                          color: colors.onAccent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: foreground,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: dark
                                    ? colors.onBrandMuted
                                    : colors.textSecondary,
                                fontSize: 10,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Realistic 3D Center Scene
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: accent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                          // Subtle translucent bottom gradient for depth
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.25),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Prominent Clickable Action Pill Button
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: market
                            ? [colors.warningSolid, colors.warning]
                            : [colors.brand, colors.brandStrong],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: dark ? 0.45 : 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          actionIcon,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          actionLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ],
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
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.emergency = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconBgColor = iconBgColor ??
        (emergency
            ? colors.errorSurface
            : (isDark
                ? colors.surfaceAlt.withValues(alpha: 0.16)
                : colors.surfaceAlt));
    final effectiveIconColor = iconColor ?? (emergency ? colors.error : colors.primaryGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.brandStrong.withValues(alpha: isDark ? 0.22 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: effectiveIconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.info,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
