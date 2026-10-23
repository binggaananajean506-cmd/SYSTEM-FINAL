import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/settings_header_wave.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'About'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Municipal seal & app identity
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.brand, context.colors.brand],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.35,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shield_rounded,
                      color: context.colors.onAccent,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'E-SUGID Barili',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 2.4.0 (2026 Edition)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Municipality of Barili, Province of Cebu',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: context.colors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview Card
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
                  'Civic Platform Mission',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'E-SUGID connects the residents of Barili with their barangay officials and municipal disaster response units. It streamlines civic document requests, incident complaints, emergency evacuation guidance, and community mutual aid.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: context.colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legal options
          _LegalTile(
            title: 'Terms of Service',
            subtitle: 'Citizen guidelines and acceptable use policy',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Terms of Service'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'By using E-SUGID, you agree to submit truthful civic reports and document requests. Misuse of the emergency siren or filing false reports may be subject to local municipal ordinances.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _LegalTile(
            title: 'Privacy Policy',
            subtitle: 'Data protection standards under RA 10173',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'All citizen data collected by E-SUGID is stored securely and processed exclusively for municipal service delivery by the Local Government Unit of Barili, Cebu.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _LegalTile(
            title: 'Open Source Licenses',
            subtitle: 'Third-party libraries and assets',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'E-SUGID Barili',
              applicationVersion: '2.4.0',
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border),
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
