import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Android can round independently measured text and flex children to
// different physical pixels while the header is between its expanded and
// collapsed states. Keep this allowance in both extents so the content always
// has the same small amount of breathing room throughout the transition.
const double _homeHeaderLayoutSafety = 6;
const double _homeHeaderExpandedSafety = 4;

String? unreadNotificationBadgeLabel(int unreadCount) {
  if (unreadCount <= 0) return null;
  return unreadCount > 9 ? '9+' : '$unreadCount';
}

/// Calculates enough pinned-header space for the header's fixed controls and
/// any additional height introduced by accessibility text scaling.
double responsiveHomeHeaderExtent(
  MediaQueryData mediaQuery, {
  bool hasEyebrow = false,
}) {
  final width = mediaQuery.size.width > 0 ? mediaQuery.size.width : 390.0;
  final compact = width < 350;
  final veryNarrow = width < 280;
  final horizontalPadding = veryNarrow
      ? 10.0
      : compact
      ? 14.0
      : 16.0;
  final actionSize = veryNarrow
      ? 32.0
      : compact
      ? 36.0
      : 42.0;
  final brandEyebrow = _singleLineTextHeight(
    mediaQuery.textScaler,
    GoogleFonts.outfit(
      fontSize: veryNarrow ? 7.5 : 8.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      height: 1,
    ),
  );
  final brandTitle = _singleLineTextHeight(
    mediaQuery.textScaler,
    GoogleFonts.outfit(
      fontSize: veryNarrow
          ? 13
          : compact
          ? 15
          : 17,
      fontWeight: FontWeight.w900,
      letterSpacing: veryNarrow ? 1.1 : 1.4,
      height: 1.05,
    ),
  );
  final brandHeight = brandEyebrow + 2 + brandTitle;
  final topRowHeight = actionSize > brandHeight ? actionSize : brandHeight;
  final greetingHeight = _singleLineTextHeight(
    mediaQuery.textScaler,
    GoogleFonts.outfit(
      fontSize: compact ? 19 : 21,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      height: 1.1,
    ),
  );
  final eyebrowHeight = hasEyebrow
      ? _singleLineTextHeight(
              mediaQuery.textScaler,
              GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ) +
            3
      : 0;

  final locationHeight = _greaterOf(
    24,
    _singleLineTextHeight(
      mediaQuery.textScaler,
      GoogleFonts.outfit(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.15,
        height: 1.15,
      ),
    ),
  );
  final weatherTopLineHeight = _greaterOf(
    _singleLineTextHeight(
      mediaQuery.textScaler,
      GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
    ),
    _singleLineTextHeight(
      mediaQuery.textScaler,
      GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w600),
    ),
  );
  final weatherTextHeight =
      weatherTopLineHeight +
      _singleLineTextHeight(
        mediaQuery.textScaler,
        GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      );
  // The weather chip has 4.5px vertical padding and a 23px icon medallion.
  final weatherHeight = _greaterOf(23, weatherTextHeight) + 9;
  final contentWidth = width - (horizontalPadding * 2);
  // HomeHeaderStatusBar applies 11px padding on each side before deciding
  // whether its location and weather content must stack.
  final statusLayoutWidth = contentWidth - 22;
  final stacksStatus =
      statusLayoutWidth < 280 || mediaQuery.textScaler.scale(1) > 1.4;
  final statusHeight = stacksStatus
      ? 10 + locationHeight + 13 + weatherHeight
      : _greaterOf(44, 10 + _greaterOf(locationHeight, weatherHeight));

  // Mirrors the actual expanded header: top inset, brand row, greeting,
  // location/weather strip, lower padding, and the 24px body crown.
  final extent =
      mediaQuery.padding.top +
      6 +
      topRowHeight +
      8 +
      eyebrowHeight +
      greetingHeight +
      10 +
      statusHeight +
      6 +
      24 +
      _homeHeaderExpandedSafety;
  return extent.ceilToDouble();
}

/// Calculates the pinned height used after the home header has collapsed.
///
/// The compact state keeps the essential header actions visible while giving
/// the community bulletin substantially more vertical space.
double responsiveCompactHomeHeaderExtent(MediaQueryData mediaQuery) {
  final width = mediaQuery.size.width > 0 ? mediaQuery.size.width : 390.0;
  final compact = width < 350;
  final veryNarrow = width < 280;
  final actionSize = veryNarrow
      ? 32.0
      : compact
      ? 36.0
      : 42.0;
  final brandHeight =
      _singleLineTextHeight(
        mediaQuery.textScaler,
        GoogleFonts.outfit(
          fontSize: veryNarrow ? 7.5 : 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          height: 1,
        ),
      ) +
      2 +
      _singleLineTextHeight(
        mediaQuery.textScaler,
        GoogleFonts.outfit(
          fontSize: veryNarrow
              ? 13
              : compact
              ? 15
              : 17,
          fontWeight: FontWeight.w900,
          letterSpacing: veryNarrow ? 1.1 : 1.4,
          height: 1.05,
        ),
      );
  final extent =
      mediaQuery.padding.top +
      6 +
      _greaterOf(actionSize, brandHeight) +
      8 +
      _homeHeaderLayoutSafety;
  return extent.ceilToDouble();
}

double responsiveHomeHorizontalPadding(double width) {
  if (width <= 340) return 12;
  if (width <= 400) return 14;
  if (width > 552) return (width - 520) / 2;
  return 16;
}

double responsiveResidentBannerHeight({
  required double availableWidth,
  required TextScaler textScaler,
}) {
  final titleHeight = textScaler.scale(16) * 1.2;
  final contentHeight = 16 + titleHeight + 16 + 28;
  return _greaterOf(88.0, contentHeight);
}

double _greaterOf(double first, double second) =>
    first > second ? first : second;

double _singleLineTextHeight(TextScaler textScaler, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  return painter.height;
}

/// Responsive location/weather strip used by the pinned home header.
class HomeHeaderStatusBar extends StatelessWidget {
  final String locationLabel;
  final Widget trailing;
  final VoidCallback? onTap;

  const HomeHeaderStatusBar({
    super.key,
    required this.locationLabel,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    Widget location() => Row(
      children: [
        // 3D Illuminated Emerald Medallion for Location Pin
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF34D399), // Fresh emerald
                Color(0xFF059669), // Rich emerald
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.50),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.40),
              width: 0.9,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 13.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            locationLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: context.colors.onAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
              height: 1.15,
              shadows: [
                Shadow(
                  color: context.colors.textPrimary.withValues(alpha: 0.35),
                  offset: const Offset(0, 1.5),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.surface.withValues(alpha: 0.18),
                context.colors.surface.withValues(alpha: 0.08),
                context.colors.shadow.withValues(alpha: 0.06),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.3),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.22),
                offset: const Offset(0, 5),
                blurRadius: 14,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.14),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top Specular Refraction Sheen Bar
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                height: 1.2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.surface.withValues(alpha: 0.0),
                        context.colors.surface.withValues(alpha: 0.65),
                        context.colors.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stackContent =
                        constraints.maxWidth < 280 || textScale > 1.4;
                    if (stackContent) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          location(),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.colors.surface.withValues(alpha: 0.0),
                                  context.colors.surface.withValues(alpha: 0.25,
                                  ),
                                  context.colors.surface.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: location()),
                        // 3D Beveled Partition Groove
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 1,
                                height: 20,
                                color: context.colors.surface.withValues(alpha: 0.28,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                color: context.colors.shadow.withValues(alpha: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
