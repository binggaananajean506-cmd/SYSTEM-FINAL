import 'package:flutter/material.dart';

/// Keeps action text at the user's chosen size, allowing the surface to grow.
class AdaptiveActionLabel extends StatelessWidget {
  const AdaptiveActionLabel({
    super.key,
    required this.label,
    required this.icon,
    required this.style,
    this.iconSize = 18,
    this.trailingIcon = false,
  });

  final String label;
  final IconData icon;
  final TextStyle style;
  final double iconSize;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final symbol = Icon(icon, color: style.color, size: iconSize);
    final text = Flexible(
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: trailingIcon
            ? [text, const SizedBox(width: 8), symbol]
            : [symbol, const SizedBox(width: 6), text],
      ),
    );
  }
}

/// Gives owner actions a full line when two columns would crowd their labels.
class AdaptiveActionPair extends StatelessWidget {
  const AdaptiveActionPair({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryFlex = 1,
  });

  final Widget primary;
  final Widget secondary;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // At large text sizes, retain the font size and move the actions apart.
      final stack =
          constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(13) > 17;
      if (stack) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 10), secondary],
        );
      }
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 10),
          Expanded(flex: secondaryFlex, child: secondary),
        ],
      );
    },
  );
}
