import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme/app_colors.dart';

export '../app/theme/app_colors.dart';

const esugidHeaderSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Shared geometry for the authenticated E-SUGID page shell.
///
/// The green identity area is deliberately square. The page surface below it
/// owns the curve, matching the visual hierarchy used by the resident hub.
const double esugidBodyTopRadius = 28;
const double esugidBodyCrownHeight = 24;
const BorderRadius esugidBodyBorderRadius = BorderRadius.vertical(
  top: Radius.circular(esugidBodyTopRadius),
);

/// Retained for custom headers that share the same identity surface.
/// The header is now square; rounding belongs to [ESugidBodyCrown].
const double esugidHeaderBottomRadius = 0;
const BorderRadius esugidHeaderBorderRadius = BorderRadius.zero;
const RoundedRectangleBorder esugidHeaderShape = RoundedRectangleBorder();

double responsiveESugidPageHeaderExtent(
  MediaQueryData mediaQuery, {
  bool hasSubtitle = false,
  bool hasSectionLabel = false,
}) {
  final textScale = mediaQuery.textScaler.scale(1);
  final accessibilityAllowance = ((textScale - 1).clamp(0.0, 1.5) * 54);
  // All sliver headers collapse over the same physical scroll distance. This
  // prevents pages with/without supporting text from feeling like different
  // components. The extra allowance is based only on the device text scale,
  // so it remains consistent throughout the app for a given user.
  return responsiveCompactESugidPageHeaderExtent(mediaQuery) +
      esugidHeaderCollapseDistance +
      accessibilityAllowance;
}

const double esugidHeaderCollapseDistance = 92;

double responsiveCompactESugidPageHeaderExtent(MediaQueryData mediaQuery) {
  final textScale = mediaQuery.textScaler.scale(1);
  final accessibilityAllowance = ((textScale - 1).clamp(0.0, 1.5) * 18);
  return mediaQuery.padding.top + 58 + accessibilityAllowance;
}

/// The standard page identity used across authenticated E-SUGID screens.
///
/// [collapseProgress] is driven by [ESugidSliverPageHeader]. At rest, the
/// supporting information and rounded body crown are visible. As content
/// scrolls, those elements recede and the title remains in a compact toolbar.
class ESugidPageHeader extends StatelessWidget {
  const ESugidPageHeader({
    super.key,
    required this.title,
    this.sectionLabel,
    this.sectionLabelWidget,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.showBackButton = false,
    this.onBack,
    this.trailing,
    this.endPadding = 12,
    this.collapseProgress = 0,
    this.showBodyCrown = true,
    this.bodyColor,
    this.expandToConstraints = false,
  });

  final String title;
  final String? sectionLabel;
  final Widget? sectionLabelWidget;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double endPadding;
  final double collapseProgress;
  final bool showBodyCrown;

  /// Matches the curved edge to pages with a distinct body surface.
  final Color? bodyColor;

  /// Used by a sliver delegate, where the header receives a tight height.
  final bool expandToConstraints;

