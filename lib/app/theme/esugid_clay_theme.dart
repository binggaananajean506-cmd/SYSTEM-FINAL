import 'package:flutter/material.dart';

import '../../app_motion.dart';
import 'app_colors.dart';

/// Builds the shared E-SUGID claymorphism theme.
///
/// The theme deliberately stays close to the existing green-and-white visual
/// identity. Depth comes from rounded geometry, restrained elevation, and
/// layered surface colors rather than expensive blur filters.
ThemeData buildESugidClayTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? ESugidColors.dark : ESugidColors.light;
  final primary = colors.primaryGreen;
  final secondary = colors.success;
  final background = colors.background;
  final surface = colors.surface;
  final outline = colors.border;
  final onSurface = colors.textPrimary;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: ESugidPalette.emerald,
        brightness: brightness,
        primary: primary,
        onPrimary: colors.onPrimary,
        secondary: secondary,
        onSecondary: colors.onPrimary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: colors.textSecondary,
        outline: outline,
        error: colors.error,
        onError: isDark ? colors.brandStrong : colors.onAccent,
      ).copyWith(
        surfaceContainerLowest: colors.background,
        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.surface,
        surfaceContainerHigh: colors.surfaceAlt,
        surfaceContainerHighest: colors.surfaceAlt,
        outlineVariant: colors.border,
        primaryContainer: colors.successSurface,
        onPrimaryContainer: colors.primaryGreen,
        secondaryContainer: colors.selected,
        onSecondaryContainer: colors.textPrimary,
        errorContainer: colors.errorSurface,
        onErrorContainer: colors.error,
      );

  const rounded16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  const rounded20 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  const rounded24 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [colors],
    disabledColor: colors.disabled,
    hintColor: colors.textSecondary,
    focusColor: primary.withValues(alpha: .22),
    hoverColor: colors.hover,
    highlightColor: colors.highlight.withValues(alpha: .10),
    iconTheme: IconThemeData(color: colors.textSecondary),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: 'Poppins',
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: .30),
      selectionHandleColor: primary,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: background,
    canvasColor: background,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ESugidPageTransitionsBuilder(),
        TargetPlatform.iOS: ESugidPageTransitionsBuilder(),
        TargetPlatform.macOS: ESugidPageTransitionsBuilder(),
        TargetPlatform.windows: ESugidPageTransitionsBuilder(),
        TargetPlatform.linux: ESugidPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ESugidPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: isDark ? scheme.onSurface : ESugidPalette.deepEmerald,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: isDark ? scheme.onSurface : ESugidPalette.deepEmerald,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: isDark ? 2 : 4,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
      surfaceTintColor: Colors.transparent,
      color: surface,
      margin: EdgeInsets.zero,
      shape: rounded24.copyWith(side: BorderSide(color: outline, width: 1)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 7,
        shadowColor: primary.withValues(alpha: 0.34),
        surfaceTintColor: Colors.transparent,
        backgroundColor: primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        disabledForegroundColor: colors.disabled,
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
        shape: rounded16,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 6,
        shadowColor: primary.withValues(alpha: 0.32),
        backgroundColor: primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.disabledBackground,
        disabledForegroundColor: colors.disabled,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: rounded16,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: isDark ? 1 : 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
        surfaceTintColor: Colors.transparent,
        backgroundColor: surface,
        foregroundColor: primary,
        disabledForegroundColor: colors.disabled,
        side: BorderSide(color: primary.withValues(alpha: 0.28), width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: rounded16,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: colors.disabled,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: rounded16,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: colors.disabled,
        backgroundColor: surface.withValues(alpha: isDark ? 0.82 : 0.94),
        highlightColor: primary.withValues(alpha: 0.12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 8,
      highlightElevation: 4,
      backgroundColor: primary,
      foregroundColor: colors.onPrimary,
      splashColor: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0x66FFFFFF), width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: primary,
      suffixIconColor: colors.textSecondary,
      labelStyle: TextStyle(color: colors.textSecondary),
      hintStyle: TextStyle(color: colors.textSecondary),
      helperStyle: TextStyle(color: colors.textSecondary),
      errorStyle: TextStyle(color: colors.error),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(17)),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      backgroundColor: surface,
      shape: rounded24,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 18,
      modalElevation: 20,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      backgroundColor: surface,
      modalBackgroundColor: surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.surface,
      contentTextStyle: TextStyle(
        color: colors.textPrimary,
        fontFamily: 'Poppins',
        fontSize: 14,
        height: 1.4,
      ),
      closeIconColor: colors.textSecondary,
      shape: rounded16.copyWith(side: BorderSide(color: colors.border)),
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      dismissDirection: DismissDirection.horizontal,
      actionTextColor: colors.primaryGreen,
    ),
    chipTheme: ChipThemeData(
      elevation: isDark ? 1 : 3,
      pressElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      backgroundColor: surface,
      selectedColor: primary.withValues(alpha: isDark ? 0.28 : 0.14),
      side: BorderSide(color: outline),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: outline.withValues(alpha: 0.8),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      textColor: scheme.onSurface,
      shape: rounded20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    popupMenuTheme: PopupMenuThemeData(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      color: surface,
      textStyle: TextStyle(color: colors.textPrimary),
      shape: rounded20,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: colors.textSecondary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.selected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? primary
              : colors.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primary
              : colors.textSecondary,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: colors.textSecondary,
      indicatorColor: primary,
      dividerColor: outline,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: colors.textPrimary),
      menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surface)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(colors.surfaceAlt),
      dataRowColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.selected
            : states.contains(WidgetState.hovered)
            ? colors.hover
            : surface,
      ),
      headingTextStyle: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      dataTextStyle: TextStyle(color: colors.textPrimary),
      dividerThickness: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.brandStrong,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: colors.onAccent),
    ),
  );
}
