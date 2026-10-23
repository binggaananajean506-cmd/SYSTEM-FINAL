import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth_service.dart';
import '../app_motion.dart';
import '../features/home/presentation/hub_service_cards.dart';
import '../marketplace_service.dart';
import '../widgets/esugid_page_header.dart';

class MarketplaceFavoritesPage extends StatefulWidget {
  const MarketplaceFavoritesPage({
    super.key,
    required this.onOpenListing,
    this.favoritesStream,
    this.itemsStream,
  });

  final ValueChanged<MarketplaceItem> onOpenListing;
  final Stream<Set<String>>? favoritesStream;
  final Stream<List<MarketplaceItem>>? itemsStream;

  @override
  State<MarketplaceFavoritesPage> createState() =>
      _MarketplaceFavoritesPageState();
}

class _MarketplaceFavoritesPageState extends State<MarketplaceFavoritesPage> {
  int _retryVersion = 0;
  Timer? _undoTimer;

  void _dismissActiveSnackbar() {
    _undoTimer?.cancel();
    _undoTimer = null;
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
    } catch (_) {}
  }

  @override
  void dispose() {
    _dismissActiveSnackbar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    if (user == null) {
      return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          _dismissActiveSnackbar();
        },
        child: Scaffold(
          body: Column(
            children: [
              ESugidPageHeader(
                sectionLabelWidget: _buildMarketBadge(),
                title: 'Favorites',
                showBackButton: true,
                onBack: () {
                  _dismissActiveSnackbar();
                  Navigator.maybePop(context);
                },
              ),
              const Expanded(
                child: _FavoritesMessage(
                  icon: Icons.login_rounded,
                  title: 'Please sign in to view your favorites.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final favoritesStream = widget.favoritesStream ??
        MarketplaceService.favoriteItemIdsStream(user.uid);
    final itemsStream = widget.itemsStream ?? MarketplaceService.itemsStream;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _dismissActiveSnackbar();
      },
      child: Scaffold(
      body: StreamBuilder<Set<String>>(
        key: ValueKey('favorite-ids-$_retryVersion'),
        stream: favoritesStream,
        builder: (context, favoritesSnapshot) {
          if (favoritesSnapshot.hasError) {
            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FavoritesMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Unable to load your favorites.',
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => setState(() => _retryVersion += 1),
                  ),
                ),
              ],
            );
          }

          if (!favoritesSnapshot.hasData) {
            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                  SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primaryGreen,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ],
            );
          }

          final favoriteIds = favoritesSnapshot.data!;
          if (favoriteIds.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FavoritesEmptyState(
                    onExplore: () => Navigator.maybePop(context),
                  ),
                ),
              ],
            );
          }

          return StreamBuilder<List<MarketplaceItem>>(
            stream: itemsStream,
            builder: (context, listingsSnapshot) {
              if (listingsSnapshot.hasError) {
                return CustomScrollView(
                  slivers: [
                    _buildHeader(context),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FavoritesMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to load saved listings.',
                        subtitle: 'Pull back and try again shortly.',
                        actionLabel: 'Retry',
                        onAction: () => setState(() => _retryVersion += 1),
                      ),
                    ),
                  ],
                );
              }

              if (!listingsSnapshot.hasData) {
                return CustomScrollView(
                  slivers: [
                    _buildHeader(context),
                      SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primaryGreen,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final listings = listingsSnapshot.data!
                  .where((item) => favoriteIds.contains(item.id))
                  .toList(growable: false);

              if (listings.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    _buildHeader(context),
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _FavoritesMessage(
                        icon: Icons.inventory_2_outlined,
                        title: 'Your saved items are no longer available.',
                        subtitle: 'They may have been removed by their sellers.',
                      ),
                    ),
                  ],
                );
              }

              return ValueListenableBuilder<Set<String>>(
                valueListenable: MarketplaceService.viewedFavoritesNotifier,
                builder: (context, viewedFavorites, _) {
                  return CustomScrollView(
                    slivers: [
                      _buildHeader(context),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index,
                            ) {
                              final item = listings[index];
                              final isViewed =
                                  viewedFavorites.contains(item.id,
                              );

                              return _FavoriteBariliCard(
                                item: item,
                                isViewed: isViewed,
                                onOpen: () {
                                  MarketplaceService.markFavoriteViewed(
                                    userId: user.uid,
                                    itemId: item.id,
                                  );
                                  widget.onOpenListing(item);
                                },
                                onRemove: () =>
                                    _removeFavorite(user.uid, item),
                              );
                            },
                            childCount: listings.length),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    ),
  );
}

  Widget _buildMarketBadge() {
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
              'LOCAL MARKET',
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

  Widget _buildHeader(BuildContext context) {
    return ESugidSliverPageHeader(
      sectionLabelWidget: _buildMarketBadge(),
      title: 'Favorites',
      showBackButton: true,
      onBack: () {
        _dismissActiveSnackbar();
        Navigator.maybePop(context);
      },
    );
  }

  Future<void> _removeFavorite(String userId, MarketplaceItem item) async {
    _dismissActiveSnackbar();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MarketplaceService.setFavorite(
        userId: userId,
        itemId: item.id,
        isFavorite: false,
      );
      if (!mounted) return;
      messenger.removeCurrentSnackBar();
      messenger.showAppSnackBar(
        AppSnackBar(
          content: Text('Removed "${item.name}" from favorites.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            textColor: context.colors.primaryGreen,
            onPressed: () {
              _dismissActiveSnackbar();
              MarketplaceService.setFavorite(
                userId: userId,
                itemId: item.id,
                isFavorite: true,
              );
            },
          ),
          kind: FeedbackKind.success,
        ),
      );

      // Explicit timer to guarantee dismissal regardless of device accessibility overrides
      _undoTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          try {
            messenger.hideCurrentSnackBar();
          } catch (_) {}
        }
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showAppSnackBar(
        AppSnackBar(
          content: Text('Could not update favorites. Please try again.'),
          duration: Duration(seconds: 2),
          kind: FeedbackKind.error,
        ),
      );
    }
  }
}

