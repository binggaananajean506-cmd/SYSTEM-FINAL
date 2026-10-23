import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';

/// A high-fidelity pressable wrapper that provides tactile spring feedback.
class TactileSpringButton extends StatefulWidget {
  const TactileSpringButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<TactileSpringButton> createState() => _TactileSpringButtonState();
}

class _TactileSpringButtonState extends State<TactileSpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class HubPrimaryServiceCard extends StatelessWidget {
  const HubPrimaryServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onTap,
    this.accent = ESugidPalette.emerald,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> actions;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Open $title. $subtitle',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                // Deep 3D Shadow
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: isDark ? 0.4 : 0.08,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
                // Accent Ambient Glow
                BoxShadow(
                  color: context.colors.accent(accent).withValues(alpha: 0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                // Claymorphic light source
                if (!isDark)
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.9),
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: (context.colors.surface)
                        .withValues(alpha: isDark ? 0.7 : 0.85),
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface.withValues(alpha: isDark ? 0.05 : 0.2,
                        ),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? context.colors.border.withValues(alpha: 0.1)
                          : context.colors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors
                                    .accent(accent)
                                    .withValues(alpha: isDark ? 0.25 : 0.12),
                                context.colors
                                    .accent(accent)
                                    .withValues(alpha: isDark ? 0.15 : 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors
                                    .accent(accent)
                                    .withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: context.colors
                                  .accent(accent)
                                  .withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: isDark ? context.colors.primaryGreen
                                : accent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: primaryText,
                                  fontSize: 18,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: secondaryText,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  actions.first.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: isDark
                                        ? context.colors.primaryGreen
                                        : accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.65,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent,
                                context.colors
                                    .accent(accent)
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: context.colors
                                    .accent(accent)
                                    .withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                              // Tactile highlight
                              BoxShadow(
                                color: context.colors.highlight.withValues(alpha: 0.3,
                                ),
                                blurRadius: 4,
                                offset: const Offset(-2, -2),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: context.colors.onAccent,
                            size: 22,
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
      ),
    );
  }
}

