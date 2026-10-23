import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders a modern top app bar with an organic mint curved wave background,
/// matching the exact aesthetic of the provided design screens.
class SettingsHeaderWave extends StatelessWidget
    implements PreferredSizeWidget {
  const SettingsHeaderWave({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.trailing,
  });

  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      height: preferredSize.height + topPadding,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          // Background organic mint wave
          Positioned.fill(
            child: CustomPaint(
              painter: _MintWavePainter(colors: context.colors),
            ),
          ),

          // Safe area header content
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: preferredSize.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Back button
                  if (showBackButton)
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap:
                            onBackPressed ?? () => Navigator.maybePop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 19,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),

                  // Centered Title
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 19.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),

                  // Trailing widget or balance spacer
                  trailing != null
                      ? SizedBox(
                          width: 44,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: trailing!,
                          ),
                        )
                      : const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MintWavePainter extends CustomPainter {
  const _MintWavePainter({required this.colors});
  final ESugidColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          colors.successSurface.withValues(alpha: 0.75),
          colors.surfaceAlt.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path1 = Path();
    path1.moveTo(0, 0);
    path1.lineTo(size.width, 0);
    path1.lineTo(size.width, size.height * 0.72);
    path1.cubicTo(
      size.width * 0.75,
      size.height * 0.98,
      size.width * 0.40,
      size.height * 0.45,
      0,
      size.height * 0.68,
    );
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [colors.selected.withValues(alpha: 0.45), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path2 = Path();
    path2.moveTo(size.width * 0.35, 0);
    path2.lineTo(size.width, 0);
    path2.lineTo(size.width, size.height * 0.58);
    path2.cubicTo(
      size.width * 0.82,
      size.height * 0.85,
      size.width * 0.55,
      size.height * 0.35,
      size.width * 0.35,
      0,
    );
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _MintWavePainter oldDelegate) =>
      oldDelegate.colors != colors;
}
