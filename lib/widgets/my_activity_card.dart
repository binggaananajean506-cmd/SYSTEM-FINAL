import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme/semantic_colors.dart';

/// Compact tracking card shared by the concern and complaint activity lists.
class MyActivityCard extends StatelessWidget {
  const MyActivityCard({
    super.key,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final String title;
  final String category;
  final Color categoryColor;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: '$title, $category, $statusLabel. Track activity',
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
                    children: [
                      const _ActivityNotebook(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.34,
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

class _ActivityNotebook extends StatelessWidget {
  const _ActivityNotebook();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primaryGreen.withValues(alpha: 0.12)),
      ),
      child: Container(
        width: 24,
        height: 30,
        decoration: BoxDecoration(
          color: colors.errorSolid,
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: colors.infoSolid, width: 6)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.bookmark_rounded,
            color: Color.lerp(colors.warning, colors.onAccent, 0.65),
            size: 12,
          ),
        ),
      ),
    );
  }
}