  @override
  Widget build(BuildContext context) {
    final progress = collapseProgress.clamp(0.0, 1.0);
    final expandedOpacity = 1 - progress;
    final crownHeight = showBodyCrown
        ? ui.lerpDouble(esugidBodyCrownHeight, 0, progress)!
        : 0.0;
    final headerContent = _HeaderContent(
      title: title,
      sectionLabel: sectionLabel,
      sectionLabelWidget: sectionLabelWidget,
      subtitle: subtitle,
      icon: icon,
      iconWidget: iconWidget,
      showBackButton: showBackButton,
      onBack: onBack,
      trailing: trailing,
      endPadding: endPadding,
      progress: progress,
      expandedOpacity: expandedOpacity,
    );

    final header = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brandStrong,
            context.colors.brandStrong,
            context.colors.brand,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 1. Top Specular Crystal Rim Light (simulating curved glass refraction)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.surface.withValues(alpha: 0.0),
                    context.colors.surface.withValues(alpha: 0.45),
                    context.colors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 2. Ambient Volumetric 3D Light Orbs matching Home Dashboard
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.warningSolid.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.brand.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 3. Embossed Municipal Watermark
          Positioned(
            top: -15,
            right: 15,
            child: Opacity(
              opacity: 0.06 * expandedOpacity,
              child: Image.asset(
                'assets/images/resident_dashboard/pinakafinal.png',
                width: 170,
                fit: BoxFit.contain,
                color: context.colors.surface,
              ),
            ),
          ),
          Column(
            mainAxisSize: expandToConstraints
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (expandToConstraints)
                Expanded(child: headerContent)
              else
                headerContent,
              ESugidBodyCrown(
                height: crownHeight,
                opacity: expandedOpacity,
                color: bodyColor,
              ),
            ],
          ),
        ],
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: esugidHeaderSystemUiOverlayStyle,
      child: header,
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.title,
    required this.sectionLabel,
    this.sectionLabelWidget,
    required this.subtitle,
    required this.icon,
    this.iconWidget,
    required this.showBackButton,
    required this.onBack,
    required this.trailing,
    required this.endPadding,
    required this.progress,
    required this.expandedOpacity,
  });

  final String title;
  final String? sectionLabel;
  final Widget? sectionLabelWidget;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double endPadding;
  final double progress;
  final double expandedOpacity;

  @override
  Widget build(BuildContext context) {
    final verticalPadding = ui.lerpDouble(14, 8, progress)!;
    final topPadding = ui.lerpDouble(endPadding, 8, progress)!;
    final titleSize = ui.lerpDouble(21, 17, progress)!;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          showBackButton ? 8 : 18,
          topPadding,
          endPadding,
          verticalPadding,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showIcon =
                (icon != null || iconWidget != null) &&
                !(showBackButton && trailing != null) &&
                !(trailing != null && constraints.maxWidth < 360);
            return Row(
              children: [
                if (showBackButton) ...[
                  _HeaderAction(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 6),
                ],
                if (showIcon)
                  ClipRect(
                    child: Align(
                      widthFactor: expandedOpacity,
                      child: Opacity(
                        opacity: expandedOpacity,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.surface.withValues(alpha: 0.22,
                                  ),
                                  context.colors.surface.withValues(alpha: 0.10,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.38,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(alpha: 0.18,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child:
                                  iconWidget ??
                                  Icon(icon, color: context.colors.onAccent, size: 21,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sectionLabelWidget != null)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topLeft,
                            heightFactor: expandedOpacity,
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: sectionLabelWidget!,
                              ),
                            ),
                          ),
                        )
                      else if (sectionLabel != null)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topLeft,
                            heightFactor: expandedOpacity,
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  sectionLabel!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent.withValues(alpha: 0.68,
                                    ),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.45,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Text(
                        title,
                        maxLines: progress > 0.55 ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: titleSize,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topLeft,
                            heightFactor: expandedOpacity,
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent.withValues(alpha: 0.76,
                                    ),
                                    fontSize: 11,
                                    height: 1.3,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: trailing!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rounded leading edge of the page body. It sits within the green header so
/// the outside corners reveal the identity color rather than empty canvas.
class ESugidBodyCrown extends StatelessWidget {
  const ESugidBodyCrown({
    super.key,
    this.height = esugidBodyCrownHeight,
    this.opacity = 1,
    this.color,
  });

  final double height;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (height <= 0) return const SizedBox.shrink();
    // The curved edge is part of the page canvas, not an elevated panel.
    // Honor an enclosing page's override in either theme to avoid a seam.
    final surface = color ??
        Scaffold.maybeOf(context)?.widget.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: esugidBodyBorderRadius,
        ),
      ),
    );
  }
}

/// A pinned, scroll-aware version of [ESugidPageHeader].
///
/// The expanded supporting text and curved body edge scroll away, while a
/// compact title bar remains visible so users retain page context.
class ESugidSliverPageHeader extends StatelessWidget {
  const ESugidSliverPageHeader({
    super.key,
    required this.title,
    this.sectionLabel,
    this.sectionLabelWidget,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.showBackButton = false,
    this.onBack,
    this.trailing,
    this.endPadding = 12,
    this.pinned = true,
    this.bodyColor,
  });

  final String title;
  final String? sectionLabel;
  final Widget? sectionLabelWidget;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double endPadding;
  final bool pinned;
  final Color? bodyColor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQueryData(
      padding: MediaQuery.paddingOf(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    return SliverPersistentHeader(
      pinned: pinned,
      delegate: _ESugidPageHeaderDelegate(
        minHeight: responsiveCompactESugidPageHeaderExtent(mediaQuery),
        maxHeight: responsiveESugidPageHeaderExtent(
          mediaQuery,
          hasSubtitle: subtitle != null,
          hasSectionLabel: sectionLabel != null || sectionLabelWidget != null,
        ),
        title: title,
        sectionLabel: sectionLabel,
        sectionLabelWidget: sectionLabelWidget,
        subtitle: subtitle,
        icon: icon,
        iconWidget: iconWidget,
        showBackButton: showBackButton,
        onBack: onBack,
        trailing: trailing,
        endPadding: endPadding,
        bodyColor: bodyColor,
      ),
    );
  }
}

class _ESugidPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ESugidPageHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.title,
    required this.sectionLabel,
    this.sectionLabelWidget,
    required this.subtitle,
    required this.icon,
    this.iconWidget,
    required this.showBackButton,
    required this.onBack,
    required this.trailing,
    required this.endPadding,
    required this.bodyColor,
  });

  final double minHeight;
  final double maxHeight;
  final Color? bodyColor;
  final String title;
  final String? sectionLabel;
  final Widget? sectionLabelWidget;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double endPadding;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final rawProgress = range == 0
        ? 1.0
        : (shrinkOffset / range).clamp(0.0, 1.0);
    final progress = Curves.easeOutCubic.transform(rawProgress);
    return Material(
      color: Colors.transparent,
      elevation: overlapsContent && progress > 0.9 ? 3 : 0,
      shadowColor: context.colors.shadow.withValues(alpha: 0.18),
      child: SizedBox.expand(
        child: ESugidPageHeader(
          title: title,
          sectionLabel: sectionLabel,
          sectionLabelWidget: sectionLabelWidget,
          subtitle: subtitle,
          icon: icon,
          iconWidget: iconWidget,
          showBackButton: showBackButton,
          onBack: onBack,
          trailing: trailing,
          endPadding: endPadding,
          collapseProgress: progress,
          expandToConstraints: true,
          bodyColor: bodyColor,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ESugidPageHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        title != oldDelegate.title ||
        sectionLabel != oldDelegate.sectionLabel ||
        subtitle != oldDelegate.subtitle ||
        icon != oldDelegate.icon ||
        iconWidget != oldDelegate.iconWidget ||
        showBackButton != oldDelegate.showBackButton ||
        onBack != oldDelegate.onBack ||
        trailing != oldDelegate.trailing ||
        endPadding != oldDelegate.endPadding ||
        bodyColor != oldDelegate.bodyColor;
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surface.withValues(alpha: 0.22),
                  context.colors.surface.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: context.colors.onAccent, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// A detached segmented control for two or more page-level destinations.
class ESugidFloatingTabBar extends StatelessWidget {
  const ESugidFloatingTabBar({super.key, required this.tabs, this.controller});

  final List<Widget> tabs;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.colors.surface;

    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.colors.border),
        boxShadow: ESugidClay.raisedShadows(
          tint: context.colors.brand,
          dark: isDark,
          depth: 0.55,
        ),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(999),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.brand, context.colors.brand],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.16),
              blurRadius: 3,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        labelColor: context.colors.onAccent,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: tabs,
      ),
    );
  }
}
