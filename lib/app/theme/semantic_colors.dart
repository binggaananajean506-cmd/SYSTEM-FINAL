import 'package:flutter/material.dart';

/// Semantic application colors. Pair status foregrounds with their surfaces,
/// and onAccent with solid brand and status backgrounds.
@immutable
class ESugidColors extends ThemeExtension<ESugidColors> {
  const ESugidColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.inputBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.primaryGreen,
    required this.onPrimary,
    required this.brand,
    required this.brandStrong,
    required this.brandAlt,
    required this.onAccent,
    required this.onBrandMuted,
    required this.disabled,
    required this.disabledBackground,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.purple,
    required this.successSurface,
    required this.warningSurface,
    required this.errorSurface,
    required this.infoSurface,
    required this.purpleSurface,
    required this.successSolid,
    required this.warningSolid,
    required this.errorSolid,
    required this.infoSolid,
    required this.purpleSolid,
    required this.hover,
    required this.selected,
    required this.highlight,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color inputBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color primaryGreen;
  final Color onPrimary;
  final Color brand;
  final Color brandStrong;
  final Color brandAlt;
  final Color onAccent;
  final Color onBrandMuted;
  final Color disabled;
  final Color disabledBackground;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color purple;
  final Color successSurface;
  final Color warningSurface;
  final Color errorSurface;
  final Color infoSurface;
  final Color purpleSurface;
  final Color successSolid;
  final Color warningSolid;
  final Color errorSolid;
  final Color infoSolid;
  final Color purpleSolid;
  final Color hover;
  final Color selected;
  final Color highlight;
  final Color shadow;

  static const light = ESugidColors(
    background: Color(0xFFEEF4F0),
    surface: Color(0xFFF8FBF9),
    surfaceAlt: Color(0xFFE7F0EB),
    inputBackground: Color(0xFFF9FCFA),
    textPrimary: Color(0xFF123127),
    textSecondary: Color(0xFF52675C),
    border: Color(0xFFC2D4C9),
    primaryGreen: Color(0xFF066B51),
    onPrimary: Color(0xFFFFFFFF),
    brand: Color(0xFF08765B),
    brandStrong: Color(0xFF123D2E),
    brandAlt: Color(0xFF2D7658),
    onAccent: Color(0xFFFFFFFF),
    onBrandMuted: Color(0xFFE3F5EC),
    disabled: Color(0xFF566A5D),
    disabledBackground: Color(0xFFDCE7DF),
    success: Color(0xFF147451),
    warning: Color(0xFF865800),
    error: Color(0xFFB33038),
    info: Color(0xFF23649A),
    purple: Color(0xFF6C4BA6),
    successSurface: Color(0xFFE1F3E8),
    warningSurface: Color(0xFFFFF3D5),
    errorSurface: Color(0xFFFBE9E9),
    infoSurface: Color(0xFFE8F2FD),
    purpleSurface: Color(0xFFEEE7F9),
    successSolid: Color(0xFF147451),
    warningSolid: Color(0xFF865800),
    errorSolid: Color(0xFFB33038),
    infoSolid: Color(0xFF23649A),
    purpleSolid: Color(0xFF6C4BA6),
    hover: Color(0xFFDDEDE3),
    selected: Color(0xFFD7EFE1),
    highlight: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
  );

  static const dark = ESugidColors(
    background: Color(0xFF101E19),
    surface: Color(0xFF192C24),
    surfaceAlt: Color(0xFF20382D),
    inputBackground: Color(0xFF14271F),
    textPrimary: Color(0xFFECF5EF),
    textSecondary: Color(0xFFB3C8BC),
    border: Color(0xFF456354),
    primaryGreen: Color(0xFF73D7AD),
    onPrimary: Color(0xFF06271D),
    brand: Color(0xFF0B6249),
    brandStrong: Color(0xFF07382A),
    brandAlt: Color(0xFF125A42),
    onAccent: Color(0xFFF5FFF9),
    onBrandMuted: Color(0xFFC9E6DA),
    disabled: Color(0xFFA0B4A7),
    disabledBackground: Color(0xFF2B3C33),
    success: Color(0xFF79E1B2),
    warning: Color(0xFFF5CF80),
    error: Color(0xFFFFB0B6),
    info: Color(0xFFA4CEFF),
    purple: Color(0xFFD1B9FF),
    successSurface: Color(0xFF203B2E),
    warningSurface: Color(0xFF40351F),
    errorSurface: Color(0xFF422A2E),
    infoSurface: Color(0xFF233749),
    purpleSurface: Color(0xFF352E49),
    successSolid: Color(0xFF0B6249),
    warningSolid: Color(0xFF805300),
    errorSolid: Color(0xFFA42C39),
    infoSolid: Color(0xFF245C91),
    purpleSolid: Color(0xFF624491),
    hover: Color(0xFF2C493A),
    selected: Color(0xFF284D3B),
    highlight: Color(0xFFB3DCC4),
    shadow: Color(0xFF000000),
  );

