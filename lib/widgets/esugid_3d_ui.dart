import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app_motion.dart';

/// Centralized 3D UI components for the E-SUGID "Emerald Spine" aesthetic.
class EmeraldSpine extends StatelessWidget {
  final Color color;
  final double width;

  const EmeraldSpine({
    super.key,
    this.color = ESugidPalette.emerald,
    this.width = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.8),
            color,
            color.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(2, 0),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // High-End Glassy Refraction Highlight
          Positioned(
            left: 0,
            right: 4,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    context.colors.surface.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom Depth Shadow
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    context.colors.shadow.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AmbientAura extends StatelessWidget {
  final Color color;
  final double height;

  const AmbientAura({
    super.key,
    this.color = ESugidPalette.emerald,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
    );
  }
}

class ESugid3DCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool showSpine;

  const ESugid3DCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor = ESugidPalette.emerald,
    this.showSpine = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = context.colors.surface;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 10,
          right: 10,
          bottom: -2,
          child: AmbientAura(color: accentColor),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: surface,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [context.colors.surface, context.colors.surface]
                      : [
                          context.colors.surface,
                          context.colors.surface,
                          context.colors.surfaceAlt,
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.colors
                      .accent(accentColor)
                      .withValues(alpha: 0.15),
                  width: 1.2,
                ),
                boxShadow: ESugidClay.raisedShadows(
                  tint: accentColor,
                  dark: isDark,
                  depth: 0.72,
                ),
              ),
              child: Stack(
                children: [
                  if (showSpine)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: EmeraldSpine(color: accentColor),
                    ),
                  Padding(
                    padding: EdgeInsets.only(left: showSpine ? 8 : 0),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ESugid3DActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool isLoading;
  final double height;
  final double fontSize;
  final IconData? icon;

  const ESugid3DActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = ESugidPalette.emerald,
    this.isLoading = false,
    this.height = 62,
    this.fontSize = 15,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ESugidPressable(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.85)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.4),
              blurRadius: 0,
              offset: const Offset(0, -3),
            ),
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.2),
              blurRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: context.colors.surface,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: context.colors.onAccent, size: fontSize + 4,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: context.colors.onAccent,
                        fontSize:
                            15, // Using a fallback for outfit if needed, but outfit is in GoogleFonts
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'Outfit',
                        shadows: [
                          Shadow(
                            color: context.colors.textPrimary,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
