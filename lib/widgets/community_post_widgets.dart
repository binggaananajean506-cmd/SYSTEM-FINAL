import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../community_service.dart';
import '../barili_barangays.dart';
import '../features/calendar/presentation/announcement_calendar_action.dart';
import '../app/theme/app_colors.dart';
import '../app_motion.dart';
import '../features/saved_announcements/presentation/offline_announcement_image.dart';
import '../features/saved_announcements/presentation/saved_announcement_button.dart';
import '../models/private_organization.dart';
import '../models/public_civic_entity.dart';
import '../pages/organization_profile_page.dart';
import '../pages/public_entity_profile_page.dart';
import '../pages/public_user_profile_page.dart';
import '../services/publisher_avatar_service.dart';
import 'dart:convert';
import 'dart:async';

String _relativePostTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'min' : 'mins'} ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
  }
  if (difference.inDays < 30) {
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }
  final years = (difference.inDays / 365).floor();
  return '$years ${years == 1 ? 'year' : 'years'} ago';
}

Widget _heroFlightShuttle(
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
      final currentRadius = lerpDouble(26, 0, t) ?? 0.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(currentRadius),
        child: Material(color: Colors.transparent, child: toHero.child),
      );
    },
  );
}

/// Publisher photos follow the profile saved by the web admin. An office icon
/// remains the fallback when no photo is available.
class PublisherAvatar extends StatefulWidget {
  static bool isBarangayPublisher(CommunityPost post) =>
      post.publisherEntityType.trim().toLowerCase() == 'barangay' ||
      post.publisherEntityId.trim().toLowerCase().startsWith('barangay_') ||
      post.authorRole.trim().toLowerCase().startsWith('barangay');
  final CommunityPost? post;
  final String? photoUrl;
  final String? authorId;
  final String? barangay;
  final String? barangayId;
  final String? organizationId;
  final double size;
  final bool isDark;
  final bool isOfficial;
  final Color? brandHeaderColor;
  final bool showVerifiedBadge;

  const PublisherAvatar({
    super.key,
    this.post,
    this.photoUrl,
    this.authorId,
    this.barangay,
    this.barangayId,
    this.organizationId,
    this.size = 32,
    this.isDark = false,
    this.isOfficial = true,
    this.brandHeaderColor,
    this.showVerifiedBadge = true,
  });

  @override
  State<PublisherAvatar> createState() => _PublisherAvatarState();
}

class _PublisherAvatarState extends State<PublisherAvatar> {
  String? _resolvedUrl;
  ValueNotifier<String?>? _activeNotifier;
  StreamSubscription<String?>? _barangayPhotoSubscription;
  int _resolutionGeneration = 0;

  bool get _isBarangayPublisher {
    final post = widget.post;
    if (post == null) {
      return widget.barangayId?.trim().isNotEmpty == true ||
          widget.barangay?.trim().isNotEmpty == true;
    }
    return PublisherAvatar.isBarangayPublisher(post);
  }

  String? get _effectiveDirectUrl {
    final direct = widget.photoUrl?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final postUrl = widget.post?.authorPhotoUrl.trim();
    if (postUrl != null && postUrl.isNotEmpty) return postUrl;
    return null;
  }

  String get _authorId => widget.authorId ?? widget.post?.authorId ?? '';
  String get _organizationId => widget.organizationId ?? widget.post?.publisherEntityId ?? '';

  @override
  void initState() {
    super.initState();
    _checkAndResolve();
  }

  @override
  void didUpdateWidget(covariant PublisherAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl ||
        oldWidget.authorId != widget.authorId ||
        oldWidget.organizationId != widget.organizationId ||
        oldWidget.post?.authorId != widget.post?.authorId ||
        oldWidget.post?.id != widget.post?.id ||
        oldWidget.post?.authorPhotoUrl != widget.post?.authorPhotoUrl ||
        oldWidget.post?.publisherEntityId != widget.post?.publisherEntityId ||
        oldWidget.post?.publisherEntityType != widget.post?.publisherEntityType ||
        oldWidget.post?.authorBarangay != widget.post?.authorBarangay ||
        oldWidget.post?.authorRole != widget.post?.authorRole ||
        oldWidget.barangayId != widget.barangayId ||
        oldWidget.barangay != widget.barangay) {
      _checkAndResolve();
    }
  }

  void _checkAndResolve() {
    final generation = ++_resolutionGeneration;
    _barangayPhotoSubscription?.cancel();
    _barangayPhotoSubscription = null;
    _activeNotifier?.removeListener(_onNotifierChanged);
    _activeNotifier = null;
    _resolvedUrl = null;
    if (_isBarangayPublisher) {
      final post = widget.post;
      final name = widget.barangay ??
          (post?.authorBarangay.trim().isNotEmpty == true
              ? post!.authorBarangay : post?.publisherEntityName);
      final id = PublisherAvatarService.barangayProfileId(
        id: widget.barangayId ?? post?.publisherEntityId,
        name: name,
      );
      _resolvedUrl = id == null ? null : PublisherAvatarService.getCached(id);
      if (id != null) {
        _activeNotifier = PublisherAvatarService.getNotifier(id);
        _activeNotifier!.addListener(_onNotifierChanged);
        _barangayPhotoSubscription = PublisherAvatarService.watchBarangayAvatar(
          barangayId: id,
        ).listen((photo) {
          if (!mounted || generation != _resolutionGeneration) return;
          setState(() => _resolvedUrl = photo);
        });
      }
      return;
    }
    final direct = _effectiveDirectUrl;
    if (direct != null && direct.isNotEmpty) {
      _resolvedUrl = direct;
      return;
    }

    final authId = _authorId;
    final orgId = _organizationId;

    // A resident's location or a post's audience is not its publisher identity.
    final cached = PublisherAvatarService.getCached(authId) ??
        PublisherAvatarService.getCached(orgId);
    if (cached != null && cached.isNotEmpty) {
      _resolvedUrl = cached;
      return;
    }

    final lookupKey = authId.isNotEmpty ? authId : orgId;
    if (lookupKey.isNotEmpty) {
      final notifier = PublisherAvatarService.getNotifier(lookupKey);
      if (_activeNotifier != notifier) {
        _activeNotifier?.removeListener(_onNotifierChanged);
        _activeNotifier = notifier;
        _activeNotifier?.addListener(_onNotifierChanged);
      }
      if (notifier.value != null && notifier.value!.isNotEmpty) {
        _resolvedUrl = notifier.value;
        return;
      }
    }

    PublisherAvatarService.resolveAvatarUrl(
      authorPhotoUrl: direct,
      authorId: authId,
      organizationId: orgId,
    ).then((resolved) {
      if (mounted && generation == _resolutionGeneration && resolved != null && resolved.isNotEmpty) {
        setState(() {
          _resolvedUrl = resolved;
        });
      }
    });
  }

  void _onNotifierChanged() {
    if (mounted && _activeNotifier?.value != null) {
      setState(() {
        _resolvedUrl = _activeNotifier!.value;
      });
    }
  }

  @override
  void dispose() {
    _resolutionGeneration++;
    _barangayPhotoSubscription?.cancel();
    _activeNotifier?.removeListener(_onNotifierChanged);
    super.dispose();
  }

  Widget _buildFallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.1,
          colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
        ),
      ),
      child: Center(
        child: Icon(
          widget.isOfficial
              ? Icons.account_balance_rounded
              : Icons.campaign_rounded,
          size: widget.size * 0.5,
          color: widget.brandHeaderColor ??
              (context.colors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildFallback();
        },
      );
    } else if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      } catch (_) {
        return _buildFallback();
      }
    } else if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl ?? _effectiveDirectUrl;
    final hasUrl = url != null && url.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.colors.border,
              width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.10),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipOval(
            child: !hasUrl
                ? _buildFallback()
                : _buildImage(url),
          ),
        ),
        if (widget.showVerifiedBadge && widget.isOfficial)
          Positioned(
            right: -3,
            bottom: -2,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.2588),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.verified_rounded,
                size: (widget.size * 0.46875).clamp(12.0, 18.0),
                color: context.colors.info,
              ),
            ),
          ),
      ],
    );
  }
}

