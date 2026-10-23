import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app_theme_controller.dart';
import '../app_preferences_controller.dart';
import '../widgets/settings_header_wave.dart';

/// App Preferences page matching the bottom-right mockup in the user specification.
class AppPreferencesPage extends StatelessWidget {
  const AppPreferencesPage({super.key});

  Future<void> _setTheme(BuildContext context, ThemeMode mode) async {
    try {
      await AppThemeController.setMode(mode);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'Could not save appearance. Your choice applies until the app closes.',
          ),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'App Preferences'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Theme Section
          _PreferenceSectionCard(
            icon: Icons.dark_mode_rounded,
            iconColor: context.colors.primaryGreen,
            title: 'Theme',
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: AppThemeController.mode,
              builder: (context, currentMode, _) {
                return LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in const {
                        ThemeMode.light: 'Light',
                        ThemeMode.dark: 'Dark',
                        ThemeMode.system: 'System Default',
                      }.entries)
                        SizedBox(
                          width: constraints.maxWidth < 430
                              ? (constraints.maxWidth - 10) / 2
                              : (constraints.maxWidth - 20) / 3,
                          child: _ChoicePill(
                            label: option.value,
                            isSelected: currentMode == option.key,
                            onTap: () => _setTheme(context, option.key),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 3. Text Size Section
          _PreferenceSectionCard(
            icon: Icons.format_size_rounded,
            iconColor: context.colors.primaryGreen,
            title: 'Text Size',
            child: ValueListenableBuilder<String>(
              valueListenable: AppPreferencesController.textSize,
              builder: (context, currentSize, _) {
                return Row(
                  children: [
                    Expanded(
                      child: _ChoicePill(
                        label: 'Small',
                        isSelected: currentSize == 'small',
                        onTap: () =>
                            AppPreferencesController.setTextSize('small'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Default',
                        isSelected: currentSize == 'default',
                        onTap: () =>
                            AppPreferencesController.setTextSize('default'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoicePill(
                        label: 'Large',
                        isSelected: currentSize == 'large',
                        onTap: () =>
                            AppPreferencesController.setTextSize('large'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // Informational note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: context.colors.primaryGreen,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preferences are synced locally on your device for immediate access and responsiveness throughout Barili civic services.',
                    // Re-layout this wrapped paragraph when appearance changes.
                    key: ValueKey(Theme.of(context).brightness),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSectionCard extends StatelessWidget {
  const _PreferenceSectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(
              alpha: isDark ? 0.2 : 0.025,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.colors.primaryGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.brand
                  : (context.colors.surfaceAlt),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? context.colors.primaryGreen
                    : (context.colors.border),
                width: 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? context.colors.onAccent
                          : (context.colors.textSecondary),
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: context.colors.onAccent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
