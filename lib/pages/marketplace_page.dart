import 'dart:async';
import 'dart:ui';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../widgets/esugid_page_header.dart';
import '../widgets/adaptive_action_content.dart';
import '../widgets/marketplace_seller_byline.dart';
import '../auth_service.dart';
import '../marketplace_service.dart';
import '../app_motion.dart';
import '../widgets/market_item_form.dart';
import 'marketplace_conversation_page.dart';
import 'marketplace_interest_requests_page.dart';
import 'marketplace_favorites_page.dart';
import 'my_listings_page.dart';
import 'public_user_profile_page.dart';
import '../features/bayanihan_messages/presentation/widgets/bayanihan_unread_button.dart';
import '../features/home/presentation/hub_service_cards.dart';
import '../services/community_trust_service.dart';

Widget _heroMarketFlightShuttle(
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
      final currentRadius = lerpDouble(16, 20, t) ?? 18.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(currentRadius),
        child: Material(
          color: Colors.transparent,
          child: toHero.child),
      );
    },
  );
}

String _formatMarketplaceItemAge(DateTime date) {
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

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key, this.itemsStream});

  final Stream<List<MarketplaceItem>>? itemsStream;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _PostMarketItemPage extends StatelessWidget {
  const _PostMarketItemPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ESugidPageHeader(
          sectionLabel: 'Local Market',
          title: 'POST AN ITEM',
          subtitle: 'Share with your local neighbors',
          icon: Icons.add_business_rounded,
          showBackButton: true,
        ),
        const Expanded(child: MarketItemForm()),
      ],
    ),
  );
}

class _EditMarketItemPage extends StatelessWidget {
  final MarketplaceItem item;
  const _EditMarketItemPage({required this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const ESugidPageHeader(
          sectionLabel: 'Local Market',
          title: 'EDIT LISTING',
          subtitle: 'Update your listing details',
          icon: Icons.edit_note_rounded,
          showBackButton: true,
        ),
        Expanded(
          child: MarketItemForm(
            initialItem: item,
            onSubmitted: () => Navigator.pop(context, true),
          ),
        ),
      ],
    ),
  );
}

class MarketListingsPage extends StatefulWidget {
  const MarketListingsPage({
    super.key,
    required this.items,
    required this.onOpen,
    required this.favorites,
    required this.onFavorite,
    this.initialFilter = 'All',
  });
  final List<MarketplaceItem> items;
  final ValueChanged<MarketplaceItem> onOpen;
  final Set<String> favorites;
  final ValueChanged<String> onFavorite;
  final String initialFilter;

  @override
  State<MarketListingsPage> createState() => _MarketListingsPageState();
}

