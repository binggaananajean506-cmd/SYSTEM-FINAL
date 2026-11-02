import 'package:esugid/core/widgets/app_feedback.dart';
import 'dart:async';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/public_civic_entity.dart';
import '../services/publisher_avatar_service.dart';

class PublicEntityProfilePage extends StatefulWidget {
  final PublicCivicEntity entity;

  const PublicEntityProfilePage({
    super.key,
    required this.entity});

  static Future<void> show(
    BuildContext context,
    PublicCivicEntity entity) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PublicEntityProfilePage(entity: entity),
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
  State<PublicEntityProfilePage> createState() =>
      _PublicEntityProfilePageState();
}

class _PublicEntityProfilePageState extends State<PublicEntityProfilePage> {
  String? _resolvedAvatarUrl;
  StreamSubscription<String?>? _barangayPhotoSubscription;
  int _avatarGeneration = 0;

  @override
  void initState() {
    super.initState();
    _resolveAvatar();
  }

  void _resolveAvatar() {
    final generation = ++_avatarGeneration;
    _barangayPhotoSubscription?.cancel();
    _barangayPhotoSubscription = null;
    _resolvedAvatarUrl = null;
    if (widget.entity.type == CivicEntityType.barangay) {
      final id = PublisherAvatarService.barangayProfileId(
        id: widget.entity.id, name: widget.entity.name,
      );
      _resolvedAvatarUrl = id == null ? widget.entity.logoUrl
          : PublisherAvatarService.getCached(id) ?? widget.entity.logoUrl;
      _barangayPhotoSubscription = PublisherAvatarService.watchBarangayAvatar(
        barangayId: id, barangay: widget.entity.name,
      ).listen((photo) {
        if (mounted && generation == _avatarGeneration) {
          setState(() => _resolvedAvatarUrl = photo ?? widget.entity.logoUrl);
        }
      });
      return;
    }
    final direct = widget.entity.logoUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      _resolvedAvatarUrl = direct;
      return;
    }
    final bgyName = widget.entity.type == CivicEntityType.barangay ? widget.entity.name : null;
    final bgyId = widget.entity.type == CivicEntityType.barangay ? widget.entity.id : null;
    final orgId = widget.entity.type == CivicEntityType.publicOrganization ? widget.entity.id : null;

    final cached = PublisherAvatarService.getCached(widget.entity.name) ??
        PublisherAvatarService.getCached(widget.entity.id);
    if (cached != null && cached.isNotEmpty) {
      _resolvedAvatarUrl = cached;
      return;
    }