class ModernPostCard extends StatelessWidget {
  final CommunityPost post;
  final bool showStatus;
  final String? heroScope;
  final VoidCallback? onTap;
  final bool animateEntrance;
  final bool isHighlighted;

  const ModernPostCard({
    super.key,
    required this.post,
    this.showStatus = false,
    this.heroScope,
    this.onTap,
    this.animateEntrance = true,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isUrgent = _isUrgentPost(post);
    final bool isOfficial =
        post.tag.toUpperCase() == 'OFFICIAL' ||
        _isBarangayPublisherRole(post.authorRole) ||
        _isLguPublisherRole(post.authorRole);

    final Color brandHeaderColor = isDark
        ? context.colors.textPrimary
        : isOfficial
        ? context.colors.textPrimary
        : context.colors.textPrimary;
    final String sourceLabel = _postSourceLabel(post, isOfficial);
    final String publishedAt = _relativePostTime(post.createdAt);
    final imageHeroTag = _postImageHeroTag(
      post,
      scope: heroScope ?? (showStatus ? 'manage' : 'feed'),
    );

    final visualTheme = _postVisualTheme(context, post);
    final accentColor = isUrgent
        ? context.colors.error
        : (context.colors.primaryGreen);
    final Color readMoreColor = isUrgent
        ? context.colors.error
        : brandHeaderColor;

    final double textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final double cardHeight = (196.0 *
            (1.0 + (textScaleFactor - 1.0).clamp(0.0, 2.0) * 0.75))
        .clamp(196.0, 380.0,
        );

    return ESugidEntrance(
      enabled: animateEntrance,
      child: _HeartbeatCardWrapper(
        enabled: isHighlighted,
        child: Semantics(
          label:
              'Announcement from $sourceLabel: ${post.title}. Description: ${post.content}.',
          button: true,
          onTapHint: 'View announcement details',
          child: Container(
            margin: const EdgeInsets.fromLTRB(4, 8, 4, 22),
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Layered Realistic Shadows for 3D Float
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: -8,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.28 : 0.16,
                          ),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Main 3D Card Body
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        onTap ??
                        () => openPostDetails(context, post, imageHeroTag),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  context.colors.surface,
                                  context.colors.surfaceAlt,
                                  context.colors.surfaceAlt,
                                ]
                              : [
                                  context.colors.surface,
                                  context.colors.surface,
                                  context.colors.surfaceAlt,
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? context.colors.border.withValues(alpha: 0.12)
                              : context.colors.border.withValues(alpha: 0.95),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(
                              alpha: isDark ? 0.35 : 0.05,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: 0.06,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                          if (isHighlighted) ...[
                            BoxShadow(
                              color: context.colors.highlight.withValues(alpha: 0.50,
                              ),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ],
                      ),
                      child: Row(
                        children: [
                          // 3. 3D Overlapping Visual Tile (Flex 40)
                          Expanded(
                            flex: 40,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: -12,
                                  left: -8,
                                  bottom: 12,
                                  right: 6,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors.shadow
                                              .withValues(
                                            alpha: isDark ? 0.35 : 0.22,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(5, 9),
                                        ),
                                        BoxShadow(
                                          color:
                                              (isUrgent
                                                      ? context
                                                            .colors
                                                            .errorSolid
                                                      : accentColor)
                                                  .withValues(alpha: 0.14),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: _buildLeftVisualTile(
                                      context: context,
                                      post: post,
                                      visualTheme: visualTheme,
                                      imageHeroTag: imageHeroTag,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 4. Details Section (Flex 60)
                          Expanded(
                            flex: 60,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Publisher Header Row
                                  Row(
                                    children: [
                                      // Publisher Avatar & Name (Tappable to view publisher profile)
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openPublisherProfile(
                                            context,
                                            post,
                                            sourceLabel,
                                          ),
                                          child: Row(
                                            children: [
                                        // Publisher Avatar with 3D Ring and Verified Badge
                                        PublisherAvatar(
                                          post: post,
                                          size: 32,
                                          isDark: isDark,
                                          isOfficial: isOfficial,
                                          brandHeaderColor: brandHeaderColor,
                                        ),
                                        const SizedBox(width: 8),
                                        // Publisher Name & Time Posted
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sourceLabel,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: brandHeaderColor,
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 11,
                                                    color: context
                                                              .colors
                                                              .textSecondary,
                                                  ),
                                                  const SizedBox(width: 3,
                                                        ),
                                                  Flexible(
                                                    child: Text(
                                                      publishedAt,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 10.5,
                                                        color: context
                                                                  .colors
                                                                  .textSecondary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
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
                                      // Clean and simple independent Saved / Bookmark Button
                                      SavedAnnouncementButton(
                                        key: ValueKey('save-card-${post.id}'),
                                        announcement: post,
                                        color: brandHeaderColor,
                                        backgroundColor: Colors.transparent,
                                        borderColor: null,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Post Title
                                  Text(
                                    post.title.isNotEmpty
                                        ? post.title
                                        : 'Community Advisory',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: context.colors.textPrimary,
                                      height: 1.18,
                                    ),
                                  ),

                                  if (post.hasCalendarSchedule &&
                                      post.eventDate != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.infoSurface,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: context.colors.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.event_rounded,
                                            size: 11,
                                            color: context.colors.info,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            DateFormat('MMM d',
                                            ).format(
                                              post.eventDate!.toLocal()),
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: context.colors.info,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 5),

                                  // Post Content Excerpt
                                  Text(
                                    post.content.trim().isNotEmpty
                                        ? post.content.trim()
                                        : 'No additional details provided.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.0,
                                      color: context.colors.textSecondary,
                                      height: 1.28,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  const Spacer(),

                                  // Subtle tap hint since the entire card is clickable
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Tap to view details',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w800,
                                            color: readMoreColor,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14.5,
                                        color: readMoreColor,
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void openPostDetails(
    BuildContext context,
    CommunityPost post,
    String imageHeroTag,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/post-details/${post.id}'),
        builder: (context) => PostDetailsPage(
          post: post,
          imageHeroTag: imageHeroTag,
          primaryGreen: context.colors.primaryGreen,
          deepGreen: context.colors.textPrimary,
        ),
      ),
    );
  }

  bool _isBarangayPublisherRole(String role) {
    final value = role.trim().toLowerCase();
    return value == 'barangay' || value.startsWith('barangay_');
  }

  bool _isLguPublisherRole(String role) {
    final value = role.trim().toLowerCase();
    return value == 'lgu' || value == 'super_admin';
  }

  String _postSourceLabel(CommunityPost post, bool isOfficial) {
    final role = post.authorRole.toLowerCase();
    if (post.publisherEntityName.trim().isNotEmpty) {
      return post.publisherEntityName.trim();
    }

    if (role == 'partner' || role == 'organization') {
      final organizationName = post.authorOrganizationName.trim();
      if (organizationName.isNotEmpty) return organizationName;
      return 'Partner Organization';
    }

    final usesBarangayName = _isBarangayPublisherRole(role);
    var barangay = post.authorBarangay.trim();

    // Older posts did not store the publisher's barangay. For those records,
    // use their single-barangay coverage when available.
    if (barangay.isEmpty &&
        usesBarangayName &&
        post.targetBarangay != 'All Barangays') {
      barangay = post.targetBarangay.trim();
    }

    if (usesBarangayName && barangay.isNotEmpty) {
      final cleaned = barangay.replaceFirst(
        RegExp(r'^barangay\s+', caseSensitive: false),
        '',
      );
      return 'Barangay $cleaned';
    }

    if (post.authorName.isNotEmpty) return post.authorName;
    return isOfficial ? 'Barangay Official' : 'Partner Organization';
  }

  static void openPublisherProfile(
    BuildContext context,
    CommunityPost post,
    String sourceLabel,
  ) {
    HapticFeedback.lightImpact();

    final authorRole = post.authorRole.trim().toLowerCase();
    final publisherType = post.publisherEntityType.trim().toLowerCase();

    // 1. Check if Barangay Council / Village FIRST
    final isBarangayRole = authorRole == 'barangay' ||
        authorRole.startsWith('barangay_') ||
        publisherType == 'barangay' ||
        post.publisherEntityId.trim().toLowerCase().startsWith('barangay_');

    final isBarangayPublisher = isBarangayRole ||
        canonicalBariliBarangay(sourceLabel) != null ||
        canonicalBariliBarangay(post.publisherEntityName) != null ||
        canonicalBariliBarangay(post.authorOrganizationName) != null ||
        canonicalBariliBarangay(post.authorName) != null;

    if (isBarangayPublisher) {
      String? resolvedBarangay;
      for (final candidate in [
        sourceLabel,
        post.publisherEntityName,
        post.authorOrganizationName,
        post.authorName,
        post.authorBarangay,
        if (post.targetBarangay != 'All Barangays') post.targetBarangay,
      ]) {
        if (candidate.trim().isNotEmpty) {
          final canonical = canonicalBariliBarangay(candidate);
          if (canonical != null) {
            resolvedBarangay = canonical;
            break;
          }
        }
      }

      if (resolvedBarangay == null && post.authorBarangay.trim().isNotEmpty) {
        resolvedBarangay = canonicalBariliBarangay(post.authorBarangay) ??
            post.authorBarangay.trim();
      }

      if (resolvedBarangay != null && resolvedBarangay.isNotEmpty) {
        final entity = PublicCivicEntity.forBarangay(resolvedBarangay);
        PublicEntityProfilePage.show(context, entity);
        return;
      }
    }

    // 2. Check if Public Civic Entity (LGU Department or Public Organization like CTU)
    PublicCivicEntity? civicEntity;
    for (final candidate in [
      post.publisherEntityId,
      post.publisherEntityName,
      post.authorOrganizationName,
      sourceLabel,
      post.authorName,
    ]) {
      if (candidate.trim().isNotEmpty) {
        final found = PublicCivicEntity.findByNameOrId(candidate);
        if (found != null) {
          civicEntity = found;
          break;
        }
      }
    }

    final isPublicOrgRole = publisherType == 'public_organization' ||
        publisherType == 'public_institution' ||
        authorRole == 'public_organization' ||
        authorRole == 'public_institution' ||
        authorRole == 'state_university';

    if (civicEntity == null && isPublicOrgRole) {
      final specificName = [
        post.publisherEntityName,
        post.authorOrganizationName,
        sourceLabel,
        post.authorName,
      ].firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');

      if (specificName.isNotEmpty) {
        civicEntity = PublicCivicEntity.forPublicOrganization(specificName);
      }
    }

    final isLguRole = authorRole == 'lgu' ||
        authorRole == 'super_admin' ||
        authorRole == 'department' ||
        authorRole.contains('lgu') ||
        authorRole.contains('admin') ||
        authorRole.contains('dept') ||
        publisherType == 'department' ||
        publisherType == 'lgu';

    if (civicEntity == null && isLguRole) {
      final specificName = [
        post.publisherEntityName,
        post.authorOrganizationName,
        sourceLabel,
        post.authorName,
      ].firstWhere(
        (s) =>
            s.trim().isNotEmpty &&
            s.toLowerCase() != 'official notice' &&
            s.toLowerCase() != 'barili lgu' &&
            s.toLowerCase() != 'lgu',
        orElse: () => '',
      );

      if (specificName.isNotEmpty) {
        civicEntity = PublicCivicEntity.forDepartment(specificName);
      } else {
        civicEntity = PublicCivicEntity.findByNameOrId('mayors_office') ??
            PublicCivicEntity.municipalDepartments.first;
      }
    }

    if (civicEntity != null) {
      PublicEntityProfilePage.show(context, civicEntity);
      return;
    }

    // 3. Check if Private Organization (Private partners with followers)
    PrivateOrganization? org;
    for (final candidate in [
      post.publisherEntityId,
      post.authorOrganizationName,
      post.publisherEntityName,
      sourceLabel,
      post.authorName,
    ]) {
      if (candidate.trim().isNotEmpty) {
        final found = PrivateOrganization.findByNameOrId(candidate);
        if (found != null) {
          org = found;
          break;
        }
      }
    }

    final isOrgRole = authorRole == 'organization' ||
        authorRole == 'private_organization' ||
        authorRole == 'school' ||
        authorRole == 'partner' ||
        publisherType == 'organization' ||
        publisherType == 'private_organization';

    if (org == null && isOrgRole) {
      final orgName = [
        post.authorOrganizationName,
        post.publisherEntityName,
        sourceLabel,
        post.authorName,
      ].firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');

      if (orgName.isNotEmpty) {
        org = PrivateOrganization.forOrganization(orgName);
      }
    }

    if (org != null) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OrganizationProfilePage(organization: org!),
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
      return;
    }

    // 4. Fallback to Resident User Profile
    if (post.authorId.isNotEmpty) {
      PublicUserProfilePage.show(
        context,
        post.authorId,
        initialName: sourceLabel,
        initialBarangay: post.authorBarangay,
      );
      return;
    }
  }

  void _openPublisherProfile(
    BuildContext context,
    CommunityPost post,
    String sourceLabel,
  ) =>
      openPublisherProfile(context, post, sourceLabel);

  String _postImageHeroTag(CommunityPost post, {required String scope}) {
    final identity = post.id.trim().isEmpty
        ? post.createdAt.microsecondsSinceEpoch.toString()
        : post.id;
    return 'post-image-$identity-$scope';
  }

  static _PostVisualTheme _postVisualTheme(
    BuildContext context,
    CommunityPost post,
  ) {
    final text = '${post.tag} ${post.title} ${post.content}'.toLowerCase();

    if (_containsAny(text, const [
      'power',
      'electric',
      'outage',
      'interruption',
    ])) {
      return _PostVisualTheme(
        kind: 'power',
        label: 'Power Advisory',
        icon: Icons.electrical_services_rounded,
        foreground: context.colors.warning,
        background: context.colors.warningSurface,
        gradientStart: context.colors.warningSurface,
        gradientEnd: context.colors.warningSurface,
      );
    }
    if (_containsAny(text, const [
      'clean',
      'broom',
      'garbage',
      'waste',
      'environment',
    ])) {
      return _PostVisualTheme(
        kind: 'clean',
        label: 'Clean-up Drive',
        icon: Icons.cleaning_services_rounded,
        foreground: context.colors.primaryGreen,
        background: context.colors.surfaceAlt,
        gradientStart: context.colors.surfaceAlt,
        gradientEnd: context.colors.successSurface,
      );
    }
    if (_containsAny(text, const [
      'rain',
      'weather',
      'storm',
      'flood',
      'typhoon',
    ])) {
      return _PostVisualTheme(
        kind: 'weather',
        label: 'Weather Alert',
        icon: Icons.thunderstorm_rounded,
        foreground: context.colors.info,
        background: context.colors.infoSurface,
        gradientStart: context.colors.infoSurface,
        gradientEnd: context.colors.infoSurface,
      );
    }
    if (_containsAny(text, const [
      'road',
      'traffic',
      'closure',
      'transport',
      'repair',
    ])) {
      return _PostVisualTheme(
        kind: 'road',
        label: 'Road Advisory',
        icon: Icons.traffic_rounded,
        foreground: context.colors.error,
        background: context.colors.errorSurface,
        gradientStart: context.colors.warningSurface,
        gradientEnd: context.colors.warningSurface,
      );
    }
    if (_containsAny(text, const [
      'event',
      'meeting',
      'festival',
      'program',
      'schedule',
    ])) {
      return _PostVisualTheme(
        kind: 'event',
        label: 'Community Event',
        icon: Icons.event_rounded,
        foreground: context.colors.purple,
        background: context.colors.purpleSurface,
        gradientStart: context.colors.purpleSurface,
        gradientEnd: context.colors.purpleSurface,
      );
    }
    if (_containsAny(text, const ['health', 'medical', 'clinic', 'vaccine'])) {
      return _PostVisualTheme(
        kind: 'health',
        label: 'Health Advisory',
        icon: Icons.health_and_safety_rounded,
        foreground: context.colors.error,
        background: context.colors.errorSurface,
        gradientStart: context.colors.errorSurface,
        gradientEnd: context.colors.errorSurface,
      );
    }
    return _PostVisualTheme(
      kind: 'general',
      label: 'Community Advisory',
      icon: Icons.campaign_rounded,
      foreground: context.colors.primaryGreen,
      background: context.colors.surfaceAlt,
      gradientStart: context.colors.surfaceAlt,
      gradientEnd: context.colors.successSurface,
    );
  }

  static bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }

  static bool _isUrgentPost(CommunityPost post) {
    return false;
  }

  Widget _buildLeftVisualTile({
    required BuildContext context,
    required CommunityPost post,
    required _PostVisualTheme visualTheme,
    required String imageHeroTag,
  }) {
    final photoUrl = post.imageUrl.trim();
    final localPath = post.localImagePath.trim();
    final hasCoverPhoto = photoUrl.isNotEmpty || localPath.isNotEmpty;

    final placeholder = _buildCategoryPlaceholderTile(
      context,
      visualTheme: visualTheme,
    );

    if (!hasCoverPhoto) {
      return Hero(
        tag: imageHeroTag,
        flightShuttleBuilder: _heroFlightShuttle,
        child: placeholder,
      );
    }

    final imageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(720, 1440)
            .toInt();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        showAnnouncementPhotoViewer(
          context,
          networkUrl: photoUrl,
          localPath: localPath,
          heroTag: imageHeroTag,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: imageHeroTag,
              flightShuttleBuilder: _heroFlightShuttle,
              child: offlineFirstAnnouncementImage(
                localPath: localPath,
                networkUrl: photoUrl,
                fit: BoxFit.cover,
                cacheWidth: imageCacheWidth,
                fallback: placeholder,
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
                    context.colors.shadow.withValues(alpha: 0.20),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),


          ],
        ),
      ),
    );
  }

  static Widget _buildCategoryPlaceholderTile(
    BuildContext context, {
    required _PostVisualTheme visualTheme,
    bool isLargeHeader = false,
  }) {
    final borderRadius =
        isLargeHeader ? BorderRadius.zero : BorderRadius.circular(26);
    final centerCircleSize = isLargeHeader ? 80.0 : 52.0;
    final centerIconSize = isLargeHeader ? 40.0 : 25.0;
    final watermarkSize = isLargeHeader ? 150.0 : 94.0;
    final labelFontSize = isLargeHeader ? 11.5 : 9.0;
    final labelPadding = isLargeHeader
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [visualTheme.gradientStart, visualTheme.gradientEnd],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thematic background illustration
            Positioned.fill(
              child: CustomPaint(
                painter: _AnnouncementIllustrationPainter(
                  kind: visualTheme.kind,
                  color: visualTheme.foreground,
                ),
              ),
            ),

            // Ambient watermark icon for high-end depth
            Positioned(
              right: isLargeHeader ? -8 : -16,
              bottom: isLargeHeader ? -10 : -16,
              child: Icon(
                visualTheme.icon,
                size: watermarkSize,
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

            // Centered Category Visual & Label (Matches Bayanihan Works card & details)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeHeader ? 24 : 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: centerCircleSize,
                      height: centerCircleSize,
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.border,
                          width: isLargeHeader ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: visualTheme.foreground.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: isLargeHeader ? 18 : 12,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.08,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          visualTheme.icon,
                          size: centerIconSize,
                          color: visualTheme.foreground,
                        ),
                      ),
                    ),
                    SizedBox(height: isLargeHeader ? 10 : 7),
                    Container(
                      padding: labelPadding,
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.75),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow.withValues(alpha: 0.06,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Text(
                        visualTheme.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w900,
                          color: visualTheme.foreground,
                          letterSpacing: 0.7,
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

}

void showAnnouncementPhotoViewer(
  BuildContext context, {
  required String networkUrl,
  String? localPath,
  String? heroTag,
}) {
  final cleanUrl = networkUrl.trim();
  final cleanLocal = (localPath ?? '').trim();
  if (cleanUrl.isEmpty && cleanLocal.isEmpty) return;

  showDialog<void>(
    context: context,
    barrierColor: context.colors.shadow,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: offlineFirstAnnouncementImage(
                    localPath: cleanLocal,
                    networkUrl: cleanUrl,
                    fit: BoxFit.contain,
                    fallback: Icon(
                      Icons.broken_image_rounded,
                      color: dialogContext.colors.onBrandMuted,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 32,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 10,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PostDetailsPage extends StatelessWidget {
  final CommunityPost post;
  final String imageHeroTag;
  final Color primaryGreen;
  final Color deepGreen;

  const PostDetailsPage({
    super.key,
    required this.post,
    required this.imageHeroTag,
    required this.primaryGreen,
    required this.deepGreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authorRole = post.authorRole.trim().toLowerCase();
    final isOfficial =
        post.tag.toUpperCase() == 'OFFICIAL' ||
        authorRole == 'barangay' ||
        authorRole.startsWith('barangay_') ||
        authorRole == 'lgu' ||
        authorRole == 'super_admin';
    final publishedAt = DateFormat(
      'MMMM d, y • h:mm a',
    ).format(post.createdAt.toLocal());

    final photoUrl = post.imageUrl.trim();
    final localPath = post.localImagePath.trim();
    final hasCoverPhoto = photoUrl.isNotEmpty || localPath.isNotEmpty;
    final visualTheme = ModernPostCard._postVisualTheme(context, post);
    final imageCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(720, 1440)
            .toInt();

    final detailsPlaceholder = ModernPostCard._buildCategoryPlaceholderTile(
      context,
      visualTheme: visualTheme,
      isLargeHeader: true,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: hasCoverPhoto ? 360 : 260,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: hasCoverPhoto
                            ? () {
                                HapticFeedback.lightImpact();
                                showAnnouncementPhotoViewer(
                                  context,
                                  networkUrl: photoUrl,
                                  localPath: localPath,
                                  heroTag: imageHeroTag,
                                );
                              }
                            : null,
                        child: Hero(
                          tag: imageHeroTag,
                          flightShuttleBuilder: _heroFlightShuttle,
                          child: hasCoverPhoto
                              ? Container(
                                  color: context.colors.shadow,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Blurred backdrop so wide/tall photos look cohesive without harsh cutoffs
                                      offlineFirstAnnouncementImage(
                                        localPath: post.localImagePath,
                                        networkUrl: post.imageUrl,
                                        fit: BoxFit.cover,
                                        cacheWidth: imageCacheWidth,
                                        fallback: detailsPlaceholder,
                                      ),
                                      BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22,
                                        ),
                                        child: Container(
                                          color: context.colors.shadow
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      // The whole picture is visible without cropping!
                                      Center(
                                        child: offlineFirstAnnouncementImage(
                                          localPath: post.localImagePath,
                                          networkUrl: post.imageUrl,
                                          fit: BoxFit.contain,
                                          cacheWidth: imageCacheWidth,
                                          fallback: detailsPlaceholder,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : detailsPlaceholder,
                        ),
                      ),
                      // Ambient Vignette for maximum button contrast & smooth bottom curve
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.colors.shadow.withValues(alpha: 0.65),
                              Colors.transparent,
                              Colors.transparent,
                              (context.colors.surfaceAlt)
                                  .withValues(alpha: 0.6,
                              ),
                              context.colors.surfaceAlt,
                            ],
                            stops: const [0.0, 0.22, 0.65, 0.90, 1.0],
                          ),
                        ),
                      ),
                      // Floating "View whole picture" chip
                      if (hasCoverPhoto)
                        Positioned(
                          right: 16,
                          bottom: 40,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showAnnouncementPhotoViewer(
                                context,
                                networkUrl: photoUrl,
                                localPath: localPath,
                                heroTag: imageHeroTag,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.shadow.withValues(alpha: 0.72,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.colors.border.withValues(alpha: 0.35,
                                  ),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.shadow.withValues(alpha: 0.35,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_rounded, color: context.colors.onAccent, size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'View whole picture',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -26, 0),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tactile Grab Indicator Bar
                        Center(
                          child: Container(
                            width: 42,
                            height: 4.5,
                            margin: const EdgeInsets.only(top: 10, bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? context.colors.surfaceAlt.withValues(alpha: 0.18,
                                    )
                                  : context.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // 3D Municipal Authority Card (Tappable to view publisher profile)
                        Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.surface,
                                context.colors.surface,
                              ],
                            ),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (context.colors.brandStrong)
                                        .withValues(
                                          alpha: isDark ? 0.35 : 0.06,
                                        ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                final label = post.displayPublisher.isNotEmpty
                                    ? post.displayPublisher
                                    : (post.authorOrganizationName.isNotEmpty
                                        ? post.authorOrganizationName
                                        : (post.authorName.isNotEmpty
                                            ? post.authorName
                                            : 'Publisher'));
                                ModernPostCard.openPublisherProfile(
                                  context,
                                  post,
                                  label,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(13),
                                child: Row(
                                  children: [
                                    // 3D Minted Civic Seal Medallion
                                    Container(
                                      width: 46,
                                      height: 46,
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
                                            color: context.colors.brandStrong
                                                .withValues(alpha: 0.3),
                                            blurRadius: 7,
                                            offset: const Offset(0, 2.5),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: PublisherAvatar(
                                          post: post,
                                          size: 40,
                                          isDark: isDark,
                                          isOfficial: true,
                                          showVerifiedBadge: false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  post.displayPublisher.isNotEmpty
                                                      ? post.displayPublisher
                                                      : (post
                                                                .authorOrganizationName
                                                                .isNotEmpty
                                                            ? post.authorOrganizationName
                                                            : post.authorName),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: context
                                                        .colors
                                                        .textPrimary,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.verified_rounded,
                                                color: context.colors.info,
                                                size: 17,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      context.colors.surfaceAlt,
                                                  borderRadius: BorderRadius.circular(
                                                    6),
                                                ),
                                                child: Text(
                                                  _formatRoleLabel(post.authorRole,
                                                  ),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: context
                                                        .colors
                                                        .primaryGreen,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  _relativePostTime(post.createdAt,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    color: context
                                                        .colors
                                                        .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isOfficial) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              context.colors.brand,
                                              context.colors.brand,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: context.colors.brandStrong
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'OFFICIAL',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: context.colors.onAccent,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 3D Frosted Category Pill
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.surfaceAlt,
                                context.colors.surfaceAlt,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: context.colors.primaryGreen.withValues(alpha: 0.4,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                visualTheme.icon,
                                color: context.colors.primaryGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (post.displayCategory.isNotEmpty
                                        ? post.displayCategory
                                        : 'COMMUNITY ADVISORY')
                                    .toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: context.colors.primaryGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (post.sourceUnavailable ||
                            const [
                              'cancelled',
                              'archived',
                            ].contains(post.status.toLowerCase())) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.errorSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.colors.error),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: context.colors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    post.sourceUnavailable
                                        ? 'The original announcement is no longer available. This is your saved offline copy.'
                                        : 'This announcement is ${post.status.toUpperCase()}.',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Chiseled Announcement Headline
                        Text(
                          post.title.isNotEmpty
                              ? post.title
                              : 'Community Announcement',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: context.colors.textPrimary,
                            height: 1.22,
                            letterSpacing: -0.4,
                          ),
                        ),

                        // Enhanced Content Card
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 14, bottom: 20),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (context.colors.brandStrong)
                                        .withValues(
                                          alpha: isDark ? 0.25 : 0.04,
                                        ),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SelectableText(
                            post.content,
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              color: context.colors.textPrimary,
                              height: 1.65,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),



                        if (post.hasCalendarSchedule) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: AnnouncementCalendarAction(post: post),
                          ),
                        ],

                        // Compact 2x2 Quick Info Grid (Replaces 4 stacked cards)
                        _build2x2QuickInfoGrid(
                          context: context,
                          post: post,
                          publishedAt: publishedAt,
                          isDark: isDark,
                        ),

                        // Civic Authenticity Certificate Banner
                        Container(
                          margin: const EdgeInsets.only(top: 24, bottom: 30),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? context.colors.surfaceAlt.withValues(alpha: 0.6,
                                  )
                                : context.colors.surfaceAlt.withValues(alpha: 0.7,
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 18,
                                color: context.colors.primaryGreen,
                              ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  'Official communication certified by ${post.authorOrganizationName.isNotEmpty ? post.authorOrganizationName : 'Barangay ${post.authorBarangay.isNotEmpty ? post.authorBarangay : 'Cabcaban'} • Municipality of Barili'}.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3D Frosted Glass Close Action
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 18,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.surface.withValues(alpha: 0.28),
                          context.colors.shadow.withValues(alpha: 0.35),
                        ],
                      ),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: context.colors.onAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3D Frosted Glass Bookmark Action
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 18,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface.withValues(alpha: 0.28),
                        context.colors.shadow.withValues(alpha: 0.35),
                      ],
                    ),
                    border: Border.all(
                      color: context.colors.border.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SavedAnnouncementButton(
                      key: ValueKey('save-details-${post.id}'),
                      announcement: post,
                      color: context.colors.surface,
                      backgroundColor: Colors.transparent,
                      borderColor: Colors.transparent,
                      iconSize: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRoleLabel(String rawRole) {
    final clean = rawRole.trim().replaceAll('_', ' ').toLowerCase();
    if (clean.isEmpty) return 'Barangay Official';
    return clean
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  Widget _build2x2QuickInfoGrid({
    required BuildContext context,
    required CommunityPost post,
    required String publishedAt,
    required bool isDark,
  }) {
    final bgy = post.targetBarangay.isNotEmpty
        ? post.targetBarangay
        : post.authorBarangay;

    final area = bgy.isNotEmpty
        ? (bgy.toLowerCase().startsWith('barangay') ? bgy : 'Barangay $bgy')
        : 'Barili-wide';

    final String audience;
    if (post.targetAudience.isNotEmpty &&
        !post.targetAudience.toLowerCase().contains('all resident') &&
        !post.targetAudience.toLowerCase().contains('all barili')) {
      audience = post.targetAudience;
    } else if (bgy.isNotEmpty) {
      final bgyClean = bgy.replaceFirst(
        RegExp(r'^barangay\s+', caseSensitive: false),
        '',
      );
      audience = '$bgyClean Residents';
    } else {
      audience = 'All Barili Residents';
    }

    final formattedDate = DateFormat(
      'MMM d, y',
    ).format(post.createdAt.toLocal());

    final isOfficial =
        post.tag.toUpperCase() == 'OFFICIAL' ||
        post.authorRole.toLowerCase().contains('barangay') ||
        post.authorRole.toLowerCase().contains('official') ||
        post.authorRole.toLowerCase().contains('admin') ||
        post.authorRole.toLowerCase().contains('lgu');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceAlt.withValues(alpha: 0.75)
            : context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.2 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge (Matching "COMMUNITY CALENDAR" pill style)
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 12,
                          color: context.colors.onAccent,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'POST DETAILS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onAccent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOfficial ? 'Official Notice' : 'Community Post',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Coverage Area (Full-width row, no cuts)
          _buildDetailRow(
            context,
            icon: Icons.location_on_rounded,
            iconColor: context.colors.error,
            label: 'Coverage Area',
            value: area,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Intended For / Audience (Full-width row, no cuts)
          _buildDetailRow(
            context,
            icon: Icons.groups_rounded,
            iconColor: context.colors.info,
            label: 'Intended For',
            value: audience,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Published Date (Full-width row, no cuts)
          _buildDetailRow(
            context,
            icon: Icons.calendar_month_rounded,
            iconColor: context.colors.primaryGreen,
            label: 'Published Date',
            value: formattedDate,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Status Note Box (Matching the reminder note style from the calendar card)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: context.colors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOfficial
                        ? 'Status: Verified Official Announcement'
                        : 'Status: Community Post',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primaryGreen,
                      height: 1.25,
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

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
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
    );
  }
}

class _PostVisualTheme {
  final String kind;
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color gradientStart;
  final Color gradientEnd;

  const _PostVisualTheme({
    required this.kind,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

class _AnnouncementIllustrationPainter extends CustomPainter {
  final String kind;
  final Color color;

  const _AnnouncementIllustrationPainter({
    required this.kind,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final softFill = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final accentFill = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.width * 0.28,
      softFill,
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.84),
      size.width * 0.35,
      accentFill,
    );

    switch (kind) {
      case 'power':
        _paintPower(canvas, size, line);
      case 'clean':
        _paintClean(canvas, size, line);
      case 'weather':
        _paintWeather(canvas, size, line, softFill);
      case 'road':
        _paintRoad(canvas, size, line, accentFill);
      case 'event':
        _paintEvent(canvas, size, line, softFill);
      case 'health':
        _paintHealth(canvas, size, line, softFill);
      default:
        _paintGeneral(canvas, size, line, softFill);
    }
  }

  void _paintPower(Canvas canvas, Size size, Paint line) {
    for (final x in [size.width * 0.12, size.width * 0.84]) {
      canvas.drawLine(
        Offset(x, size.height * 0.28),
        Offset(x, size.height),
        line,
      );
      canvas.drawLine(
        Offset(x - 10, size.height * 0.42),
        Offset(x + 10, size.height * 0.42),
        line,
      );
    }
    final wire = Path()
      ..moveTo(size.width * 0.02, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.6,
        size.width * 0.98,
        size.height * 0.42,
      );
    canvas.drawPath(wire, line);
  }

  void _paintClean(Canvas canvas, Size size, Paint line) {
    for (var i = 0; i < 5; i++) {
      final x = 8.0 + (i * 23);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + 5, size.height - 20 - (i.isEven ? 5 : 0)),
        line,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(x + 8, size.height - 24),
          width: 13,
          height: 8,
        ),
        0.2,
        2.7,
        false,
        line,
      );
    }
  }

  void _paintWeather(Canvas canvas, Size size, Paint line, Paint fill) {
    final cloud = Path()
      ..moveTo(8, 34)
      ..quadraticBezierTo(11, 22, 22, 27)
      ..quadraticBezierTo(30, 13, 42, 27)
      ..quadraticBezierTo(55, 23, 58, 36)
      ..lineTo(8, 36)
      ..close();
    canvas.drawPath(cloud, fill);
    canvas.drawPath(cloud, line);
    for (var i = 0; i < 4; i++) {
      final x = 14.0 + (i * 13);
      canvas.drawLine(Offset(x, 43), Offset(x - 4, 55), line);
    }
  }

  void _paintRoad(Canvas canvas, Size size, Paint line, Paint fill) {
    final road = Path()
      ..moveTo(size.width * 0.22, size.height)
      ..lineTo(size.width * 0.45, size.height * 0.48)
      ..lineTo(size.width * 0.6, size.height * 0.48)
      ..lineTo(size.width * 0.88, size.height)
      ..close();
    canvas.drawPath(road, fill);
    canvas.drawPath(road, line);
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.6),
      Offset(size.width * 0.58, size.height * 0.78),
      line,
    );
  }

  void _paintEvent(Canvas canvas, Size size, Paint line, Paint fill) {
    final cord = Path()
      ..moveTo(0, 22)
      ..quadraticBezierTo(size.width / 2, 40, size.width, 20);
    canvas.drawPath(cord, line);
    for (var i = 0; i < 5; i++) {
      final x = 8.0 + (i * 24);
      final flag = Path()
        ..moveTo(x, 25)
        ..lineTo(x + 10, 28)
        ..lineTo(x + 4, 40)
        ..close();
      canvas.drawPath(flag, fill);
      canvas.drawPath(flag, line);
    }
  }

  void _paintHealth(Canvas canvas, Size size, Paint line, Paint fill) {
    final center = Offset(size.width * 0.78, size.height * 0.76);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 38, height: 38),
        const Radius.circular(8),
      ),
      fill,
    );
    canvas.drawLine(center.translate(-10, 0), center.translate(10, 0), line);
    canvas.drawLine(center.translate(0, -10), center.translate(0, 10), line);
  }

  void _paintMegaphone(Canvas canvas, Size size, Color baseColor) {
    final conePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height * 0.3)
      ..lineTo(size.width * 0.72, size.height * 0.7)
      ..lineTo(size.width * 0.25, size.height * 0.5)
      ..close();

    final handlePath = Path()
      ..moveTo(size.width * 0.35, size.height * 0.5)
      ..lineTo(size.width * 0.32, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.8,
        size.width * 0.38,
        size.height * 0.75,
      )
      ..lineTo(size.width * 0.4, size.height * 0.5)
      ..close();

    final backPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.25, size.height * 0.5),
          width: size.width * 0.08,
          height: size.height * 0.18,
        ),
      );

    final ringPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.68, size.height * 0.5),
          width: size.width * 0.12,
          height: size.height * 0.4,
        ),
      );

    final paint = Paint()
      ..color = baseColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawPath(handlePath, paint);
    canvas.drawPath(conePath, paint);
    canvas.drawPath(backPath, paint..color = baseColor);

    canvas.drawPath(
      ringPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final wavePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i <= 3; i++) {
      final radius = 10.0 + (i * 12);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.75, size.height * 0.5),
          width: radius * 1.5,
          height: radius * 2.5,
        ),
        -0.8,
        1.6,
        false,
        wavePaint,
      );
    }
  }

  void _paintGeneral(Canvas canvas, Size size, Paint line, Paint fill) {
    _paintMegaphone(canvas, size, line.color.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(covariant _AnnouncementIllustrationPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

/// Provides a subtle, two-beat heartbeat pulse (Messenger-style quote jump animation)
/// with a soft fading emerald halo when a specific card is selected from notifications.
class _HeartbeatCardWrapper extends StatefulWidget {
  const _HeartbeatCardWrapper({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_HeartbeatCardWrapper> createState() => _HeartbeatCardWrapperState();
}

class _HeartbeatCardWrapperState extends State<_HeartbeatCardWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Subtle two-throb heartbeat curve (Messenger/replied photo style)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.045,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.045,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.98,
          end: 1.03,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.03,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 36,
      ),
    ]).animate(_controller);

    _glowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.enabled) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_HeartbeatCardWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.50 * _glowAnimation.value,
                  ),
                  blurRadius: 24,
                  spreadRadius: 4 * _glowAnimation.value,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Neutral Facebook-style skeleton loading card that mirrors the structure
/// and layout of [ModernPostCard] without distracting colors or icons.
class ModernPostCardSkeleton extends StatelessWidget {
  final bool isUrgent;
  final EdgeInsetsGeometry margin;
  final bool enableShimmer;

  const ModernPostCardSkeleton({
    super.key,
    this.isUrgent = false,
    this.margin = const EdgeInsets.fromLTRB(4, 8, 4, 22),
    this.enableShimmer = true,
  });

  /// Builds a feed list of neutral skeleton cards matching the announcement stream.
  static Widget feedList({
    int count = 2,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(4, 8, 4, 22),
  }) {
    return ESugidShimmerLoading(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (index) => ModernPostCardSkeleton(
            isUrgent: index % 2 == 1,
            margin: margin,
            enableShimmer: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Classic neutral Facebook skeleton palette (zero colors)
    final primaryBoneColor = context.colors.surfaceAlt;

    final secondaryBoneColor = context.colors.surfaceAlt;

    final card = Container(
      margin: margin,
      height: 196,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Subtle Neutral Floating Shadow
          Positioned(
            left: 20,
            right: 20,
            bottom: -8,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(
                      alpha: isDark ? 0.25 : 0.04,
                    ),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Card Body
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? context.colors.border.withValues(alpha: 0.08)
                    : context.colors.border.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(
                    alpha: isDark ? 0.30 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // 3. Media Tile Placeholder (Flex 40)
                Expanded(
                  flex: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -12,
                        left: -8,
                        bottom: 12,
                        right: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primaryBoneColor,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(
                                  alpha: isDark ? 0.28 : 0.07,
                                ),
                                blurRadius: 12,
                                offset: const Offset(2, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Details Section (Flex 60)
                Expanded(
                  flex: 60,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Publisher Header Row (Avatar circle + name/date bars + bookmark)
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryBoneColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: isUrgent ? 95 : 80,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: primaryBoneColor,
                                      borderRadius:
                                          BorderRadius.circular(5.5),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 48,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: secondaryBoneColor,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 14,
                              height: 18,
                              decoration: BoxDecoration(
                                color: secondaryBoneColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Title Bars
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            right: isUrgent ? 12 : 24),
                          height: 14,
                          decoration: BoxDecoration(
                            color: primaryBoneColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: isUrgent ? 120 : 85,
                          height: 14,
                          decoration: BoxDecoration(
                            color: primaryBoneColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Excerpt Lines
                        Container(
                          width: double.infinity,
                          height: 9,
                          decoration: BoxDecoration(
                            color: secondaryBoneColor,
                            borderRadius: BorderRadius.circular(4.5),
                          ),
                        ),
                        const SizedBox(height: 4.5),
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            right: isUrgent ? 22 : 14),
                          height: 9,
                          decoration: BoxDecoration(
                            color: secondaryBoneColor,
                            borderRadius: BorderRadius.circular(4.5),
                          ),
                        ),
                        const SizedBox(height: 4.5),
                        Container(
                          width: isUrgent ? 65 : 95,
                          height: 9,
                          decoration: BoxDecoration(
                            color: secondaryBoneColor,
                            borderRadius: BorderRadius.circular(4.5),
                          ),
                        ),

                        const Spacer(),

                        // Read More / Action Bar
                        Container(
                          width: 75,
                          height: 10,
                          decoration: BoxDecoration(
                            color: secondaryBoneColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (enableShimmer) {
      return ESugidShimmerLoading(child: card);
    }
    return card;
  }
}