class _MarketListingsPageState extends State<MarketListingsPage> {
  late String _filter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(MarketplaceItem item) {
    final matchesFilter =
        _filter == 'All' ||
        item.category.toLowerCase().contains(_filter.toLowerCase()) ||
        (_filter == 'Plants' && item.category == 'Plants & Seeds') ||
        (_filter == 'Handmade' && item.category == 'Local Food') ||
        (_filter == 'Tools' && item.category == 'Tools & Equipment');

    if (!matchesFilter) return false;

    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return item.name.toLowerCase().contains(q) ||
        item.sellerName.toLowerCase().contains(q) ||
        item.location.toLowerCase().contains(q) ||
        item.category.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where(_matches).toList();
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          ESugidPageHeader(
            sectionLabel: 'Local Market',
            title: 'ALL LISTINGS',
            showBackButton: true,
          ),

          _buildSearchBar(),

          // Realistic 3D Segmented Filter Chips
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: 8,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final labels = [
                  'All',
                  'Farm Produce',
                  'Livestock',
                  'Plants',
                  'Handmade',
                  'Tools',
                  'Household',
                  'Other',
                ];
                final icons = [
                  Icons.grid_view_rounded,
                  Icons.grass_rounded,
                  Icons.pets_rounded,
                  Icons.local_florist_rounded,
                  Icons.brush_rounded,
                  Icons.handyman_rounded,
                  Icons.home_rounded,
                  Icons.more_horiz_rounded,
                ];
                final label = labels[index];
                final active = label == _filter;

                return ESugidPressable(
                  onTap: () {
                    setState(() => _filter = label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.surface,
                                context.colors.surface,
                              ],
                            ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? context.colors.border.withValues(alpha: 0.45)
                            : context.colors.border.withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.38,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: context.colors.highlight.withValues(alpha: 0.35,
                                ),
                                offset: const Offset(0, -1.2),
                                blurRadius: 0,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.04,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: active
                                ? context.colors.surface.withValues(alpha: 0.20)
                                : context.colors.brand.withValues(alpha: 0.09),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              icons[index],
                              size: 13,
                              color: active
                                  ? context.colors.onAccent
                                  : context.colors.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: active
                                ? context.colors.onAccent
                                : context.colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // High-End 3D Listing Cards
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching listings found.',
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, index) =>
                        _buildBariliFindsListingCard(items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBariliFindsListingCard(MarketplaceItem item) {
    final isSold = item.isSold;
    final isOwner = item.isOwnedBy(AuthService.currentUser?.uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFavorite = widget.favorites.contains(item.id);

    return Semantics(
      label:
          'Marketplace item: ${item.name}, priced at ${item.formattedPrice} per ${item.priceUnit}. Seller: ${item.sellerName}. Status: ${item.status}.',
      button: true,
      onTapHint: 'View product details',
      child: Container(
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
            onTap: () => widget.onOpen(item),
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
                // Clean porcelain theme border (matches app theme)
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: Seller Avatar + Name & Age + Status Badge + 3D Heart
                    Row(
                      children: [
                        // Seller Info (Tappable to view public profile)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: item.sellerId.isNotEmpty
                                ? () => PublicUserProfilePage.show(
                                      context,
                                      item.sellerId,
                                    )
                                : null,
                            child: Row(
                              children: [
                                // Avatar circle with subtle 3D border
                                _SellerCardAvatar(
                                  sellerId: item.sellerId,
                                  sellerName: item.sellerName,
                                  isDark: isDark,
                                  size: 38,
                                ),
                                const SizedBox(width: 10),

                                // Seller Name + Verified Badge + Age
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.sellerName.isNotEmpty
                                                  ? item.sellerName
                                                  : 'Barili Neighbor',
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
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 14,
                                            color: context.colors.primaryGreen,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _formatMarketplaceItemAge(item.createdAt,
                                        ),
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

                        // Status Pill Badge (e.g. AVAILABLE or SOLD)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSold
                                ? (isDark
                                    ? context.colors.surfaceAlt.withValues(
                                          alpha: 0.1020,
                                        )
                                      : context.colors.surfaceAlt)
                                : (isDark
                                    ? context.colors.surfaceAlt.withValues(alpha: 0.6,
                                        )
                                    : context.colors.surfaceAlt),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSold
                                  ? (isDark
                                      ? context.colors.border.withValues(
                                            alpha: 0.2392,
                                          )
                                        : context.colors.border)
                                  : (isDark
                                      ? context.colors.primaryGreen
                                        : context.colors.border),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            isSold ? 'SOLD' : 'AVAILABLE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSold
                                  ? context.colors.textSecondary
                                  : (context.colors.primaryGreen),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3D Glossy Heart Favorite Button
                        ESugidPressable(
                          onTap: () {
                            widget.onFavorite(item.id);
                            setState(() {});
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isFavorite
                                    ? [
                                        context.colors.errorSurface,
                                        context.colors.errorSurface,
                                      ]
                                    : [
                                        context.colors.surface,
                                        context.colors.surfaceAlt,
                                      ],
                              ),
                              border: Border.all(
                                color: isFavorite
                                    ? context.colors.error
                                    : context.colors.border,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isFavorite
                                      ? context.colors.highlight.withValues(alpha: 0.25,
                                        )
                                      : context.colors.shadow.withValues(alpha: 0.05,
                                        ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFavorite
                                    ? context.colors.error
                                    : context.colors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo (Right)
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
                                item.category.toUpperCase(),
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

                              // Product Title
                              Text(
                                item.name,
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

                              // Gold & Emerald Price Badge
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
                                        item.formattedPrice,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.onBrandMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '/ ${item.priceUnit}',
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
                                      '${item.location.isNotEmpty ? item.location : (item.meetupArea.isNotEmpty ? item.meetupArea : 'Barili, Cebu')} · ${(item.id.codeUnits.fold<int>(0, (a, b) => a + b) % 8) + 1} km away',
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
                            child: _listingImage(item.imageUrl),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Bottom Row: 3D Highlighted Tactile Action Button
                    TactileSpringButton(
                      onTap: () => widget.onOpen(item),
                      scale: 0.97,
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: isSold
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
                            color: isSold
                                ? context.colors.border.withValues(
                                    alpha: 0.2392,
                                  )
                                : context.colors.border.withValues(alpha: 0.90),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (!isSold) ...[
                              // Vibrant radiant luxury depth shadow
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(
                                  alpha: 0.45,
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
                              if (!isSold)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isOwner
                                          ? 'MANAGE LISTING'
                                          : isSold
                                          ? 'SOLD OUT'
                                          : "I'M INTERESTED",
                                      style: GoogleFonts.outfit(
                                        color: isSold
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
                                          : isSold
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.volunteer_activism_rounded,
                                      color: isSold
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

  Widget _listingImage(String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderBg = isDark
        ? context.colors.surfaceAlt
        : context.colors.surfaceAlt;
    if (url.trim().isEmpty) {
      return Container(
        color: placeholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: context.colors.textSecondary,
          size: 40,
        ),
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 720,
      errorBuilder: (_, _, _) => Container(
        color: placeholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Deep Realistic 3D Shadow for Elevation
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.12),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
            // Emerald Ambient Glow
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            enabled: MediaQuery.viewInsetsOf(context).bottom == 0,
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Barili\'s treasures...',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 15,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 14, right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.45,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                        // Internal highlight for realistic 3D depth
                        BoxShadow(
                          color: context.colors.highlight.withValues(
                            alpha: 0.2392,
                          ),
                          offset: Offset(0, -2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: context.colors.onAccent,
                      size: 20,
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.colors.textSecondary,
                            size: 22,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.brandStrong.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: context.colors.textPrimary,
                            size: 20,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplacePageState extends State<MarketplacePage> {
  final TextEditingController _marketSearchController = TextEditingController();
  final Set<String> _favoriteItemIds = <String>{};
  StreamSubscription<Set<String>>? _favoritesSubscription;
  late Stream<List<MarketplaceItem>> _itemsStream;

  @override
  void initState() {
    super.initState();
    _itemsStream = widget.itemsStream ?? MarketplaceService.itemsStream;
    final user = AuthService.currentUser;
    if (user != null) {
      MarketplaceService.loadViewedFavorites(user.uid);
      _favoritesSubscription =
          MarketplaceService.favoriteItemIdsStream(user.uid).listen((
            favoriteIds,
          ) {
            if (!mounted) return;
            setState(() {
              _favoriteItemIds
                ..clear()
                ..addAll(favoriteIds);
            });
          });
    }
  }

  @override
  void didUpdateWidget(covariant MarketplacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemsStream != widget.itemsStream) {
      _itemsStream = widget.itemsStream ?? MarketplaceService.itemsStream;
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _marketSearchController.dispose();
    super.dispose();
  }

  Widget _buildMarketListings(
    BuildContext context,
    AsyncSnapshot<List<MarketplaceItem>> snapshot,
    List<MarketplaceItem> allItems,
  ) {
    final items = _filteredMarketItems(allItems);

    if (snapshot.connectionState == ConnectionState.waiting &&
        allItems.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: context.colors.primaryGreen,
          ),
        ),
      );
    }

    if (allItems.isEmpty) {
      return SliverToBoxAdapter(child: _buildMarketIntroSection());
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No items found matching your criteria',
                style: GoogleFonts.outfit(
                  color: context.colors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) return _buildBariliFindsHeader(allItems);
          return ESugidEntrance(
            enabled: index <= 4,
            child: _buildBariliFindsCard(items[index - 1]),
          );
        }, childCount: items.length + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          _buildMarketHeader(),
          SliverToBoxAdapter(child: _buildMarketSearch()),
          SliverToBoxAdapter(child: _buildPromotionalBanner()),
          StreamBuilder<List<MarketplaceItem>>(
            stream: _itemsStream,
            builder: (context, snapshot) {
              final allItems = snapshot.data ?? [];
              return SliverMainAxisGroup(slivers: [
                SliverToBoxAdapter(child: _buildMarketCategories(allItems)),
                _buildMarketListings(context, snapshot, allItems),
              ]);
            },
          ),
        ],
      ),
      floatingActionButton: ESugidPressable(
        onTap: _showSellForm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.colors.brand, context.colors.brand],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.20),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_business_rounded,
                color: context.colors.onAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sell an Item',
                style: GoogleFonts.outfit(
                  color: context.colors.onAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(
                      color: context.colors.textPrimary.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MarketplaceItem> _filteredMarketItems(List<MarketplaceItem> items) {
    final query = _marketSearchController.text.trim().toLowerCase();
    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          '${item.name} ${item.sellerName} ${item.location} ${item.category}'
              .toLowerCase()
              .contains(query);
      return matchesQuery;
    }).toList();
  }


  Widget _buildMarketHeader() {
    return ESugidSliverPageHeader(
      pinned: true,
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
              'BARILI COMMERCE',
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
      title: 'Local Market',
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
              Icons.storefront_rounded,
              color: context.colors.onBrandMuted,
              size: 19,
            ),
          ),
        ),
      ),
      showBackButton: true,
      onBack: () => Navigator.maybePop(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buyerRequestsButton(),
          const SizedBox(width: 6),
          ValueListenableBuilder<Set<String>>(
            valueListenable: MarketplaceService.viewedFavoritesNotifier,
            builder: (context, viewedFavorites, _) {
              final unviewedCount = _favoriteItemIds
                  .where((id) => !viewedFavorites.contains(id))
                  .length;
              return _marketHeaderAction(
                tooltip: 'Favorites',
                icon: _favoriteItemIds.isEmpty
                    ? Icons.favorite_border_rounded
                    : Icons.favorite_rounded,
                badgeCount: unviewedCount,
                onTap: _openFavorites,
              );
            },
          ),
          const SizedBox(width: 6),
          _marketHeaderAction(
            tooltip: 'My Listings',
            icon: Icons.inventory_2_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyListingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketHeaderAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badgeCount > 0 ? '$tooltip, $badgeCount items' : tooltip,
        child: ESugidPressable(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface.withValues(alpha: 0.22),
                        context.colors.surface.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.40),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: context.colors.highlight.withValues(
                          alpha: 0.2392,
                        ),
                        offset: Offset(0, -1),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: context.colors.onAccent, size: 20),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -3,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.errorSolid,
                            context.colors.errorSolid,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.colors.border, width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.errorSolid.withValues(alpha: 0.5,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.onAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
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
  }

  Widget _buyerRequestsButton() {
    final user = AuthService.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<List<MarketplaceInterestRequest>>(
      stream: MarketplaceService.sellerInterestRequests(user.uid),
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? const [])
            .where(
              (request) => request.status == MarketplaceInterestStatus.pending,
            )
            .length;
        return CivicMessagingButton(
          tooltip: pending > 0
              ? '$pending pending buyer ${pending == 1 ? 'inquiry' : 'inquiries'}'
              : 'Buyer Inquiries',
          unreadCount: pending,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MarketplaceInterestRequestsPage(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Deep Realistic 3D Elevation Shadow
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
          // Ambient Emerald Soft Glow
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          // Top Specular Highlight Rim
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          enabled: MediaQuery.viewInsetsOf(context).bottom == 0,
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.surface, context.colors.surface],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.95),
                width: 1.6,
              ),
            ),
            child: Row(
              children: [
                // 3D Jewel Search Medallion (Bigger Icon)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [context.colors.brand, context.colors.brand],
                      ),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.38,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: context.colors.highlight.withValues(alpha: 0.35,
                          ),
                          blurRadius: 0,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.search_rounded,
                        color: context.colors.onAccent,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Search Input Field
                Expanded(
                  child: TextField(
                    controller: _marketSearchController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search fresh harvests, local sellers...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14.5,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                // Trailing Action: 3D Clear or 3D Tactile Filter Button
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 6),
                  child: _marketSearchController.text.isNotEmpty
                      ? ESugidPressable(
                          onTap: () {
                            _marketSearchController.clear();
                            setState(() {});
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.brandStrong.withValues(alpha: 0.08,
                              ),
                              border: Border.all(
                                color: context.colors.primaryGreen.withValues(alpha: 0.12,
                                ),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.close_rounded,
                                color: context.colors.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        )
                      : ESugidPressable(
                          onTap: () {
                            // Filter tap action
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.surfaceAlt,
                                  context.colors.surfaceAlt,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.colors.primaryGreen.withValues(alpha: 0.35,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.12,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: context.colors.highlight,
                                  blurRadius: 0,
                                  offset: Offset(0, -1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.tune_rounded,
                                color: context.colors.textPrimary,
                                size: 21,
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
    ),
  );

  Widget _buildMarketCategories(List<MarketplaceItem> allItems) {
    const categories = <({String name, String asset})>[
      (
        name: 'Farm Produce',
        asset: 'assets/images/resident_dashboard/farm.png',
      ),
      (
        name: 'Livestock',
        asset: 'assets/images/resident_dashboard/livestock.png',
      ),
      (name: 'Plants', asset: 'assets/images/resident_dashboard/plants.png'),
      (
        name: 'Handmade',
        asset: 'assets/images/resident_dashboard/handmade.png',
      ),
      (name: 'Tools', asset: 'assets/images/resident_dashboard/tools.png'),
      (
        name: 'Household',
        asset: 'assets/images/resident_dashboard/household.png',
      ),
      (name: 'Other', asset: 'assets/images/resident_dashboard/other.png'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: context.colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              ESugidPressable(
                onTap: () => _openAllListings(allItems),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: context.colors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, index) {
              final item = categories[index];
              return ESugidPressable(
                onTap: () =>
                    _openAllListings(allItems, initialFilter: item.name),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 3D Porcelain / Crystal Category Medallion
                    Container(
                      width: 64,
                      height: 64,
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
                        border: Border.all(color: context.colors.border, width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.14,
                            ),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.18,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.85,
                            ),
                            blurRadius: 0,
                            offset: const Offset(0, -1.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.surface,
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.06,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              item.asset,
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.category_outlined,
                                    color: context.colors.primaryGreen,
                                    size: 26,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.name,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionalBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.38),
          width: 1.4,
        ),
        boxShadow: [
          // 3D Realistic Grounding Shadow
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          // Volumetric Emerald Glow
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.30),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Lush Multi-Stop Deep Forest to Jade Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.brandStrong,
                    context.colors.brandStrong,
                    context.colors.brand,
                    context.colors.brand,
                  ],
                ),
              ),
            ),
            // Volumetric Ambient Sunburst Orb 1: Amber Glow
            Positioned(
              top: -35,
              left: -35,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.colors.warningSolid.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Volumetric Ambient Orb 2: Vivid Jade Glow
            Positioned(
              bottom: -25,
              right: 80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.colors.brand.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Top Specular Crystal Rim Highlight Line
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              height: 1.6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.surface.withValues(alpha: 0.0),
                      context.colors.surface.withValues(alpha: 0.90),
                      context.colors.surface.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Background Image Overlay (tinted green)
            Opacity(
              opacity: 0.16,
              child: Image.asset(
                'assets/images/resident_dashboard/banner.jfif',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                color: context.colors.brand,
                colorBlendMode: BlendMode.color,
              ),
            ),
            // Grounding Shadow for Farmer Character
            Positioned(
              right: -10,
              bottom: -6,
              child: Container(
                width: 170,
                height: 26,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.70),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            // 3D Farmer Character with Basket Pop-Out
            Positioned(
              right: -16,
              bottom: -16,
              child: Image.asset(
                'assets/images/resident_dashboard/man1.png',
                height: 228,
                fit: BoxFit.contain,
              ),
            ),
            // Content Column (Left)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3D Glassmorphic Civic Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9.5,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandStrong.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌾', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 5),
                        Text(
                          'BARILI HARVEST SHOWCASE',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bold 3D Headline
                  Text(
                    'Local Market\nShowcase',
                    style: GoogleFonts.outfit(
                      fontSize: 27,
                      color: context.colors.onAccent,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: context.colors.textPrimary.withValues(alpha: 0.55,
                          ),
                          offset: const Offset(0, 2.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    'Discover Barili\'s finest products\ndirectly from our neighbors.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: context.colors.onAccent.withValues(alpha: 0.94),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      shadows: [
                        Shadow(
                          color: context.colors.textPrimary.withValues(alpha: 0.4,
                          ),
                          offset: const Offset(0, 1.5),
                          blurRadius: 4,
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
    );
  }

  Widget _buildMarketIntroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.04),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.02),
                  blurRadius: 1,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.brand.withValues(alpha: 0.1),
                              context.colors.brand.withValues(alpha: 0.02),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Image.asset(
                        'assets/images/resident_dashboard/man1.png',
                        height: 190,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Barili Finds',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Be the first to list your fresh harvests, livestock, or local food and help our Barili community grow together.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.colors.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                _build3DActionButton(
                  label: 'Start Selling Today',
                  onTap: _showSellForm,
                  color: context.colors.brand,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyListingsPage()),
                  ),
                  child: Text(
                    'Manage Your Listings',
                    style: GoogleFonts.outfit(
                      color: context.colors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _marketFeatureCard(
                  Icons.verified_user_outlined,
                  'Safe & Trusted',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _marketFeatureCard(
                  Icons.local_shipping_outlined,
                  'Direct Pickup',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marketFeatureCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.highlight,
            blurRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.colors.primaryGreen, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String itemId) async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(content: Text('Please sign in to save favorites.'),
          kind: FeedbackKind.warning,
        ),
      );
      return;
    }

    final wasFavorite = _favoriteItemIds.contains(itemId);
    setState(() {
      wasFavorite
          ? _favoriteItemIds.remove(itemId)
          : _favoriteItemIds.add(itemId);
    });
    try {
      await MarketplaceService.setFavorite(
        userId: user.uid,
        itemId: itemId,
        isFavorite: !wasFavorite,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasFavorite
            ? _favoriteItemIds.add(itemId)
            : _favoriteItemIds.remove(itemId);
      });
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not update favorites. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  void _openFavorites() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MarketplaceFavoritesPage(onOpenListing: _showItemDetails),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
    }
  }

  void _openAllListings(
    List<MarketplaceItem> items, {
    String initialFilter = 'All',
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MarketListingsPage(
        items: items,
        initialFilter: initialFilter,
        onOpen: (item) => _showItemDetails(item),
        favorites: _favoriteItemIds,
        onFavorite: _toggleFavorite,
      ),
    ),
  );

  Widget _buildBariliFindsHeader(List<MarketplaceItem> allItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        'Barili Finds',
        style: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: context.colors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  String _formatItemAge(DateTime date) => _formatMarketplaceItemAge(date);

  Widget _buildBariliFindsCard(MarketplaceItem item) {
    final isSold = item.isSold;
    final isOwner = item.isOwnedBy(AuthService.currentUser?.uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFavorite = _favoriteItemIds.contains(item.id);

    return Semantics(
      label:
          'Marketplace item: ${item.name}, priced at ${item.formattedPrice} per ${item.priceUnit}. Seller: ${item.sellerName}. Status: ${item.status}.',
      button: true,
      onTapHint: 'View product details',
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
            onTap: () => _showItemDetails(item),
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
                // Clean porcelain theme border (matches app theme)
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: Seller Avatar + Name & Age + Status Badge + 3D Heart
                    Row(
                      children: [
                        // Seller Info (Tappable to view public profile)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: item.sellerId.isNotEmpty
                                ? () => PublicUserProfilePage.show(
                                      context,
                                      item.sellerId,
                                    )
                                : null,
                            child: Row(
                              children: [
                                // Avatar circle with subtle 3D border
                                _SellerCardAvatar(
                                  sellerId: item.sellerId,
                                  sellerName: item.sellerName,
                                  isDark: isDark,
                                  size: 38,
                                ),
                                const SizedBox(width: 10),

                                // Seller Name + Verified Badge + Age
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.sellerName.isNotEmpty
                                                  ? item.sellerName
                                                  : 'Barili Neighbor',
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
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 14,
                                            color: context.colors.primaryGreen,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        _formatItemAge(item.createdAt),
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

                        // Status Pill Badge (e.g. AVAILABLE or SOLD)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSold
                                ? (isDark ? context.colors.surfaceAlt.withValues(
                                          alpha: 0.1020,
                                        )
                                      : context.colors.surfaceAlt)
                                : (isDark
                                    ? context.colors.surfaceAlt.withValues(alpha: 0.6,
                                        )
                                    : context.colors.surfaceAlt),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSold
                                  ? (isDark ? context.colors.border.withValues(
                                            alpha: 0.2392,
                                          )
                                  : context.colors.border)
                                      : (context.colors.border),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            isSold ? 'SOLD' : 'AVAILABLE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSold
                                  ? context.colors.textSecondary
                                  : (context.colors.primaryGreen),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3D Glossy Heart Favorite Button
                        ESugidPressable(
                          onTap: () => _toggleFavorite(item.id),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isFavorite
                                    ? [
                                        context.colors.errorSurface,
                                        context.colors.errorSurface,
                                      ]
                                    : [
                                        context.colors.surface,
                                        context.colors.surfaceAlt,
                                      ],
                              ),
                              border: Border.all(
                                color: isFavorite
                                    ? context.colors.error
                                    : context.colors.border,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isFavorite
                                      ? context.colors.highlight.withValues(alpha: 0.25,
                                        )
                                      : context.colors.shadow.withValues(alpha: 0.05,
                                        ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFavorite
                                    ? context.colors.error
                                    : context.colors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo (Right)
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
                                item.category.toUpperCase(),
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

                              // Product Title
                              Text(
                                item.name,
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

                              // Gold & Emerald Price Badge
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
                                        item.formattedPrice,
                                        style: GoogleFonts.outfit(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w900,
                                          color: context.colors.onBrandMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '/ ${item.priceUnit}',
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
                                      '${item.location.isNotEmpty ? item.location : (item.meetupArea.isNotEmpty ? item.meetupArea : 'Barili, Cebu')} · ${(item.id.codeUnits.fold<int>(0, (a, b) => a + b) % 8) + 1} km away',
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
                          tag: 'market-image-${item.id}',
                          flightShuttleBuilder: _heroMarketFlightShuttle,
                          child: Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: context.colors.border,
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
                              child: _marketImage(item.imageUrl),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Bottom Row: 3D Highlighted Tactile Action Button
                    TactileSpringButton(
                      onTap: () => _showItemDetails(item),
                      scale: 0.97,
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: isSold
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
                            color: isSold
                                ? context.colors.border.withValues(
                                    alpha: 0.2392,
                                  )
                                : context.colors.border.withValues(alpha: 0.90),
                            width: 1.5,
                          ),
                          boxShadow: [
                            if (!isSold) ...[
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
                              if (!isSold)
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
                                          ? 'MANAGE LISTING'
                                          : isSold
                                          ? 'SOLD OUT'
                                          : "I'M INTERESTED",
                                      style: GoogleFonts.outfit(
                                        color: isSold
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
                                          : isSold
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.volunteer_activism_rounded,
                                      color: isSold
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

  Widget _marketImage(String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderBg = isDark ? context.colors.surfaceAlt
        : context.colors.surfaceAlt;
    if (url.isEmpty) {
      return Container(
        color: placeholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: context.colors.textSecondary,
          size: 40,
        ),
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 720,
      errorBuilder: (_, _, _) => Container(
        color: placeholderBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _showSellForm() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const _PostMarketItemPage()),
    );
  }

  Future<void> _showItemDetails(MarketplaceItem item) {
    final user = AuthService.currentUser;
    if (user != null) {
      MarketplaceService.markFavoriteViewed(
        userId: user.uid,
        itemId: item.id);
    }
    var isSendingInterest = false;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.colors.shadow.withValues(alpha: 0.65),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) =>
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('marketplace')
                  .doc(item.id)
                  .snapshots(),
              builder: (sheetContext, itemSnapshot) {
                if (itemSnapshot.hasData &&
                    itemSnapshot.data != null &&
                    !itemSnapshot.data!.exists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  });
                  return const SizedBox.shrink();
                }

                final currentItem =
                    itemSnapshot.hasData &&
                    itemSnapshot.data != null &&
                    itemSnapshot.data!.exists
                    ? MarketplaceItem.fromMap(itemSnapshot.data!.data()!)
                    : item;
                final isOwner = currentItem.isOwnedBy(user?.uid);
                final isAvailable = currentItem.isAvailable;
                final isSold = currentItem.isSold;
                final isFavorite = _favoriteItemIds.contains(currentItem.id);

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
                            _buildMarketEditorialTopBar(
                              sheetContext: sheetContext,
                              currentItem: currentItem,
                              isFavorite: isFavorite,
                              setModalState: setModalState,
                            ),

                            // 2. Scrollable Content
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 3. Wide 3D Hero Showcase with Floating Badges
                                    _buildMarket3DHeroShowcase(currentItem),

                                    const SizedBox(height: 18),

                                    // 4. Product Title & Status Badge
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            currentItem.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: sheetContext
                                                  .colors
                                                  .textPrimary,
                                              height: 1.2,
                                              letterSpacing: -0.3,
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
                                            color: isSold
                                                ? sheetContext.colors.surfaceAlt
                                                : sheetContext
                                                      .colors
                                                      .surfaceAlt,
                                            borderRadius: BorderRadius.circular(20,
                                            ),
                                            border: Border.all(
                                              color: isSold
                                                  ? sheetContext.colors.border
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
                                                  color: isSold
                                                      ? sheetContext
                                                            .colors
                                                            .infoSolid
                                                      : sheetContext
                                                            .colors
                                                            .brand,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                isSold ? 'Sold' : 'Available',
                                                style: GoogleFonts.outfit(
                                                  color: isSold
                                                      ? sheetContext
                                                            .colors
                                                            .textSecondary
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

                                    const SizedBox(height: 12),

                                    // 5. Luxury Gold & Emerald Price Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sheetContext.colors.brandStrong,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: sheetContext.colors.border,
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: sheetContext
                                                .colors
                                                .brandStrong
                                                .withValues(alpha: 0.30),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            currentItem.formattedPrice,
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: sheetContext
                                                  .colors
                                                  .onBrandMuted,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '/ ${currentItem.priceUnit}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: sheetContext
                                                  .colors
                                                  .onBrandMuted
                                                  .withValues(alpha: 0.90),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    MarketplaceSellerByline(
                                      sellerName: currentItem.sellerName,
                                      age: _formatItemAge(currentItem.createdAt),
                                      avatar: _SellerCardAvatar(
                                        sellerId: currentItem.sellerId,
                                        sellerName: currentItem.sellerName,
                                        isDark: Theme.of(sheetContext).brightness == Brightness.dark,
                                        size: 28,
                                      ),
                                      onSellerTap: currentItem.sellerId.isNotEmpty
                                          ? () => PublicUserProfilePage.show(
                                                context,
                                                currentItem.sellerId,
                                              )
                                          : null,
                                    ),

                                    const SizedBox(height: 18),

                                    // 7. 4-Metric Highlights Bar
                                    _buildMarketHighlightsBar(currentItem),

                                    const SizedBox(height: 18),

                                    // 8. Product Narrative Card
                                    _buildMarketProductNarrative(currentItem.description,
                                    ),

                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),

                            // 9. Sticky Dual Bottom Action Bar
                            Container(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16,
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
                              child: _buildMarketDetailsBottomBar(
                                currentItem: currentItem,
                                isOwner: isOwner,
                                isAvailable: isAvailable,
                                sheetContext: sheetContext,
                                isSendingInterest: isSendingInterest,
                                setModalState: setModalState,
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


  Widget _buildBuyerInterestAction(
    MarketplaceItem item, {
    required bool isSendingInterest,
    required ValueChanged<bool> setSending,
  }) {
    final user = AuthService.currentUser;
    if (item.isOwnedBy(user?.uid)) {
      return _buildLuxuryInterestedButton(
        label: 'MANAGE LISTING',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyListingsPage()),
        ),
        icon: Icons.tune_rounded,
      );
    }
    if (user == null) {
      return _buildLuxuryInterestedButton(
        label: "I'M INTERESTED",
        onTap: () => ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(content: Text('Please sign in to continue.'),
            kind: FeedbackKind.warning,
          ),
        ),
        icon: Icons.volunteer_activism_rounded,
      );
    }

    return StreamBuilder<MarketplaceInterestRequest?>(
      stream: MarketplaceService.interestRequestStream(
        item: item,
        buyerId: user.uid,
      ),
      builder: (context, snapshot) {
        final request = snapshot.data;
        if (request == null) {
          return _buildLuxuryInterestedButton(
            label: "I'M INTERESTED",
            onTap: () =>
                _showInterestRequestSheet(item, setSending: setSending),
            isLoading: isSendingInterest,
            icon: Icons.volunteer_activism_rounded,
          );
        }
        final label = switch (request.status) {
          MarketplaceInterestStatus.pending => 'REQUEST SENT',
          MarketplaceInterestStatus.accepted => 'OPEN CONVERSATION',
          MarketplaceInterestStatus.declined => 'REQUEST DECLINED',
          MarketplaceInterestStatus.completed => 'VIEW CONVERSATION',
        };
        final icon = request.status == MarketplaceInterestStatus.pending
            ? Icons.schedule_rounded
            : Icons.forum_rounded;

        if (request.status == MarketplaceInterestStatus.accepted) {
          return _buildLuxuryInterestedButton(
            label: label,
            onTap: () => _openInterestConversation(request),
            icon: icon,
          );
        }

        return _build3DMarketAction(
          label: label,
          onTap: () => _openInterestConversation(request),
          icon: icon,
          color: request.status == MarketplaceInterestStatus.declined
              ? context.colors.textSecondary
              : context.colors.primaryGreen,
          isOutline: request.status != MarketplaceInterestStatus.accepted,
        );
      },
    );
  }

  Future<void> _showInterestRequestSheet(
    MarketplaceItem item, {
    required ValueChanged<bool> setSending,
  }) async {
    final user = AuthService.currentUser;
    if (user == null || item.sellerId == user.uid) return;

    final createdId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InterestRequestSheet(item: item),
    );

    if (!mounted || createdId == null) return;

    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(
        content: Text('Interest request sent successfully!'),
        kind: FeedbackKind.success,
      ),
    );

    try {
      final request = await MarketplaceService.conversationStream(
        createdId,
      ).first;
      if (mounted && request != null) {
        await _openInterestConversation(request);
      }
    } catch (_) {
      // Ignored: parent details sheet StreamBuilder will update status
    }
  }

  Future<void> _openInterestConversation(
    MarketplaceInterestRequest request,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketplaceConversationPage(request: request),
      ),
    );
  }

  Widget _build3DActionButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
    double height = 62,
    double fontSize = 15,
  }) {
    return ESugidPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.85)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.4),
              blurRadius: 0,
              offset: const Offset(0, -3),
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.2),
              blurRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: context.colors.surface,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: context.colors.onAccent,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: context.colors.shadow.withValues(alpha: 0.2588),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _build3DMarketAction({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    bool isOutline = false,
    bool isLoading = false,
  }) {
    return ESugidPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isOutline
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.85)],
                ),
          color: isOutline ? context.colors.surface : null,
          boxShadow: [
            // Dynamic outer glow
            BoxShadow(
              color: color.withValues(alpha: isOutline ? 0.05 : 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            // Glossy 3D Highlight
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: isOutline ? 0.8 : 0.45,
              ),
              blurRadius: 0,
              offset: const Offset(0, -4),
            ),
            // Realistic weighted depth shadow
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.2),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isOutline
                ? context.colors.border
                : context.colors.border.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: isOutline ? color : context.colors.surface,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isOutline ? color : context.colors.onAccent,
                      shadows: isOutline
                          ? null
                          : [
                              Shadow(
                                color: context.colors.textPrimary.withValues(alpha: 0.3,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: isOutline ? color : context.colors.onAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        shadows: isOutline
                            ? null
                            : [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildMarketEditorialTopBar({
    required BuildContext sheetContext,
    required MarketplaceItem currentItem,
    required bool isFavorite,
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
                'Item Details',
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
                    final willBeFav = !isFavorite;
                    setModalState(() {
                      if (willBeFav) {
                        _favoriteItemIds.add(currentItem.id);
                      } else {
                        _favoriteItemIds.remove(currentItem.id);
                      }
                    });
                    setState(() {});
                    _toggleFavorite(currentItem.id);
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFavorite ? sheetContext.colors.errorSurface
                          : sheetContext.colors.surface,
                      border: Border.all(
                        color: isFavorite
                            ? sheetContext.colors.error
                            : sheetContext.colors.border,
                        width: isFavorite ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isFavorite
                              ? sheetContext.colors.highlight.withValues(alpha: 0.25,
                                )
                              : sheetContext.colors.shadow.withValues(alpha: 0.04,
                                ),
                          blurRadius: isFavorite ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFavorite
                            ? sheetContext.colors.error
                            : sheetContext.colors.textSecondary,
                      ),
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

  Widget _buildMarket3DHeroShowcase(MarketplaceItem item) {
    final hasPhoto = item.imageUrl.trim().isNotEmpty;
    final catIcon = switch (item.category.toLowerCase()) {
      'farm produce' => Icons.grass_rounded,
      'livestock' => Icons.pets_rounded,
      'plants' => Icons.local_florist_rounded,
      'handmade' => Icons.brush_rounded,
      'tools' => Icons.handyman_rounded,
      'household' => Icons.home_rounded,
      _ => Icons.storefront_rounded,
    };

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.border,
          width: 2.0),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            hasPhoto
                ? Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: context.colors.surfaceAlt,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: context.colors.info,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.brandStrong,
                          context.colors.brand,
                          context.colors.brandStrong,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        catIcon,
                        size: 64,
                        color: context.colors.onAccent.withValues(alpha: 0.8),
                      ),
                    ),
                  ),

            // Subtle Gradient Vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.colors.shadow.withValues(alpha: 0.35),
                      Colors.transparent,
                      context.colors.shadow.withValues(alpha: 0.30),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // Top-Left Floating Category Pill
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
                      catIcon,
                      size: 13,
                      color: context.colors.onAccent),
                    const SizedBox(width: 5),
                    Text(
                      item.category.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-Right Floating Condition Badge
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(alpha: 0.1216),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  item.condition.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: context.colors.primaryGreen,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // If Sold: Frosted Overlay
            if (item.isSold)
              Positioned.fill(
                child: Container(
                  color: context.colors.shadow.withValues(alpha: 0.55),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.shadow.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.colors.border.withValues(
                            alpha: 0.7020,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'SOLD OUT',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketHighlightsBar(MarketplaceItem item) {
    final locationText = item.location.trim().isNotEmpty
        ? item.location.trim()
        : (item.meetupArea.trim().isNotEmpty ? item.meetupArea.trim() : 'Barili, Cebu');
    final formattedDate = DateFormat('MMMM d, y').format(item.createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
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
          // Row 1: Pick-up Location
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick-up Location',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primaryGreen,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      locationText,
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

          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: context.colors.border, height: 1),
          ),

          // Row 2: Condition & Date Listed
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 17,
                      color: context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Condition',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                          Text(
                            item.condition,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 17,
                      color: context.colors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Listed',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                          Text(
                            formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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

        ],
      ),
    );
  }

  Widget _buildMarketProductNarrative(String description) {
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
                'Product Narrative',
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
            hasDesc ? cleanDesc : 'No extra description provided for this listing.',
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

  Widget _buildMarketDetailsBottomBar({
    required MarketplaceItem currentItem,
    required bool isOwner,
    required bool isAvailable,
    required BuildContext sheetContext,
    required bool isSendingInterest,
    required void Function(VoidCallback fn) setModalState,
  }) {
    if (isOwner) {
      return AdaptiveActionPair(
        secondaryFlex: 2,
        primary: ESugidPressable(
          onTap: () => _showManageListingModal(currentItem, sheetContext),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: sheetContext.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sheetContext.colors.border, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: sheetContext.colors.shadow.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AdaptiveActionLabel(
              label: 'MANAGE',
              icon: Icons.tune_rounded,
              iconSize: 16,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.8,
                color: sheetContext.colors.textPrimary,
              ),
            ),
          ),
        ),
        secondary: ESugidPressable(
          onTap: () async {
            final newStatus = isAvailable ? 'Sold' : 'Available';
            await MarketplaceService.updateItemStatus(currentItem.id, newStatus);
            if (mounted) {
              ScaffoldMessenger.of(context).showAppSnackBar(
                AppSnackBar(
                  content: Text(
                    isAvailable
                        ? 'Item marked as sold!'
                        : 'Item is available again.',
                  ),
                  kind: FeedbackKind.success,
                ),
              );
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAvailable
                    ? [
                        sheetContext.colors.brand,
                        sheetContext.colors.brand,
                        sheetContext.colors.brandStrong,
                      ]
                    : [
                        sheetContext.colors.brand,
                        sheetContext.colors.brand,
                        sheetContext.colors.brand,
                      ],
              ),
              border: Border.all(
                color: sheetContext.colors.border.withValues(alpha: 0.90),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: sheetContext.colors.brandStrong.withValues(alpha: 0.40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: sheetContext.colors.highlight.withValues(alpha: 0.3020),
                  blurRadius: 0,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: AdaptiveActionLabel(
              label: isAvailable ? 'MARK AS SOLD' : 'MAKE AVAILABLE',
              icon: isAvailable
                  ? Icons.check_circle_outline_rounded
                  : Icons.refresh_rounded,
              iconSize: 17,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.8,
                color: sheetContext.colors.onAccent,
              ),
            ),
          ),
        ),
      );
    }
    // Buyer / Resident View:
    if (!isAvailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sheetContext.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'THIS ITEM IS SOLD OUT',
          style: GoogleFonts.outfit(
            color: sheetContext.colors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    return _buildBuyerInterestAction(
      currentItem,
      isSendingInterest: isSendingInterest,
      setSending: (val) => setModalState(() => isSendingInterest = val),
    );
  }

  Future<void> _showManageListingModal(
    MarketplaceItem item,
    BuildContext sheetContext,
  ) async {
    await showModalBottomSheet<void>(
      context: sheetContext,
      showDragHandle: false,
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
                          'Manage Market Listing',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: sheetContext.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Select an action for this product',
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
              // Option 1: EDIT LISTING
              ESugidPressable(
                onTap: () async {
                  Navigator.pop(manageCtx);
                  final updated = await Navigator.push<bool>(
                    sheetContext,
                    MaterialPageRoute(
                      builder: (context) => _EditMarketItemPage(item: item),
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
                              'Edit Listing',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: sheetContext.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update price, description, photo, or location',
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
              // Option 2: DELETE LISTING
              ESugidPressable(
                onTap: () {
                  Navigator.pop(manageCtx);
                  _confirmAndDeleteItem(item, sheetContext);
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
                              'Delete Listing',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: sheetContext.colors.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permanently remove this item from the market',
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

  Future<void> _confirmAndDeleteItem(
    MarketplaceItem item,
    BuildContext sheetContext,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogCtx) => Dialog(
        backgroundColor: sheetContext.colors.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Concentric glowing red badge
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
                'Delete Market Listing?',
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
                'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
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
                        'Keep Listing',
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
      await MarketplaceService.deleteItem(item.id);
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Listing deleted successfully.'),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Failed to delete listing: $e'),
            kind: FeedbackKind.error,
          ),
        );
      }
    }
  }

  Widget _buildLuxuryInterestedButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return ESugidPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
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
            color: context.colors.border.withValues(alpha: 0.90),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.3843),
              blurRadius: 0,
              offset: Offset(0, -1.8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                height: 1.6,
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
              Center(
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: context.colors.warningSolid,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.outfit(
                              color: context.colors.onBrandMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              shadows: [
                                Shadow(
                                  color: context.colors.textPrimary.withValues(alpha: 0.35,
                                  ),
                                  offset: const Offset(0, 1.5),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            icon,
                            color: context.colors.onBrandMuted,
                            size: 19,
                            shadows: [
                              Shadow(
                                color: context.colors.textPrimary.withValues(alpha: 0.35,
                                ),
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
    );
  }

}

class _InterestRequestSheet extends StatefulWidget {
  const _InterestRequestSheet({required this.item});

  final MarketplaceItem item;

  @override
  State<_InterestRequestSheet> createState() => _InterestRequestSheetState();
}

class _InterestRequestSheetState extends State<_InterestRequestSheet> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: 'Hi! Interested ko sa ${widget.item.name}. Available pa ni?',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_isSubmitting) return;

    final user = AuthService.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to send a request.');
      return;
    }

    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Please enter a message before sending.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final id = await MarketplaceService.sendInterestRequest(
        item: widget.item,
        buyerId: user.uid,
        buyerName: user.name,
        buyerPhotoUrl: user.profilePhotoUrl,
        message: message,
      );

      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e, stack) {
      debugPrint('SEND_INTEREST_ERROR: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        if (e is FirebaseException) {
          _errorMessage = switch (e.code) {
            'permission-denied' =>
              'Unable to send request due to permissions. Please ensure your residency profile is verified.',
            'not-found' => 'This item is no longer available.',
            _ => 'Unable to send request. Please try again.',
          };
        } else if (e is StateError) {
          _errorMessage = e.message;
        } else if (e is ArgumentError) {
          _errorMessage = e.message?.toString() ?? 'Invalid message.';
        } else {
          _errorMessage = 'Unable to send request. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Send an interest request',
                style: GoogleFonts.outfit(
                  color: context.colors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send one introduction to the seller. You can continue chatting after the seller accepts.',
                style: GoogleFonts.outfit(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.errorSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.error),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: context.colors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.outfit(
                            color: context.colors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                enabled: !_isSubmitting,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Your message',
                  filled: true,
                  fillColor: context.colors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleSend,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: context.colors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.surface,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Sending...' : 'Send Request',
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seller Card Avatar with Live Photo Resolution
// ─────────────────────────────────────────────────────────────────────────────

class _SellerCardAvatar extends StatefulWidget {
  const _SellerCardAvatar({
    required this.sellerId,
    required this.sellerName,
    required this.isDark,
    this.size = 38,
  });

  final String sellerId;
  final String sellerName;
  final bool isDark;
  final double size;

  @override
  State<_SellerCardAvatar> createState() => _SellerCardAvatarState();
}

class _SellerCardAvatarState extends State<_SellerCardAvatar> {
  static final Map<String, String> _photoCache = {};
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant _SellerCardAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId) {
      _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    final id = widget.sellerId.trim();
    if (id.isEmpty) {
      _photoUrl = null;
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser != null && currentUser.uid == id) {
      final photo = currentUser.profilePhotoUrl?.trim();
      if (photo != null && photo.isNotEmpty) {
        _photoUrl = photo;
        _photoCache[id] = photo;
        return;
      }
    }

    if (_photoCache.containsKey(id)) {
      _photoUrl = _photoCache[id];
      return;
    }

    final cachedTrust = CommunityTrustService.getCachedProfile(id);
    final trustPhoto = cachedTrust?.profilePhotoUrl?.trim();
    if (trustPhoto != null && trustPhoto.isNotEmpty) {
      _photoUrl = trustPhoto;
      _photoCache[id] = trustPhoto;
      return;
    }

    _fetchPhoto(id);
  }

  Future<void> _fetchPhoto(String id) async {
    try {
      final trust = await CommunityTrustService().getTrustProfile(id);
      final photo = trust?.profilePhotoUrl?.trim();
      if (photo != null && photo.isNotEmpty) {
        _photoCache[id] = photo;
        if (mounted && widget.sellerId.trim() == id) {
          setState(() => _photoUrl = photo);
        }
        return;
      }
    } catch (_) {}

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final photo = data['profilePhotoUrl']?.toString().trim() ??
            data['photoUrl']?.toString().trim() ??
            data['avatarUrl']?.toString().trim();
        if (photo != null && photo.isNotEmpty) {
          _photoCache[id] = photo;
          if (mounted && widget.sellerId.trim() == id) {
            setState(() => _photoUrl = photo);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final initial = widget.sellerName.trim().isNotEmpty
        ? widget.sellerName.trim()[0].toUpperCase()
        : 'S';

    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.surfaceAlt.withValues(alpha: widget.isDark ? 0.20 : 0.85,
        ),
        border: Border.all(
          color: context.colors.border,
          width: size >= 30 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: ClipOval(
          child: hasPhoto
              ? Image.network(
                  _photoUrl!,
                  width: size,
                  height: size,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(initial),
                )
              : _buildFallback(initial),
        ),
      ),
    );
  }

  Widget _buildFallback(String initial) {
    final fontSize = widget.size >= 36 ? 16.0 : (widget.size * 0.44);
    return Container(
      width: widget.size,
      height: widget.size,
      color: context.colors.surfaceAlt.withValues(alpha: widget.isDark ? 0.20 : 0.85,
      ),
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
}
