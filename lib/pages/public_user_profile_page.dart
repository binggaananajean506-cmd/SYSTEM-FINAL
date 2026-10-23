import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_service.dart';
import '../services/community_trust_service.dart';
import '../widgets/esugid_page_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class PublicUserProfilePage extends StatefulWidget {
  const PublicUserProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.initialPhotoUrl,
    this.initialBarangay,
  });

  final String userId;
  final String? initialName;
  final String? initialPhotoUrl;
  final String? initialBarangay;

  static Future<void> show(
    BuildContext context,
    String userId, {
    String? initialName,
    String? initialPhotoUrl,
    String? initialBarangay,
  }) {
    if (userId.isEmpty) return Future.value();
    final current = AuthService.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Please sign in to view community profiles.'),
          kind: FeedbackKind.warning,
        ),
      );
      return Future.value();
    }
    if (initialName != null && initialName.isNotEmpty) {
      CommunityTrustService.seedProfile(
        userId: userId,
        displayName: initialName,
        photoUrl: initialPhotoUrl,
        barangay: initialBarangay,
      );
    }
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicUserProfilePage(
          userId: userId,
          initialName: initialName,
          initialPhotoUrl: initialPhotoUrl,
          initialBarangay: initialBarangay,
        ),
      ),
    );
  }

  @override
  State<PublicUserProfilePage> createState() => _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends State<PublicUserProfilePage> {
  final _service = CommunityTrustService();
  UserTrustProfile? _profile;

  @override
  void initState() {
    super.initState();
    // 1. Check in-memory cache first
    _profile = CommunityTrustService.getCachedProfile(widget.userId);

    // 2. If viewing own profile, populate from currentUser instantly
    final current = AuthService.currentUser;
    if (_profile == null && current != null && current.uid == widget.userId) {
      _profile = UserTrustProfile(
        userId: current.uid,
        displayName: current.name,
        barangay: current.barangay,
        isVerified: current.isVerified,
        profilePhotoUrl: current.profilePhotoUrl,
        bayanihanRating: 5.0,
        bayanihanRatingCount: 0,
        marketRating: 0.0,
        marketRatingCount: 0,
        memberSince: null,
      );
    }

    // 3. Fallback placeholder so profile renders immediately with ZERO waiting/loading effect
    _profile ??= UserTrustProfile(
      userId: widget.userId,
      displayName: (widget.initialName?.isNotEmpty ?? false)
          ? widget.initialName!
          : 'Resident Member',
      barangay: widget.initialBarangay,
      isVerified: true,
      profilePhotoUrl: widget.initialPhotoUrl,
      bayanihanRating: 5.0,
      bayanihanRatingCount: 0,
      marketRating: 0.0,
      marketRatingCount: 0,
      memberSince: null,
    );

    // 4. Silently revalidate / fetch fresh data in background
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final fresh = await _service.getTrustProfile(widget.userId);
    if (fresh != null && mounted) {
      setState(() => _profile = fresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard: only verified residents can view profiles
    final viewer = AuthService.currentUser;
    if (viewer == null || !viewer.isVerified) {
      return Scaffold(
        body: Column(
          children: [
            ESugidPageHeader(
              sectionLabel: 'Community',
              title: 'Community Profile',
              subtitle: 'Resident trust & reputation',
              icon: Icons.person_rounded,
              showBackButton: true,
            ),
            const Expanded(child: _AccessDeniedView()),
          ],
        ),
      );
    }

    final activeProfile = _profile!;
    return Scaffold(
      body: _ProfileBody(profile: activeProfile, service: _service),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main profile body
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.service});

  final UserTrustProfile profile;
  final CommunityTrustService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ESugidPageHeader(
          sectionLabel: 'BAYANIHAN WORKS',
          title: 'Resident Profile',
          icon: Icons.volunteer_activism_rounded,
          showBackButton: true,
          endPadding: 6,
          trailing: _ReportIconButton(profile: profile),
        ),
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              // ── Hero Profile Identity Card ──────────────────────────────
              _AvatarSection(profile: profile),
              const SizedBox(height: 18),

              // ── Bayanihan Works Trust & Reputation Card ─────────────────
              _TrustScoreCard(
                averageRating: profile.bayanihanRating,
                ratingCount: profile.bayanihanRatingCount,
              ),
              const SizedBox(height: 24),

              // ── Reviews section header ──────────────────────────────────
              _SectionHeader(
                title: 'Bayanihan Reviews',
                subtitle: profile.bayanihanRatingCount == 0
                    ? 'No reviews yet'
                    : '${profile.bayanihanRatingCount} ${profile.bayanihanRatingCount == 1 ? 'review' : 'reviews'}',
              ),
              const SizedBox(height: 14),

              // ── Reviews list (filtered strictly to Bayanihan works) ─────
              _ReviewsList(userId: profile.userId, service: service),
              const SizedBox(height: 20),

              // ── Bayanihan trust info footnote card ──────────────────────
              const _BayanihanTrustSafetyCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar & Identity Hero Section
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({required this.profile});

  final UserTrustProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.displayName);
    final memberSinceText = profile.memberSince != null
        ? 'Member since ${_formatYear(profile.memberSince!)}'
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.95),
            blurRadius: 0,
            offset: const Offset(0, -1.2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft ambient gradient banner decoration
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 76,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.surfaceAlt,
                      context.colors.surfaceAlt,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with double-ring & Facebook-style verification badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.surfaceAlt,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [context.colors.brand, context.colors.brand],
                        ),
                        border: Border.all(color: context.colors.border, width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.12,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.25,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: profile.profilePhotoUrl != null &&
                              profile.profilePhotoUrl!.trim().isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                profile.profilePhotoUrl!.trim(),
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, _) =>
                                    _InitialsText(initials),
                              ),
                            )
                          : _InitialsText(initials),
                    ),
                    if (profile.isVerified)
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: context.colors.infoSolid,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.border, width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.highlight.withValues(alpha: 0.40,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          color: context.colors.onAccent,
                          size: 15,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Full Resident Name
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Verified Barili Resident Badge Pill
                if (profile.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: context.colors.primaryGreen,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Verified Barili Resident',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: 16),

                // Informational badges / chips (Bayanihan Contributor removed per request)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (profile.barangay != null && profile.barangay!.isNotEmpty)
                      _MetaInfoChip(
                        icon: Icons.location_on_rounded,
                        label: 'Brgy. ${profile.barangay}',
                      ),
                    if (memberSinceText != null)
                      _MetaInfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: memberSinceText,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
  }

  static String _formatYear(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _MetaInfoChip extends StatelessWidget {
  const _MetaInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isDark ? context.colors.primaryGreen : context.colors.border).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: context.colors.onAccent,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bayanihan Works Trust & Reputation Card
// ─────────────────────────────────────────────────────────────────────────────

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({
    required this.averageRating,
    required this.ratingCount,
  });

  final double averageRating;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avg = averageRating;
    final hasRatings = ratingCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? context.colors.primaryGreen : context.colors.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.95),
            blurRadius: 0,
            offset: const Offset(0, -1.2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.warningSolid,
                      context.colors.warningSolid,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.highlight.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: context.colors.onAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bayanihan Works',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasRatings
                          ? '$ratingCount completed community help${ratingCount == 1 ? '' : 's'}'
                          : 'Community assistance & volunteer reputation',
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

          const SizedBox(height: 18),

          if (hasRatings) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        avg.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: context.colors.textPrimary,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 6),
                        child: Text(
                          '/ 5.0',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StarRatingDisplay(rating: avg, size: 26),
                  const SizedBox(height: 12),
                  _RatingBreakdownBar(rating: avg),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.handshake_outlined,
                      size: 28,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No Bayanihan Ratings Yet',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This resident has not received ratings for Bayanihan activities yet. Feedback appears here after participating in community requests.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBreakdownBar extends StatelessWidget {
  const _RatingBreakdownBar({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final fill = (rating / 5.0).clamp(0.0, 1.0);
    final color = _colorForRating(context, rating);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: fill,
        minHeight: 8,
        backgroundColor: context.colors.surfaceAlt,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  static Color _colorForRating(BuildContext context, double r) {
    if (r >= 4.0) return context.colors.primaryGreen;
    if (r >= 3.0) return context.colors.warning;
    return context.colors.error;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bayanihan Reviews
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.userId, required this.service});

  final String userId;
  final CommunityTrustService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserReview>>(
      stream: service.reviewsFor(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final allReviews = snapshot.data ?? [];
        // Only include reviews for Bayanihan works (exclude Local Market)
        final reviews = allReviews
            .where((r) => r.context == TrustContext.bayanihan)
            .toList(growable: false);

        if (reviews.isEmpty) {
          return const _EmptyReviews();
        }
        return Column(
          children: reviews
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewCard(review: r),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final UserReview review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? context.colors.primaryGreen : context.colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reviewer avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.brand.withValues(alpha: 0.12),
                  border: Border.all(
                    color: context.colors.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    _initial(review.reviewerName),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StarRatingDisplay(rating: review.rating, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.infoSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🤝 ',
                          style: TextStyle(fontSize: 10)),
                        Text(
                          'Bayanihan',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: context.colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(review.createdAt),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Text(
                '"${review.comment}"',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: context.colors.textPrimary,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? context.colors.primaryGreen : context.colors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_outlined,
              size: 36,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Bayanihan Reviews Yet',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Reviews from fellow Barili residents will appear here after completing volunteer activities or assisting in Bayanihan requests.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: context.colors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bayanihan Trust & Community Safety Footer Card
// ─────────────────────────────────────────────────────────────────────────────

class _BayanihanTrustSafetyCard extends StatelessWidget {
  const _BayanihanTrustSafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: context.colors.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Bayanihan Trust',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All Bayanihan reviews are from verified Barili residents who collaborated on community requests.',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: context.colors.primaryGreen,
                    height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Report Icon (header trailing)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportIconButton extends StatelessWidget {
  const _ReportIconButton({required this.profile});

  final UserTrustProfile profile;

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    // Don't show report button on own profile
    if (currentUser?.uid == profile.userId) return const SizedBox.shrink();

    return Tooltip(
      message: 'Report this user',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReportSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surface.withValues(alpha: 0.22),
                  context.colors.surface.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: context.colors.highlight.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.flag_rounded,
              color: context.colors.onAccent,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportUserSheet(profile: profile),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report User Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReportUserSheet extends StatefulWidget {
  const _ReportUserSheet({required this.profile});

  final UserTrustProfile profile;

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  static const _reasons = [
    'Fake or misleading profile',
    'Offensive or inappropriate behavior',
    'No-show or cancellation without notice',
    'Spam or scam attempt',
    'Other',
  ];

  String _selectedReason = _reasons.first;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _submitted
                ? _SuccessView()
                : _FormView(
                    selectedReason: _selectedReason,
                    detailsCtrl: _detailsCtrl,
                    submitting: _submitting,
                    onReasonChanged: (r) =>
                        setState(() => _selectedReason = r!),
                    onSubmit: _submit,
                    profileName: widget.profile.displayName,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await CommunityTrustService().reportUser(
        reportedUserId: widget.profile.userId,
        reportedUserName: widget.profile.displayName,
        reason: _selectedReason,
        details: _detailsCtrl.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not submit report. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.selectedReason,
    required this.detailsCtrl,
    required this.submitting,
    required this.onReasonChanged,
    required this.onSubmit,
    required this.profileName,
  });

  final String selectedReason;
  final TextEditingController detailsCtrl;
  final bool submitting;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback onSubmit;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.errorSolid.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flag_rounded,
                color: context.colors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report User',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    profileName,
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
        const SizedBox(height: 20),
        Text(
          'Reason for report',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          dropdownColor: context.colors.surface,
          initialValue: selectedReason,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.colors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: _ReportUserSheetState._reasons
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: onReasonChanged,
        ),
        const SizedBox(height: 14),
        Text(
          'Additional details (optional)',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: detailsCtrl,
          maxLines: 3,
          maxLength: 400,
          decoration: InputDecoration(
            hintText: 'Describe what happened...',
            filled: true,
            fillColor: context.colors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              foregroundColor: context.colors.onAccent,

              backgroundColor: context.colors.errorSolid,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: context.colors.onAccent,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              submitting ? 'Submitting...' : 'Submit Report',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your report is confidential and will be reviewed by the E-SUGID helpdesk.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.brand.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: context.colors.primaryGreen,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Report Submitted',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thank you. The E-SUGID helpdesk will review your report confidentially.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: context.colors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: context.colors.onAccent,

              backgroundColor: context.colors.brand,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Done',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rating prompt widget (reusable in conversation pages)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a star-rating prompt after a completed interaction.
/// Drop this at the bottom of a conversation screen.
class CommunityRatingPrompt extends StatefulWidget {
  const CommunityRatingPrompt({
    super.key,
    required this.sourceId,
    required this.targetUserId,
    required this.targetUserName,
    required this.context,
  });

  final String sourceId;
  final String targetUserId;
  final String targetUserName;
  final TrustContext context;

  @override
  State<CommunityRatingPrompt> createState() => _CommunityRatingPromptState();
}

class _CommunityRatingPromptState extends State<CommunityRatingPrompt>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  bool _alreadyRated = false;
  bool _loading = true;
  int _hovered = 0;
  int _selected = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _checkRated();
  }

  Future<void> _checkRated() async {
    bool rated;
    try {
      rated = await CommunityTrustService().hasRated(
        sourceId: widget.sourceId,
        targetUserId: widget.targetUserId,
        context: widget.context,
      );
    } catch (_) {
      rated = false;
    }
    if (!mounted) return;
    setState(() {
      _alreadyRated = rated;
      _loading = false;
    });
    if (!rated) _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _alreadyRated || _dismissed) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.primaryGreen.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _submitted ? _buildThanks() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate your experience',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'with ${widget.targetUserName}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(
                  Icons.close_rounded,
                  color: context.colors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = star <= (_hovered > 0 ? _hovered : _selected);
              return GestureDetector(
                onTap: () => setState(() => _selected = star),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hovered = star),
                  onExit: (_) => setState(() => _hovered = 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        key: ValueKey('$star-$filled'),
                        color: filled
                            ? context.colors.warning
                            : context.colors.textSecondary,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_selected > 0) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Leave a short comment (optional)...',
                filled: true,
                fillColor: context.colors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  foregroundColor: context.colors.onAccent,

                  backgroundColor: context.colors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Submit Rating',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThanks() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: context.colors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rating submitted!',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  'Thank you for contributing to community trust.',
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
    );
  }

  Future<void> _submit() async {
    if (_selected == 0) return;
    setState(() => _submitting = true);
    try {
      await CommunityTrustService().submitRating(
        targetUserId: widget.targetUserId,
        rating: _selected.toDouble(),
        comment: _commentCtrl.text,
        context: widget.context,
        sourceId: widget.sourceId,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not submit rating. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Report User Sheet (callable from conversations)
// ─────────────────────────────────────────────────────────────────────────────

/// Call this from any conversation page to show the report-user bottom sheet.
Future<void> showReportUserSheet(
  BuildContext context, {
  required String reportedUserId,
  required String reportedUserName,
  String? conversationId,
  TrustContext context_ = TrustContext.bayanihan,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _StandaloneReportSheet(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        conversationId: conversationId,
        trustContext: context_,
      ),
    ),
  );
}

class _StandaloneReportSheet extends StatefulWidget {
  const _StandaloneReportSheet({
    required this.reportedUserId,
    required this.reportedUserName,
    this.conversationId,
    required this.trustContext,
  });

  final String reportedUserId;
  final String reportedUserName;
  final String? conversationId;
  final TrustContext trustContext;

  @override
  State<_StandaloneReportSheet> createState() => _StandaloneReportSheetState();
}

class _StandaloneReportSheetState extends State<_StandaloneReportSheet> {
  static const _reasons = [
    'Fake or misleading profile',
    'Offensive or inappropriate behavior',
    'No-show or cancellation without notice',
    'Spam or scam attempt',
    'Other',
  ];

  String _reason = _reasons.first;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _submitted
              ? _SuccessView()
              : _FormView(
                  selectedReason: _reason,
                  detailsCtrl: _detailsCtrl,
                  submitting: _submitting,
                  onReasonChanged: (r) => setState(() => _reason = r!),
                  onSubmit: _submit,
                  profileName: widget.reportedUserName,
                ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await CommunityTrustService().reportUser(
        reportedUserId: widget.reportedUserId,
        reportedUserName: widget.reportedUserName,
        reason: _reason,
        details: _detailsCtrl.text,
        conversationId: widget.conversationId,
        context: widget.trustContext,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not submit report. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star rating display (read-only)
// ─────────────────────────────────────────────────────────────────────────────

class _StarRatingDisplay extends StatelessWidget {
  const _StarRatingDisplay({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= rating;
        final halfFilled = !filled && (star - 0.5) <= rating;
        return Icon(
          filled
              ? Icons.star_rounded
              : halfFilled
              ? Icons.star_half_rounded
              : Icons.star_border_rounded,
          color: context.colors.warning,
          size: size,
        );
      }),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: context.colors.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}



class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.warningSolid.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_rounded,
                size: 44,
                color: context.colors.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verified Residents Only',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Community profiles are only visible to verified Barili residents. Complete your identity verification to access this feature.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
