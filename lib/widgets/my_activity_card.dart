import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme/semantic_colors.dart';

/// Compact tracking card shared by the concern and complaint activity lists.
class MyActivityCard extends StatelessWidget {
  const MyActivityCard({
    super.key,
    required this.title,
    this.description,
    required this.category,
    required this.categoryColor,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.originalReporter,
    this.photoUrl,
    this.otherReporters = const [],
    this.reporterCount,
    this.onViewReporters,
    this.isPublicBarangay = false,
    this.timeAgo,
  });

  final String title;
  final String? description;
  final String category;
  final Color categoryColor;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final String? originalReporter;
  final String? photoUrl;
  final List<String> otherReporters;
  final int? reporterCount;
  final VoidCallback? onViewReporters;
  final bool isPublicBarangay;
  final String? timeAgo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(12);

    final cleanReporter = (originalReporter ?? '').trim();
    final hasRealPosterName =
        cleanReporter.isNotEmpty && cleanReporter.toLowerCase() != 'resident';
    final hasPosterIdentity = hasRealPosterName;

    final buffer = StringBuffer('$title, $category, $statusLabel');
    if (isPublicBarangay && hasPosterIdentity) {
      buffer.write(', Originally reported by $cleanReporter');
    }
    if (isPublicBarangay && otherReporters.isNotEmpty) {
      buffer.write(', Also reported by ${otherReporters.join(", ")}');
    }
    if (isPublicBarangay && reporterCount != null) {
      buffer.write(
        reporterCount! > 1
            ? ', $reporterCount residents reported'
            : ', 1 reporter',
      );
    }
    if (!isPublicBarangay && description?.trim().isNotEmpty == true) {
      buffer.write(', ${description!.trim()}');
    }
    buffer.write('. Track activity');
    final semanticsLabel = buffer.toString();

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(
                  colors.brand.withValues(alpha: 0.12),
                  colors.surfaceAlt,
                ),
                colors.surface,
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            focusColor: colors.primaryGreen.withValues(alpha: 0.2),
            hoverColor: colors.hover.withValues(alpha: 0.5),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isPublicBarangay) ...[
                        PosterAvatar(
                          name: hasRealPosterName ? cleanReporter : 'Resident',
                          photoUrl: photoUrl,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isPublicBarangay) ...[
                              // Public Barangay Card: 3-line layout matching UI screenshot
                              // Line 1: Poster Name • Relative Time
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      hasRealPosterName
                                          ? cleanReporter
                                          : (cleanReporter.isNotEmpty
                                              ? cleanReporter
                                              : 'Resident'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if ((timeAgo ?? '').trim().isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                      ),
                                      child: Text(
                                        '•',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: colors.textSecondary
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeAgo!.trim(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Line 2: Concern Title
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Line 3: Mint pill chip [people icon] [X residents reported] [>]
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onViewReporters,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.brand.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_alt_rounded,
                                        size: 13,
                                        color: colors.primaryGreen,
                                      ),
                                      const SizedBox(width: 4.5),
                                      Flexible(
                                        child: Text(
                                          (reporterCount != null &&
                                                  reporterCount! > 1)
                                              ? '$reporterCount residents reported'
                                              : '1 resident reported',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: colors.primaryGreen,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2.5),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: colors.primaryGreen,
                                      ),
                                      if (((reporterCount ?? 0) > 1 ||
                                              otherReporters.isNotEmpty) &&
                                          onViewReporters != null)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: onViewReporters,
                                          child: const SizedBox(
                                            width: 1,
                                            height: 1,
                                            child: Text(
                                              'View Reporters',
                                              style: TextStyle(
                                                color: Colors.transparent,
                                                fontSize: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (hasPosterIdentity)
                                Opacity(
                                  opacity: 0.0,
                                  child: SizedBox(
                                    height: 0,
                                    child: Text(
                                      'Originally reported by $cleanReporter',
                                    ),
                                  ),
                                ),
                              if (otherReporters.isNotEmpty)
                                Opacity(
                                  opacity: 0.0,
                                  child: SizedBox(
                                    height: 0,
                                    child: Text(
                                      'Also reported by ${otherReporters.join(", ")}',
                                    ),
                                  ),
                                ),
                              if (reporterCount == 1)
                                const Opacity(
                                  opacity: 0.0,
                                  child: SizedBox(
                                    height: 0,
                                    child: Text('1 reporter'),
                                  ),
                                ),
                            ] else ...[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (description?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 3),
                                Text(
                                  description!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if ((timeAgo ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      '\u2022 ${timeAgo!.trim()}',
                                      maxLines: 1,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.38,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.solid(statusColor),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: colors.onAccent,
                                ),
                              ),
                            ),
                            if (!isPublicBarangay &&
                                ((reporterCount ?? 0) > 1 ||
                                    otherReporters.isNotEmpty) &&
                                onViewReporters != null) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onViewReporters,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'View Reporters',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primaryGreen,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                            ] else
                              const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.only(left: 9),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: colors.border),
                                ),
                              ),
                              child: Text(
                                'Track →',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primaryGreen,
                                ),
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
          ),
        ),
      ),
    );
  }
}

class PosterAvatar extends StatelessWidget {
  const PosterAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
  });

  final String name;
  final String? photoUrl;
  final double size;

  String get _initials {
    final clean = name.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'resident') return 'R';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildFallback(BuildContext context, dynamic colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.brandStrong,
            colors.primaryGreen,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.outfit(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
            color: colors.onAccent,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cleanPhoto = photoUrl?.trim() ?? '';
    if (cleanPhoto.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.primaryGreen.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primaryGreen.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            cleanPhoto,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallback(context, colors),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallback(context, colors);
            },
          ),
        ),
      );
    }
    return _buildFallback(context, colors);
  }
}
