import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:esugid/app_motion.dart';

/// Shows a modern, beautifully styled exit confirmation modal.
/// Returns `true` if the user confirmed exit, `false` or `null` otherwise.
Future<bool?> showExitConfirmationDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss exit dialog',
    barrierColor: context.colors.shadow.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 340),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      dialogContext.colors.surface,
                      dialogContext.colors.surface,
                    ],
                  ),
                  border: Border.all(
                    color: dialogContext.colors.border,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: dialogContext.colors.shadow.withValues(alpha: isDark ? 0.6 : 0.18,
                      ),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: dialogContext.colors.brandStrong.withValues(alpha: isDark ? 0.12 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: Stack(
                    children: [
                      // Top specular highlight rim
                      Positioned(
                        top: 0,
                        left: 24,
                        right: 24,
                        height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                dialogContext.colors.surface.withValues(alpha: isDark ? 0.25 : 0.7,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Glowing Medallion Icon
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dialogContext.colors.surfaceAlt,
                                boxShadow: [
                                  BoxShadow(
                                    color: dialogContext.colors.brandStrong
                                        .withValues(alpha: isDark ? 0.2 : 0.15),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        dialogContext.colors.brand,
                                        dialogContext.colors.brand,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dialogContext.colors.brandStrong
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.logout_rounded,
                                      color: dialogContext.colors.onAccent,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Civic tag pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: dialogContext.colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: dialogContext.colors.border,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'E-SUGID BARILI',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: dialogContext.colors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title
                            Text(
                              'Exit E-SUGID?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: dialogContext.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle description
                            Text(
                              'Are you sure you want to exit the app?',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                                color: dialogContext.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Action buttons
                            Row(
                              children: [
                                // Cancel / Stay button
                                Expanded(
                                  child: ESugidPressable(
                                    onTap: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Container(
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: dialogContext.colors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: dialogContext.colors.border,
                                          width: 1.1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color:
                                              dialogContext.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Exit button
                                Expanded(
                                  child: ESugidPressable(
                                    onTap: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Container(
                                      height: 46,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            dialogContext.colors.errorSolid,
                                            dialogContext.colors.errorSolid,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: dialogContext.colors.border
                                              .withValues(alpha: 0.35),
                                          width: 1.1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: dialogContext
                                                .colors
                                                .errorSolid
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.exit_to_app_rounded,
                                            color:
                                                dialogContext.colors.onAccent,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Exit',
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  dialogContext.colors.onAccent,
                                              letterSpacing: 0.1,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
