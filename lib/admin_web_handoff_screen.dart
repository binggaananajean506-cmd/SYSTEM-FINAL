import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'session_service.dart';
import 'widgets/esugid_page_header.dart';

class AdminWebHandoffScreen extends StatelessWidget {
  const AdminWebHandoffScreen({super.key});

  static final Uri _adminConsoleUri = Uri.parse('https://e-sugid.web.app');

  Future<void> _openAdminConsole(BuildContext context) async {
    final opened = await launchUrl(
      _adminConsoleUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open the web admin console.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          const ESugidPageHeader(
            sectionLabel: 'Administration',
            title: 'Municipal Administration',
            subtitle: 'Administrative tools are available on the web.',
            icon: Icons.admin_panel_settings_outlined,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 58,
                            color: context.colors.primaryGreen,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Continue on the web console',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: context.colors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Concerns, verifications, content moderation, alerts, and user management now use one secure administrative workspace.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openAdminConsole(context),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open Web Admin'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: SessionService.logout,
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