    PublisherAvatarService.resolveAvatarUrl(
      authorPhotoUrl: direct,
      barangay: bgyName,
      barangayId: bgyId,
      organizationId: orgId,
    ).then((url) {
      if (mounted && generation == _avatarGeneration && url != null && url.isNotEmpty) {
        setState(() {
          _resolvedAvatarUrl = url;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PublicEntityProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity) _resolveAvatar();
  }

  @override
  void dispose() {
    _avatarGeneration++;
    _barangayPhotoSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleShareOutsideApp() async {
    HapticFeedback.lightImpact();
    final entity = widget.entity;
    final buffer = StringBuffer();
    buffer.writeln('🏛️ ${entity.name}');
    buffer.writeln('Category: ${entity.category}');
    buffer.writeln();
    buffer.writeln(_simplifiedAboutText(entity));
    buffer.writeln();
    buffer.writeln('📍 Location: ${entity.address}');
    buffer.writeln('⏰ Operating Hours: ${entity.operatingHours}');
    buffer.writeln('🌐 Jurisdiction: ${entity.jurisdiction}');

    if (entity.contactNumbers.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('📞 Contact Lines:');
      for (final contact in entity.contactNumbers) {
        buffer.writeln('• ${contact.label}: ${contact.number}');
      }
    }

    if (entity.officialPageUrl != null &&
        entity.officialPageUrl!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🌐 Official Portal: ${entity.officialPageUrl}');
    }

    buffer.writeln();
    buffer.writeln('Shared via E-SUGID Barili App');

    final shareText = buffer.toString().trim();

    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: '${entity.name} - Barili Public Profile',
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

  Future<void> _openMapNavigation() async {
    HapticFeedback.mediumImpact();
    final query = '${widget.entity.name}, ${widget.entity.address}';
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open map navigation.'),
          kind: FeedbackKind.error,
        ),
      );
    }
  }

  String _simplifiedAboutText(PublicCivicEntity entity) {
    if (entity.type == CivicEntityType.barangay) {
      final clean = entity.name.replaceFirst(
        RegExp(r'^(barangay|brgy\.?|bgy\.?)\s+', caseSensitive: false),
        '',
      ).trim();
      return 'Barangay $clean serves and supports all residents in our community. We help keep our neighborhood safe, clean, and peaceful, issue local clearances and permits, and assist families with everyday community services in Barili, Cebu.';
    }
    return entity.about;
  }

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Executive Civic Pinned App Bar (No cover photo)
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
                        color: context.colors.border.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.15),
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
              entity.type == CivicEntityType.department
                  ? 'Municipal Office'
                  : entity.type == CivicEntityType.publicOrganization
                      ? 'Public Organization'
                      : 'Barangay Profile',
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

          // 2. Profile Identity Card (Emblem, Name, Facebook Verified Badge, Category)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? context.colors.infoSolid.withValues(alpha: 0.3) : context.colors.infoSolid.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildEmblem(entity),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entity.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (entity.isVerified) ...[
                                const SizedBox(width: 6),
                                _buildFacebookVerifiedBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors
                                  .accent(entity.brandColor)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.colors
                                    .accent(entity.brandColor)
                                    .withValues(alpha: 0.20),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  entity.fallbackIcon,
                                  size: 13,
                                  color: context.colors.accent(
                                    entity.brandColor,
                                ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    entity.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.accent(
                                        entity.brandColor,
                                    ),
                                  ),
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
            ),
          ),

          // 3. About & Location Information Section (Clean direct layout without redundant tabs)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            sliver: SliverToBoxAdapter(
              child: _buildAboutTab(entity)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmblem(PublicCivicEntity entity) {
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
          color: context.colors
              .accent(entity.brandColor)
              .withValues(alpha: 0.35),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors
                .accent(entity.brandColor)
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
        padding: const EdgeInsets.all(4.0),
        child: ClipOval(
          child: (_resolvedAvatarUrl != null && _resolvedAvatarUrl!.isNotEmpty)
              ? Image.network(
                  _resolvedAvatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) =>
                      _buildLogoAssetOrFallback(entity),
                )
              : _buildLogoAssetOrFallback(entity),
        ),
      ),
    );
  }

  Widget _buildLogoAssetOrFallback(PublicCivicEntity entity) {
    if (entity.logoAsset != null && entity.logoAsset!.isNotEmpty) {
      return Image.asset(
        entity.logoAsset!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildLogoFallback(entity),
      );
    }
    return _buildLogoFallback(entity);
  }

  Widget _buildLogoFallback(PublicCivicEntity entity) {
    return Container(
      color: context.colors.accent(entity.brandColor).withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          entity.fallbackIcon,
          size: 32,
          color: context.colors.accent(entity.brandColor),
        ),
      ),
    );
  }

  Widget _buildFacebookVerifiedBadge() {
    return Tooltip(
      message: 'Verified Official Profile',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
            ),
          ),
          Icon(
            Icons.verified,
            size: 20,
            color: context.colors.info, // Official Facebook Verified Blue
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab(PublicCivicEntity entity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
          // Simplified citizen-friendly description (Basic Words)
          Text(
            _simplifiedAboutText(entity),
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w400,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: context.colors.border),
          const SizedBox(height: 16),

          // Enhanced 3D Location & Google Maps Card
          _buildLocationAndMapCard(entity),

          const SizedBox(height: 14),

          // Leadership Card
          _buildLeadershipCard(entity),
        ],
      ),
    );
  }

  Widget _buildLocationAndMapCard(PublicCivicEntity entity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address Row with 3D Medallion Pin
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.brand, context.colors.brand],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 24,
                  color: context.colors.onAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.type == CivicEntityType.publicOrganization
                          ? 'Physical Campus / Office Location'
                          : 'Physical Hall / Office Location',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entity.address,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Enhanced Tactile 3D Google Maps Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openMapNavigation,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 16,
                ),
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.border.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: context.colors.surface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        size: 17,
                        color: context.colors.onAccent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Open in Google Maps',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.colors.onAccent,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: context.colors.onAccent,
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

  Widget _buildLeadershipCard(PublicCivicEntity entity) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.warningSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_pin_rounded,
              size: 20,
              color: context.colors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.leadershipTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.colors.info,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entity.leadershipName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
