import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../session_service.dart';
import '../widgets/settings_header_wave.dart';
import 'about_app_page.dart';
import 'account_security_page.dart';
import 'app_preferences_page.dart';
import 'help_support_page.dart';
import 'location_settings_page.dart';
import 'notifications_settings_page.dart';
import 'privacy_settings_page.dart';

/// Standalone Settings page matching the left mockup in the user specification.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'Settings'),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: SettingsCardsList(),
      ),
    );
  }
}

/// Reusable list of the 7 settings cards + Log Out button.
class SettingsCardsList extends StatefulWidget {
  const SettingsCardsList({super.key});

  @override
  State<SettingsCardsList> createState() => _SettingsCardsListState();
}

class _SettingsCardsListState extends State<SettingsCardsList> {
  bool _isLoggingOut = false;
  bool _logoutConfirmationOpen = false;

  Future<void> _confirmLogout() async {
    if (_isLoggingOut || _logoutConfirmationOpen) return;
    _logoutConfirmationOpen = true;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final colors = Theme.of(modalContext).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: modalContext.colors.errorSolid.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: modalContext.colors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Log out of E-SUGID?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to sign out? You will need your credentials to sign back in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(modalContext, true),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: modalContext.colors.errorSolid,
                        foregroundColor: modalContext.colors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => _logoutConfirmationOpen = false);

    if (confirmed != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      await SessionService.logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(AppSnackBar(
          content: Text(userFacingError(error)),
          kind: FeedbackKind.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Account & Security
        _SettingsItemCard(
          icon: Icons.lock_rounded,
          iconColor: context.colors.primaryGreen,
          iconBgColor: context.colors.surfaceAlt,
          title: 'Account & Security',
          subtitle: 'Change password and security settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSecurityPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Notifications
        _SettingsItemCard(
          icon: Icons.notifications_rounded,
          iconColor: context.colors.info,
          iconBgColor: context.colors.infoSurface,
          title: 'Notifications',
          subtitle: 'Manage your notification preferences',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsSettingsPage(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Location
        _SettingsItemCard(
          icon: Icons.location_on_rounded,
          iconColor: context.colors.error,
          iconBgColor: context.colors.errorSurface,
          title: 'Location',
          subtitle: 'Manage location permission and map access',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocationSettingsPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Privacy
        _SettingsItemCard(
          icon: Icons.shield_rounded,
          iconColor: context.colors.purple,
          iconBgColor: isDark ? context.colors.purpleSolid
              : context.colors.purpleSurface,
          title: 'Privacy',
          subtitle: 'Control your privacy settings and data',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacySettingsPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 5. App Preferences
        _SettingsItemCard(
          icon: Icons.palette_rounded,
          iconColor: context.colors.warning,
          iconBgColor: context.colors.warningSurface,
          title: 'App Preferences',
          subtitle: 'Theme and text size',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AppPreferencesPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 6. Help & Support
        _SettingsItemCard(
          icon: Icons.help_rounded,
          iconColor: context.colors.primaryGreen,
          iconBgColor: context.colors.surfaceAlt,
          title: 'Help & Support',
          subtitle: 'Get help or report a problem',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpSupportPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 7. About
        _SettingsItemCard(
          icon: Icons.info_rounded,
          iconColor: context.colors.textSecondary,
          iconBgColor: context.colors.surfaceAlt,
          title: 'About',
          subtitle: 'Terms, privacy policy, and app version',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutAppPage()),
          ),
        ),
        const SizedBox(height: 22),

        // 8. Log Out Button Card
        _SettingsLogoutCard(
          isLoading: _isLoggingOut,
          onTap: _isLoggingOut ? null : _confirmLogout,
        ),
      ],
    );
  }
}

class _SettingsItemCard extends StatelessWidget {
  const _SettingsItemCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.border,
          width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.028,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Icon in soft tinted rounded box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.info,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLogoutCard extends StatelessWidget {
  const _SettingsLogoutCard({
    required this.isLoading,
    required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.errorSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: isDark ? 0.15 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.errorSolid,
                    ),
                  )
                else ...[
                  Icon(
                    Icons.logout_rounded,
                    color: context.colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: GoogleFonts.outfit(
                      color: context.colors.error,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
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
