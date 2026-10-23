import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_preferences_controller.dart';
import '../widgets/settings_header_wave.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'Privacy'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Compliance Badge Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.purpleSurface,
                  context.colors.purpleSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.colors.purpleSolid.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: context.colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Republic Act 10173 Compliant',
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: context.colors.purple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Philippine Data Privacy Act standards strictly implemented by the Municipality of Barili.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: context.colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Community Visibility Toggle
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.communityVisibility,
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
                          'Community Profile Visibility',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Allow verified neighbors in Barili to see your resident badge on civic posts.',
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
                      onChanged: (val) => AppPreferencesController.setCommunityVisibility(val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Activity Sharing
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.activityLogging,
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
                          'Activity History Logging',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keep local log of emergency alerts and document status for quick reference.',
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
                      onChanged: (val) => AppPreferencesController.setActivityLogging(val),
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
