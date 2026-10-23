import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/private_organization.dart';
import '../services/private_organization_service.dart';
import '../widgets/community_post_widgets.dart';

class OrganizationProfilePage extends StatefulWidget {
  final PrivateOrganization organization;

  const OrganizationProfilePage({
    super.key,
    required this.organization});

  @override
  State<OrganizationProfilePage> createState() =>
      _OrganizationProfilePageState();
}

class _OrganizationProfilePageState extends State<OrganizationProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = PrivateOrganizationService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleFollow() async {
    HapticFeedback.mediumImpact();
    final bool isNowFollowed;
    try {
      isNowFollowed = await _service.toggleFollow(widget.organization.id);
    } on FollowException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showAppSnackBar(
          AppSnackBar(content: Text(error.message), kind: FeedbackKind.error),
        );
      return;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(
        content: Text(
                isNowFollowed
                    ? 'Following ${widget.organization.name}. Updates will appear in your feed.'
                    : 'Unfollowed ${widget.organization.name}.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
        kind: FeedbackKind.success,
      ),
    );
  }

  void _openUpdateDetail(PrivateOrganizationUpdate update) {
    HapticFeedback.lightImpact();
    final post = update.toCommunityPost(widget.organization);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PostDetailsPage(
          post: post,
          imageHeroTag: 'org_update_${update.id}',
          primaryGreen: context.colors.primaryGreen,
          deepGreen: context.colors.textPrimary,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Future<void> _handleShareOutsideApp() async {
    HapticFeedback.lightImpact();
    final org = widget.organization;
    final buffer = StringBuffer();
    buffer.writeln('📍 ${org.name} • Barili Private Partner');
    buffer.writeln('Sector: ${org.category}');
    buffer.writeln();
    buffer.writeln(org.about);
    buffer.writeln();
    if (org.address.isNotEmpty) {
      buffer.writeln('Address: ${org.address}');
    }
    if (org.website.isNotEmpty) {
      buffer.writeln('Official Portal: ${org.website}');
    }
    buffer.writeln();
    buffer.writeln('Shared via E-SUGID Barili App');

    final shareText = buffer.toString().trim();

    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: '${org.name} - Barili Partner Profile',
          sharePositionOrigin: box != null
              ? (box.localToGlobal(Offset.zero) & box.size)
              : null,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
                  'Profile details copied to clipboard to share outside the app.',
                  style: GoogleFonts.outfit(fontSize: 13),
              ),
          kind: FeedbackKind.error,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final org = widget.organization;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _service.followedIdsNotifier,
      builder: (context, followedIds, _) {
        final isFollowed = followedIds.contains(org.id);
        final followerLabel = org.formattedFollowerCount(
          _service.followerOffsetFor(org),
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Executive Civic Pinned App Bar (No cover photo banner)
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 2,
                backgroundColor: context.colors.brandStrong,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 64,
                leadingWidth: 64,
                leading: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.surface.withValues(alpha: 0.12),
                          border: Border.all(
                            color: context.colors.border.withValues(alpha: 0.22,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.15,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: context.colors.onAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'Organization Profile',
                  style: GoogleFonts.outfit(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onAccent,
                    letterSpacing: 0.2,
                  ),
                ),
                centerTitle: true,
                actions: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleShareOutsideApp,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.surface.withValues(alpha: 0.12,
                              ),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.22,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(alpha: 0.15,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.share_rounded,
                              color: context.colors.onAccent,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. 3D Organization Showcase Hero Card (Below App Bar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? context.colors.infoSolid.withValues(alpha: 0.3) : context.colors.infoSolid.withValues(alpha: 0.05,
                                ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.02,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Barili Private Partner badge & Follow button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.colors.surfaceAlt,
                                    context.colors.surfaceAlt,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? context.colors.primaryGreen
                                      : context.colors.primaryGreen.withValues(alpha: 0.35,
                                        ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.colors.brand,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'BARILI PRIVATE PARTNER',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.primaryGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildFollowButton(isFollowed),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Organization Identity Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildEmblem(org),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          org.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: context.colors.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                      if (org.isVerified) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                context.colors.infoSolid,
                                                context.colors.infoSolid,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: context.colors.infoSolid
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 11,
                                            color: context.colors.onAccent,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.colors
                                              .accent(org.brandColor)
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(8,
                                          ),
                                          border: Border.all(
                                            color: context.colors
                                                .accent(org.brandColor)
                                                .withValues(alpha: 0.20),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              org.fallbackIcon,
                                              size: 13,
                                              color: context.colors.accent(
                                                org.brandColor,
                                            ),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                org.category,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.colors.accent(
                                                    org.brandColor,
                                                ),
                                              ),
                                            ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '•  Private Organization',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 3-Metric 3D Quick-Glance Ribbon
                        _buildMetricRibbon(org, followerLabel),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Tactile 3D Segmented Tab Control
              SliverToBoxAdapter(
                child: _buildTabSelector()),

              // 4. Tab Body Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                sliver: SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      switch (_tabController.index) {
                        case 0:
                          return _buildAboutTab(org);
                        case 1:
                          return _buildUpdatesTab(org);
                        case 2:
                          return _buildCommunityTab(org, followerLabel);
                        default:
                          return _buildAboutTab(org);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmblem(PrivateOrganization org) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surface],
        ),
        border: Border.all(
          color: context.colors.accent(org.brandColor).withValues(alpha: 0.35),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors
                .accent(org.brandColor)
                .withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: ClipOval(
          child: (org.logoUrl != null && org.logoUrl!.isNotEmpty)
              ? Image.network(
                  org.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _buildLogoFallback(org),
                )
              : (org.logoAsset != null && org.logoAsset!.isNotEmpty)
                  ? Image.asset(
                      org.logoAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) =>
                          _buildLogoFallback(org),
                    )
                  : _buildLogoFallback(org),
        ),
      ),
    );
  }

  Widget _buildFollowButton(bool isFollowed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleToggleFollow,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
          decoration: BoxDecoration(
            gradient: isFollowed
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.brand, context.colors.brand],
                  ),
            color: isFollowed ? context.colors.surfaceAlt : null,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isFollowed
                  ? context.colors.primaryGreen
                  : context.colors.border.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isFollowed
                    ? context.colors.brandStrong.withValues(alpha: 0.20)
                    : context.colors.brandStrong.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowed
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_rounded,
                size: 16,
                color: isFollowed ? context.colors.primaryGreen
                    : context.colors.onAccent,
              ),
              const SizedBox(width: 5),
              Text(
                isFollowed ? 'Following' : 'Follow',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isFollowed ? context.colors.primaryGreen
                      : context.colors.onAccent,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRibbon(PrivateOrganization org, String followerLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border,
          width: 1),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatTile(
            icon: Icons.people_alt_rounded,
            iconColor: context.colors.primaryGreen,
            value: followerLabel.split(' ').first,
            label: 'Followers',
          ),
          Container(
            height: 30,
            width: 1,
            color: context.colors.infoSurface),
          _buildStatTile(
            icon: org.fallbackIcon,
            iconColor: context.colors.accent(org.brandColor),
            value: org.category.split('&').first.trim(),
            label: 'Sector',
          ),
          Container(
            height: 30,
            width: 1,
            color: context.colors.infoSurface),
          _buildStatTile(
            icon: Icons.verified_user_rounded,
            iconColor: context.colors.info,
            value: 'Verified',
            label: 'Trust Status',
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.border,
            width: 1),
        ),
        child: Row(
          children: [
            _buildTabButton(0, 'About'),
            _buildTabButton(1, 'Updates'),
            _buildTabButton(2, 'Community'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (context.colors.surface)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: (context.colors.border).withValues(alpha: 0.6),
                    width: 1,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (context.colors.primaryGreen)
                    : (context.colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback(PrivateOrganization org) {
    return Container(
      color: context.colors.accent(org.brandColor).withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          org.fallbackIcon,
          size: 34,
          color: context.colors.accent(org.brandColor),
        ),
      ),
    );
  }

  Widget _buildAboutTab(PrivateOrganization org) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3D Card for Description & Overview
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: context.colors.border,
              width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isDark ? context.colors.infoSolid.withValues(alpha: 0.3) : context.colors.infoSolid.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.surfaceAlt,
                          context.colors.surfaceAlt,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'About Organization',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                org.about,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: context.colors.border),
              const SizedBox(height: 16),

              // Location Detail Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address & Service Area',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.colors.info,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            org.address,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
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
        ),

        const SizedBox(height: 22),

        // Latest Advisories Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest Advisories & Updates',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            if (org.updates.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _tabController.animateTo(1);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.primaryGreen.withValues(alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All (${org.updates.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: context.colors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (org.updates.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.border,
                width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surfaceAlt,
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 28,
                    color: context.colors.info,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No advisories published by ${org.name} yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: org.updates.take(3).length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final update = org.updates[index];
              return _buildUpdateItem(update);
            },
          ),
      ],
    );
  }

  Widget _buildUpdateItem(PrivateOrganizationUpdate update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openUpdateDetail(update),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 3D Elevated Icon Thumbnail
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surfaceAlt,
                        context.colors.surfaceAlt,
                      ],
                    ),
                    border: Border.all(
                      color: context.colors.border,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.15,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.campaign_rounded,
                      color: context.colors.primaryGreen,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Date with category pill
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.warningSurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              update.category.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d, yyyy').format(update.date),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.colors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        update.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surface,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: context.colors.info,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesTab(PrivateOrganization org) {
    if (org.updates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: context.colors.border,
            width: 1.2),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.surfaceAlt,
                ),
                child: Icon(
                  Icons.mark_chat_unread_outlined,
                  size: 36,
                  color: context.colors.info,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No updates available from ${org.name}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When ${org.name} publishes bulletins or advisories, they will show up here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: context.colors.info,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: org.updates.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final update = org.updates[index];
        return _buildUpdateItem(update);
      },
    );
  }

  Widget _buildCommunityTab(PrivateOrganization org, String followerLabel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? context.colors.infoSolid.withValues(alpha: 0.3) : context.colors.infoSolid.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.brand, context.colors.brand],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.people_alt_rounded,
                color: context.colors.onAccent,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            followerLabel,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Residents and community members following updates from ${org.name}. When you follow this organization, their service advisories, maintenance schedules, and public bulletins appear automatically in your Community Updates feed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
