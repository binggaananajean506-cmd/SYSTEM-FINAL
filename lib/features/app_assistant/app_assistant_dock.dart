import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Floats the assistant over the page with Messenger chat head behavior.
/// Draggable to any position on screen; snaps smoothly to the nearest edge
/// while preserving the vertical height chosen by the user.
class AppAssistantDock extends StatefulWidget {
  const AppAssistantDock({
    super.key,
    required this.child,
    required this.launcher,
    required this.bottomInset,
    this.visible = true,
    this.reserveRightCorner = false,
  });

  final Widget child;
  final Widget launcher;
  final double bottomInset;
  final bool visible;
  final bool reserveRightCorner;

  static const double targetSize = 64;
  static const double edgeSpacing = 12;

  @override
  State<AppAssistantDock> createState() => _AppAssistantDockState();
}

class _AppAssistantDockState extends State<AppAssistantDock> {
  bool _right = true;
  double? _dockedYFraction; // 0.0 (top) to 1.0 (bottom)
  Offset? _dragPosition;

  @override
  void didUpdateWidget(AppAssistantDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _dragPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safePadding = MediaQuery.viewPaddingOf(context);
        final minX = safePadding.left + AppAssistantDock.edgeSpacing;
        final maxX = math.max(
          minX,
          constraints.maxWidth -
              safePadding.right -
              AppAssistantDock.edgeSpacing -
              AppAssistantDock.targetSize,
        );
        final maxY = math.max(
          0.0,
          constraints.maxHeight -
              widget.bottomInset -
              AppAssistantDock.targetSize -
              8,
        );
        final minY = math.min(safePadding.top + 8, maxY);

        Offset clamp(Offset value) =>
            Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));

        // Default resting position: bottom-right (or bottom-left if reserved)
        final restingY = minY + (_dockedYFraction ?? 1.0) * (maxY - minY);
        final restingX = (_right && !widget.reserveRightCorner) ? maxX : minX;
        final resting = Offset(restingX, restingY);

        final position = _dragPosition == null
            ? resting
            : clamp(_dragPosition!);

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (widget.visible)
              AnimatedPositioned(
                duration: _dragPosition == null
                    ? const Duration(milliseconds: 260)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                left: position.dx,
                top: position.dy,
                width: AppAssistantDock.targetSize,
                height: AppAssistantDock.targetSize,
                child: GestureDetector(
                  key: const ValueKey('assistant-drag-target'),
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (_) => setState(() => _dragPosition = position),
                  onPanUpdate: (details) => setState(() {
                    _dragPosition = clamp(
                      (_dragPosition ?? position) + details.delta,
                    );
                  }),
                  onPanEnd: (_) => setState(() {
                    final current = _dragPosition ?? position;
                    // Messenger Chat Head snap: snaps to nearest edge horizontally
                    _right = !widget.reserveRightCorner &&
                        (current.dx + AppAssistantDock.targetSize / 2 >=
                            constraints.maxWidth / 2);
                    // Retain vertical position where the user dropped it
                    _dockedYFraction = (maxY > minY)
                        ? ((current.dy - minY) / (maxY - minY)).clamp(0.0, 1.0)
                        : 1.0;
                    _dragPosition = null;
                  }),
                  onPanCancel: () => setState(() => _dragPosition = null),
                  child: widget.launcher,
                ),
              ),
          ],
        );
      },
    );
  }
}