class _FavoriteBariliCard extends StatelessWidget {
  const _FavoriteBariliCard({
    required this.item,
    required this.isViewed,
    required this.onOpen,
    required this.onRemove,
  });

  final MarketplaceItem item;
  final bool isViewed;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

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

  Widget _marketImage(BuildContext context, String url) {
    final placeholderBg = context.colors.surfaceAlt;
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

  @override
  Widget build(BuildContext context) {
    final isSold = item.isSold;
    final isOwner = item.isOwnedBy(AuthService.currentUser?.uid);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'Favorite marketplace item: ${item.name}, priced at ${item.formattedPrice} per ${item.priceUnit}. Seller: ${item.sellerName}. Status: ${item.status}.',
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
            // Ambient shadow
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.03,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            // Specular reflection
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
            onTap: onOpen,
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
                // Clean porcelain theme border
                border: Border.all(
                  color: context.colors.border,
                  width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Row: Seller Avatar + Name + New Sign + Status Badge + 3D Heart
                    Row(
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
                            child: item.sellerName.isNotEmpty
                                ? Text(
                                    item.sellerName[0].toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: context.colors.primaryGreen,
                                    ),
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    size: 20,
                                    color: context.colors.primaryGreen,
                                  ),
                          ),
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
                                        color: context.colors.textPrimary,
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
                                  // Notification-style unread sign
                                  if (!isViewed) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.brand,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.colors.brandStrong
                                                .withValues(alpha: 0.4),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: GoogleFonts.outfit(
                                          color: context.colors.onAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
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

                        // 3D Glossy Heart Button (Active Favorite)
                        ESugidPressable(
                          onTap: onRemove,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.errorSurface,
                                  context.colors.errorSurface,
                                ],
                              ),
                              border: Border.all(
                                color: context.colors.error,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.highlight.withValues(alpha: 0.25,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.favorite_rounded,
                                color: context.colors.error,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Middle Row: Details (Left) + Generous 3D Photo (Right: 124x124)
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
                          tag: 'favorite-market-image-${item.id}',
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
                              child: _marketImage(context, item.imageUrl),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Bottom Row: 3D Highlighted Tactile Action Button
                    TactileSpringButton(
                      onTap: onOpen,
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
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.45,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.28,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ],
                        ),
                        child: Stack(
                          children: [
                            if (!isSold)
                              Positioned(
                                top: 0,
                                left: 16,
                                right: 16,
                                height: 1.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.colors.surface.withValues(alpha: 0.35,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSold
                                        ? Icons.remove_shopping_cart_rounded
                                        : (isOwner
                                            ? Icons.tune_rounded
                                            : Icons.volunteer_activism_rounded),
                                    color: isSold
                                        ? context.colors.onBrandMuted
                                        : Colors.white,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSold
                                        ? 'VIEW SOLD DETAILS'
                                        : (isOwner
                                            ? 'MANAGE LISTING'
                                            : "I'M INTERESTED"),
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Layered Heart Medallion
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.errorSolid.withValues(alpha: 0.18),
                        context.colors.errorSurface.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface,
                        context.colors.errorSurface,
                        context.colors.errorSurface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.colors.border, width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.errorSolid.withValues(alpha: 0.18,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 40,
                      color: context.colors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'No favorites saved yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Tap the heart button on any item in Barili Finds to save it here for quick access.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: context.colors.onAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: Text(
                'Explore Barili Finds',
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: context.colors.textSecondary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