  /// Data-owned category and organization colors retain their hue, with a
  /// readable foreground from the same application palette in either theme.
  Color accent(Color source) {
    if ([
      primaryGreen,
      success,
      warning,
      error,
      info,
      purple,
      textPrimary,
      textSecondary,
    ].contains(source)) {
      return source;
    }
    final hsv = HSVColor.fromColor(source);
    if (hsv.saturation < .16) return textSecondary;
    final hue = hsv.hue;
    return hue < 25 || hue >= 335
        ? error
        : hue < 75
        ? warning
        : hue < 190
        ? primaryGreen
        : hue < 255
        ? info
        : purple;
  }

  Color solid(Color source) {
    if ([
      brand,
      brandStrong,
      brandAlt,
      successSolid,
      warningSolid,
      errorSolid,
      infoSolid,
      purpleSolid,
    ].contains(source)) {
      return source;
    }
    final hsv = HSVColor.fromColor(source);
    if (hsv.saturation < .16) return brandStrong;
    final hue = hsv.hue;
    return hue < 25 || hue >= 335
        ? errorSolid
        : hue < 75
        ? warningSolid
        : hue < 190
        ? brand
        : hue < 255
        ? infoSolid
        : purpleSolid;
  }

  @override
  ESugidColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? inputBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? primaryGreen,
    Color? onPrimary,
    Color? brand,
    Color? brandStrong,
    Color? brandAlt,
    Color? onAccent,
    Color? onBrandMuted,
    Color? disabled,
    Color? disabledBackground,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? purple,
    Color? successSurface,
    Color? warningSurface,
    Color? errorSurface,
    Color? infoSurface,
    Color? purpleSurface,
    Color? successSolid,
    Color? warningSolid,
    Color? errorSolid,
    Color? infoSolid,
    Color? purpleSolid,
    Color? hover,
    Color? selected,
    Color? highlight,
    Color? shadow,
  }) => ESugidColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    inputBackground: inputBackground ?? this.inputBackground,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    primaryGreen: primaryGreen ?? this.primaryGreen,
    onPrimary: onPrimary ?? this.onPrimary,
    brand: brand ?? this.brand,
    brandStrong: brandStrong ?? this.brandStrong,
    brandAlt: brandAlt ?? this.brandAlt,
    onAccent: onAccent ?? this.onAccent,
    onBrandMuted: onBrandMuted ?? this.onBrandMuted,
    disabled: disabled ?? this.disabled,
    disabledBackground: disabledBackground ?? this.disabledBackground,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    info: info ?? this.info,
    purple: purple ?? this.purple,
    successSurface: successSurface ?? this.successSurface,
    warningSurface: warningSurface ?? this.warningSurface,
    errorSurface: errorSurface ?? this.errorSurface,
    infoSurface: infoSurface ?? this.infoSurface,
    purpleSurface: purpleSurface ?? this.purpleSurface,
    successSolid: successSolid ?? this.successSolid,
    warningSolid: warningSolid ?? this.warningSolid,
    errorSolid: errorSolid ?? this.errorSolid,
    infoSolid: infoSolid ?? this.infoSolid,
    purpleSolid: purpleSolid ?? this.purpleSolid,
    hover: hover ?? this.hover,
    selected: selected ?? this.selected,
    highlight: highlight ?? this.highlight,
    shadow: shadow ?? this.shadow,
  );

  @override
  ESugidColors lerp(covariant ESugidColors? other, double t) {
    if (other == null) return this;
    return ESugidColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      primaryGreen: Color.lerp(primaryGreen, other.primaryGreen, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandAlt: Color.lerp(brandAlt, other.brandAlt, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onBrandMuted: Color.lerp(onBrandMuted, other.onBrandMuted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      disabledBackground: Color.lerp(
        disabledBackground,
        other.disabledBackground,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      purpleSurface: Color.lerp(purpleSurface, other.purpleSurface, t)!,
      successSolid: Color.lerp(successSolid, other.successSolid, t)!,
      warningSolid: Color.lerp(warningSolid, other.warningSolid, t)!,
      errorSolid: Color.lerp(errorSolid, other.errorSolid, t)!,
      infoSolid: Color.lerp(infoSolid, other.infoSolid, t)!,
      purpleSolid: Color.lerp(purpleSolid, other.purpleSolid, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension ESugidThemeContext on BuildContext {
  ESugidColors get colors =>
      Theme.of(this).extension<ESugidColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? ESugidColors.dark
          : ESugidColors.light);
}
