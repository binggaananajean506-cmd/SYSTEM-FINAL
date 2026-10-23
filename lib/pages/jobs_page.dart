import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../jobs_service.dart';
import '../widgets/esugid_page_header.dart';
import '../features/bayanihan_messages/presentation/widgets/bayanihan_card_action.dart';
import '../core/widgets/async_error_view.dart';
import '../features/bayanihan_messages/presentation/pages/bayanihan_conversation_page.dart';
import '../features/bayanihan_messages/presentation/widgets/bayanihan_unread_button.dart';
import '../features/bayanihan_messages/services/bayanihan_messaging_service.dart';
import '../features/bayanihan_messages/models/bayanihan_conversation.dart';
import '../verification_screen.dart';
import '../app_motion.dart';
import 'request_help_page.dart';
import 'public_user_profile_page.dart';
import '../services/community_trust_service.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _RequesterProfile {
  final String name;
  final String? photoUrl;
  final bool isVerified;

  const _RequesterProfile({
    required this.name,
    this.photoUrl,
    this.isVerified = false,
  });
}

class _CategoryVisualConfig {
  final String label;
  final IconData mainIcon;
  final IconData backgroundWatermarkIcon;
  final List<Color> gradientColors;
  final Color accentColor;
  final String? assetPath;

  const _CategoryVisualConfig({
    required this.label,
    required this.mainIcon,
    required this.backgroundWatermarkIcon,
    required this.gradientColors,
    required this.accentColor,
    this.assetPath,
  });
}

_CategoryVisualConfig _getCategoryVisualConfig(
  BuildContext context,
  String rawCategory,
) {
  final cat = rawCategory.trim().toLowerCase();

  // 1. Errands
  if (cat == 'errands' ||
      cat.contains('errand') ||
      cat.contains('deliver') ||
      cat.contains('pabili') ||
      cat.contains('buy') ||
      cat.contains('shop') ||
      cat.contains('grocer')) {
    return _CategoryVisualConfig(
      label: 'Errands',
      mainIcon: Icons.directions_run_rounded,
      backgroundWatermarkIcon: Icons.local_shipping_rounded,
      gradientColors: [
        context.colors.warningSurface,
        context.colors.warningSurface,
        context.colors.warningSurface,
      ],
      accentColor: context.colors.error,
      assetPath: null,
    );
  }

  // 2. Repairs
  if (cat == 'repairs' ||
      cat == 'repair' ||
      cat.contains('repair') ||
      cat.contains('labor') ||
      cat.contains('manual') ||
      cat.contains('handyman') ||
      cat.contains('construct') ||
      cat.contains('tool') ||
      cat.contains('fix') ||
      cat.contains('plumb') ||
      cat.contains('electric') ||
      cat.contains('carpenter')) {
    return _CategoryVisualConfig(
      label: 'Repairs',
      mainIcon: Icons.handyman_rounded,
      backgroundWatermarkIcon: Icons.fitness_center_rounded,
      gradientColors: [
        context.colors.warningSurface,
        context.colors.warningSurface,
        context.colors.warningSurface,
      ],
      accentColor: context.colors.error,
      assetPath: 'assets/images/resident_dashboard/tools.png',
    );
  }

  // 3. Farming
  if (cat == 'farming' ||
      cat == 'farm' ||
      cat.contains('farm') ||
      cat.contains('plant') ||
      cat.contains('garden') ||
      cat.contains('agri') ||
      cat.contains('harvest')) {
    return _CategoryVisualConfig(
      label: 'Farming',
      mainIcon: Icons.eco_rounded,
      backgroundWatermarkIcon: Icons.yard_rounded,
      gradientColors: [
        context.colors.surfaceAlt,
        context.colors.surfaceAlt,
        context.colors.successSurface,
      ],
      accentColor: context.colors.textPrimary,
      assetPath: 'assets/images/resident_dashboard/plants.png',
    );
  }

  // 4. Hauling
  if (cat == 'hauling' ||
      cat == 'haul' ||
      cat.contains('haul') ||
      cat.contains('hakot') ||
      cat.contains('lift') ||
      cat.contains('mov') ||
      cat.contains('carry')) {
    return _CategoryVisualConfig(
      label: 'Hauling',
      mainIcon: Icons.local_shipping_rounded,
      backgroundWatermarkIcon: Icons.local_shipping_rounded,
      gradientColors: [
        context.colors.infoSurface,
        context.colors.infoSurface,
        context.colors.infoSurface,
      ],
      accentColor: context.colors.info,
      assetPath: null,
    );
  }

  // 5. Care
  if (cat == 'care' ||
      cat.contains('care') ||
      cat.contains('elder') ||
      cat.contains('senior') ||
      cat.contains('medic') ||
      cat.contains('health') ||
      cat.contains('child') ||
      cat.contains('assist') ||
      cat.contains('nurse')) {
    return _CategoryVisualConfig(
      label: 'Care',
      mainIcon: Icons.volunteer_activism_rounded,
      backgroundWatermarkIcon: Icons.favorite_rounded,
      gradientColors: [
        context.colors.surfaceAlt,
        context.colors.surfaceAlt,
        context.colors.surfaceAlt,
      ],
      accentColor: context.colors.primaryGreen,
      assetPath: null,
    );
  }

  // 6. Animals
  if (cat == 'animals' ||
      cat == 'animal' ||
      cat.contains('animal') ||
      cat.contains('pet') ||
      cat.contains('dog') ||
      cat.contains('cat') ||
      cat.contains('goat') ||
      cat.contains('kanding') ||
      cat.contains('livestock')) {
    return _CategoryVisualConfig(
      label: 'Animals',
      mainIcon: Icons.pets_rounded,
      backgroundWatermarkIcon: Icons.cruelty_free_rounded,
      gradientColors: [
        context.colors.purpleSurface,
        context.colors.purpleSurface,
        context.colors.purpleSurface,
      ],
      accentColor: context.colors.purple,
      assetPath: 'assets/images/resident_dashboard/livestock.png',
    );
  }

  // 7. Tech
  if (cat == 'tech' ||
      cat.contains('tech') ||
      cat.contains('it') ||
      cat.contains('computer') ||
      cat.contains('software') ||
      cat.contains('phone') ||
      cat.contains('device')) {
    return _CategoryVisualConfig(
      label: 'Tech',
      mainIcon: Icons.devices_rounded,
      backgroundWatermarkIcon: Icons.computer_rounded,
      gradientColors: [
        context.colors.infoSurface,
        context.colors.infoSurface,
        context.colors.infoSurface,
      ],
      accentColor: context.colors.textPrimary,
      assetPath: null,
    );
  }

  // Fallbacks for specific custom categories
  if (cat.contains('clean') ||
      cat.contains('house') ||
      cat.contains('home') ||
      cat.contains('chore')) {
    return _CategoryVisualConfig(
      label: 'Cleaning',
      mainIcon: Icons.cleaning_services_rounded,
      backgroundWatermarkIcon: Icons.home_repair_service_rounded,
      gradientColors: [
        context.colors.surfaceAlt,
        context.colors.surfaceAlt,
        context.colors.successSurface,
      ],
      accentColor: context.colors.primaryGreen,
      assetPath: 'assets/images/resident_dashboard/household.png',
    );
  }
  if (cat.contains('food') || cat.contains('meal') || cat.contains('cook')) {
    return _CategoryVisualConfig(
      label: 'Cooking',
      mainIcon: Icons.restaurant_rounded,
      backgroundWatermarkIcon: Icons.lunch_dining_rounded,
      gradientColors: [
        context.colors.errorSurface,
        context.colors.errorSurface,
        context.colors.errorSurface,
      ],
      accentColor: context.colors.error,
      assetPath: null,
    );
  }

  // 8. Other / Custom user category fallback
  return _CategoryVisualConfig(
    label:
        rawCategory.trim().isNotEmpty &&
            rawCategory.trim().toLowerCase() != 'other'
        ? rawCategory.trim()
        : 'Other',
    mainIcon: Icons.more_horiz_rounded,
    backgroundWatermarkIcon: Icons.category_rounded,
    gradientColors: [
      context.colors.surfaceAlt,
      context.colors.surfaceAlt,
      context.colors.brand,
    ],
    accentColor: context.colors.textPrimary,
    assetPath: null,
  );
}

