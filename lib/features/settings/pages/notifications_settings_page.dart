import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../permission_setup_screen.dart';
import '../app_preferences_controller.dart';
import '../widgets/settings_header_wave.dart';

/// Notifications Preferences page matching the top-right mockup in the user specification.
class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'Notifications'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Emergency Alerts (Always enabled)
          _NotificationRow(
            icon: Icons.warning_amber_rounded,
            iconColor: context.colors.error,
            iconBgColor: context.colors.errorSurface,
            title: 'Emergency Alerts',
            subtitle: 'Important safety information from the barangay.',
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.scale(
                  scale: 0.88,
                  child: Switch(
                    value: true,
                    onChanged: null),
                ),
                Text(
                  'Always enabled',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: context.colors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Barangay Announcements
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.barangayAnnouncements,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.campaign_rounded,
              iconColor: context.colors.primaryGreen,
              iconBgColor: isDark ? context.colors.brandStrong
                  : context.colors.surfaceAlt,
              title: 'Barangay Announcements',
              subtitle: 'Updates from the barangay officials.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setBarangayAnnouncements(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Public Advisories
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.publicAdvisories,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.description_rounded,
              iconColor: context.colors.info,
              iconBgColor: isDark ? context.colors.infoSolid
                  : context.colors.infoSurface,
              title: 'Public Advisories',
              subtitle: 'Weather, health, and other important advisories.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setPublicAdvisories(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 4. Events & Activities
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.eventsActivities,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.event_rounded,
              iconColor: context.colors.warning,
              iconBgColor: isDark ? context.colors.warningSolid
                  : context.colors.warningSurface,
              title: 'Events & Activities',
              subtitle: 'Upcoming events in the community.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setEventsActivities(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 5. Concern Updates
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.concernUpdates,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.assignment_rounded,
              iconColor: context.colors.purple,
              iconBgColor: context.colors.infoSurface,
              title: 'Concern Updates',
              subtitle: 'Status updates on your concerns.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setConcernUpdates(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 6. Complaint Updates
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.complaintUpdates,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.gavel_rounded,
              iconColor: context.colors.error,
              iconBgColor: context.colors.errorSurface,
              title: 'Complaint Updates',
              subtitle: 'Updates on your complaints.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setComplaintUpdates(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 7. Organization Updates
          ValueListenableBuilder<bool>(
            valueListenable: AppPreferencesController.organizationUpdates,
            builder: (context, value, _) => _NotificationRow(
              icon: Icons.groups_rounded,
              iconColor: context.colors.info,
              iconBgColor: context.colors.infoSurface,
              title: 'Organization Updates',
              subtitle: 'Announcements from local organizations you follow.',
              trailing: Transform.scale(
                scale: 0.88,
                child: Switch(
                  value: value,
                  activeThumbColor: context.colors.surface,
                  activeTrackColor: context.colors.brand,
                  inactiveThumbColor: isDark ? context.colors.surface.withValues(alpha: 0.7020)
                      : context.colors.surface,
                  inactiveTrackColor: context.colors.infoSurface,
                  onChanged: (val) => AppPreferencesController.setOrganizationUpdates(val),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Device System Settings Link
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
                  'Critical Emergency Alert Access',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make sure full-screen sirens and lock screen popups are permitted on your device for disaster alerts.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openAppNotificationSettings(),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('System Settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primaryGreen,
                          side: BorderSide(color: context.colors.primaryGreen, width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => openEmergencyAlertSettings(),
                        icon: const Icon(Icons.emergency_outlined, size: 16),
                        label: const Text('Siren Access'),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.brand,
                          foregroundColor: context.colors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border,
          width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.025,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: context.colors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
