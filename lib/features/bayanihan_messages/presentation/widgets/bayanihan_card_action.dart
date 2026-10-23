import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/semantic_colors.dart';
import '../../../../app_motion.dart';
import '../../../../widgets/adaptive_action_content.dart';

enum BayanihanActionTone { brand, info, warning, closed }

/// Shared request/activity card action, with foregrounds paired to its fill.
class BayanihanCardAction extends StatelessWidget {
  const BayanihanCardAction({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final BayanihanActionTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final closed = tone == BayanihanActionTone.closed;
    final fills = switch (tone) {
      BayanihanActionTone.brand => [
        colors.brand,
        colors.brand,
        colors.brandStrong,
      ],
      BayanihanActionTone.info => [colors.infoSolid, colors.infoSolid],
      BayanihanActionTone.warning => [colors.warningSolid, colors.errorSolid],
      BayanihanActionTone.closed => [
        colors.disabledBackground,
        colors.disabledBackground,
      ],
    };
    final foreground = closed ? colors.disabled : colors.onAccent;
    return ESugidPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: fills,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.border.withValues(alpha: closed ? 0.2392 : 0.90),
            width: 1.5,
          ),
          boxShadow: closed
              ? null
              : [
                  BoxShadow(
                    color: fills.last.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: colors.highlight.withValues(alpha: 0.3843),
                    blurRadius: 0,
                    offset: const Offset(0, -1.8),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (!closed)
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1.6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.surface.withValues(alpha: 0),
                          colors.surface.withValues(alpha: 0.95),
                          colors.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: AdaptiveActionLabel(
                  label: label.toUpperCase(),
                  icon: icon,
                  iconSize: 19,
                  trailingIcon: true,
                  style: GoogleFonts.outfit(
                    color: foreground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
