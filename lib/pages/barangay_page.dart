import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_service.dart';
import '../barili_barangays.dart';
import '../services/barangay_logo_service.dart';
import '../community_service.dart';
import '../widgets/esugid_page_header.dart';
import '../widgets/community_post_widgets.dart';

enum BarangayCategoryFilter {
  all,
  notices,
  advisory,
  events }

class BarangayPage extends StatefulWidget {
  final User? initialData;
  final List<CommunityPost>? initialPosts;
  const BarangayPage({super.key, this.initialData, this.initialPosts});

  @override
  State<BarangayPage> createState() => _BarangayPageState();
}

class _BarangayPageState extends State<BarangayPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  BarangayCategoryFilter _selectedCategory = BarangayCategoryFilter.all;
  Stream<List<CommunityPost>>? _postsStream;
  String? _postsStreamBarangay;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<CommunityPost>> _getOrCreatePostsStream(User user) {
    final canon = canonicalBariliBarangay(user.barangay);
    if (_postsStream == null || _postsStreamBarangay != canon) {
      _postsStreamBarangay = canon;
      _postsStream = CommunityService.barangayPostsForUser(user);
    }
    return _postsStream!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: AuthService.currentUserDocStream,
        initialData: widget.initialData ?? AuthService.currentUser,
        builder: (context, snapshot) {
          final user =
              snapshot.data ?? widget.initialData ?? AuthService.currentUser;

          return RefreshIndicator(
            color: context.colors.primaryGreen,
            onRefresh: () async {
              if (user != null) {
                CommunityService.clearBarangayStream(user.barangay);
                if (mounted) {
                  setState(() {
                    _postsStream = null;
                  });
                }
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
              _buildHeader(context, user),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList.list(
                  children: [
                    if (snapshot.hasError)
                      _buildMessageCard(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to refresh your information',
                        message:
                            'Check your internet connection and try again.',
                        isWarning: true,
                      )
                    else if (user == null)
                      _buildMessageCard(
                        icon: Icons.person_off_outlined,
                        title: 'Account information unavailable',
                        message: 'Please sign in again to view your barangay.',
                        isWarning: true,
                      )
                    else ...[
                      // 3D Barangay Overview Badge
                      _buildBarangayOverviewCard(user),
                      const SizedBox(height: 12),
                      // 3D Glass Search Bar
                      _buildSearchBar(),
                      const SizedBox(height: 12),
                      // Category Pills Filter Row
                      _buildCategoryPills(),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              if (user != null && (user.barangay?.isNotEmpty ?? false))
                _buildBarangayFeed(user)
              else if (user != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildFeedGuide(context, user),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    return ESugidSliverPageHeader(
      sectionLabelWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: context.colors.brandStrong.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.75),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.warningSolid,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'BARILI COMMUNITY',
              style: GoogleFonts.outfit(
                color: context.colors.onBrandMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      title: 'My Barangay',
      iconWidget: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.warningSolid,
              context.colors.warningSolid,
              context.colors.brand,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2.5),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [context.colors.brand, context.colors.brandStrong],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
      showBackButton: true,
    );
  }

  Widget _buildBarangayOverviewCard(User user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final identity = BarangayLogos.forResident(user);
    final barangay = identity.canonicalName ?? 'Not specified';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.brandStrong,
            context.colors.brandStrong,
            context.colors.brand,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy Specular Top Rim Light
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.surface.withValues(alpha: 0.0),
                    context.colors.surface.withValues(alpha: 0.65),
                    context.colors.surface.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              // Barangay office icon.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.warningSolid,
                      context.colors.warningSolid,
                      context.colors.brand,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.brand,
                        context.colors.brandStrong,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Barangay $barangay',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              shadows: const [
                                Shadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 1.5),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF34D399),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.40 : 0.30,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF34D399).withValues(
                            alpha: 0.55,
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
                              color: const Color(0xFF34D399),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF34D399).withValues(alpha: 0.65),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'BARILI DISTRICT • VERIFIED FEED',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF1F5F9),
                              letterSpacing: 0.6,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: context.colors.surface,
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (context.colors.brandStrong)
                .withValues(alpha: isDark ? 0.3 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            setState(() => _searchQuery = value.trim().toLowerCase()),
        style: GoogleFonts.outfit(
          color: context.colors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search barangay announcements...',
          hintStyle: GoogleFonts.outfit(
            color: context.colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [context.colors.brand, context.colors.brand],
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_rounded,
                color: context.colors.onAccent,
                size: 17,
              ),
            ),
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colors.primaryGreen,
                    size: 18,
                  ),
                ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      (
        filter: BarangayCategoryFilter.all,
        label: 'All',
        icon: Icons.auto_awesome_mosaic_rounded,
      ),
      (
        filter: BarangayCategoryFilter.notices,
        label: 'Notices',
        icon: Icons.campaign_rounded,
      ),
      (
        filter: BarangayCategoryFilter.advisory,
        label: 'Advisories',
        icon: Icons.warning_amber_rounded,
      ),
      (
        filter: BarangayCategoryFilter.events,
        label: 'Events',
        icon: Icons.event_available_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final selected = _selectedCategory == cat.filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_selectedCategory != cat.filter) {
                  setState(() {
                    _selectedCategory = cat.filter;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 38,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.brand,
                            context.colors.brandStrong,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface,
                            context.colors.surfaceAlt,
                          ],
                        ),
                  border: Border.all(
                    color: selected
                        ? context.colors.primaryGreen.withValues(alpha: 0.8)
                        : (isDark
                            ? context.colors.border.withValues(alpha: 0.25)
                            : context.colors.border),
                    width: selected ? 1.4 : 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? context.colors.brandStrong.withValues(alpha: 0.35)
                          : (isDark
                              ? context.colors.brandStrong.withValues(alpha: 0.25,
                                )
                                : context.colors.brandStrong.withValues(alpha: 0.08,
                                  )),
                      blurRadius: selected ? 8 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 15,
                      color: selected
                          ? context.colors.warning
                          : (context.colors.primaryGreen),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label,
                      style: GoogleFonts.outfit(
                        color: selected
                            ? context.colors.onAccent
                            : (context.colors.textPrimary),
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _matchesCategoryFilter(
    CommunityPost post,
    BarangayCategoryFilter filter,
  ) {
    if (filter == BarangayCategoryFilter.all) return true;

    final catText =
        '${post.category} ${post.customCategory} ${post.displayCategory} ${post.tag} ${post.title}'
            .toLowerCase();

    if (filter == BarangayCategoryFilter.notices) {
      final isEvent =
          catText.contains('event') ||
          catText.contains('activity') ||
          post.hasCalendarSchedule;
      final isAdvisory =
          catText.contains('advisory') ||
          catText.contains('urgent') ||
          catText.contains('emergency') ||
          post.priority.toLowerCase() == 'urgent';
      return !isEvent && !isAdvisory;
    }

    if (filter == BarangayCategoryFilter.advisory) {
      return catText.contains('advisory') ||
          catText.contains('urgent') ||
          catText.contains('emergency') ||
          post.priority.toLowerCase() == 'urgent' ||
          post.priority.toLowerCase() == 'emergency';
    }

    if (filter == BarangayCategoryFilter.events) {
      return catText.contains('event') ||
          catText.contains('activity') ||
          post.hasCalendarSchedule ||
          post.eventDate != null;
    }

    return true;
  }

  Widget _buildBarangayFeed(User user) {
    final initialPosts = widget.initialPosts ??
        CommunityService.latestBarangayPosts(user.barangay);

    return StreamBuilder<List<CommunityPost>>(
      initialData: initialPosts,
      stream: _getOrCreatePostsStream(user),
      builder: (context, snapshot) {
        if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildMessageCard(
                icon: Icons.cloud_off_rounded,
                title: 'Updates are unavailable',
                message: 'Please check your connection and try again.',
                isWarning: true,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          );
        }

        final query = _searchQuery;
        final selectedCat = _selectedCategory;

        final posts = snapshot.data!.where((post) {
          if (!_matchesCategoryFilter(post, selectedCat)) return false;
          if (query.isEmpty) return true;
          return [
            post.title,
            post.content,
            post.authorName,
            post.publisherEntityName,
            post.displayCategory,
          ].join(' ').toLowerCase().contains(query);
        }).toList();

        if (posts.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildMessageCard(
                icon: Icons.search_off_rounded,
                title: query.isEmpty ? 'No updates yet' : 'No matching updates',
                message: query.isEmpty
                    ? 'Announcements for your barangay will appear here.'
                    : 'Try another word or clear your search.',
                isWarning: false,
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) => RepaintBoundary(
              child: ModernPostCard(
                post: posts[index],
                heroScope: 'barangay',
                animateEntrance: index < 5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedGuide(BuildContext context, User user) {
    final barangay = _clean(user.barangay);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.brand.withValues(alpha: 0.08),
            context.colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: context.colors.primaryGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barangay announcements',
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  barangay == null
                      ? 'Complete your profile to receive local posts.'
                      : 'Posts for Barangay $barangay appear in your feed.',
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: context.colors.brand,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: context.colors.onAccent,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    required bool isWarning,
  }) {
    final color = isWarning ? context.colors.warning
        : context.colors.primaryGreen;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
