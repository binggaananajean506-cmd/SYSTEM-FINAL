import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';

import '../auth_service.dart';

class UserProfileAvatar extends StatelessWidget {
  const UserProfileAvatar({
    super.key,
    required this.user,
    required this.size,
    this.borderColor,
    this.borderWidth = 1.5,
    this.backgroundColor,
    this.foregroundColor,
    this.badgeBorderColor,
    this.showVerifiedBadge = true,
  });

  final User user;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? badgeBorderColor;
  final bool showVerifiedBadge;

  bool get _showsResidentVerification =>
      showVerifiedBadge &&
      user.role == UserRole.resident &&
      user.verificationStatus == VerificationStatus.verified;

  @override
  Widget build(BuildContext context) {
    final badgeSize = (size * 0.34).clamp(12.0, 28.0);
    return Semantics(
      image: true,
      label: _showsResidentVerification
          ? '${user.name}, verified resident'
          : user.name,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  padding: EdgeInsets.all(borderWidth),
                  decoration: BoxDecoration(
                    color: borderColor ?? context.colors.border,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(child: _buildPhoto(context)),
                ),
              ),
            ),
            if (_showsResidentVerification)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: context.colors.infoSolid,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          badgeBorderColor ??
                          Theme.of(context).colorScheme.surface,
                      width: badgeSize >= 20 ? 2.5 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.highlight.withValues(
                          alpha: 0.2000,
                        ),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: badgeSize * 0.62,
                    color: context.colors.onAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final photoUrl = user.profilePhotoUrl?.trim() ?? '';
    final fallback = ColoredBox(
      color: backgroundColor ?? context.colors.surfaceAlt,
      child: Center(
        child: Text(
          _initials(user.name),
          maxLines: 1,
          style: TextStyle(
            color: foregroundColor ?? context.colors.primaryGreen,
            fontSize: size * 0.36,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    if (photoUrl.isEmpty) return fallback;

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      cacheWidth: (size * 3).round(),
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) return 'U';
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class BayanihanUserAvatar extends StatelessWidget {
  const BayanihanUserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 46,
    this.borderColor,
    this.borderWidth = 1.5,
    this.showVerifiedBadge = true,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final bool showVerifiedBadge;

  @override
  Widget build(BuildContext context) {
    final validUrl = photoUrl?.trim();
    final hasPhoto = validUrl != null && validUrl.isNotEmpty;
    final badgeSize = (size * 0.35).clamp(12.0, 20.0);

    final avatarCircle = hasPhoto
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor ?? context.colors.border, width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                validUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _buildFallback(context),
              ),
            ),
          )
        : _buildFallback(context);

    if (!showVerifiedBadge) return avatarCircle;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatarCircle),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: context.colors.infoSolid, // Verified Blue
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.border,
                  width: badgeSize >= 16 ? 1.8 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.highlight.withValues(alpha: 0.2000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: badgeSize * 0.62,
                  color: context.colors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
        ),
        border: Border.all(color: context.colors.border, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          maxLines: 1,
          style: TextStyle(
            color: context.colors.primaryGreen,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }

  String _initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) return 'U';
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}
