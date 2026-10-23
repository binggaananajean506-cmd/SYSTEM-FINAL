import 'package:flutter/material.dart';

export 'semantic_colors.dart';

/// Semantic color tokens shared by the mobile application.
abstract final class ESugidPalette {
  static const deepEmerald = Color(0xFF123D2E);
  static const emerald = Color(0xFF08765B);
  static const emeraldLight = Color(0xFF2D7658);
  static const pageBackground = Color(0xFFF4F8F5);
  static const surface = Colors.white;
  static const outline = Color(0xFFDCE8E1);
  static const textPrimary = Color(0xFF123127);
  static const mutedText = Color(0xFF687A71);
  static const success = Color(0xFF218B62);
  static const warning = Color(0xFFB97700);
  static const danger = Color(0xFFC73A3A);
  static const info = Color(0xFF2E74B5);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepEmerald, emerald, emeraldLight],
    stops: [0, 0.58, 1],
  );
}

/// Neutral surfaces and lightweight shadow recipes used by the shared clay UI.
/// These are intentionally blur-free at the widget level to keep scrolling
/// smooth on lower-end Android devices.
abstract final class ESugidClayColors {
  static const background = Color(0xFFEEF4F0);
  static const surface = Color(0xFFF8FBF9);
  static const surfaceHighlight = Color(0xFFFFFFFF);
  static const surfaceShade = Color(0xFFE2ECE6);
  static const outline = Color(0xFFD2E1D9);
  static const darkBackground = Color(0xFF09150F);
  static const darkSurface = Color(0xFF14251D);
}

abstract final class ESugidClay {
  static List<BoxShadow> raisedShadows({
    Color tint = ESugidPalette.deepEmerald,
    bool dark = false,
    double depth = 1,
  }) {
    if (dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 14 * depth,
          offset: Offset(5 * depth, 7 * depth),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.08),
          blurRadius: 10 * depth,
          offset: Offset(-3 * depth, -3 * depth),
        ),
      ];
    }
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.12),
        blurRadius: 18 * depth,
        offset: Offset(7 * depth, 9 * depth),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.92),
        blurRadius: 12 * depth,
        offset: Offset(-5 * depth, -5 * depth),
      ),
    ];
  }
}

abstract final class ESugidSpacing {
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double xLarge = 32;
}
