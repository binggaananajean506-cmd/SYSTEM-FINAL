import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth_service.dart';
import '../../../widgets/community_post_widgets.dart';
import '../../../widgets/esugid_page_header.dart';
import '../domain/offline_announcement.dart';
import '../services/saved_announcement_service.dart';
import 'offline_announcement_image.dart';
import 'saved_announcement_button.dart';

class SavedAnnouncementsPage extends StatefulWidget {
  const SavedAnnouncementsPage({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SavedAnnouncementsPage(),
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

  @override
  State<SavedAnnouncementsPage> createState() => _SavedAnnouncementsPageState();
}

class _SavedAnnouncementsPageState extends State<SavedAnnouncementsPage> {
  final SavedAnnouncementService _service = SavedAnnouncementService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      _service.sync(user.uid);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            const ESugidPageHeader(
              sectionLabel: 'OFFLINE ARCHIVE',
              title: 'Saved Announcements',
              icon: Icons.bookmark_rounded,
              showBackButton: true,
            ),
            const Expanded(
              child: Center(
                child: Text('Please sign in to view your saved announcements.'),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: StreamBuilder<List<OfflineAnnouncement>>(
        stream: _service.watchOffline(user.uid),
        builder: (context, snapshot) {
          final allSaved = snapshot.data ?? const [];
          final filtered = allSaved.where((announcement) {
            final matchesQuery = _searchQuery.isEmpty ||
                announcement.title
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase(),
                ) ||
                announcement.content
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase(),
                ) ||
                announcement.publisherEntityName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase(),
                ) ||
                announcement.authorName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase(),
                );

            final matchesCategory = _selectedCategory == 'All' ||
                announcement.category.toLowerCase() ==
                    _selectedCategory.toLowerCase();

            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            children: [
              ESugidPageHeader(
                sectionLabel: 'OFFLINE ARCHIVE',
                title: 'Saved Announcements',
                subtitle: 'Available anytime, even without internet',
                icon: Icons.bookmark_rounded,
                showBackButton: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${allSaved.length} Saved',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onAccent,
                    ),
                  ),
                ),
              ),
              if (allSaved.isNotEmpty) ...[
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search saved announcements…',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 13.5,
                        color: context.colors.info,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: context.colors.primaryGreen,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.colors.inputBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? context.colors.border.withValues(alpha: 0.1216)
                              : context.colors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark
                              ? context.colors.border.withValues(alpha: 0.1216)
                              : context.colors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: context.colors.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: allSaved.isEmpty
                    ? _buildEmptyState(context, isDark)
                    : filtered.isEmpty
                        ? _buildNoResultsState(context, isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _SavedAnnouncementCard(
                                announcement: item,
                                userId: user.uid,
                                isDark: isDark,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 42,
                color: context.colors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Saved Announcements Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any community update to save it for quick offline reading.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Updates'),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.colors.info,
            ),
            const SizedBox(height: 14),
            Text(
              'No matching saved announcements',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different title or keyword.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: context.colors.info,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAnnouncementCard extends StatelessWidget {
  final OfflineAnnouncement announcement;
  final String userId;
  final bool isDark;

  const _SavedAnnouncementCard({
    required this.announcement,
    required this.userId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final post = announcement.toPost();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.border,
          width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.25 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            ModernPostCard.openPostDetails(
              context,
              post,
              'saved-${post.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Publisher & Save button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        announcement.category.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primaryGreen,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        announcement.publisherEntityName.isNotEmpty
                            ? announcement.publisherEntityName
                            : announcement.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                    SavedAnnouncementButton(
                      announcement: post,
                      color: context.colors.brand,
                      backgroundColor: Colors.transparent,
                      borderColor: null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Post Title
                Text(
                  announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),

                // Post Excerpt
                Text(
                  announcement.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                    height: 1.35,
                  ),
                ),

                if (announcement.networkImageUrl.isNotEmpty ||
                    announcement.localImagePath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: offlineFirstAnnouncementImage(
                        localPath: announcement.localImagePath,
                        networkUrl: announcement.networkImageUrl,
                        fit: BoxFit.cover,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.offline_pin_rounded,
                      size: 14,
                      color: context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Saved for offline reading',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Read details →',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primaryGreen,
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
}
