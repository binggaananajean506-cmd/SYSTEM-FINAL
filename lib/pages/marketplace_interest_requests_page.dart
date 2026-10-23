import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../auth_service.dart';
import '../marketplace_service.dart';
import '../services/community_trust_service.dart';
import '../widgets/esugid_page_header.dart';
import 'marketplace_conversation_page.dart';
import 'public_user_profile_page.dart';

class MarketplaceInterestRequestsPage extends StatefulWidget {
  const MarketplaceInterestRequestsPage({
    super.key,
    this.requestsStream});

  final Stream<List<MarketplaceInterestRequest>>? requestsStream;

  @override
  State<MarketplaceInterestRequestsPage> createState() =>
      _MarketplaceInterestRequestsPageState();
}

class _MarketplaceInterestRequestsPageState
    extends State<MarketplaceInterestRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    if (user == null) {
      return Scaffold(
        body: Column(
          children: [
            ESugidPageHeader(
              sectionLabelWidget: _buildMarketBadge(),
              title: 'Buyer Requests',
              showBackButton: true,
              onBack: () => Navigator.maybePop(context),
            ),
            const Expanded(
              child: Center(
                child: Text('Please sign in to view your buyer requests.'),
              ),
            ),
          ],
        ),
      );
    }

    final stream = widget.requestsStream ??
        MarketplaceService.sellerInterestRequests(user.uid);

    return StreamBuilder<List<MarketplaceInterestRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            requests.isEmpty;

        final pendingRequests =
            requests
                .where((r) => r.status == MarketplaceInterestStatus.pending)
                .toList();
        final activeRequests =
            requests
                .where((r) => r.status == MarketplaceInterestStatus.accepted)
                .toList();
        final archiveRequests =
            requests
                .where(
                  (r) =>
                      r.status == MarketplaceInterestStatus.declined ||
                      r.status == MarketplaceInterestStatus.completed,
                )
                .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildHeader(context),
                SliverToBoxAdapter(
                  child: _build3DSegmentedTabBar(
                    pendingCount: pendingRequests.length,
                    activeCount: activeRequests.length,
                  ),
                ),
              ],
              body:
                  isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.brand,
                        ),
                      )
                      : snapshot.hasError
                      ? Center(
                        child: Text(
                          'Could not load buyer requests.',
                          style: GoogleFonts.outfit(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      : TabBarView(
                        children: [
                          _BuyerRequestList(
                            requests: pendingRequests,
                            section: _RequestSection.pending,
                          ),
                          _BuyerRequestList(
                            requests: activeRequests,
                            section: _RequestSection.active,
                          ),
                          _BuyerRequestList(
                            requests: archiveRequests,
                            section: _RequestSection.archive,
                          ),
                        ],
                      ),
            ),
          ),
        );
      },
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
      title: 'Buyer Requests',
      showBackButton: true,
      onBack: () => Navigator.maybePop(context),
    );
  }

  Widget _build3DSegmentedTabBar({
    required int pendingCount,
    required int activeCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: context.colors.onAccent,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.brand, context.colors.brand],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.38),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.35),
              offset: const Offset(0, -1),
              blurRadius: 0,
            ),
          ],
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending'),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.warningSolid,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Active'),
                if (activeCount > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Archive'),
        ],
      ),
    );
  }
}

enum _RequestSection { pending, active, archive }

class _BuyerRequestList extends StatelessWidget {
  const _BuyerRequestList({required this.requests, required this.section});

  final List<MarketplaceInterestRequest> requests;
  final _RequestSection section;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _BuyerRequestsEmptyState(section: section);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _BuyerRequestCard(
          request: requests[index],
          section: section);
      },
    );
  }
}

class _BuyerRequestCard extends StatefulWidget {
  const _BuyerRequestCard({
    required this.request,
    required this.section});

  final MarketplaceInterestRequest request;
  final _RequestSection section;

  @override
  State<_BuyerRequestCard> createState() => _BuyerRequestCardState();
}

