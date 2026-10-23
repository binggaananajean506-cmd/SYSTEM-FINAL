import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/private_organization.dart';
import '../services/private_organization_service.dart';
import '../widgets/esugid_page_header.dart';
import 'organization_profile_page.dart';

class DiscoverPrivateOrganizationsPage extends StatefulWidget {
  const DiscoverPrivateOrganizationsPage({super.key});

  @override
  State<DiscoverPrivateOrganizationsPage> createState() =>
      _DiscoverPrivateOrganizationsPageState();
}

class _DiscoverPrivateOrganizationsPageState
    extends State<DiscoverPrivateOrganizationsPage> {
  final _searchController = TextEditingController();
  final _service = PrivateOrganizationService.instance;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<PrivateOrganization> _organizations = [];
  bool _loading = true;

  // The 4 top primary categories shown in the single row, followed by 'Others'
  static const List<Map<String, dynamic>> _primaryCategories = [
    {'label': 'All', 'icon': Icons.grid_view_rounded},
    {'label': 'Banking & Finance', 'icon': Icons.account_balance_rounded},
    {'label': 'School & Education', 'icon': Icons.school_rounded},
    {'label': 'Health & Medical', 'icon': Icons.favorite_rounded},
  ];

  // Complete list of all categories accessible via the "Others" dropdown
  static const List<Map<String, dynamic>> _allCategories = [
    {'label': 'All', 'icon': Icons.grid_view_rounded},
    {'label': 'Banking & Finance', 'icon': Icons.account_balance_rounded},
    {'label': 'School & Education', 'icon': Icons.school_rounded},
    {'label': 'Health & Medical', 'icon': Icons.favorite_rounded},
    {'label': 'Utilities', 'icon': Icons.bolt_rounded},
    {'label': 'Internet & Telecom', 'icon': Icons.wifi_rounded},
    {'label': 'Transportation', 'icon': Icons.directions_bus_rounded},
    {'label': 'Retail & Commercial', 'icon': Icons.storefront_rounded},
    {'label': 'Community & NGO', 'icon': Icons.volunteer_activism_rounded},
    {'label': 'Religious & Civic', 'icon': Icons.church_rounded},
    {'label': 'Other Services', 'icon': Icons.business_center_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    setState(() => _loading = true);
    final list = await _service.getOrganizations(
      query: _searchQuery,
      category: _selectedCategory,
    );
    if (!mounted) return;
    setState(() {
      _organizations = list;
      _loading = false;
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
    });
    _loadOrganizations();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadOrganizations();
  }

  Future<void> _toggleFollow(PrivateOrganization org) async {
    HapticFeedback.selectionClick();
    final bool isNowFollowed;
    try {
      isNowFollowed = await _service.toggleFollow(org.id);
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
        duration: const Duration(milliseconds: 1600),
        content: Text(
                isNowFollowed
                    ? 'Following ${org.name}'
                    : 'Unfollowed ${org.name}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700,
                  fontSize: 13),
              ),
        kind: FeedbackKind.success,
      ),
    );
  }

  void _openProfile(PrivateOrganization org) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OrganizationProfilePage(organization: org),
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
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
  void _showAllCategoriesModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: ctx.colors.shadow.withValues(alpha: 0.2588),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.colors.infoSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ctx.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      color: ctx.colors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Organization Category',
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: ctx.colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Filter verified private institutions and services',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: ctx.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: ctx.colors.border),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _allCategories.length,
                  separatorBuilder: (_, index) =>
                      Divider(height: 1, color: ctx.colors.border),
                  itemBuilder: (ctx, index) {
                    final item = _allCategories[index];
                    final label = item['label'] as String;
                    final icon = item['icon'] as IconData;
                    final isSelected = _selectedCategory == label;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? ctx.colors.surfaceAlt
                          : Colors.transparent,
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ctx.colors.brand
                              : ctx.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          icon,
                          size: 17,
                          color: isSelected ? ctx.colors.onAccent
                              : ctx.colors.textSecondary,
                        ),
                      ),
                      title: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? ctx.colors.primaryGreen
                              : ctx.colors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: ctx.colors.primaryGreen,
                              size: 19,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _onCategorySelected(label);
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _service.followedIdsNotifier,
      builder: (context, followedIds, _) {
        return Scaffold(
          body: Column(
            children: [
              // 1. Top Green Header matching the official E-SUGID header design from Screen 1
              ESugidPageHeader(
                title: 'Private Organizations',
                sectionLabelWidget: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
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
                        'BARILI DIRECTORY',
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
                showBackButton: true,
                onBack: () => Navigator.of(context).pop(),
                showBodyCrown: true,
              ),

              // 2. Body List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                  children: [
                    // 3D Enhanced Glassmorphic / Neumorphic Search Bar
                    _Enhanced3DSearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onClear: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      onOpenFilter: _showAllCategoriesModal,
                      selectedCategory: _selectedCategory,
                    ),
                    const SizedBox(height: 14),

                    // Single-line Category Filter: 5 categories in one line with "Others" dropdown
                    _buildSingleLineCategoryFilter(),
                    const SizedBox(height: 14),

                    // Section Title: "Organizations You May Want to Follow" + "See All"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Organizations You May Want to Follow',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            if (_organizations.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7.5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_organizations.length}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_selectedCategory != 'All' || _searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _onCategorySelected('All');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Clear',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primaryGreen,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            'See All',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Functional Organization Cards List from Firestore
                    if (_loading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: context.colors.brand,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else if (_organizations.isEmpty)
                      _buildEmptyState()
                    else ...[
                      for (int i = 0; i < _organizations.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _buildOrganizationCard(
                          _organizations[i],
                          followedIds.contains(_organizations[i].id),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Single horizontal line with at least 5 categories, where the 5th is "Others" with a dropdown
  Widget _buildSingleLineCategoryFilter() {
    final isOtherSelected = !_primaryCategories
        .any((cat) => (cat['label'] as String) == _selectedCategory,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // The 4 primary category pills
          ..._primaryCategories.map((cat) {
            final label = cat['label'] as String;
            final icon = cat['icon'] as IconData?;
            final isSelected = _selectedCategory == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(
                label: label,
                icon: icon,
                isSelected: isSelected,
                onTap: () => _onCategorySelected(label),
              ),
            );
          }),

          // The 5th item: "Others" with a dropdown icon
          _buildOthersCategoryChip(
            isOtherSelected: isOtherSelected,
            selectedOtherLabel: isOtherSelected ? _selectedCategory : 'Others',
            onTap: _showAllCategoriesModal,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.brand,
                      context.colors.brand,
                      context.colors.brand,
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : (context.colors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? context.colors.primaryGreen.withValues(alpha: 0.75)
                  : (context.colors.border),
              width: 1.2,
            ),
            boxShadow: [
              if (!isDark || isSelected)
                BoxShadow(
                  color: isSelected
                      ? context.colors.highlight.withValues(alpha: 0.35)
                      : context.colors.highlight,
                  offset: const Offset(0, 1.2),
                  blurRadius: 0,
                ),
              BoxShadow(
                color: isSelected
                    ? context.colors.brandStrong.withValues(alpha: 0.38)
                    : (isDark
                        ? context.colors.brandStrong.withValues(alpha: 0.25)
                        : context.colors.brandStrong.withValues(alpha: 0.05)),
                blurRadius: isSelected ? 8 : 4,
                offset: Offset(0, isSelected ? 3 : 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15.5,
                  color: isSelected
                      ? context.colors.onAccent
                      : (context.colors.textSecondary),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected
                      ? context.colors.onAccent
                      : (context.colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOthersCategoryChip({
    required bool isOtherSelected,
    required String selectedOtherLabel,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
          decoration: BoxDecoration(
            gradient: isOtherSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.brand,
                      context.colors.brand,
                      context.colors.brand,
                    ],
                  )
                : null,
            color: isOtherSelected
                ? null
                : (context.colors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOtherSelected
                  ? context.colors.primaryGreen.withValues(alpha: 0.75)
                  : (context.colors.border),
              width: 1.2,
            ),
            boxShadow: [
              if (!isDark || isOtherSelected)
                BoxShadow(
                  color: isOtherSelected
                      ? context.colors.highlight.withValues(alpha: 0.35)
                      : context.colors.highlight,
                  offset: const Offset(0, 1.2),
                  blurRadius: 0,
                ),
              BoxShadow(
                color: isOtherSelected
                    ? context.colors.brandStrong.withValues(alpha: 0.38)
                    : (isDark
                        ? context.colors.brandStrong.withValues(alpha: 0.25)
                        : context.colors.brandStrong.withValues(alpha: 0.05)),
                blurRadius: isOtherSelected ? 8 : 4,
                offset: Offset(0, isOtherSelected ? 3 : 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 15.5,
                color: isOtherSelected
                    ? context.colors.onAccent
                    : (context.colors.textSecondary),
              ),
              const SizedBox(width: 5.5),
              Text(
                selectedOtherLabel,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight:
                      isOtherSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isOtherSelected
                      ? context.colors.onAccent
                      : (context.colors.textPrimary),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: isOtherSelected
                    ? context.colors.onAccent
                    : (context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? context.colors.primaryGreen : context.colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.surfaceAlt,
              border: Border.all(color: context.colors.border),
            ),
            child: Center(
              child: Icon(
                Icons.domain_verification_rounded,
                size: 32,
                color: context.colors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching organizations'
                : _selectedCategory != 'All'
                    ? 'No $_selectedCategory organizations yet'
                    : 'No private organizations found',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term or reset your category filter.'
                : 'Verified private organizations, utility providers, and institutions in Barili will appear here once registered.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategory != 'All') ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                _onCategorySelected('All');
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Reset Filters',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primaryGreen,
                side: BorderSide(color: context.colors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrganizationCard(PrivateOrganization org, bool isFollowed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCustomDescription = org.shortDescription.isNotEmpty &&
        org.shortDescription != 'Verified private organization in Barili.' &&
        org.shortDescription != org.name;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFollowed
              ? context.colors.primaryGreen.withValues(alpha: 0.45)
              : (context.colors.border),
          width: 1.2,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: context.colors.highlight,
              offset: Offset(0, 1.2),
              blurRadius: 0,
            ),
          BoxShadow(
            color: isFollowed
                ? context.colors.brandStrong.withValues(alpha: 0.12)
                : (isDark
                    ? context.colors.brandStrong.withValues(alpha: 0.3)
                    : context.colors.brandStrong.withValues(alpha: 0.06)),
            blurRadius: 16,
            offset: const Offset(0, 5),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.15 : 0.02,
            ),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openProfile(org),
            splashColor: context.colors
                .accent(org.brandColor)
                .withValues(alpha: 0.06),
            highlightColor: context.colors
                .accent(org.brandColor)
                .withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  // 3D Embossed Logo Container (Generous 50x50 with specular depth)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors
                              .accent(org.brandColor)
                              .withValues(alpha: 0.22),
                          context.colors
                              .accent(org.brandColor)
                              .withValues(alpha: 0.07),
                        ],
                      ),
                      border: Border.all(
                        color: context.colors
                            .accent(org.brandColor)
                            .withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors
                              .accent(org.brandColor)
                              .withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        if (!isDark)
                          BoxShadow(
                            color: context.colors.highlight,
                            blurRadius: 0,
                            offset: Offset(0, -1),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (org.logoUrl != null && org.logoUrl!.isNotEmpty)
                          ? Image.network(
                              org.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) =>
                                  _buildBrandFallback(org),
                            )
                          : (org.logoAsset != null && org.logoAsset!.isNotEmpty)
                              ? Image.asset(
                                  org.logoAsset!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) =>
                                      _buildBrandFallback(org),
                                )
                              : _buildBrandFallback(org),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Organization Details (Clean, modern, 3D typography)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name + Verified Badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                org.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (org.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: context.colors.info,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3.5),

                        // Category Pill & Follower Count
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors
                                    .accent(org.brandColor)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    org.fallbackIcon,
                                    size: 11,
                                    color: context.colors.accent(
                                      org.brandColor,
                                  ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    org.category,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.accent(
                                        org.brandColor,
                                    ),
                                  ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: context.colors.info,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.people_alt_rounded,
                              size: 11.5,
                              color: context.colors.textSecondary,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              org.formattedFollowerCount(_service.followerOffsetFor(org),
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        if (hasCustomDescription) ...[
                          const SizedBox(height: 3.5),
                          Text(
                            org.shortDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 3D Single-Tap Follow Button
                  _FollowButton3D(
                    isFollowed: isFollowed,
                    onTap: () => _toggleFollow(org),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandFallback(PrivateOrganization org) {
    return Center(
      child: Icon(
        org.fallbackIcon,
        color: context.colors.accent(org.brandColor),
        size: 24,
      ),
    );
  }
}

/// 3D tactile, realistic single-tap Follow button with instant optimistic feedback
class _FollowButton3D extends StatefulWidget {
  final bool isFollowed;
  final VoidCallback onTap;

  const _FollowButton3D({
    required this.isFollowed,
    required this.onTap});

  @override
  State<_FollowButton3D> createState() => _FollowButton3DState();
}

class _FollowButton3DState extends State<_FollowButton3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFollowed = widget.isFollowed;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isFollowed
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.colors.surfaceAlt,
                      context.colors.surfaceAlt,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.colors.brand,
                      context.colors.brand,
                      context.colors.brand,
                    ],
                  ),
            border: Border.all(
              color: isFollowed
                  ? context.colors.border
                  : context.colors.primaryGreen.withValues(alpha: 0.65),
              width: 1.2,
            ),
            boxShadow: isFollowed
                ? [
                    if (!isDark)
                      BoxShadow(
                        color: context.colors.highlight,
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.10),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: context.colors.highlight.withValues(alpha: 0.35),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.38),
                      blurRadius: _isPressed ? 2.5 : 7,
                      offset: Offset(0, _isPressed ? 1 : 2.5),
                    ),
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child),
                child: Icon(
                  isFollowed ? Icons.check_rounded : Icons.add_rounded,
                  key: ValueKey<bool>(isFollowed),
                  size: 14.5,
                  color: isFollowed
                      ? context.colors.primaryGreen
                      : context.colors.onAccent,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: isFollowed
                      ? context.colors.primaryGreen
                      : context.colors.onAccent,
                ),
                child: Text(isFollowed ? 'Following' : 'Follow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3D Enhanced Glassmorphic & Neumorphic Search Bar with tactile depth and smooth transitions
class _Enhanced3DSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onOpenFilter;
  final String selectedCategory;

  const _Enhanced3DSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onOpenFilter,
    required this.selectedCategory,
  });

  @override
  State<_Enhanced3DSearchBar> createState() => _Enhanced3DSearchBarState();
}

class _Enhanced3DSearchBarState extends State<_Enhanced3DSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = widget.controller.text.isNotEmpty;
    final isCategoryFiltered = widget.selectedCategory != 'All';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 52,
      decoration: BoxDecoration(
        color: (_isFocused ? context.colors.surface : context.colors.surface),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isFocused
              ? context.colors.primaryGreen
              : (context.colors.border),
          width: _isFocused ? 1.6 : 1.2,
        ),
        boxShadow: [
          // 3D Top Specular Highlight (physical bevel effect)
          BoxShadow(
            color: isDark
                ? context.colors.highlight.withValues(alpha: 0.05)
                : context.colors.highlight,
            offset: const Offset(0, 1.2),
            blurRadius: 0,
          ),
          // Directional Ambient Shadow with emerald bloom on focus
          BoxShadow(
            color: _isFocused
                ? context.colors.brandStrong.withValues(alpha: 0.18)
                : (isDark
                    ? context.colors.brandStrong.withValues(alpha: 0.35)
                    : context.colors.brandStrong.withValues(alpha: 0.06)),
            blurRadius: _isFocused ? 16 : 10,
            offset: Offset(0, _isFocused ? 5 : 3),
          ),
          // Subtle contact drop shadow
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // 3D Embossed Search Icon Badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isFocused
                    ? [
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brand,
                      ]
                    : [
                        context.colors.brand,
                        context.colors.brand,
                        context.colors.brand,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.highlight.withValues(alpha: 0.35),
                  offset: const Offset(0, -1),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.38),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.search_rounded,
                color: context.colors.onAccent,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 11),

          // Search TextField
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search organizations, banks, clinics...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: context.colors.info,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Clear Button (when query is entered)
          if (hasText) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onClear();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surfaceAlt,
                    border: Border.all(
                      color: context.colors.border,
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // 3D Tactile Filter / Tune Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenFilter();
              },
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isCategoryFiltered
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.brand,
                            context.colors.brand,
                            context.colors.brand,
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
                    color: isCategoryFiltered
                        ? context.colors.primaryGreen
                        : (context.colors.border),
                    width: 1.1,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.8),
                        offset: const Offset(0, -1),
                        blurRadius: 0,
                      ),
                    BoxShadow(
                      color: isCategoryFiltered
                          ? context.colors.brandStrong.withValues(alpha: 0.35)
                          : context.colors.shadow.withValues(alpha: isDark ? 0.25 : 0.04,
                            ),
                      blurRadius: isCategoryFiltered ? 6 : 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: isCategoryFiltered
                          ? context.colors.onAccent
                          : (context.colors.primaryGreen),
                    ),
                    if (isCategoryFiltered)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.warningSolid,
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
    );
  }
}
