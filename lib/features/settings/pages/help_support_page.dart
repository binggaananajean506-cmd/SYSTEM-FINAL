import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth_service.dart';
import '../../../features/app_assistant/app_assistant_launcher.dart';
import '../widgets/settings_header_wave.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SettingsHeaderWave(title: 'Help & Support'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // AI Assistant Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: context.colors.primaryGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-SUGID AI Assistant',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask questions about local procedures, emergency tips, or barangay services.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Open Assistant Button
          FilledButton.icon(
            onPressed: () {
              final user = AuthService.currentUser;
              if (user != null) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: context.colors.shadow.withValues(alpha: 0.58),
                  builder: (_) => AppAssistantSheet(
                    user: user,
                    onNavigate: (action) {
                      Navigator.pop(context);
                    },
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  AppSnackBar(content: Text('Please sign in to access E-SUGID AI Assistant.',
                    ),
                    kind: FeedbackKind.warning,
                  ),
                );
              }
            },
            icon: const Icon(Icons.forum_rounded, size: 18),
            label: const Text('Open AI Assistant'),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: context.colors.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Municipal Hotlines
          Text(
            'Barili Emergency Hotlines',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _HotlineTile(
            agency: 'MDRRMO Barili Disaster Office',
            number: '0917-123-4567',
            icon: Icons.shield_rounded,
            color: context.colors.errorSolid,
            onCall: () => _makePhoneCall('09171234567'),
          ),
          const SizedBox(height: 8),
          _HotlineTile(
            agency: 'PNP Barili Police Station',
            number: '(032) 470-9111',
            icon: Icons.local_police_rounded,
            color: context.colors.infoSolid,
            onCall: () => _makePhoneCall('0324709111'),
          ),
          const SizedBox(height: 8),
          _HotlineTile(
            agency: 'BFP Barili Fire Station',
            number: '(032) 470-9222',
            icon: Icons.local_fire_department_rounded,
            color: context.colors.errorSolid,
            onCall: () => _makePhoneCall('0324709222'),
          ),
          const SizedBox(height: 8),
          _HotlineTile(
            agency: 'Rural Health Unit (RHU) Clinic',
            number: '(032) 470-9333',
            icon: Icons.local_hospital_rounded,
            color: context.colors.brand,
            onCall: () => _makePhoneCall('0324709333'),
          ),
        ],
      ),
    );
  }
}

class _HotlineTile extends StatelessWidget {
  const _HotlineTile({
    required this.agency,
    required this.number,
    required this.icon,
    required this.color,
    required this.onCall,
  });

  final String agency;
  final String number;
  final IconData icon;
  final Color color;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agency,
                  style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  number,
                  style: GoogleFonts.outfit(fontSize: 12, color: context.colors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: Icon(Icons.phone_rounded, color: context.colors.primaryGreen),
            tooltip: 'Call Hotline',
          ),
        ],
      ),
    );
  }
}
