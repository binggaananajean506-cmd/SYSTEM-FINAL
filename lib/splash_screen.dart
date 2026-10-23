import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/theme/semantic_colors.dart';

/// Clean, elegant, and minimal municipal splash screen for E-SUGID Barili.
///
/// Features a pristine central seal logo with gentle breathing float,
/// clean brand typography without clutter, and a clearly visible, modern
/// animated loading bar indicator.
class ESugidSplashScreen extends StatefulWidget {
  const ESugidSplashScreen({super.key});

  @override
  State<ESugidSplashScreen> createState() => _ESugidSplashScreenState();
}

class _ESugidSplashScreenState extends State<ESugidSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _logoSize = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft, serene ambient background halo centered behind logo (clean, no clutter)
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primaryGreen.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Centered Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // 1. Prestigious Seal Logo with gentle breathing animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final floatY = math.sin(_controller.value * 2 * math.pi) * 3.0;
                    return Transform.translate(
                      offset: Offset(0, floatY),
                      child: child,
                    );
                  },
                  child: Container(
                    width: _logoSize,
                    height: _logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.brandStrong.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: colors.primaryGreen.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/resident_dashboard/pinakafinal.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Clean, Simple Brand Lockup (No busy dividers, stars, or heavy badges)
                Text(
                  'E-Sugid',
                  style: GoogleFonts.outfit(
                    color: colors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BARILI, CEBU',
                  style: GoogleFonts.outfit(
                    color: colors.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                  ),
                ),

                const Spacer(flex: 2),

                // 3. Clearly Visible, Modern Loading Effect
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Smooth, glowing animated loading track
                    Container(
                      width: 160,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _VisibleLoadingRunnerPainter(
                              progress: _controller.value,
                              color: colors.primaryGreen,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Kasayuran ug serbisyo, duol kanimo.',
                      style: GoogleFonts.outfit(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Clearly visible animated loading runner painter.
class _VisibleLoadingRunnerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _VisibleLoadingRunnerPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    final pillWidth = size.width * 0.45;
    // Loops smoothly from before left edge to past right edge
    final left = (progress * (size.width + pillWidth)) - pillWidth;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color,
          const Color(0xFF34D399),
          color,
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(left, 0, pillWidth, size.height));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, pillWidth, size.height),
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _VisibleLoadingRunnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