class _BuyerRequestCardState extends State<_BuyerRequestCard> {
  static final Map<String, String?> _buyerPhotoCache = {};
  String? _buyerPhotoUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _resolveBuyerPhoto();
  }

  @override
  void didUpdateWidget(covariant _BuyerRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.buyerId != widget.request.buyerId ||
        oldWidget.request.buyerPhotoUrl != widget.request.buyerPhotoUrl) {
      _resolveBuyerPhoto();
    }
  }

  void _resolveBuyerPhoto() {
    final buyerId = widget.request.buyerId.trim();
    final directPhoto = widget.request.buyerPhotoUrl?.trim();
    if (directPhoto != null && directPhoto.isNotEmpty) {
      _buyerPhotoUrl = directPhoto;
      if (buyerId.isNotEmpty) {
        _buyerPhotoCache[buyerId] = directPhoto;
      }
      return;
    }

    if (buyerId.isNotEmpty && _buyerPhotoCache.containsKey(buyerId)) {
      _buyerPhotoUrl = _buyerPhotoCache[buyerId];
      return;
    }

    final cachedTrust = CommunityTrustService.getCachedProfile(buyerId);
    if (cachedTrust?.profilePhotoUrl != null &&
        cachedTrust!.profilePhotoUrl!.isNotEmpty) {
      _buyerPhotoUrl = cachedTrust.profilePhotoUrl;
      _buyerPhotoCache[buyerId] = _buyerPhotoUrl;
      return;
    }

    _fetchBuyerPhoto(buyerId);
  }

  Future<void> _fetchBuyerPhoto(String buyerId) async {
    if (buyerId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(buyerId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final photo = data?['profilePhotoUrl']?.toString() ??
            data?['photoUrl']?.toString() ??
            data?['avatarUrl']?.toString();
        if (photo != null && photo.trim().isNotEmpty) {
          _buyerPhotoCache[buyerId] = photo.trim();
          if (mounted) {
            setState(() => _buyerPhotoUrl = photo.trim());
          }
          return;
        }
      }

      final trust = await CommunityTrustService().getTrustProfile(buyerId);
      final photo = trust?.profilePhotoUrl;
      if (photo != null && photo.trim().isNotEmpty) {
        _buyerPhotoCache[buyerId] = photo.trim();
        if (mounted) {
          setState(() => _buyerPhotoUrl = photo.trim());
        }
      }
    } catch (_) {}
  }

  Widget _buildAvatarFallback(String name) {
    final initials = _getInitials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) return 'B';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  Future<void> _review(bool accept) async {
    final user = AuthService.currentUser;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (accept) {
        await MarketplaceService.acceptInterestRequest(
          conversationId: widget.request.id,
          sellerId: user.uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text(
                    'Request accepted! Moved to Active.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
              kind: FeedbackKind.success,
            ),
          );
        }
      } else {
        await MarketplaceService.declineInterestRequest(
          conversationId: widget.request.id,
          sellerId: user.uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text(
                'Request declined.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              kind: FeedbackKind.success,
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Could not update this request. Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketplaceConversationPage(request: widget.request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isPending = widget.section == _RequestSection.pending;
    final unread = request.unreadCountFor(AuthService.currentUser?.uid ?? '');


    final statusLabel = switch (request.status) {
      MarketplaceInterestStatus.pending => 'Waiting for your review',
      MarketplaceInterestStatus.accepted => 'Active Chat',
      MarketplaceInterestStatus.declined => 'Declined',
      MarketplaceInterestStatus.completed => 'Completed',
    };

    final statusColor = switch (request.status) {
      MarketplaceInterestStatus.pending => context.colors.warning,
      MarketplaceInterestStatus.accepted => context.colors.primaryGreen,
      MarketplaceInterestStatus.declined => context.colors.error,
      MarketplaceInterestStatus.completed => context.colors.info,
    };

    final statusBgColor = switch (request.status) {
      MarketplaceInterestStatus.pending => context.colors.warningSurface,
      MarketplaceInterestStatus.accepted => context.colors.surfaceAlt,
      MarketplaceInterestStatus.declined => context.colors.errorSurface,
      MarketplaceInterestStatus.completed => context.colors.infoSurface,
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPending ? context.colors.border : context.colors.border,
          width: isPending ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? context.colors.brandStrong.withValues(alpha: 0.08)
                : context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Profile Avatar (48x48) with Verified Blue Badge
                    GestureDetector(
                      onTap: request.buyerId.isNotEmpty
                          ? () => PublicUserProfilePage.show(
                                context,
                                request.buyerId,
                                initialName: request.buyerName,
                                initialPhotoUrl: _buyerPhotoUrl,
                              )
                          : null,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.colors.surfaceAlt,
                                border: Border.all(
                                  color: context.colors.border,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.brandStrong
                                        .withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: (_buyerPhotoUrl != null &&
                                        _buyerPhotoUrl!.isNotEmpty)
                                    ? Image.network(
                                        _buyerPhotoUrl!,
                                        fit: BoxFit.cover,
                                        width: 48,
                                        height: 48,
                                        errorBuilder: (_, _, _) =>
                                            _buildAvatarFallback(
                                              request.buyerName,
                                            ),
                                      )
                                    : _buildAvatarFallback(request.buyerName),
                              ),
                            ),
                            // Verified Blue Badge
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: context
                                      .colors
                                      .infoSolid, // Verified Blue Badge
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.colors.border,
                                    width: 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.highlight
                                          .withValues(alpha: 0.2000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 10.5,
                                    color: context.colors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Top: Buyer Name & Status, Subtitle: Item Name & Timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Buyer's Name on TOP
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: request.buyerId.isNotEmpty
                                      ? () => PublicUserProfilePage.show(
                                            context,
                                            request.buyerId,
                                            initialName: request.buyerName,
                                            initialPhotoUrl: _buyerPhotoUrl,
                                          )
                                      : null,
                                  child: Text(
                                    request.buyerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: context.colors.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (unread > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.errorSolid,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.colors.highlight
                                            .withValues(alpha: 0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Subtitle: Item Name & Time
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: context.colors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  request.itemName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeago.format(
                                  request.updatedAt ?? request.createdAt,
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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

                const SizedBox(height: 12),

                // Message snippet bubble
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.colors.border,
                      width: 1),
                  ),
                  child: Text(
                    request.initialMessage.isNotEmpty
                        ? request.initialMessage
                        : 'Hi! Interested ko sa ${request.itemName}. Available pa ni?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      height: 1.35,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Pending Actions (Decline & Accept)
                if (isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _review(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.textSecondary,
                            side: BorderSide(
                              color: context.colors.border,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _busy ? null : () => _review(true),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11,
                                ),
                                child: Center(
                                  child: _busy
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: context.colors.surface,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_rounded,
                                              color: context.colors.onAccent,
                                              size: 17,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Accept & Chat',
                                              style: GoogleFonts.outfit(
                                                color: context.colors.onAccent,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open conversation',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: context.colors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyerRequestsEmptyState extends StatelessWidget {
  const _BuyerRequestsEmptyState({required this.section});

  final _RequestSection section;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      _RequestSection.pending => 'No pending buyer requests',
      _RequestSection.active => 'No active buyer chats',
      _RequestSection.archive => 'No archived requests',
    };

    final description = switch (section) {
      _RequestSection.pending =>
        'Inquiries from interested neighbors for your listings will appear here.',
      _RequestSection.active =>
        'Accepted buyer conversations will appear here so you can chat and coordinate meetups.',
      _RequestSection.archive =>
        'Past completed deals or declined requests will be saved here.',
    };

    final iconData = switch (section) {
      _RequestSection.pending => Icons.inbox_rounded,
      _RequestSection.active => Icons.chat_bubble_outline_rounded,
      _RequestSection.archive => Icons.archive_outlined,
    };

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Layered Medallion
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
                        context.colors.brand.withValues(alpha: 0.22),
                        context.colors.brand.withValues(alpha: 0.05),
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
                        context.colors.surfaceAlt,
                        context.colors.surfaceAlt,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.colors.border, width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.18,
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
                      iconData,
                      size: 40,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
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
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
