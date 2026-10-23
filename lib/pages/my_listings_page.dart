import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app_motion.dart';
import '../auth_service.dart';
import '../features/home/presentation/hub_service_cards.dart';
import '../marketplace_service.dart';
import '../widgets/esugid_page_header.dart';
import '../widgets/adaptive_action_content.dart';
import '../widgets/market_item_form.dart';

class MyListingsPage extends StatefulWidget {
  const MyListingsPage({super.key, this.itemsStream});

  final Stream<List<MarketplaceItem>>? itemsStream;

  @override
  State<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends State<MyListingsPage> {
  int _retryVersion = 0;

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
      title: 'My Listings',
      showBackButton: true,
      onBack: () => Navigator.maybePop(context),
    );
  }

  Widget _buildSoldHistoryButton({
    required int soldCount,
    required List<MarketplaceItem> soldItems,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSoldHistorySheet(context, soldItems),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
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
                  'Sold History',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (soldCount > 0) ...[
                  const SizedBox(width: 6),
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
                      '$soldCount',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }

  void _showSoldHistorySheet(
    BuildContext context,
    List<MarketplaceItem> soldItems,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
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
                            color: sheetContext.colors.brandStrong.withValues(alpha: 0.25,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: sheetContext.colors.onAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sold History',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: sheetContext.colors.textPrimary,
                                ),
                              ),
                              if (soldItems.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sheetContext.colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${soldItems.length}',
                                    style: GoogleFonts.outfit(
                                      color: sheetContext.colors.primaryGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Marketplace items marked as sold',
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
                child: soldItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: sheetContext.colors.brand.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: sheetContext.colors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No sold listings yet',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: sheetContext.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'When your items sell, mark them as sold to archive them here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: sheetContext.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: soldItems.length,
                        itemBuilder: (context, index) {
                          return _MyBariliListingCard(
                            item: soldItems[index],
                            isSoldHistoryView: true,
                            onStatusChanged: () {
                              Navigator.pop(sheetContext);
                              setState(() {});
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
    final user = AuthService.currentUser;
    if (user == null) {
      return Scaffold(
        body: Column(
          children: [
            ESugidPageHeader(
              sectionLabelWidget: _buildMarketBadge(),
              title: 'My Listings',
              showBackButton: true,
              onBack: () => Navigator.maybePop(context),
            ),
            const Expanded(
              child: Center(
                child: Text('Please sign in to view your listings.'),
              ),
            ),
          ],
        ),
      );
    }

    final itemsStream = widget.itemsStream ??
        MarketplaceService.userItemsStream(user.uid);

    return Scaffold(
      body: StreamBuilder<List<MarketplaceItem>>(
        key: ValueKey('my-listings-$_retryVersion'),
        stream: itemsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 58,
                            color: context.colors.textSecondary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Unable to load your listings.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Check your connection and try again.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _retryVersion += 1),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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

          final allItems = snapshot.data ?? [];
          final activeItems = allItems.where((item) => !item.isSold).toList();
          final soldItems = allItems.where((item) => item.isSold).toList();

          return CustomScrollView(
            slivers: [
              _buildHeader(context),
              // Sub-bar with Active count & Sold History button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.colors.border,
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
                            const SizedBox(width: 5),
                            Text(
                              '${activeItems.length} Active ${activeItems.length == 1 ? 'Listing' : 'Listings'}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: context.colors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildSoldHistoryButton(
                        soldCount: soldItems.length,
                        soldItems: soldItems,
                      ),
                    ],
                  ),
                ),
              ),
              if (activeItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MyListingsEmptyState(
                    hasSoldItems: soldItems.isNotEmpty,
                    onViewSold: () => _showSoldHistorySheet(context, soldItems),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _MyBariliListingCard(
                          item: activeItems[index],
                          isSoldHistoryView: false,
                          onStatusChanged: () => setState(() {}),
                        );
                      },
                      childCount: activeItems.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MyBariliListingCard extends StatelessWidget {
  const _MyBariliListingCard({
    required this.item,
    required this.isSoldHistoryView,
    required this.onStatusChanged,
  });

  final MarketplaceItem item;
  final bool isSoldHistoryView;
  final VoidCallback onStatusChanged;

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

  void _showManageModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Material(
        color: sheetContext.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.infoSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: sheetContext.colors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: sheetContext.colors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manage "${item.name}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: sheetContext.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: sheetContext.colors.primaryGreen,
                  ),
                ),
                title: Text(
                  'Edit Listing',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Update title, photos, price or description',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: sheetContext.colors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditPage(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sheetContext.colors.errorSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: sheetContext.colors.error,
                  ),
                ),
                title: Text(
                  'Delete Listing',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: sheetContext.colors.error,
                  ),
                ),
                subtitle: Text(
                  'Permanently remove this item from the market',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: sheetContext.colors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              ESugidPageHeader(
                sectionLabelWidget: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandStrong.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.85),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      'LOCAL MARKET',
                      style: GoogleFonts.outfit(
                        color: context.colors.onBrandMuted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                title: 'Edit Listing',
                showBackButton: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: MarketItemForm(
                    initialItem: item,
                    onSubmitted: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dialogContext.colors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: dialogContext.colors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Listing',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: dialogContext.colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            height: 1.4,
            color: dialogContext.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: dialogContext.colors.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await MarketplaceService.deleteItem(item.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showAppSnackBar(
                  AppSnackBar(
                    content: Text('Listing "${item.name}" deleted.'),
                    kind: FeedbackKind.success,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              foregroundColor: dialogContext.colors.onAccent,

              backgroundColor: dialogContext.colors.errorSolid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context) async {
    final nextStatus = item.isSold ? 'Available' : 'Sold';
    try {
      await MarketplaceService.updateItemStatus(item.id, nextStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
                  item.isSold
                      ? 'Listing marked as Available!'
                      : 'Listing marked as Sold!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
            kind: FeedbackKind.success,
          ),
        );
      }
      onStatusChanged();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Could not update status. Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSold = item.isSold;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'My listing: ${item.name}, priced at ${item.formattedPrice} per ${item.priceUnit}. Status: ${item.status}.',
      button: true,
      onTapHint: 'Manage listing',
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
            onTap: () => _showManageModal(context),
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
                    // 1. Top Header Row: Seller Avatar + Name + Age + Status Badge + Menu
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
                                          : 'My Listing',
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

                        // Status Pill Badge (AVAILABLE / SOLD)
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

                        // 3D Options menu trigger
                        ESugidPressable(
                          onTap: () => _showManageModal(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.surface,
                              border: Border.all(
                                color: context.colors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(alpha: 0.04,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: context.colors.textPrimary,
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
                                  decoration: isSold
                                      ? TextDecoration.lineThrough
                                      : null,
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
                          tag: 'my-listing-image-${item.id}',
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

                    // 3. Bottom Row: Dual Action Buttons: MANAGE LISTING & MARK AS SOLD / AVAILABLE
                    AdaptiveActionPair(
                      primary: TactileSpringButton(
                        onTap: () => _showManageModal(context),
                        scale: 0.97,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                                context.colors.brandStrong,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: context.colors.border.withValues(alpha: 0.90),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.40),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AdaptiveActionLabel(
                            label: 'MANAGE',
                            icon: Icons.tune_rounded,
                            iconSize: 16,
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      secondary: TactileSpringButton(
                        onTap: () => _toggleStatus(context),
                        scale: 0.97,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          decoration: BoxDecoration(
                            color: isSold ? context.colors.brand : context.colors.surface,
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: isSold ? context.colors.primaryGreen : context.colors.border,
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: AdaptiveActionLabel(
                            label: isSold ? 'MAKE AVAILABLE' : 'MARK AS SOLD',
                            icon: isSold
                                ? Icons.replay_rounded
                                : Icons.check_circle_outline_rounded,
                            iconSize: 16,
                            style: GoogleFonts.outfit(
                              color: isSold
                                  ? context.colors.onAccent
                                  : context.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
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
      ),
    );
  }
}

class _MyListingsEmptyState extends StatelessWidget {
  const _MyListingsEmptyState({
    required this.hasSoldItems,
    required this.onViewSold,
  });

  final bool hasSoldItems;
  final VoidCallback onViewSold;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Layered Package Medallion
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
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: context.colors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'No active listings right now',
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
                hasSoldItems
                    ? 'All your current items have been sold! You can review them in Sold History or post a new listing.'
                    : 'List your farm produce, handmade crafts, or pre-loved goods to share them with your Barili neighbors.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (hasSoldItems) ...[
              FilledButton.icon(
                onPressed: onViewSold,
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
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text(
                  'View Sold History',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