class HubActivityCard extends StatelessWidget {
  const HubActivityCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Semantics(
        button: true,
        label: 'Open My Service Activity',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: isDark ? 0.3 : 0.08,
                  ),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                if (!isDark)
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.9),
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: (context.colors.surface)
                        .withValues(alpha: isDark ? 0.7 : 0.85),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? context.colors.border.withValues(alpha: 0.1)
                          : context.colors.border,
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface.withValues(alpha: isDark ? 0.05 : 0.2,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand.withValues(alpha: 0.15),
                                context.colors.brand.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.colors.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: context.colors.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Service Activity',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your requests, offers, messages, and listings',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colors.primaryGreen,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single, unambiguous destination for the municipality's officials list.
/// It replaces the former utility grid, which duplicated Alerts functionality
/// and split closely related government information across multiple cards.
class HubMunicipalOfficialsCard extends StatelessWidget {
  const HubMunicipalOfficialsCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Semantics(
        button: true,
        label: 'Open Municipal Officials',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.primaryGreen.withValues(
                  alpha: isDark ? 0.18 : 0.12,
                ),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(
                    alpha: isDark ? 0.22 : 0.06,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Left Accent Spine
                  Positioned(
                    left: 0,
                    top: 12,
                    bottom: 12,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.colors.brandStrong,
                            context.colors.brand,
                            context.colors.brand,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: context.colors.brand.withValues(
                              alpha: isDark ? 0.20 : 0.09,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            color: context.colors.onAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Municipal Officials',
                                style: GoogleFonts.outfit(
                                  color: primaryText,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tan-awa ang mga opisyal ug ilang opisina.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colors.primaryGreen,
                          size: 22,
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

class HubShortcutCard extends StatelessWidget {
  const HubShortcutCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = ESugidPalette.emerald,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.surface, context.colors.surface],
          ),
          border: Border.all(
            color: isDark ? context.colors.border.withValues(alpha: 0.1) : context.colors.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 112),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors
                              .accent(accent)
                              .withValues(alpha: isDark ? 0.25 : 0.12),
                          context.colors
                              .accent(accent)
                              .withValues(alpha: isDark ? 0.15 : 0.06),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors
                            .accent(accent)
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isDark ? context.colors.primaryGreen : accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
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

class HubSafetyNotice extends StatelessWidget {
  const HubSafetyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brand.withValues(alpha: isDark ? 0.15 : 0.08),
            context.colors.brand.withValues(alpha: isDark ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.primaryGreen.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.brand,
                  context.colors.brand.withValues(alpha: 0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.shield_outlined,
              color: context.colors.onAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Pakigkita sa luwas nga lugar. Ayaw paghatag daan og bayad.',
              style: GoogleFonts.outfit(
                color: isDark
                    ? context.colors.onAccent
                    : context.colors.onAccent,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityLeadersCard extends StatelessWidget {
  const CommunityLeadersCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open elected government officials',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.3),
              offset: const Offset(0, 12),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [context.colors.brand, context.colors.brandStrong],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            context.colors.surface.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -40,
                    child: Icon(
                      Icons.account_balance_rounded,
                      size: 140,
                      color: context.colors.onAccent.withValues(alpha: 0.03),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 140),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface.withValues(alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: context.colors.border.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'COMMUNITY LEADERS',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Elected Government\nOfficials',
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(alpha: 0.15,
                                  ),
                                  offset: const Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: context.colors.textPrimary,
                              size: 32,
                            ),
                          ),
                        ],
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
}

class FeaturedServiceCard extends StatelessWidget {
  const FeaturedServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.color,
    required this.onTap,
    this.badge,
    this.tagline,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    final isBayanihan = title.toLowerCase().contains('bayanihan');
    final accentColor = isBayanihan
        ? context.colors.primaryGreen
        : context.colors.primaryGreen;
    final categoryBadge = isBayanihan ? 'COMMUNITY' : 'MARKET';

    return TactileSpringButton(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Open $title. $subtitle',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [context.colors.surfaceAlt, context.colors.surfaceAlt]
                    : (isBayanihan
                          ? [context.colors.surface, context.colors.surfaceAlt]
                          : [
                              context.colors.surface,
                              context.colors.surfaceAlt,
                            ]),
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.colors
                    .accent(accentColor)
                    .withValues(alpha: isDark ? 0.22 : 0.16),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors
                      .accent(accentColor)
                      .withValues(alpha: isDark ? 0.35 : 0.09),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                if (!isDark)
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.9),
                    blurRadius: 10,
                    offset: const Offset(-3, -3),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Top Accent Gradient Bar
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 0,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isBayanihan
                              ? [
                                  context.colors.brandStrong,
                                  context.colors.brand,
                                  context.colors.brand,
                                ]
                              : [
                                  context.colors.brand,
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 232),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Category Chip + Icon
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isBayanihan
                                            ? [
                                                context.colors.brandStrong,
                                                context.colors.brand,
                                              ]
                                            : [
                                                context.colors.brand,
                                                context.colors.brand,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors
                                              .accent(accentColor)
                                              .withValues(
                                            alpha: 0.32),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        icon,
                                        color: context.colors.onAccent,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors
                                          .accent(accentColor)
                                          .withValues(
                                        alpha: isDark ? 0.22 : 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      categoryBadge,
                                      style: GoogleFonts.outfit(
                                        color: isDark
                                            ? context.colors.primaryGreen
                                            : accentColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  color: primaryText,
                                  fontSize: 17.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: secondaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // High-polish Stadium Action Button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8.5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isBayanihan
                                    ? [
                                        context.colors.brand,
                                        context.colors.brand,
                                      ]
                                    : [
                                        context.colors.brand,
                                        context.colors.brand,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors
                                      .accent(accentColor)
                                      .withValues(alpha: 0.32),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  action.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: context.colors.onAccent,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
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
}

class ServiceSectionHeader extends StatelessWidget {
  const ServiceSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.colors.brandStrong, context.colors.brand],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Keeps the two primary services equal in a two-column layout, then stacks
/// them when the available width or accessibility text scale would make the
/// cards cramped.
class FeaturedServicesLayout extends StatelessWidget {
  const FeaturedServicesLayout({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackCards = constraints.maxWidth < 340 || textScale > 1.35;

        if (stackCards) {
          return Column(
            children: [primary, const SizedBox(height: 14), secondary],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: primary),
              const SizedBox(width: 14),
              Expanded(child: secondary),
            ],
          ),
        );
      },
    );
  }
}

class ServiceQuickAccessTile extends StatelessWidget {
  const ServiceQuickAccessTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = ESugidPalette.emerald,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Semantics(
        button: true,
        label: 'Open $title. $subtitle',
        child: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? context.colors.border.withValues(alpha: 0.1)
                    : context.colors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(
                    alpha: isDark ? 0.20 : 0.05,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Signature 5px Left Spine
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(color: accent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: context.colors
                                .accent(accent)
                                .withValues(
                              alpha: isDark ? 0.22 : 0.10),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: context.colors
                                  .accent(accent)
                                  .withValues(alpha: 0.18),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(icon, color: context.colors.accent(accent), size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  color: primaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colors.accent(accent),
                          size: 22,
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

class QuickAccessIconButton extends StatelessWidget {
  const QuickAccessIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = ESugidPalette.emerald,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.93,
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.surface, context.colors.surface],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.colors
                      .accent(accent)
                      .withValues(alpha: isDark ? 0.20 : 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.24 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors
                            .accent(accent)
                            .withValues(alpha: isDark ? 0.28 : 0.14),
                        context.colors
                            .accent(accent)
                            .withValues(alpha: isDark ? 0.16 : 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: context.colors
                          .accent(accent)
                          .withValues(alpha: isDark ? 0.22 : 0.12),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isDark ? context.colors.primaryGreen : accent,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: primaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAccessRow extends StatelessWidget {
  const QuickAccessRow({super.key, required this.items});

  final List<QuickAccessIconButton> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Expanded(child: item)).toList(),
    );
  }
}

class CivicQuickActionPill extends StatelessWidget {
  const CivicQuickActionPill({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        width: 154,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: context.colors
                .accent(accent)
                .withValues(alpha: isDark ? 0.25 : 0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors
                  .accent(accent)
                  .withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.colors.accent(accent), size: 20,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors
                          .accent(accent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: context.colors.accent(accent),
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: context.colors.accent(accent).withValues(alpha: 0.5),
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CivicServiceHeroCard extends StatelessWidget {
  const CivicServiceHeroCard({
    super.key,
    required this.icon,
    required this.tag,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
    this.accent = ESugidPalette.emerald,
    this.badge,
    this.trailingIcon,
  });

  final IconData icon;
  final String tag;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;
  final Color accent;
  final String? badge;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors
                .accent(accent)
                .withValues(alpha: isDark ? 0.22 : 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors
                  .accent(accent)
                  .withValues(alpha: isDark ? 0.24 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                left: 16,
                right: 16,
                top: 0,
                height: 3.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.accent(accent),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -15,
                top: -15,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.08 : 0.05),
                  ),
                  child: Icon(
                    trailingIcon ?? icon,
                    size: 68,
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.12 : 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.colors
                                .accent(accent)
                                .withValues(
                              alpha: isDark ? 0.22 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.colors
                                  .accent(accent)
                                  .withValues(alpha: 0.20),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, color: context.colors.accent(accent), size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tag.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: context.colors.accent(accent),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  color: primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors
                                  .accent(accent)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.accent(accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: secondaryText,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          actionLabel,
                          style: GoogleFonts.outfit(
                            color: context.colors.accent(accent),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: context.colors
                                .accent(accent)
                                .withValues(
                              alpha: isDark ? 0.20 : 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: context.colors.accent(accent),
                            size: 15,
                          ),
                        ),
                      ],
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
}

class CivicDualCard extends StatelessWidget {
  const CivicDualCard({
    super.key,
    required this.icon,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String tag;
  final String title;
  final String subtitle;
  final String action;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors
                .accent(accent)
                .withValues(alpha: isDark ? 0.22 : 0.14),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors
                  .accent(accent)
                  .withValues(alpha: isDark ? 0.20 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: context.colors
                          .accent(accent)
                          .withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: context.colors.accent(accent), size: 22,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: context.colors.accent(accent),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: secondaryText,
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  action,
                  style: GoogleFonts.outfit(
                    color: context.colors.accent(accent),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: context.colors.accent(accent), size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CivicUtilityGridCard extends StatelessWidget {
  const CivicUtilityGridCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? context.colors.border.withValues(alpha: 0.08)
                : context.colors.border.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(
                alpha: isDark ? 0.18 : 0.04,
              ),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors
                    .accent(accent)
                    .withValues(alpha: isDark ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.colors.accent(accent), size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.accent(accent).withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class EmergencyHotlineBanner extends StatelessWidget {
  const EmergencyHotlineBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.errorSurface, context.colors.errorSurface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.error.withValues(alpha: isDark ? 0.35 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.errorSolid.withValues(alpha: isDark ? 0.22 : 0.08,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.colors.errorSolid.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.error.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.emergency_rounded,
                color: context.colors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: context.colors.errorSolid,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '24/7 EMERGENCY HOTLINES',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: context.colors.error,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Need Urgent Response?',
                    style: GoogleFonts.outfit(
                      color: context.colors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Barili Police, BFP Fire & MDRRMO Rescue are on standby.',
                    style: GoogleFonts.outfit(
                      color: context.colors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.errorSolid,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.errorSolid.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_rounded, color: context.colors.onAccent, size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Call',
                    style: GoogleFonts.outfit(
                      color: context.colors.onAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DirectServiceCard extends StatelessWidget {
  const DirectServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = context.colors.textPrimary;
    final secondaryText = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.16 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.22 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: context.colors
                          .accent(accent)
                          .withValues(alpha: isDark ? 0.35 : 0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: context.colors.accent(accent), size: 22,
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.colors
                        .accent(accent)
                        .withValues(alpha: isDark ? 0.18 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: context.colors.accent(accent),
                    size: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: primaryText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: secondaryText,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CivicOfficialsHeroBanner extends StatelessWidget {
  const CivicOfficialsHeroBanner({
    super.key,
    required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.brandStrong,
              context.colors.brand,
              context.colors.brand,
                  ],
          ),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: isDark ? 0.40 : 0.28,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -20,
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 130,
                  color: context.colors.onAccent.withValues(alpha: 0.05),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.surface.withValues(alpha: 0.0),
                        context.colors.surface.withValues(alpha: 0.5),
                        context.colors.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.warningSolid,
                            context.colors.warningSolid,
                          ],
                        ),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.warningSolid.withValues(alpha: 0.45,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.account_balance_rounded,
                          color: context.colors.onAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.shadow.withValues(alpha: 0.20,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: context.colors.border.withValues(alpha: 0.5,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'BARILI OFFICIALS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.warning,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Municipal Officials',
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.12,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: context.colors.onAccent,
                            size: 14,
                          ),
                        ],
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
}

class PrioritizedCommunityCard extends StatelessWidget {
  const PrioritizedCommunityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.actionLabel,
    required this.primaryGradient,
    required this.accentColor,
    required this.watermarkIcon,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String actionLabel;
  final List<Color> primaryGradient;
  final Color accentColor;
  final IconData watermarkIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = context.colors.surface;
    final primaryTextColor = context.colors.textPrimary;
    final secondaryTextColor = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? context.colors.accent(accentColor).withValues(alpha: 0.30)
                : context.colors.border,
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors
                  .accent(accentColor)
                  .withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.30 : 0.04,
              ),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors
                            .accent(accentColor)
                            .withValues(alpha: isDark ? 0.12 : 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -10,
                bottom: -15,
                child: Icon(
                  watermarkIcon,
                  size: 85,
                  color: context.colors
                      .accent(accentColor)
                      .withValues(alpha: isDark ? 0.07 : 0.04),
                ),
              ),
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                height: 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.surface.withValues(alpha: 0.0),
                        context.colors.surface.withValues(alpha: isDark ? 0.4 : 0.9,
                        ),
                        context.colors.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: primaryGradient
                                  .map(context.colors.solid)
                                  .toList(growable: false),
                            ),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.45,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryGradient.last.withValues(alpha: 0.45,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.15,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              icon,
                              color: context.colors.onAccent,
                              size: 24,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors
                                .accent(accentColor)
                                .withValues(
                              alpha: isDark ? 0.22 : 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colors
                                  .accent(accentColor)
                                  .withValues(
                                alpha: isDark ? 0.40 : 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.accent(accentColor),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: primaryTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: secondaryTextColor,
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors
                            .accent(accentColor)
                            .withValues(
                          alpha: isDark ? 0.25 : 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.colors
                              .accent(accentColor)
                              .withValues(
                            alpha: isDark ? 0.35 : 0.20),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.accent(accentColor),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: context.colors.accent(accentColor),
                          ),
                        ],
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
}

class ElevatedUtilityCard extends StatelessWidget {
  const ElevatedUtilityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = context.colors.surface;
    final primaryTextColor = context.colors.textPrimary;
    final secondaryTextColor = context.colors.textSecondary;

    return TactileSpringButton(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors
                  .accent(accent)
                  .withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.03,
              ),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient.last.withValues(alpha: 0.40),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: context.colors.onAccent, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: GoogleFonts.outfit(
                        color: primaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: secondaryTextColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.accent(accent).withValues(alpha: 0.8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
