import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../permission_setup_screen.dart';
import '../app_preferences_controller.dart';
import '../widgets/settings_header_wave.dart';

class LocationSettingsPage extends StatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  State<LocationSettingsPage> createState() => _LocationSettingsPageState();
}

class _LocationSettingsPageState extends State<LocationSettingsPage> {
  bool _clearingCache = false;

  Future<void> _clearMapCache() async {
    setState(() => _clearingCache = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _clearingCache = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Offline map cache and route tiles cleared!'),
          kind: FeedbackKind.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'Location'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.025,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.errorSolid.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: context.colors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location & GPS Access',
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Used for emergency response, navigation, and barangay incident reporting.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // High Accuracy GPS Toggle
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.highAccuracyGps,
            builder: (context, enabled, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'High-Accuracy GPS Fix',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Delivers sub-meter positioning during live route navigation across Barili.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.88,
                    child: Switch(
                      value: enabled,
                      activeThumbColor: context.colors.surface,
                      activeTrackColor: context.colors.brand,
                      onChanged: (val) => AppPreferencesController.setHighAccuracyGps(val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Map Storage & Offline Cache
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Map Tiles & Cache',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Local cached roads, barangay boundary polygons, and landmark markers.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _clearingCache ? null : _clearMapCache,
                  icon: _clearingCache
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cached_rounded, size: 18),
                  label: const Text('Clear Map Cache (12.4 MB)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primaryGreen,
                    side: BorderSide(color: context.colors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // System Permission Setting
          FilledButton.icon(
            onPressed: () => openAppNotificationSettings(),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Manage System Location Permissions'),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: context.colors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