class _JobsPageState extends State<JobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _activeTabIndex = 0;
  int _myActivitySubIndex = 0; // 0: My Requests, 1: Helping
  String _feedFilter = 'All'; // 'All', 'Urgent', 'Mine', 'Others', 'Saved'
  String _selectedCategory =
      'All'; // 'All', 'Errands', 'Manual Labor', 'Technical/IT', 'Elder Care', 'Pet Care', 'Emergency/Urgent'
  bool _initialRequestOpened = false;
  final Set<String> _savedJobIds = <String>{};
  final ValueNotifier<int> _savedJobsRevision = ValueNotifier<int>(0);
  final Map<String, _RequesterProfile> _posterProfileCache = {};

  @override
  void initState() {
    super.initState();
    _loadSavedJobIds();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_activeTabIndex == _tabController.index) return;
      setState(() => _activeTabIndex = _tabController.index);
    });
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        final query = _searchController.text.toLowerCase();
        if (query != _searchQuery) setState(() => _searchQuery = query);
      });
    });
    if (widget.initialRequestId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openInitialRequest(),
      );
    }
  }

  Future<void> _openInitialRequest() async {
    final requestId = widget.initialRequestId;
    if (_initialRequestOpened || requestId == null || requestId.isEmpty) return;
    _initialRequestOpened = true;
    try {
      final job = await JobsService.getJob(requestId);
      if (!mounted) return;
      if (job == null) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('This help request is no longer available.'),
            kind: FeedbackKind.warning,
          ),
        );
        return;
      }
      await _showJobDetails(job);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('The request could not be opened. Try again.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  Future<void> _loadSavedJobIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_bayanihan_job_ids') ?? [];
      if (mounted && list.isNotEmpty) {
        setState(() {
          _savedJobIds.addAll(list);
          _savedJobsRevision.value++;
        });
      }
    } catch (_) {}
  }

  Future<void> _persistSavedJobIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'saved_bayanihan_job_ids',
        _savedJobIds.toList(),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _savedJobsRevision.dispose();
    super.dispose();
  }

  void _ensureVerified(
    BuildContext context, {
    required VoidCallback onVerified,
  }) {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Please sign in to participate in Bayanihan Works.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }
    if (!user.canUseInteractiveFeatures) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: dialogContext.colors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resident verification required',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Verify your account before participating in Bayanihan Works.',
            style: GoogleFonts.outfit(
              color: dialogContext.colors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                foregroundColor: dialogContext.colors.onAccent,

                backgroundColor: dialogContext.colors.brand,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                );
              },
              child: const Text('Verify Now'),
            ),
          ],
        ),
      );
      return;
    }
    onVerified();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildHeader(),
          SliverToBoxAdapter(
            key: const ValueKey('sliver-top-search-bar'),
            child: _buildTopSearchBar(),
          ),
          SliverToBoxAdapter(
            key: const ValueKey('sliver-main-tab-bar'),
            child: _build3DMainTabBar(),
          ),
          if (_activeTabIndex == 0)
            SliverToBoxAdapter(
              key: const ValueKey('sliver-feed-filter'),
              child: _buildFeedCategoryFilters(),
            )
          else
            SliverToBoxAdapter(
              key: const ValueKey('sliver-activity-subtabs'),
              child: _buildMyActivitySubTabs(),
            ),
        ],
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _activeTabIndex == 0
              ? KeyedSubtree(
                  key: const ValueKey('tab-help-requests'),
                  child: _buildHelpRequestsFeed(),
                )
              : KeyedSubtree(
                  key: const ValueKey('tab-my-activity'),
                  child: _buildMyActivityContent(),
                ),
        ),
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildHeader() {
    return ESugidSliverPageHeader(
      sectionLabelWidget: _buildCivicBadge(),
      title: 'Bayanihan Works',
      showBackButton: true,
      onBack: () => Navigator.maybePop(context),
      endPadding: 4,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _build3DSavedRequestsHeaderButton(),
          const SizedBox(width: 6),
          const BayanihanUnreadButton(),
        ],
      ),
    );
  }

  Widget _build3DSavedRequestsHeaderButton() {
    return ValueListenableBuilder<int>(
      valueListenable: _savedJobsRevision,
      builder: (context, revision, child) {
        final savedCount = _savedJobIds.length;
        final hasSaved = savedCount > 0;

        return Semantics(
          button: true,
          label: 'Saved Requests ($savedCount)',
          child: Tooltip(
            message: 'Saved Requests ($savedCount)',
            child: ESugidPressable(
              onTap: () => _showSavedRequestsSheet(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hasSaved
                              ? [
                                  context.colors.warningSolid,
                                  context.colors.warningSolid,
                                ]
                              : [
                                  context.colors.surface.withValues(alpha: 0.22,
                                  ),
                                  context.colors.surface.withValues(alpha: 0.08,
                                  ),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasSaved
                              ? context.colors.border
                              : context.colors.border.withValues(alpha: 0.42),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.22,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          if (hasSaved)
                            BoxShadow(
                              color: context.colors.highlight.withValues(alpha: 0.45,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          hasSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: hasSaved ? context.colors.error
                              : context.colors.onAccent,
                          size: 21,
                        ),
                      ),
                    ),
                    if (savedCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.elasticOut,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 19),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.errorSolid,
                                  context.colors.errorSolid,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: context.colors.border, width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.errorSolid.withValues(alpha: 0.55,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              savedCount > 99 ? '99+' : '$savedCount',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.colors.onAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCivicBadge() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.brandStrong.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.85),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.3804),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.warningSolid,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.highlight,
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'BARILI COMMUNITY NETWORK',
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: context.colors.onBrandMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DMainTabBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surface, context.colors.surfaceAlt],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(999),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.brand,
              context.colors.brand,
              context.colors.brandStrong,
            ],
            stops: [0.0, 0.58, 1.0],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.38),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.36),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.12),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: context.colors.onAccent,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_rounded, size: 15),
                SizedBox(width: 6),
                Text('Help Requests'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_pin_rounded, size: 16),
                SizedBox(width: 6),
                Text('My Activity'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    return Semantics(
      button: true,
      label: 'Ask for Help',
      child: ESugidPressable(
        onTap: () {
          _ensureVerified(
            context,
            onVerified: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RequestHelpPage(),
                ),
              );
            },
          );
        },
        child: Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.brand,
                context.colors.brand,
                context.colors.brand,
                context.colors.brandStrong,
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.90),
              width: 1.5,
            ),
            boxShadow: [
              // 1. Radiant luminous emerald bloom
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              // 2. Realistic 3D floor shadow
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.40),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              // 3. Top specular light rim
              BoxShadow(
                color: context.colors.highlight.withValues(alpha: 0.3843),
                blurRadius: 0,
                offset: Offset(0, -1.8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top Specular Crystal Highlight Line
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  height: 1.8,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.surface.withValues(alpha: 0.0),
                          context.colors.surface.withValues(alpha: 0.95),
                          context.colors.surface.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Elevated 3D Glossy Icon Badge
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surface,
                            context.colors.surfaceAlt,
                            context.colors.surfaceAlt,
                          ],
                        ),
                        border: Border.all(
                          color: context.colors.border,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.18,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.35,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: context.colors.primaryGreen,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ask for Help',
                      style: GoogleFonts.outfit(
                        color: context.colors.onBrandMuted,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: context.colors.textPrimary.withValues(alpha: 0.40,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchBar() {
    final hasActiveFilter = _feedFilter != 'All';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.surface, context.colors.surface],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: _activeTabIndex == 0
                      ? 'Search help requests...'
                      : 'Search your activity...',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.surfaceAlt,
                            context.colors.surfaceAlt,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.15,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: context.colors.primaryGreen,
                        size: 18,
                      ),
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: context.colors.disabledBackground
                                  .withValues(
                                alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 3D Filter Button with active indicator badge
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: context.colors.brand.withValues(alpha: 0.1),
            ),
            child: PopupMenuButton<String>(
              onSelected: (String value) {
                setState(() {
                  _feedFilter = value;
                  if (_activeTabIndex != 0) {
                    _tabController.animateTo(0);
                  }
                });
              },
              offset: const Offset(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: context.colors.border,
                  width: 1.2),
              ),
              itemBuilder: (context) => [
                _buildPopupItem(
                  'All',
                  'All Requests',
                  Icons.auto_awesome_mosaic_rounded,
                ),
                _buildPopupItem(
                  'Urgent',
                  'Urgent Only',
                  Icons.priority_high_rounded,
                ),
                _buildPopupItem('Mine', 'My Requests', Icons.stars_rounded),
                _buildPopupItem(
                  'Others',
                  'From Neighbors',
                  Icons.explore_rounded,
                ),
                _buildPopupItem(
                  'Saved',
                  'Saved Requests',
                  Icons.bookmark_rounded,
                ),
              ],
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brand,
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(
                            alpha: 0.38,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: context.colors.onAccent,
                      size: 22,
                    ),
                  ),
                  if (hasActiveFilter)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: context.colors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.colors.border, width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadow.withValues(
                                alpha: 0.2588,
                              ),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
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

  Widget _buildFeedCategoryFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_feedFilter == 'Saved') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.surfaceAlt,
                    context.colors.surfaceAlt,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: context.colors.onAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Requests (${_savedJobIds.length})',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                        Text(
                          'All requests you have saved',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _feedFilter = 'All'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.04,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'Show All',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_feedFilter != 'Saved')
            _buildQuickCategoryChips(),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryChips() {
    final categories = [
      {
        'id': 'All',
        'label': 'All',
        'icon': Icons.grid_view_rounded,
        'accent': context.colors.primaryGreen,
      },
      {
        'id': 'Errands',
        'label': 'Errands',
        'icon': Icons.directions_run_rounded,
        'accent': context.colors.warning,
      },
      {
        'id': 'Repairs',
        'label': 'Repairs',
        'icon': Icons.handyman_rounded,
        'accent': context.colors.error,
      },
      {
        'id': 'Farming',
        'label': 'Farming',
        'icon': Icons.eco_rounded,
        'accent': context.colors.primaryGreen,
      },
      {
        'id': 'Hauling',
        'label': 'Hauling',
        'icon': Icons.local_shipping_rounded,
        'accent': context.colors.info,
      },
      {
        'id': 'Care',
        'label': 'Care',
        'icon': Icons.volunteer_activism_rounded,
        'accent': context.colors.primaryGreen,
      },
      {
        'id': 'Animals',
        'label': 'Animals',
        'icon': Icons.pets_rounded,
        'accent': context.colors.purple,
      },
      {
        'id': 'Tech',
        'label': 'Tech',
        'icon': Icons.devices_rounded,
        'accent': context.colors.info,
      },
      {
        'id': 'Other',
        'label': 'Other',
        'icon': Icons.more_horiz_rounded,
        'accent': context.colors.textSecondary,
      },
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final id = cat['id'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final accent = cat['accent'] as Color;
          final isSelected = _selectedCategory == id;

          return ESugidPressable(
            onTap: () => setState(() => _selectedCategory = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brand,
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                      )
                    : null,
                color: isSelected ? null : context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? context.colors.border.withValues(alpha: 0.45)
                      : context.colors.border,
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? context.colors.brandStrong.withValues(alpha: 0.32)
                        : context.colors.shadow.withValues(alpha: 0.035),
                    blurRadius: isSelected ? 8 : 4,
                    offset: Offset(0, isSelected ? 3 : 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? context.colors.onAccent : accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? context.colors.onAccent
                          : context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesCategory(String jobCategory, String selectedCategory) {
    if (selectedCategory == 'All') return true;
    final jc = jobCategory.trim().toLowerCase();
    final sc = selectedCategory.trim().toLowerCase();

    if (sc == 'errands') {
      return jc == 'errands' ||
          jc.contains('errand') ||
          jc.contains('deliver') ||
          jc.contains('pabili');
    }
    if (sc == 'repairs') {
      return jc == 'repairs' ||
          jc == 'repair' ||
          jc.contains('repair') ||
          jc.contains('labor') ||
          jc.contains('manual') ||
          jc.contains('handyman') ||
          jc.contains('construct') ||
          jc.contains('tool') ||
          jc.contains('fix') ||
          jc.contains('plumb') ||
          jc.contains('electric') ||
          jc.contains('carpenter');
    }
    if (sc == 'farming') {
      return jc == 'farming' ||
          jc == 'farm' ||
          jc.contains('farm') ||
          jc.contains('plant') ||
          jc.contains('garden') ||
          jc.contains('agri') ||
          jc.contains('harvest');
    }
    if (sc == 'hauling') {
      return jc == 'hauling' ||
          jc == 'haul' ||
          jc.contains('haul') ||
          jc.contains('hakot') ||
          jc.contains('lift') ||
          jc.contains('mov') ||
          jc.contains('carry');
    }
    if (sc == 'care') {
      return jc == 'care' ||
          jc.contains('care') ||
          jc.contains('elder') ||
          jc.contains('senior') ||
          jc.contains('medic') ||
          jc.contains('health') ||
          jc.contains('child') ||
          jc.contains('assist') ||
          jc.contains('nurse');
    }
    if (sc == 'animals') {
      return jc == 'animals' ||
          jc == 'animal' ||
          jc.contains('animal') ||
          jc.contains('pet') ||
          jc.contains('dog') ||
          jc.contains('cat') ||
          jc.contains('goat') ||
          jc.contains('kanding') ||
          jc.contains('livestock');
    }
    if (sc == 'tech') {
      return jc == 'tech' ||
          jc.contains('tech') ||
          jc.contains('it') ||
          jc.contains('computer') ||
          jc.contains('software') ||
          jc.contains('phone') ||
          jc.contains('device');
    }
    if (sc == 'other') {
      final isKnown =
          _matchesCategory(jobCategory, 'Errands') ||
          _matchesCategory(jobCategory, 'Repairs') ||
          _matchesCategory(jobCategory, 'Farming') ||
          _matchesCategory(jobCategory, 'Hauling') ||
          _matchesCategory(jobCategory, 'Care') ||
          _matchesCategory(jobCategory, 'Animals') ||
          _matchesCategory(jobCategory, 'Tech');
      return !isKnown || jc == 'other' || jc.contains('other');
    }

    return jc == sc || jc.contains(sc);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Errands':
        return Icons.directions_run_rounded;
      case 'Repairs':
        return Icons.handyman_rounded;
      case 'Farming':
        return Icons.eco_rounded;
      case 'Hauling':
        return Icons.local_shipping_rounded;
      case 'Care':
        return Icons.volunteer_activism_rounded;
      case 'Animals':
        return Icons.pets_rounded;
      case 'Tech':
        return Icons.devices_rounded;
      case 'Other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = _feedFilter == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? context.colors.primaryGreen
                : context.colors.textSecondary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(
              Icons.check_circle_rounded,
              color: context.colors.primaryGreen,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpRequestsFeed() {
    return StreamBuilder<List<JobItem>>(
      stream: JobsService.jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.primaryGreen,
            ),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }

        final user = AuthService.currentUser;

        List<JobItem> requests;
        if (_feedFilter == 'Saved') {
          requests = (snapshot.data ?? [])
              .where(
                (j) => j.category == 'request' && _savedJobIds.contains(j.id),
              )
              .toList();
        } else {
          // ONLY Open / Active requests that still need assistance
          requests = (snapshot.data ?? [])
              .where(
                (j) =>
                    j.category == 'request' &&
                    j.status.toLowerCase() == 'active' &&
                    j.acceptedHelperCount < j.helpersNeeded,
              )
              .toList();

          if (_feedFilter == 'Urgent') {
            requests = requests
                .where((j) => j.urgency.toLowerCase() == 'urgent')
                .toList();
          } else if (user != null) {
            if (_feedFilter == 'Mine') {
              requests = requests.where((j) => j.posterId == user.uid).toList();
            } else if (_feedFilter == 'Others') {
              requests = requests.where((j) => j.posterId != user.uid).toList();
            }
          }
        }

        // Search Filter
        if (_searchQuery.isNotEmpty) {
          requests = requests.where((j) {
            final titleMatch = j.title.toLowerCase().contains(_searchQuery);
            final descMatch = j.description.toLowerCase().contains(
              _searchQuery,
            );
            final companyMatch = j.company.toLowerCase().contains(_searchQuery);
            final locationMatch = j.location.toLowerCase().contains(
              _searchQuery,
            );
            final categoryMatch = j.helpCategory.toLowerCase().contains(
              _searchQuery,
            );
            return titleMatch ||
                descMatch ||
                companyMatch ||
                locationMatch ||
                categoryMatch;
          }).toList();
        }

        // Category Filter (from horizontal category chips) - NOT applied when viewing pure Saved requests!
        if (_feedFilter != 'Saved' && _selectedCategory != 'All') {
          requests = requests
              .where((j) => _matchesCategory(j.helpCategory, _selectedCategory))
              .toList();
        }

        if (requests.isEmpty) {
          final isFilteredByCategory =
              _feedFilter != 'Saved' && _selectedCategory != 'All';
          return _buildEmptyState(
            icon: isFilteredByCategory
                ? _getCategoryIcon(_selectedCategory)
                : (_feedFilter == 'Saved'
                      ? Icons.bookmark_border_rounded
                      : Icons.handshake_rounded),
            title: isFilteredByCategory
                ? 'No $_selectedCategory Requests'
                : (_feedFilter == 'Saved'
                      ? 'No Saved Requests'
                      : 'No Help Requests Yet'),
            message: isFilteredByCategory
                ? 'No requests found for "$_selectedCategory".\n\nCheck back later or tap "+ Ask for Help"!'
                : (_feedFilter == 'Saved'
                      ? 'You have not saved any requests yet.\n\nTap the bookmark icon on any request to save it here.'
                      : 'No help requests right now.\n\nTap "+ Ask for Help" if you need a helping hand!'),
          );
        }

        return ListView.builder(
          key: const ValueKey('bayanihan-help-requests-list'),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 100),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return ESugidEntrance(
              enabled: index <= 5,
              child: _buildHelpRequestCard(requests[index]),
            );
          },
        );
      },
    );
  }

  Future<_RequesterProfile> _fetchPosterProfile(JobItem job) async {
    final posterId = job.posterId.trim();
    if (posterId.isEmpty) {
      return _RequesterProfile(
        name: job.company.isNotEmpty ? job.company : 'Neighbor',
        isVerified: true,
      );
    }

    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.uid == posterId) {
      final profile = _RequesterProfile(
        name: currentUser.name.isNotEmpty
            ? currentUser.name
            : (job.company.isNotEmpty ? job.company : 'Neighbor'),
        photoUrl: currentUser.profilePhotoUrl,
        isVerified: currentUser.isVerified,
      );
      _posterProfileCache[posterId] = profile;
      return profile;
    }

    // The shared cache includes avatar-less profiles, coalesces requests, and
    // revalidates after two minutes instead of permanently pinning an avatar.
    try {
      final trust = await CommunityTrustService().getTrustProfile(posterId);
      if (trust != null) {
        final profile = _RequesterProfile(
          name: trust.displayName.isNotEmpty
              ? trust.displayName
              : (job.company.isNotEmpty ? job.company : 'Neighbor'),
          photoUrl: trust.profilePhotoUrl,
          isVerified: trust.isVerified,
        );
        _posterProfileCache[posterId] = profile;
        return profile;
      }
    } catch (_) {}

    final cached = _posterProfileCache[posterId];
    if (cached != null) return cached;

    // 3. Fallback direct read attempt
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(posterId)
          .get();
      if (doc.exists && doc.data() != null) {
        final u = User.fromMap(doc.data()!);
        final profile = _RequesterProfile(
          name: u.name.isNotEmpty
              ? u.name
              : (job.company.isNotEmpty ? job.company : 'Neighbor'),
          photoUrl: u.profilePhotoUrl,
          isVerified: u.isVerified,
        );
        _posterProfileCache[posterId] = profile;
        return profile;
      }
    } catch (_) {}

    final fallback = _RequesterProfile(
      name: job.company.isNotEmpty ? job.company : 'Neighbor',
      isVerified: true,
    );
    _posterProfileCache[posterId] = fallback;
    return fallback;
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1 ? '1 min ago' : '$m mins ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return d == 1 ? 'yesterday' : '$d days ago';
    } else if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return w == 1 ? '1 week ago' : '$w weeks ago';
    } else {
      final mo = (diff.inDays / 30).floor();
      return mo == 1 ? '1 month ago' : '$mo months ago';
    }
  }

  String _formatItemAge(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return DateFormat('MMM d').format(date);
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _toggleSavedRequest(JobItem job) {
    final willBeSaved = !_savedJobIds.contains(job.id);
    setState(() {
      if (willBeSaved) {
        _savedJobIds.add(job.id);
      } else {
        _savedJobIds.remove(job.id);
      }
    });
    _savedJobsRevision.value++;
    _persistSavedJobIds();
    HapticFeedback.lightImpact();
  }

  Widget _buildHelpRequestCard(JobItem job) {
    final posterId = job.posterId.trim();
    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.uid == posterId) {
      final profile = _RequesterProfile(
        name: currentUser.name.isNotEmpty
            ? currentUser.name
            : (job.company.isNotEmpty ? job.company : 'Neighbor'),
        photoUrl: currentUser.profilePhotoUrl,
        isVerified: currentUser.isVerified,
      );
      return _buildHelpRequestCardContent(job, profile);
    }

    final cachedTrust = CommunityTrustService.getCachedProfile(posterId);
    if (cachedTrust != null) {
      final profile = _RequesterProfile(
        name: cachedTrust.displayName.isNotEmpty
            ? cachedTrust.displayName
            : (job.company.isNotEmpty ? job.company : 'Neighbor'),
        photoUrl: cachedTrust.profilePhotoUrl,
        isVerified: cachedTrust.isVerified,
      );
      _posterProfileCache[posterId] = profile;
    }

    return FutureBuilder<_RequesterProfile>(
      future: _fetchPosterProfile(job),
      initialData: _posterProfileCache[posterId],
      builder: (context, snapshot) {
        final profile =
            snapshot.data ??
            _posterProfileCache[posterId] ??
            _RequesterProfile(
              name: job.company.isNotEmpty ? job.company : 'Neighbor',
              isVerified: true,
            );
        return _buildHelpRequestCardContent(job, profile);
      },
    );
  }

  Widget _buildHelpRequestCardContent(JobItem job, _RequesterProfile profile) {
    final isUrgent = job.urgency.toLowerCase() == 'urgent';
    final isNew = DateTime.now().difference(job.createdAt).inHours < 48;
    final isFull = job.acceptedHelperCount >= job.helpersNeeded;
    final user = AuthService.currentUser;
    final isOwner = user?.uid == job.posterId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Highlight Gold Badge calculation (Matches Local Market gold badge)
    final String primaryBadgeText;
    final String secondaryBadgeText;
    final trimmedSalary = job.salary.trim();
    if (trimmedSalary.isNotEmpty &&
        trimmedSalary != '0' &&
        trimmedSalary.toLowerCase() != 'volunteer') {
      primaryBadgeText = trimmedSalary.startsWith('₱') ? trimmedSalary : '₱$trimmedSalary';
      secondaryBadgeText = '/ allowance';
    } else {
      if (job.helpersNeeded > 1) {
        primaryBadgeText = '${job.helpersNeeded} Helpers';
        secondaryBadgeText = '/ needed';
      } else {
        primaryBadgeText = 'Volunteer';
        secondaryBadgeText = '/ 1 needed';
      }
    }

    final categoryName = (job.helpCategory.isNotEmpty
            ? job.helpCategory
            : (job.category.isNotEmpty ? job.category : 'COMMUNITY HELP'))
        .toUpperCase();

    final locationBase = job.location.isNotEmpty ? job.location : 'Barili, Cebu';
    final distanceKm = (job.id.codeUnits.fold<int>(0, (a, b) => a + b) % 8) + 1;
    final locationText = '$locationBase · $distanceKm km away';

    return Semantics(
      label:
          'Help request by ${profile.name}: ${job.title}, category: $categoryName. Urgency: ${job.urgency}.',
      button: true,
      onTapHint: 'View request details',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            // Deep realistic 3D floor shadow
            BoxShadow(
              color: isDark
                  ? context.colors.brandStrong.withValues(alpha: 0.45)
                  : context.colors.brandStrong.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Subtle ambient shadow
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            // Top specular porcelain reflection
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: isDark ? 0.06 : 0.95,
              ),
              blurRadius: 0,
              offset: const Offset(0, -1.2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showJobDetails(job),
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [context.colors.surface, context.colors.surface]
                      : [
                          context.colors.surface,
                          context.colors.surface,
                          context.colors.surface,
                        ],
                ),
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: Requester Avatar + Name & Age + Status Badge + 3D Heart Favorite
                    Row(
                      children: [
                        // Requester Info (Tappable to view public profile)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => PublicUserProfilePage.show(
                              context,
                              job.posterId,
                              initialName: profile.name.isNotEmpty
                                  ? profile.name
                                  : (job.company.isNotEmpty ? job.company : null),
                              initialBarangay: job.location,
                            ),
                            child: Row(
                              children: [
                                // Avatar circle with subtle 3D border
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.surfaceAlt.withValues(
                                      alpha: isDark ? 0.20 : 0.85,
                                    ),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.shadow.withValues(alpha: 0.08,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: ClipOval(
                                      child: (profile.photoUrl != null &&
                                              profile.photoUrl!.isNotEmpty)
                                          ? Image.network(
                                              profile.photoUrl!,
                                              width: 38,
                                              height: 38,
                                              cacheWidth: (38 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  _buildMiniAvatarFallback(profile.name,
                                                  ),
                                            )
                                          : _buildMiniAvatarFallback(profile.name,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Requester Name + Verified Badge + Age
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              profile.name.isNotEmpty
                                                  ? profile.name
                                                  : (job.company.isNotEmpty
                                                      ? job.company
                                                      : 'Barili Neighbor'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    context.colors.textPrimary,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.verified_rounded,
                                              size: 14,
                                              color:
                                                  context.colors.primaryGreen,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _formatItemAge(job.createdAt),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Status Pill Badge (e.g. AVAILABLE / URGENT / HELP FOUND)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isFull
                                ? (isDark ? context.colors.surfaceAlt.withValues(
                                          alpha: 0.1020,
                                        )
                                      : context.colors.surfaceAlt)
                                : (isUrgent
                                    ? context.colors.errorSurface
                                      : (isDark
                                        ? context.colors.surfaceAlt
                                                  .withValues(alpha: 0.6)
                                        : context.colors.surfaceAlt)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFull
                                  ? (isDark ? context.colors.border.withValues(
                                            alpha: 0.2392,
                                          )
                                  : context.colors.border)
                                      : (isUrgent
                                        ? context.colors.error
                                        : (context.colors.border)),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            isFull
                                ? 'HELP FOUND'
                                : (isUrgent ? 'URGENT' : 'AVAILABLE'),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isFull
                                  ? context.colors.textSecondary
                                  : (isUrgent
                                      ? context.colors.error
                                        : (context.colors.primaryGreen)),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3D Glossy Save / Bookmark Button
                        ValueListenableBuilder<int>(
                          valueListenable: _savedJobsRevision,
                          builder: (context, revision, child) {
                            final isSaved = _savedJobIds.contains(job.id);
                            return Semantics(
                              button: true,
                              label: isSaved ? 'Remove from saved' : 'Save request',
                              child: Tooltip(
                                message: isSaved ? 'Remove from saved' : 'Save request',
                                child: ESugidPressable(
                                  onTap: () => _toggleSavedRequest(job),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isSaved
                                            ? [
                                                context.colors.warningSurface,
                                                context.colors.warningSolid,
                                              ]
                                            : [
                                                context.colors.surface,
                                                context.colors.surfaceAlt,
                                              ],
                                      ),
                                      border: Border.all(
                                        color: isSaved
                                            ? context.colors.border
                                            : context.colors.border,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSaved
                                              ? context.colors.highlight
                                                    .withValues(alpha: 0.3)
                                              : context.colors.shadow
                                                    .withValues(alpha: 0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isSaved
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_border_rounded,
                                        color: isSaved
                                            ? context.colors.warning
                                            : context.colors.textSecondary,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo Squircle (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Tag
                              Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.primaryGreen,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Request Title
                              Text(
                                job.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: context.colors.textPrimary,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Gold & Emerald Badge
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.brandStrong,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        primaryBadgeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.onBrandMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (secondaryBadgeText.isNotEmpty) ...[
                                        const SizedBox(width: 3),
                                        Text(
                                          secondaryBadgeText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.onBrandMuted
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Location Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13.5,
                                    color: context.colors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      locationText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Right: Generous 3D Photo Squircle (124x124)
                        Hero(
                          tag: 'bayanihan-job-image-${job.id}',
                          flightShuttleBuilder: _heroBayanihanFlightShuttle,
                          child: Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark
                                    ? context.colors.primaryGreen
                                    : context.colors.border,
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(
                                    alpha: isDark ? 0.35 : 0.12,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.14,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildRightPhotoTile(
                                job: job,
                                isUrgent: isUrgent,
                                isNew: isNew,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Bottom Row: 3D Highlighted Tactile Action Button
                    ESugidPressable(
                      onTap: () => _showJobDetails(job),
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: isFull
                              ? LinearGradient(
                                  colors: [
                                    context.colors.disabledBackground,
                                    context.colors.disabledBackground,
                                  ],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.colors.brand,
                                    context.colors.brand,
                                    context.colors.brandStrong,
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isFull
                                ? context.colors.border.withValues(
                                    alpha: 0.2392,
                                  )
                                : context.colors.border.withValues(alpha: 0.90),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (!isFull) ...[
                              // Vibrant radiant luxury depth shadow
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.45,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 5),
                              ),
                              // Top specular 3D light reflection
                              BoxShadow(
                                color: context.colors.highlight.withValues(
                                  alpha: 0.3843,
                                ),
                                blurRadius: 0,
                                offset: Offset(0, -1.8),
                              ),
                            ],
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Top Specular Crystal Highlight Line
                              if (!isFull)
                                Positioned(
                                  top: 0,
                                  left: 20,
                                  right: 20,
                                  height: 1.6,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          context.colors.surface.withValues(alpha: 0.0,
                                          ),
                                          context.colors.surface.withValues(alpha: 0.95,
                                          ),
                                          context.colors.surface.withValues(alpha: 0.0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        isOwner
                                            ? 'VIEW REQUEST'
                                            : isFull
                                                ? 'HELP FOUND'
                                                : 'I CAN HELP',
                                        style: GoogleFonts.outfit(
                                          color: isFull
                                              ? context.colors.onAccent
                                              : Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        shadows: [
                                          Shadow(
                                            color: context.colors.textPrimary
                                                .withValues(alpha: 0.35),
                                            offset: const Offset(0, 1.5),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isOwner
                                          ? Icons.tune_rounded
                                          : isFull
                                              ? Icons.check_circle_outline_rounded
                                              : Icons.volunteer_activism_rounded,
                                      color: isFull
                                            ? context.colors.onAccent
                                            : Colors.white,
                                        size: 19,
                                      shadows: [
                                        Shadow(
                                          color: context.colors.textPrimary
                                              .withValues(alpha: 0.35),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroBayanihanFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final Hero toHero = toHeroContext.widget as Hero;
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final t = curvedAnimation.value;
        final currentRadius = lerpDouble(22, 22, t) ?? 22.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(currentRadius),
          child: Material(color: Colors.transparent, child: toHero.child),
        );
      },
    );
  }

  Widget _buildRightPhotoTile({
    required JobItem job,
    required bool isUrgent,
    required bool isNew,
  }) {
    final photoUrl = job.imageUrl?.trim();
    final hasTaskPhoto = photoUrl != null && photoUrl.isNotEmpty;

    if (!hasTaskPhoto) {
      return _buildCategoryPlaceholderTile(
        category: job.helpCategory,
        isUrgent: isUrgent,
        isNew: isNew,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          photoUrl,
          fit: BoxFit.cover,
          cacheWidth: 600,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildCategoryPlaceholderTile(
              category: job.helpCategory,
              isUrgent: isUrgent,
              isNew: isNew,
            );
          },
          errorBuilder: (_, _, _) => _buildCategoryPlaceholderTile(
            category: job.helpCategory,
            isUrgent: isUrgent,
            isNew: isNew,
          ),
        ),
        // 3D Specular Glass Sheen Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                context.colors.surface.withValues(alpha: 0.22),
                Colors.transparent,
                context.colors.shadow.withValues(alpha: 0.15),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPlaceholderTile({
    required String category,
    required bool isUrgent,
    required bool isNew,
  }) {
    final config = _getCategoryVisualConfig(context, category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.gradientColors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ambient watermark icon for high-end depth
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                config.backgroundWatermarkIcon,
                size: 94,
                color: context.colors.onAccent.withValues(alpha: 0.38),
              ),
            ),

            // 3D Diagonal Specular Glass Light
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    context.colors.surface.withValues(alpha: 0.28),
                    Colors.transparent,
                    context.colors.shadow.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),

            // Centered Category Visual & Label
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.colors.border, width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: config.accentColor.withValues(alpha: 0.20),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.06,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: config.assetPath != null
                            ? Image.asset(
                                config.assetPath!,
                                width: 30,
                                height: 30,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(
                                  config.mainIcon,
                                  size: 25,
                                  color: config.accentColor,
                                ),
                              )
                            : Icon(
                                config.mainIcon,
                                size: 25,
                                color: config.accentColor,
                              ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.6),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.05,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        config.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: config.accentColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatarFallback(String name, {double fontSize = 16}) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      color: context.colors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: context.colors.primaryGreen,
        ),
      ),
    );
  }


  Widget _buildMyActivitySubTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_buildCompletedHistoryButton()],
          ),
          const SizedBox(height: 10),
          // 3D Inset Track Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.colors.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentedPill(
                    label: 'My Requests',
                    index: 0,
                    icon: Icons.assignment_outlined,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSegmentedPill(
                    label: 'Helping',
                    index: 1,
                    icon: Icons.volunteer_activism_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedPill({
    required String label,
    required int index,
    required IconData icon,
  }) {
    final isSelected = _myActivitySubIndex == index;
    return GestureDetector(
      onTap: () {
        if (_myActivitySubIndex != index) {
          setState(() => _myActivitySubIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.surface, context.colors.surface],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: context.colors.border, width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedHistoryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCompletedHistorySheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.primaryGreen.withValues(alpha: 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 13,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Completed History',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 9.5,
                color: context.colors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletedHistorySheet() {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Please sign in to view your completed history.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.78,
          decoration: BoxDecoration(
            color: sheetContext.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.shadow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            sheetContext.colors.brand,
                            sheetContext.colors.brandStrong,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: sheetContext.colors.brandStrong.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.task_alt_rounded,
                        color: sheetContext.colors.onAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completed History',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: sheetContext.colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Bayanihan requests marked as completed',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: sheetContext.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: sheetContext.colors.shadow.withValues(alpha: 0.05,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: sheetContext.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: sheetContext.colors.border),
              Expanded(
                child: StreamBuilder<List<JobItem>>(
                  stream: JobsService.jobsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primaryGreen,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load completed history.',
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      );
                    }

                    final completedJobs = (snapshot.data ?? [])
                        .where(
                          (j) =>
                              j.posterId == user.uid &&
                              j.status.toLowerCase() == 'completed',
                        )
                        .toList();

                    if (completedJobs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceAlt,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.checklist_rtl_rounded,
                                  size: 40,
                                  color: context.colors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Completed Posts Yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When you mark any of your help requests as "Completed", it will appear here in your activity history.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: context.colors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: completedJobs.length,
                      itemBuilder: (context, index) {
                        final job = completedJobs[index];
                        final catConfig = _getCategoryVisualConfig(
                          context,
                          job.helpCategory,
                        );
                        final displayDate = job.scheduledAt != null
                            ? DateFormat('MMM d, yyyy').format(job.scheduledAt!)
                            : DateFormat('MMM d, yyyy').format(job.createdAt);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.03,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showJobDetails(job);
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: catConfig.gradientColors,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          catConfig.mainIcon,
                                          color: context.colors.onAccent,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: context.colors.brand
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: context
                                                        .colors
                                                        .primaryGreen
                                                        .withValues(alpha: 0.25,
                                                        ),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 9.5,
                                                      color: context
                                                          .colors
                                                          .primaryGreen,
                                                    ),
                                                    const SizedBox(width: 3.5),
                                                    Text(
                                                      'COMPLETED',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: 0.4,
                                                        color: context
                                                            .colors
                                                            .primaryGreen,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                displayDate,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  color: context
                                                      .colors
                                                      .textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            job.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                          if (job.description
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              job.description.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.5,
                                                color: context
                                                    .colors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 13,
                                      color: context.colors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildMyActivityContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _myActivitySubIndex == 0
          ? KeyedSubtree(
              key: const ValueKey('sub-tab-my-requests'),
              child: _buildMyRequestsList(),
            )
          : KeyedSubtree(
              key: const ValueKey('sub-tab-helping'),
              child: _buildHelpingList(),
            ),
    );
  }

  Widget _buildMyRequestsList() {
    final user = AuthService.currentUser;
    if (user == null) {
      return _buildSignInPrompt();
    }

    return StreamBuilder<List<JobItem>>(
      stream: JobsService.jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.primaryGreen,
            ),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }

        var myRequests = (snapshot.data ?? [])
            .where((j) => j.posterId == user.uid && j.category == 'request')
            .toList();

        if (_searchQuery.isNotEmpty) {
          myRequests = myRequests.where((j) {
            final titleMatch = j.title.toLowerCase().contains(_searchQuery);
            final descMatch = j.description.toLowerCase().contains(_searchQuery,
            );
            final companyMatch = j.company.toLowerCase().contains(_searchQuery);
            final locationMatch = j.location.toLowerCase().contains(_searchQuery,
            );
            return titleMatch || descMatch || companyMatch || locationMatch;
          }).toList();
        }

        if (myRequests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No Active Requests Yet',
            message:
                'Need help with chores, errands, or repairs? Ask your neighbors for help.',
            actionLabel: '+ Ask for Help',
            onAction: () {
              _ensureVerified(
                context,
                onVerified: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestHelpPage(),
                    ),
                  );
                },
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
          itemCount: myRequests.length,
          itemBuilder: (context, index) =>
              _buildMyRequestCard(myRequests[index]),
        );
      },
    );
  }

  Widget _buildMyRequestCard(JobItem req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = req.status.toLowerCase() == 'completed';
    final isCancelled = req.status.toLowerCase() == 'cancelled';
    final hasHelpers = req.acceptedHelperCount > 0;
    final isMatched = hasHelpers && !isCompleted && !isCancelled;
    final isUrgent = req.urgency.toLowerCase() == 'urgent';

    final String statusLabel;
    final String actionText;
    final IconData actionIcon;

    if (isCompleted) {
      statusLabel = 'Completed';
      actionText = 'View Details';
      actionIcon = Icons.assignment_outlined;
    } else if (isCancelled) {
      statusLabel = 'Cancelled';
      actionText = 'View Details';
      actionIcon = Icons.assignment_outlined;
    } else if (isMatched) {
      statusLabel = 'Matched';
      actionText = 'View Conversation';
      actionIcon = Icons.forum_rounded;
    } else {
      statusLabel = 'Open';
      actionText = 'View Offers';
      actionIcon = Icons.people_alt_rounded;
    }

    final String displayDate;
    if (req.scheduledAt != null) {
      displayDate = DateFormat(
        'MMM d, yyyy - hh:mm a',
      ).format(req.scheduledAt!);
    } else if (req.dateNeeded.trim().isNotEmpty) {
      displayDate = req.dateNeeded.trim();
    } else {
      displayDate = _formatItemAge(req.createdAt);
    }

    // Badge calculation matching Help Requests cards
    final String primaryBadgeText;
    final String secondaryBadgeText;
    final trimmedSalary = req.salary.trim();
    if (trimmedSalary.isNotEmpty &&
        trimmedSalary != '0' &&
        trimmedSalary.toLowerCase() != 'volunteer') {
      primaryBadgeText = trimmedSalary.startsWith('₱')
          ? trimmedSalary
          : '₱$trimmedSalary';
      secondaryBadgeText = '/ allowance';
    } else {
      if (req.helpersNeeded > 1) {
        primaryBadgeText = '${req.helpersNeeded} Helpers';
        secondaryBadgeText = '/ needed';
      } else if (isMatched) {
        primaryBadgeText = '${req.acceptedHelperCount} Helpers';
        secondaryBadgeText = '/ matched';
      } else {
        primaryBadgeText = 'Volunteer';
        secondaryBadgeText = '/ 1 needed';
      }
    }

    final categoryName = (req.helpCategory.isNotEmpty
            ? req.helpCategory
            : (req.category.isNotEmpty ? req.category : 'COMMUNITY HELP'))
        .toUpperCase();

    final locationBase =
        req.location.isNotEmpty ? req.location : 'Barili, Cebu';
    final distanceKm =
        (req.id.codeUnits.fold<int>(0, (a, b) => a + b) % 8) + 1;
    final locationText = '$locationBase · $distanceKm km away';

    final user = AuthService.currentUser;
    final userName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : (req.company.isNotEmpty ? req.company : 'You');
    final userPhoto = user?.profilePhotoUrl;
    final isVerified = user?.isVerified ?? true;

    return Semantics(
      label: 'My request: ${req.title}, status: $statusLabel.',
      button: true,
      onTapHint: 'Open request options',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            // Deep realistic 3D floor shadow
            BoxShadow(
              color: isDark
                  ? context.colors.brandStrong.withValues(alpha: 0.45)
                  : context.colors.brandStrong.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Subtle ambient shadow
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            // Top specular porcelain reflection
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: isDark ? 0.06 : 0.95,
              ),
              blurRadius: 0,
              offset: const Offset(0, -1.2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleMyRequestTap(req, isMatched),
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [context.colors.surface, context.colors.surface]
                      : [
                          context.colors.surface,
                          context.colors.surface,
                          context.colors.surface,
                        ],
                ),
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: User Info + "MY REQUEST" Pill + Status Pill
                    Row(
                      children: [
                        // User Info (Tappable to view public profile)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (user != null) {
                                PublicUserProfilePage.show(
                                  context,
                                  user.uid,
                                  initialName: userName,
                                  initialBarangay: req.location,
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.surfaceAlt.withValues(
                                      alpha: isDark ? 0.20 : 0.85,
                                    ),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.shadow.withValues(alpha: 0.08,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: ClipOval(
                                      child: (userPhoto != null &&
                                              userPhoto.isNotEmpty)
                                          ? Image.network(
                                              userPhoto,
                                              width: 38,
                                              height: 38,
                                              cacheWidth: (38 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  _buildMiniAvatarFallback(userName,
                                                  ),
                                            )
                                          : _buildMiniAvatarFallback(userName),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              userName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    context.colors.textPrimary,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          if (isVerified) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.verified_rounded,
                                              size: 14,
                                              color:
                                                  context.colors.primaryGreen,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        displayDate,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // "MY REQUEST" Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.colors.primaryGreen.withValues(alpha: 0.40,
                              ),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_ind_rounded,
                                size: 12,
                                color: context.colors.primaryGreen,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                'MY REQUEST',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.primaryGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Status Pill Badge (e.g. OPEN / MATCHED / COMPLETED / CANCELLED)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? (isDark ? context.colors.surfaceAlt.withValues(
                                          alpha: 0.1020,
                                        )
                                      : context.colors.surfaceAlt)
                                : isCancelled
                                    ? context.colors.errorSurface
                                : isMatched
                                        ? context.colors.infoSurface
                                : (isDark
                                            ? context.colors.surfaceAlt.withValues(alpha: 0.6,
                                        )
                                            : context.colors.surfaceAlt),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted
                                  ? (isDark ? context.colors.border.withValues(
                                            alpha: 0.2392,
                                          )
                                        : context.colors.border)
                                  : isCancelled
                                      ? context.colors.error
                                  : isMatched
                                          ? context.colors.border
                                  : (context.colors.border),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            statusLabel.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCompleted
                                  ? context.colors.textSecondary
                                  : isCancelled
                                      ? context.colors.error
                                  : isMatched
                                          ? context.colors.info
                                  : (context.colors.primaryGreen),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo Squircle (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Tag
                              Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.primaryGreen,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Request Title
                              Text(
                                req.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: context.colors.textPrimary,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Gold & Emerald Badge
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.brandStrong,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        primaryBadgeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.onBrandMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (secondaryBadgeText.isNotEmpty) ...[
                                        const SizedBox(width: 3),
                                        Text(
                                          secondaryBadgeText,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.onBrandMuted
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Location Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 13.5,
                                    color: context.colors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      locationText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Right: Generous 3D Photo Squircle (124x124)
                        Hero(
                          tag: 'bayanihan-my-request-${req.id}',
                          flightShuttleBuilder: _heroBayanihanFlightShuttle,
                          child: Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark
                                    ? context.colors.primaryGreen
                                    : context.colors.border,
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(
                                    alpha: isDark ? 0.35 : 0.12,
                                  ),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.14,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildRightPhotoTile(
                                job: req,
                                isUrgent: isUrgent,
                                isNew: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    BayanihanCardAction(
                      label: actionText,
                      icon: actionIcon,
                      tone: (isCompleted || isCancelled)
                          ? BayanihanActionTone.closed
                          : isMatched
                              ? BayanihanActionTone.info
                              : BayanihanActionTone.brand,
                      onTap: () => _handleMyRequestTap(req, isMatched),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMyRequestTap(JobItem req, bool isMatched) async {
    if (isMatched) {
      try {
        final convs = await BayanihanMessagingService()
            .conversationsFor(AuthService.currentUser?.uid ?? '')
            .first;
        final match = convs
            .where(
              (c) =>
                  c.requestId == req.id &&
                  c.status == BayanihanConversationStatus.active,
            )
            .firstOrNull;
        if (match != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BayanihanConversationPage(
                initialConversation: match,
                service: BayanihanMessagingService(),
              ),
            ),
          );
          return;
        }
      } catch (_) {}
    }
    _showJobDetails(req);
  }

  Widget _buildHelpingList() {
    final user = AuthService.currentUser;
    if (user == null) {
      return _buildSignInPrompt();
    }

    return StreamBuilder<List<BayanihanConversation>>(
      stream: BayanihanMessagingService().conversationsFor(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: context.colors.primaryGreen,
            ),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorView(onRetry: () => setState(() {}));
        }

        var helpingConversations = (snapshot.data ?? [])
            .where((c) => c.helperId == user.uid)
            .toList();

        if (_searchQuery.isNotEmpty) {
          helpingConversations = helpingConversations.where((c) {
            final titleMatch = c.requestTitle.toLowerCase().contains(_searchQuery,
            );
            final requesterMatch = c.requesterName.toLowerCase().contains(_searchQuery,
            );
            return titleMatch || requesterMatch;
          }).toList();
        }

        if (helpingConversations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.volunteer_activism_rounded,
            title: "You haven't offered help yet",
            message:
                'Help your neighbors in Barili. When you offer to help someone, it will show up here.',
            actionLabel: 'See Help Requests →',
            onAction: () => _tabController.animateTo(0),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
          itemCount: helpingConversations.length,
          itemBuilder: (context, index) =>
              _buildHelpingCard(helpingConversations[index]),
        );
      },
    );
  }

  Widget _buildHelpingCard(BayanihanConversation conv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = conv.status == BayanihanConversationStatus.completed;
    final isAcceptedOrActive = conv.status == BayanihanConversationStatus.active;
    final isPending = conv.status == BayanihanConversationStatus.pending;
    final requesterDisplay = conv.requesterName.isNotEmpty
        ? conv.requesterName
        : 'Neighbor';

    final String statusLabel;
    final String actionText;
    final IconData actionIcon;
    final VoidCallback actionCallback;

    if (isPending) {
      statusLabel = 'Pending Offer';
      actionText = 'View Request';
      actionIcon = Icons.schedule_send_rounded;
      actionCallback = () => _openRequestSafely(conv.requestId);
    } else if (isAcceptedOrActive) {
      statusLabel = 'In Progress';
      actionText = 'View Conversation';
      actionIcon = Icons.forum_rounded;
      actionCallback = () => _openConversationSafely(conv);
    } else if (isCompleted) {
      statusLabel = 'Completed';
      actionText = 'View Conversation';
      actionIcon = Icons.forum_rounded;
      actionCallback = () => _openConversationSafely(conv);
    } else {
      statusLabel = 'Cancelled';
      actionText = 'View Details';
      actionIcon = Icons.visibility_rounded;
      actionCallback = () => _openDetailsSafely(conv);
    }

    final String primaryBadgeText = isPending
        ? 'Offer Sent'
        : (isAcceptedOrActive ? 'Active Helper' : (isCompleted ? 'Completed' : 'Volunteer'));
    final String secondaryBadgeText = isPending
        ? '/ pending'
        : (isAcceptedOrActive ? '/ in progress' : (isCompleted ? '/ finished' : '/ closed'));

    return Semantics(
      label: 'Helping request by $requesterDisplay: ${conv.requestTitle}, status: $statusLabel.',
      button: true,
      onTapHint: 'Open activity',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            // Deep realistic 3D floor shadow
            BoxShadow(
              color: isDark
                  ? context.colors.brandStrong.withValues(alpha: 0.45)
                  : context.colors.brandStrong.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Subtle ambient shadow
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            // Top specular porcelain reflection
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: isDark ? 0.06 : 0.95,
              ),
              blurRadius: 0,
              offset: const Offset(0, -1.2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: actionCallback,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [context.colors.surface, context.colors.surface]
                      : [
                          context.colors.surface,
                          context.colors.surface,
                          context.colors.surface,
                        ],
                ),
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: Requester Info + "HELPING" Pill + Status Pill
                    Row(
                      children: [
                        // Requester Info (Tappable to view public profile)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => PublicUserProfilePage.show(
                              context,
                              conv.requesterId,
                              initialName: requesterDisplay,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.surfaceAlt.withValues(
                                      alpha: isDark ? 0.20 : 0.85,
                                    ),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.shadow.withValues(alpha: 0.08,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: ClipOval(
                                      child: (conv.requesterPhotoUrl != null &&
                                              conv.requesterPhotoUrl!.isNotEmpty)
                                          ? Image.network(
                                              conv.requesterPhotoUrl!,
                                              width: 38,
                                              height: 38,
                                              cacheWidth: (38 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  _buildMiniAvatarFallback(requesterDisplay,
                                                  ),
                                            )
                                          : _buildMiniAvatarFallback(requesterDisplay,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        requesterDisplay,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _formatRelativeTime(conv.createdAt),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // "HELPING" Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.infoSolid.withValues(alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.40,
                              ),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.volunteer_activism_rounded,
                                size: 12,
                                color: context.colors.info,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                'HELPING',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.info,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Status Pill Badge (e.g. IN PROGRESS / PENDING OFFER / COMPLETED)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? (isDark ? context.colors.surfaceAlt.withValues(
                                          alpha: 0.1020,
                                        )
                                      : context.colors.surfaceAlt)
                                : isPending
                                ? context.colors.warningSurface
                                : isAcceptedOrActive
                                ? context.colors.infoSurface
                                : (isDark
                                    ? context.colors.surfaceAlt.withValues(alpha: 0.6,
                                        )
                                    : context.colors.surfaceAlt),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted
                                  ? (isDark ? context.colors.border.withValues(
                                            alpha: 0.2392,
                                          )
                                        : context.colors.border)
                                  : isPending
                                  ? context.colors.border
                                  : isAcceptedOrActive
                                  ? context.colors.border
                                  : context.colors.border,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            statusLabel.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isCompleted
                                  ? context.colors.textSecondary
                                  : isPending
                                  ? context.colors.warning
                                  : isAcceptedOrActive
                                  ? context.colors.info
                                  : context.colors.primaryGreen,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo Squircle (Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Tag
                              Text(
                                'BAYANIHAN VOLUNTEER',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.primaryGreen,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Request Title
                              Text(
                                conv.requestTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: context.colors.textPrimary,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Gold & Emerald Badge
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.brandStrong,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.brandStrong
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        primaryBadgeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.onBrandMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        secondaryBadgeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.onBrandMuted
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Message Preview Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 13.5,
                                    color: context.colors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (conv.lastMessage?.isNotEmpty == true)
                                          ? conv.lastMessage!
                                          : (conv.initialMessage.isNotEmpty
                                              ? conv.initialMessage
                                              : 'You offered to help $requesterDisplay.'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Right: Generous 3D Photo Squircle (124x124)
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark
                                  ? context.colors.primaryGreen
                                  : context.colors.border,
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(
                                  alpha: isDark ? 0.35 : 0.12,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.14,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _buildCategoryPlaceholderTile(
                              category: 'care',
                              isUrgent: false,
                              isNew: false,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    BayanihanCardAction(
                      label: actionText,
                      icon: actionIcon,
                      tone: isCompleted
                          ? BayanihanActionTone.closed
                          : isPending
                              ? BayanihanActionTone.warning
                              : BayanihanActionTone.info,
                      onTap: actionCallback,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRequestSafely(String? requestId) async {
    if (requestId == null || requestId.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Unable to open this activity. Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
      return;
    }
    try {
      final job = await JobsService.getJob(requestId.trim());
      if (!mounted) return;
      if (job == null) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('This help request is no longer available.'),
            kind: FeedbackKind.warning,
          ),
        );
        return;
      }
      await _showJobDetails(job);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Unable to open this activity. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  void _openConversationSafely(BayanihanConversation conv) {
    if (conv.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Conversation is not available yet.'),
          kind: FeedbackKind.error,
        ),
      );
      return;
    }
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BayanihanConversationPage(
            initialConversation: conv,
            service: BayanihanMessagingService(),
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Unable to open this activity. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  Future<void> _openDetailsSafely(BayanihanConversation conv) async {
    if (conv.requestId.trim().isNotEmpty) {
      try {
        final job = await JobsService.getJob(conv.requestId.trim());
        if (job != null && mounted) {
          await _showJobDetails(job);
          return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: ctx.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: ctx.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                conv.requestTitle,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ctx.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Requester: ${conv.requesterName}',
                style: GoogleFonts.outfit(
                  color: ctx.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ctx.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ctx.colors.primaryGreen
                        : ctx.colors.border,
                  ),
                ),
                child: Text(
                  conv.declineReason != null && conv.declineReason!.isNotEmpty
                      ? 'Note: ${conv.declineReason}'
                      : 'This request was cancelled or is no longer active.',
                  style: GoogleFonts.outfit(
                    color: ctx.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    foregroundColor: ctx.colors.onAccent,

                    backgroundColor: ctx.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.surface,
                context.colors.surface,
                context.colors.surfaceAlt,
              ],
            ),
            border: Border.all(color: context.colors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D Layered Glowing Medallion
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer diffuse aura
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            context.colors.brand.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Middle frosted metallic ring
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.surfaceAlt,
                            context.colors.surfaceAlt,
                          ],
                        ),
                        border: Border.all(color: context.colors.border, width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    // Inner 3D Sphere with Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.brand,
                            context.colors.brand,
                            context.colors.brandStrong,
                          ],
                        ),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.20,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          color: context.colors.onAccent,
                          size: 26,
                          shadows: [
                            Shadow(
                              color: context.colors.textPrimary,
                              blurRadius: 4,
                              offset: Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: context.colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 8),

              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                // 3D Primary Button
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brand],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.38,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.25),
                        blurRadius: 0,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: Text(
                            actionLabel,
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Civic Trust Micro-Badges
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTrustBadge(Icons.verified_user_rounded, 'Verified'),
                    Container(
                      width: 1,
                      height: 16,
                      color: context.colors.surfaceAlt,
                    ),
                    _buildTrustBadge(Icons.lock_outline_rounded, 'Protected'),
                    Container(
                      width: 1,
                      height: 16,
                      color: context.colors.surfaceAlt,
                    ),
                    _buildTrustBadge(Icons.favorite_rounded, 'Bayanihan'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.colors.primaryGreen),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Please sign in to view your Bayanihan activity.',
          style: GoogleFonts.outfit(
            color: context.colors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _openConversationFromInterest(
    Map<String, dynamic>? interestData,
    BuildContext sheetContext,
  ) async {
    final convId = interestData?['conversationId']?.toString();
    if (convId == null || convId.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showAppSnackBar(
        AppSnackBar(
          content: Text('Conversation is not available yet.'),
          kind: FeedbackKind.error,
        ),
      );
      return;
    }
    try {
      final conv = await BayanihanMessagingService().conversation(convId).first;
      if (conv != null && sheetContext.mounted) {
        Navigator.push(
          sheetContext,
          MaterialPageRoute(
            builder: (_) => BayanihanConversationPage(
              initialConversation: conv,
              service: BayanihanMessagingService(),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _showManageRequestModal(
    JobItem job,
    BuildContext sheetContext,
  ) async {
    await showModalBottomSheet<void>(
      context: sheetContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (manageCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: sheetContext.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.infoSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: sheetContext.colors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: sheetContext.colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Help Request',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: sheetContext.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Select an action for this request',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: sheetContext.colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: sheetContext.colors.infoSolid,
                    onPressed: () => Navigator.pop(manageCtx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Button 1: EDIT REQUEST -> Opens RequestHelpPage(existingJob: job)
              ESugidPressable(
                onTap: () async {
                  Navigator.pop(manageCtx);
                  final updated = await Navigator.push<bool>(
                    sheetContext,
                    MaterialPageRoute(
                      builder: (context) => RequestHelpPage(existingJob: job),
                    ),
                  );
                  if (updated == true && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sheetContext.colors.primaryGreen.withValues(alpha: 0.35,
                      ),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: sheetContext.colors.brandStrong.withValues(alpha: 0.08,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: sheetContext.colors.brand.withValues(alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: 24,
                            color: sheetContext.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Request',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: sheetContext.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Modify task description, date, helpers, or photo',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: sheetContext.colors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: sheetContext.colors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Button 2: DELETE REQUEST -> Opens creative confirmation dialog
              ESugidPressable(
                onTap: () {
                  Navigator.pop(manageCtx);
                  _confirmAndDeleteJob(job, sheetContext);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.errorSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sheetContext.colors.error.withValues(alpha: 0.35),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: sheetContext.colors.highlight.withValues(alpha: 0.08,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: sheetContext.colors.errorSolid.withValues(alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: sheetContext.colors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Request',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: sheetContext.colors.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permanently cancel and remove this request',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: sheetContext.colors.error.withValues(alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: sheetContext.colors.error,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteJob(
    JobItem job,
    BuildContext sheetContext,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogCtx) => Dialog(
        backgroundColor: sheetContext.colors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Concentric glowing badge
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sheetContext.colors.errorSurface,
                        border: Border.all(
                          color: sheetContext.colors.error.withValues(alpha: 0.4,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            sheetContext.colors.errorSolid,
                            sheetContext.colors.errorSolid,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: sheetContext.colors.highlight.withValues(alpha: 0.38,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          size: 26,
                          color: sheetContext.colors.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Help Request?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: sheetContext.colors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to delete this request? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: sheetContext.colors.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: sheetContext.colors.surface,
                        side: BorderSide(
                          color: sheetContext.colors.border,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep Request',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sheetContext.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ESugidPressable(
                      onTap: () => Navigator.pop(dialogCtx, true),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              sheetContext.colors.errorSolid,
                              sheetContext.colors.errorSolid,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: sheetContext.colors.highlight.withValues(alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_forever_rounded,
                              size: 18,
                              color: sheetContext.colors.onAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Delete',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: sheetContext.colors.onAccent,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      try {
        await BayanihanMessagingService().closeRequest(
          job.id,
          completed: false,
        );
      } catch (_) {}

      await FirebaseFirestore.instance.collection('jobs').doc(job.id).delete();

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Help request deleted successfully.'),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Failed to delete request: $e'),
            kind: FeedbackKind.error,
          ),
        );
      }
    }
  }

  Future<void> _showSavedRequestsSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.shadow.withValues(alpha: 0.65),
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _savedJobsRevision,
        builder: (context, revision, child) {
          final savedCount = _savedJobIds.length;

          return Container(
            height: MediaQuery.sizeOf(sheetContext).height * 0.90,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Scaffold(
                backgroundColor: context.colors.background,
                body: SafeArea(
                  child: Column(
                    children: [
                      // Header with drag handle and title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: context.colors.infoSurface,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.pop(sheetContext),
                                    borderRadius: BorderRadius.circular(99),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.colors.surface,
                                        border: Border.all(
                                          color: context.colors.border,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.colors.shadow
                                                .withValues(
                                              alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 15,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.bookmark_rounded,
                                            size: 20,
                                            color: context.colors.primaryGreen,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Saved Requests',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.colors.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: context.colors.border,
                                              ),
                                            ),
                                            child: Text(
                                              '$savedCount',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    context.colors.primaryGreen,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'All the requests you saved',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.colors.border),
                      // Pure saved cards stream!
                      Expanded(
                        child: StreamBuilder<List<JobItem>>(
                          stream: JobsService.jobsStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: context.colors.primaryGreen,
                                ),
                              );
                            }
                            final allJobs = snapshot.data ?? [];
                            final savedJobs = allJobs
                                .where(
                                  (j) =>
                                      j.category == 'request' &&
                                      _savedJobIds.contains(j.id),
                                )
                                .toList();

                            if (savedJobs.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: context.colors.surfaceAlt,
                                          border: Border.all(
                                            color: context.colors.border,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.bookmark_border_rounded,
                                          size: 38,
                                          color: context.colors.primaryGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'No Saved Requests Yet',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap the bookmark icon on any request to save it here.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textSecondary,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.fromLTRB(
                                0,
                                16,
                                0,
                                40),
                              itemCount: savedJobs.length,
                              itemBuilder: (context, index) {
                                final job = savedJobs[index];
                                return _buildHelpRequestCard(job);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _showJobDetails(JobItem job) {
    final user = AuthService.currentUser;
    final isOwner = user?.uid == job.posterId;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.shadow.withValues(alpha: 0.65),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) =>
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(job.id)
                  .snapshots(),
              builder: (sheetContext, jobSnapshot) {
                final currentJob =
                    jobSnapshot.hasData && jobSnapshot.data!.exists
                    ? JobItem.fromMap(jobSnapshot.data!.data()!)
                    : job;
                final isActive = currentJob.status.toLowerCase() == 'active';
                final isUrgent = currentJob.urgency.toLowerCase() == 'urgent';
                final catConfig = _getCategoryVisualConfig(
                  sheetContext,
                  currentJob.helpCategory,
                );
                final isSaved = _savedJobIds.contains(currentJob.id);

                return Container(
                  height: MediaQuery.sizeOf(sheetContext).height * 0.92,
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    child: Scaffold(
                      backgroundColor: sheetContext.colors.background,
                      body: SafeArea(
                        child: Column(
                          children: [
                            // 1. Editorial Top Navigation Bar
                            _buildEditorialTopBar(
                              sheetContext: sheetContext,
                              currentJob: currentJob,
                              isSaved: isSaved,
                              setModalState: setModalState,
                            ),

                            // 2. Scrollable Content
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 3. Wide Hero Image Showcase with Category Pill
                                    _build3DHeroShowcase(
                                      job: currentJob,
                                      catConfig: catConfig,
                                      isUrgent: isUrgent,
                                    ),

                                    const SizedBox(height: 18),

                                    // 4. Request Title & Status Badge
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            currentJob.title,
                                            style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: sheetContext
                                                  .colors
                                                  .textPrimary,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isUrgent
                                                ? sheetContext
                                                      .colors
                                                      .errorSurface
                                                : sheetContext
                                                      .colors
                                                      .surfaceAlt,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: isUrgent
                                                  ? sheetContext.colors.error
                                                  : sheetContext.colors.border,
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
                                                  color: isUrgent
                                                      ? sheetContext
                                                            .colors
                                                            .errorSolid
                                                      : sheetContext
                                                            .colors
                                                            .brand,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                isUrgent
                                                    ? 'Urgent'
                                                    : (isActive
                                                          ? 'Active'
                                                          : currentJob.status),
                                                style: GoogleFonts.outfit(
                                                  color: isUrgent
                                                      ? sheetContext
                                                            .colors
                                                            .error
                                                      : sheetContext
                                                            .colors
                                                            .primaryGreen,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // 5. Requester Byline Row
                                    FutureBuilder<_RequesterProfile>(
                                      future: _fetchPosterProfile(currentJob),
                                      builder: (context, profileSnap) {
                                        final profile = profileSnap.data;
                                        final photoUrl = profile?.photoUrl;
                                        final isVerified =
                                            profile?.isVerified ?? true;
                                        final displayName =
                                            (profile?.name.isNotEmpty ?? false)
                                            ? profile!.name
                                            : (currentJob.company.isNotEmpty
                                                  ? currentJob.company
                                                  : 'Neighbor');

                                        return Row(
                                          children: [
                                            Flexible(
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap:
                                                    currentJob.posterId.isNotEmpty
                                                    ? () =>
                                                          PublicUserProfilePage.show(
                                                            context,
                                                            currentJob.posterId,
                                                          )
                                                    : null,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: context
                                                              .colors
                                                              .border,
                                                          width: 1.2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: context
                                                                .colors
                                                                .shadow
                                                                .withValues(
                                                                  alpha: 0.08,
                                                                ),
                                                            blurRadius: 3,
                                                            offset:
                                                                const Offset(
                                                              0,
                                                              1,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipOval(
                                                        child:
                                                            (photoUrl != null &&
                                                                photoUrl
                                                                    .isNotEmpty)
                                                            ? Image.network(
                                                                photoUrl,
                                                                width: 24,
                                                                height: 24,
                                                                cacheWidth: (24 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      _,
                                                                      _,
                                                                      _,
                                                                    ) =>
                                                                        _buildMiniAvatarFallback(
                                                                      displayName,
                                                                    ),
                                                              )
                                                            : _buildMiniAvatarFallback(
                                                                displayName,
                                                              ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        'Posted by $displayName',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: context
                                                                  .colors
                                                                  .textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isVerified) ...[
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.verified_rounded,
                                                        size: 13,
                                                        color: context
                                                            .colors
                                                            .primaryGreen,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: Text(
                                                '|',
                                                style: TextStyle(
                                                  color: context
                                                      .colors
                                                      .textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatRelativeTime(
                                                currentJob.createdAt,
                                              ),
                                              maxLines: 1,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: context
                                                    .colors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 18),

                                    // 6. 4-Metric Highlights Bar
                                    _buildHorizontalHighlightsBar(currentJob),

                                    const SizedBox(height: 20),

                                    // 7. Request Summary Section
                                    _buildEditorialOverview(
                                      currentJob.description,
                                    ),

                                    // 8. Help Offers Section (for Owner)
                                    if (isOwner && isActive) ...[
                                      const SizedBox(height: 20),
                                      _buildOffersSectionForOwner(
                                        currentJob,
                                        sheetContext,
                                      ),
                                    ],

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),

                            // 11. Sticky Dual Bottom Action Bar
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                14,
                                20,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: sheetContext.colors.surface,
                                border: Border(
                                  top: BorderSide(
                                    color: sheetContext.colors.border,
                                    width: 1,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: sheetContext.colors.brandStrong
                                        .withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, -4),
                                  ),
                                ],
                              ),
                              child: _buildDetailsBottomBar(
                                currentJob,
                                isOwner,
                                isActive,
                                sheetContext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildEditorialTopBar({
    required BuildContext sheetContext,
    required JobItem currentJob,
    required bool isSaved,
    required void Function(VoidCallback fn) setModalState,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: sheetContext.colors.infoSurface,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(sheetContext),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sheetContext.colors.surface,
                      border: Border.all(color: sheetContext.colors.border),
                      boxShadow: [
                        BoxShadow(
                          color: sheetContext.colors.shadow.withValues(alpha: 0.04,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: sheetContext.colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Request Details',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: sheetContext.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final willBeSaved = !isSaved;
                    setModalState(() {
                      if (willBeSaved) {
                        _savedJobIds.add(currentJob.id);
                      } else {
                        _savedJobIds.remove(currentJob.id);
                      }
                    });
                    setState(() {});
                    _savedJobsRevision.value++;
                    _persistSavedJobIds();
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSaved ? sheetContext.colors.surfaceAlt
                          : sheetContext.colors.surface,
                      border: Border.all(
                        color: isSaved
                            ? sheetContext.colors.primaryGreen
                            : sheetContext.colors.border,
                        width: isSaved ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSaved
                              ? sheetContext.colors.brandStrong.withValues(alpha: 0.38,
                                )
                              : sheetContext.colors.shadow.withValues(alpha: 0.04,
                                ),
                          blurRadius: isSaved ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: isSaved
                              ? sheetContext.colors.primaryGreen
                              : sheetContext.colors.textSecondary,
                        ),
                        if (isSaved)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: sheetContext.colors.brand,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sheetContext.colors.border,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DHeroShowcase({
    required JobItem job,
    required _CategoryVisualConfig catConfig,
    required bool isUrgent,
  }) {
    final photoUrl = job.imageUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    if (!hasPhoto) {
      return Container(
        width: double.infinity,
        height: 165,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: catConfig.gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: catConfig.accentColor.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Large background watermark in bottom right corner (Photo 1)
              Positioned(
                right: -10,
                bottom: -15,
                child: Opacity(
                  opacity: 0.22,
                  child: Icon(
                    catConfig.backgroundWatermarkIcon,
                    size: 130,
                    color: catConfig.accentColor,
                  ),
                ),
              ),

              // Center: prominent circular medallion with category icon (Photo 1)
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: catConfig.accentColor.withValues(alpha: 0.20),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      catConfig.mainIcon,
                      size: 38,
                      color: catConfig.accentColor,
                    ),
                  ),
                ),
              ),

              // Top-left: Category pill badge (Photo 1)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brandStrong.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.2588),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        catConfig.mainIcon,
                        size: 13,
                        color: context.colors.onAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        catConfig.label,
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'bayanihan-job-image-${job.id}',
              flightShuttleBuilder: _heroBayanihanFlightShuttle,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      context.colors.shadow.withValues(alpha: 0.45),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.brandStrong.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.2588),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      catConfig.mainIcon,
                      size: 13,
                      color: context.colors.onAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      catConfig.label,
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalHighlightsBar(JobItem currentJob) {
    final isFull = currentJob.acceptedHelperCount >= currentJob.helpersNeeded;

    // Parse date and time cleanly
    final rawDate = currentJob.dateNeeded.trim();
    String displayDate = rawDate.isNotEmpty ? rawDate : 'To be coordinated';
    String displayTime = '';
    if (displayDate.contains(' - ')) {
      final parts = displayDate.split(' - ');
      displayDate = parts[0].trim();
      displayTime = parts.sublist(1).join(' - ').trim();
    } else if (displayDate.contains(' | ')) {
      final parts = displayDate.split(' | ');
      displayDate = parts[0].trim();
      displayTime = parts.sublist(1).join(' | ').trim();
    } else if (displayDate.contains(' at ')) {
      final parts = displayDate.split(' at ');
      displayDate = parts[0].trim();
      displayTime = parts.sublist(1).join(' at ').trim();
    }

    final locationText = currentJob.location.trim().isNotEmpty
        ? currentJob.location.trim()
        : 'Barili Municipal Area';
    final helpersText =
        '${currentJob.helpersNeeded} ${currentJob.helpersNeeded == 1 ? 'Helper' : 'Helpers'}';
    final acceptedText =
        '${currentJob.acceptedHelperCount} of ${currentJob.helpersNeeded}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Time (matching Photo 3)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: context.colors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDate,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (displayTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayTime,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Location if present (matching Photo 3)
          if (locationText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: context.colors.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locationText,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Inset White Helpers / Reminder Banner (matching Photo 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 14,
                  color: context.colors.primaryGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$helpersText Needed · $acceptedText Accepted',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isFull
                        ? context.colors.surfaceAlt
                        : context.colors.warningSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFull ? 'FILLED' : 'ACTIVE',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isFull
                          ? context.colors.primaryGreen
                          : context.colors.warning,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialOverview(String description) {
    final cleanDesc = description.trim();
    final hasDesc = cleanDesc.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border, width: 1.1),
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
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notes_rounded,
                  size: 14,
                  color: context.colors.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Request Summary',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasDesc ? cleanDesc : 'No extra details provided for this request.',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: hasDesc
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
              fontStyle: hasDesc ? FontStyle.normal : FontStyle.italic,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSectionForOwner(JobItem job, BuildContext sheetContext) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(job.id)
          .collection('interests')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Help Offers',
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${job.acceptedHelperCount} / ${job.helpersNeeded} accepted',
                    style: GoogleFonts.outfit(
                      color: context.colors.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1.1),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.volunteer_activism_rounded,
                          size: 20,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Waiting for Offers',
                      style: GoogleFonts.outfit(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'When neighbors offer to help with this task, they will appear here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final helperName =
                    data['volunteerName']?.toString() ?? 'Neighbor';
                final message = data['initialMessage']?.toString() ?? '';
                final status =
                    data['status']?.toString().toLowerCase() ?? 'pending';
                final convId = data['conversationId']?.toString() ?? '';
                final helperId = data['helperId']?.toString() ?? doc.id;

                final isAccepted = status == 'accepted';
                final isPending = status == 'pending';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAccepted
                          ? context.colors.primaryGreen
                          : context.colors.border,
                      width: isAccepted ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: helperId.isNotEmpty
                                  ? () => PublicUserProfilePage.show(
                                        context,
                                        helperId,
                                        initialName: helperName,
                                      )
                                  : null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: context.colors.brand
                                        .withValues(
                                      alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: context.colors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      helperName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAccepted
                                  ? context.colors.brand.withValues(alpha: 0.1)
                                  : context.colors.warningSurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAccepted ? 'ACCEPTED' : 'PENDING',
                              style: GoogleFonts.outfit(
                                color: isAccepted
                                    ? context.colors.primaryGreen
                                    : context.colors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '“$message”',
                          style: GoogleFonts.outfit(
                            fontStyle: FontStyle.italic,
                            color: context.colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _showHelperProfile(
                              sheetContext,
                              helperId,
                              helperName,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'View Profile',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isPending &&
                              (job.acceptedHelperCount < job.helpersNeeded))
                            FilledButton(
                              onPressed: () => _acceptHelperOffer(
                                sheetContext,
                                conversationId: convId,
                                helperName: helperName,
                              ),
                              style: FilledButton.styleFrom(
                                foregroundColor: context.colors.onAccent,

                                backgroundColor: context.colors.brand,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Accept Help',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else if (isAccepted)
                            FilledButton.icon(
                              onPressed: () => _openConversationFromInterest(
                                data,
                                sheetContext,
                              ),
                              style: FilledButton.styleFrom(
                                foregroundColor: context.colors.onAccent,

                                backgroundColor: context.colors.brand,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 14,
                              ),
                              label: Text(
                                'Open Chat',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildDetailsBottomBar(
    JobItem job,
    bool isOwner,
    bool isActive,
    BuildContext sheetContext,
  ) {
    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sheetContext.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          job.status.toLowerCase() == 'completed'
              ? 'THIS REQUEST IS COMPLETED'
              : 'THIS REQUEST WAS CANCELLED',
          style: GoogleFonts.outfit(
            color: sheetContext.colors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    if (isOwner) {
      final isFull = job.acceptedHelperCount >= job.helpersNeeded;
      return Row(
        children: [
          Expanded(
            child: ESugidPressable(
              onTap: () => _showManageRequestModal(job, sheetContext),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: sheetContext.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sheetContext.colors.border,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sheetContext.colors.shadow.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: sheetContext.colors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MANAGE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: sheetContext.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ESugidPressable(
              onTap: () async {
                try {
                  await BayanihanMessagingService().closeRequest(
                    job.id,
                    completed: true,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showAppSnackBar(
                      AppSnackBar(
                        content: Text(
                          'Bayanihan request completed! Thank you.',
                        ),
                        kind: FeedbackKind.success,
                      ),
                    );
                  }
                } catch (_) {}
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isFull
                        ? [
                            sheetContext.colors.brand,
                            sheetContext.colors.brand,
                            sheetContext.colors.brand,
                          ]
                        : [
                            sheetContext.colors.brand,
                            sheetContext.colors.brandStrong,
                            sheetContext.colors.brandStrong,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isFull
                                  ? sheetContext.colors.brandStrong
                                  : sheetContext.colors.brandStrong)
                              .withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: sheetContext.colors.highlight.withValues(alpha: 0.25,
                      ),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: sheetContext.colors.onAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'COMPLETE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: sheetContext.colors.onAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Resident / Non-owner
    final user = AuthService.currentUser;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(job.id)
          .collection('interests')
          .doc(user?.uid ?? '')
          .snapshots(),
      builder: (_, offerSnapshot) {
        final hasOffer =
            offerSnapshot.hasData && (offerSnapshot.data?.exists ?? false);
        final offerData = hasOffer ? offerSnapshot.data?.data() : null;
        final offerStatus = offerData?['status']?.toString().toLowerCase();
        final isFull = job.acceptedHelperCount >= job.helpersNeeded;

        if (hasOffer) {
          if (offerStatus == 'accepted') {
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    _openConversationFromInterest(offerData, sheetContext),
                style: FilledButton.styleFrom(
                  foregroundColor: sheetContext.colors.onAccent,

                  backgroundColor: sheetContext.colors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: sheetContext.colors.primaryGreen.withValues(alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                label: Text(
                  'OPEN DIRECT CHAT',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            );
          } else if (offerStatus == 'pending') {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sheetContext.colors.border,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: sheetContext.colors.brandStrong.withValues(alpha: 0.06,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sheetContext.colors.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: sheetContext.colors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Help Offer Submitted',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: sheetContext.colors.textPrimary,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sheetContext.colors.warningSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: sheetContext.colors.border,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'Pending Review',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: sheetContext.colors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Awaiting neighbor to review and accept. You can chat with them anytime.',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                height: 1.35,
                                color: sheetContext.colors.primaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _openConversationFromInterest(offerData, sheetContext),
                    style: FilledButton.styleFrom(
                      foregroundColor: sheetContext.colors.onAccent,

                      backgroundColor: sheetContext.colors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 3,
                      shadowColor: sheetContext.colors.primaryGreen.withValues(alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      'OPEN DIRECT CHAT',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        }

        // If request is full:
        if (isFull) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: sheetContext.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: sheetContext.colors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: sheetContext.colors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Help Found • Required helpers reached',
                  style: GoogleFonts.outfit(
                    color: sheetContext.colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Fresh Offer Help action (Full-width 3D action button)
        return SizedBox(
          width: double.infinity,
          child: ESugidPressable(
            onTap: () => _showOfferHelpConfirmationSheet(
              job,
              detailsSheetContext: sheetContext,
            ),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    sheetContext.colors.brand,
                    sheetContext.colors.brand,
                    sheetContext.colors.brandStrong,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: sheetContext.colors.brandStrong.withValues(alpha: 0.42,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: sheetContext.colors.highlight.withValues(alpha: 0.3),
                    blurRadius: 0,
                    offset: const Offset(0, -1.5),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: sheetContext.colors.onAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'OFFER TO HELP NEIGHBOR',
                      style: GoogleFonts.outfit(
                        color: sheetContext.colors.onAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOfferHelpConfirmationSheet(
    JobItem job, {
    BuildContext? detailsSheetContext,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please sign in to offer help.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }

    _ensureVerified(
      context,
      onVerified: () async {
        final messageController = TextEditingController(
          text: 'Hi! I’m available to help with this request.',
        );
        bool isSubmitting = false;
        String? errorMessage;
        bool alreadyOffered = false;
        bool checkedExisting = false;

        void openConversationDirectly(String text) {
          if (!mounted) return;
          final targetConvId = '${job.id}_${user.uid}';
          final convToOpen = BayanihanConversation(
            id: targetConvId,
            requestId: job.id,
            offerId: user.uid,
            requesterId: job.posterId,
            helperId: user.uid,
            requestTitle: job.title.isNotEmpty ? job.title : 'Help request',
            requesterName: job.company.isNotEmpty ? job.company : 'Neighbor',
            helperName: user.name.isNotEmpty ? user.name : 'Helper',
            helperPhotoUrl: user.profilePhotoUrl,
            initialMessage: text,
            status: BayanihanConversationStatus.pending,
            createdAt: DateTime.now(),
            lastMessage: text,
            lastMessageAt: DateTime.now(),
          );

          if (detailsSheetContext?.mounted ?? false) {
            Navigator.pop(detailsSheetContext!);
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BayanihanConversationPage(
                initialConversation: convToOpen,
                service: BayanihanMessagingService(),
              ),
            ),
          );
        }

        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setModalState) {
              // Rapid check to see if user has already offered help on this request
              if (!checkedExisting) {
                checkedExisting = true;
                FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(job.id)
                    .collection('interests')
                    .doc(user.uid)
                    .get()
                    .then((doc) {
                  if (doc.exists && sheetContext.mounted) {
                    setModalState(() {
                      alreadyOffered = true;
                      errorMessage =
                          'You already offered help for this request.';
                    });
                  }
                }).catchError((_) {});
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: sheetContext.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Text(
                          'Offer to help ${job.company}?',
                          style: GoogleFonts.outfit(
                            color: sheetContext.colors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Send an optional message letting the requester know your availability.',
                          style: GoogleFonts.outfit(
                            color: sheetContext.colors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Error or Notice Banner Displayed Directly in the Front
                        if (errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: alreadyOffered
                                  ? sheetContext.colors.warningSurface
                                  : sheetContext.colors.errorSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: alreadyOffered
                                    ? sheetContext.colors.border
                                    : sheetContext.colors.error,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  alreadyOffered
                                      ? Icons.info_outline_rounded
                                      : Icons.error_outline_rounded,
                                  color: alreadyOffered
                                      ? sheetContext.colors.warning
                                      : sheetContext.colors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: GoogleFonts.outfit(
                                      color: alreadyOffered
                                          ? sheetContext.colors.error
                                          : sheetContext.colors.error,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextField(
                          controller: messageController,
                          enabled: !isSubmitting,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          autofocus: !alreadyOffered,
                          onChanged: (_) {
                            if (errorMessage != null && !alreadyOffered) {
                              setModalState(() => errorMessage = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. I’m available this afternoon...',
                            labelText: 'Optional message',
                            filled: true,
                            fillColor: sheetContext.colors.inputBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Theme.of(sheetContext).brightness == Brightness.dark
                                    ? sheetContext.colors.primaryGreen
                                    : sheetContext.colors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: sheetContext.colors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  alreadyOffered ? 'Close' : 'Cancel',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : alreadyOffered
                                        ? () {
                                            Navigator.pop(sheetContext);
                                            openConversationDirectly(
                                              messageController.text.trim(),
                                            );
                                          }
                                        : () async {
                                            final msg =
                                                messageController.text.trim();
                                            if (msg.isEmpty) {
                                              setModalState(() {
                                                errorMessage =
                                                    'Please enter a message for the requester.';
                                              });
                                              return;
                                            }

                                            // Lock submit immediately to prevent spamming multiple requests
                                            setModalState(() {
                                              isSubmitting = true;
                                              errorMessage = null;
                                            });

                                            try {
                                              await BayanihanMessagingService()
                                                  .sendOffer(
                                                    requestId: job.id,
                                                    initialMessage: msg,
                                                    availability: '',
                                                  )
                                                  .timeout(
                                                    const Duration(
                                                      seconds: 10),
                                                    onTimeout: () {
                                                      throw const BayanihanMessagingException(
                                                        'Sending timed out. Please check your internet connection and try again.',
                                                      );
                                                    },
                                                  );

                                              if (sheetContext.mounted) {
                                                Navigator.pop(sheetContext);
                                              }
                                              openConversationDirectly(msg);
                                            } catch (error) {
                                              if (sheetContext.mounted) {
                                                final rawMsg = error
                                                        is BayanihanMessagingException
                                                    ? error.message
                                                    : error.toString();
                                                final isAlready = rawMsg
                                                        .toLowerCase()
                                                        .contains(
                                                          'already offered',
                                                        ) ||
                                                    rawMsg
                                                        .toLowerCase()
                                                        .contains(
                                                          'already exists',
                                                        );
                                                if (isAlready) {
                                                  if (sheetContext.mounted) {
                                                    Navigator.pop(sheetContext);
                                                  }
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showAppSnackBar(
                                                AppSnackBar(
                                                      content: Text(
                                                        'You already offered help. Opening conversation...',
                                                      ),
                                                  duration:
                                                          Duration(seconds: 2,
                                                  ),
                                                  kind: FeedbackKind.error,
                                                ),
                                                  );
                                                  openConversationDirectly(msg);
                                                  return;
                                                }

                                                setModalState(() {
                                                  isSubmitting = false;
                                                  errorMessage = error
                                                          is BayanihanMessagingException
                                                      ? error.message
                                                      : 'Unable to send offer. Please try again.';
                                                });
                                              }
                                            }
                                          },
                                style: FilledButton.styleFrom(
                                  foregroundColor: sheetContext.colors.onAccent,

                                  backgroundColor: sheetContext.colors.brand,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: isSubmitting
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: sheetContext.colors.surface,
                                        ),
                                      )
                                    : Icon(
                                        alreadyOffered
                                            ? Icons.chat_bubble_outline_rounded
                                            : Icons.volunteer_activism_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  isSubmitting
                                      ? 'Sending...'
                                      : alreadyOffered
                                          ? 'Open Chat'
                                          : 'Offer Help',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showHelperProfile(
    BuildContext context,
    String helperId,
    String helperName,
  ) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(helperId)
        .get();
    final data = userDoc.data() ?? {};
    final barangay = data['barangay']?.toString() ?? 'Barili Resident';

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: sheetContext.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: sheetContext.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: sheetContext.colors.brand.withValues(alpha: 0.12,
                ),
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: sheetContext.colors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    helperName,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: sheetContext.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.verified,
                    size: 18,
                    color: sheetContext.colors.primaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Verified Resident • $barangay',
                style: GoogleFonts.outfit(
                  color: sheetContext.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sheetContext.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(sheetContext).brightness == Brightness.dark
                        ? sheetContext.colors.primaryGreen
                        : sheetContext.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: sheetContext.colors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Account verified through Barili LGU residency verification.',
                        style: GoogleFonts.outfit(
                          color: sheetContext.colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    foregroundColor: sheetContext.colors.onAccent,

                    backgroundColor: sheetContext.colors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptHelperOffer(
    BuildContext context, {
    required String conversationId,
    required String helperName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Accept $helperName as helper?'),
        content: const Text(
          'Once accepted, you can coordinate details directly in private chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: dialogContext.colors.onAccent,

              backgroundColor: dialogContext.colors.brand,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept Help'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await BayanihanMessagingService().acceptOffer(conversationId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            'Help accepted from $helperName! Opening conversation...',
          ),
          kind: FeedbackKind.success,
        ),
      );
      final conv = await BayanihanMessagingService()
          .conversation(conversationId)
          .first
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => null);
      if (conv != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BayanihanConversationPage(
              initialConversation: conv,
              service: BayanihanMessagingService(),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
              error is BayanihanMessagingException
                  ? error.message
                  : 'Unable to accept offer. Try again.',
            ),
            kind: FeedbackKind.error,
          ),
        );
      }
    }
  }
}
