import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_service.dart';
import '../community_service.dart';
import '../widgets/esugid_page_header.dart';

class TrustSafetyDashboard extends StatelessWidget {
  const TrustSafetyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      body: Column(
        children: [
          ESugidPageHeader(
            sectionLabel: 'Account',
            title: 'Trust & Safety',
            subtitle: 'Manage your community standing and security',
            icon: Icons.verified_user_rounded,
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _buildVerificationStatusCard(context, user),
                const SizedBox(height: 24),
                _buildCivicPointsSummaryCard(user.uid),
                const SizedBox(height: 32),
                _buildSectionHeader(context, 'Civic Activity Log'),
                const SizedBox(height: 16),
                _buildActivityLog(user.uid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? context.colors.textSecondary
              : context.colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildVerificationStatusCard(BuildContext context, User user) {
    final isVerified = user.isVerified;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isVerified ? context.colors.infoSolid
                              : context.colors.warningSolid).withValues(
                    alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified
                      ? Icons.verified_rounded
                      : Icons.pending_actions_rounded,
                  color: isVerified
                      ? context.colors.info
                      : context.colors.warning,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified
                          ? 'Fully Verified Resident'
                          : 'Verification Pending',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      isVerified
                          ? 'Your identity is confirmed by the Barangay.'
                          : 'Your documents are being reviewed.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isVerified) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: context.colors.warningSolid.withValues(alpha: 0.1,
              ),
              color: context.colors.warningSolid,
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text(
              'Est. remaining time: 1-2 business days',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCivicPointsSummaryCard(String userId) {
    return StreamBuilder<int>(
      stream: CommunityService.civicPoints(userId),
      builder: (context, snapshot) {
        final points = snapshot.data ?? 0;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.colors.brand, context.colors.brand],
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.stars_rounded,
                  size: 140,
                  color: context.colors.onAccent.withValues(alpha: 0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Civic Points',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent.withValues(alpha: 0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          points.toString(),
                          style: GoogleFonts.outfit(
                            color: context.colors.onAccent,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PTS',
                          style: GoogleFonts.outfit(
                            color: context.colors.onAccent.withValues(alpha: 0.6,
                            ),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            color: context.colors.onAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Top 15% of your Barangay',
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityLog(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('civic_points')
          .doc(userId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyActivity(context);
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildActivityItem(context, data);
          },
        );
      },
    );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: context.colors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start helping your community to earn civic points!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> data) {
    final int points = data['points'] ?? 0;
    final String description = data['description'] ?? 'Civic contribution';
    final DateTime? timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? context.colors.primaryGreen : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              points >= 0 ? Icons.add_rounded : Icons.remove_rounded,
              color: points >= 0 ? context.colors.primaryGreen
                  : context.colors.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${points > 0 ? '+' : ''}$points',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: points >= 0 ? context.colors.primaryGreen
                  : context.colors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? context.colors.surface.withValues(alpha: 0.85)
                : context.colors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? context.colors.primaryGreen.withValues(alpha: 0.6)
                  : context.colors.border.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
