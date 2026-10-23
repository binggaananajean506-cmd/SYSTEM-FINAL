import 'package:flutter/material.dart';

class NotebookWireBinding extends StatelessWidget {
  final Color? color;
  const NotebookWireBinding({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: CustomPaint(painter: _NotebookWireBindingPainter(color: color)),
    );
  }
}

class _NotebookWireBindingPainter extends CustomPainter {
  final Color? color;
  const _NotebookWireBindingPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;

    final loopCount = (size.height / 18).round().clamp(6, 12);
    const topInset = 8.0;
    final usableHeight = size.height - (topInset * 2);
    const entryX = 26.0;

    for (var index = 0; index < loopCount; index++) {
      final centerY = loopCount == 1
          ? size.height / 2
          : topInset + (usableHeight * index / (loopCount - 1));
      _paintLoop(canvas, centerY, entryX);
    }
  }

  void _paintLoop(Canvas canvas, double centerY, double entryX) {
    const wireHalfHeight = 3.2;

    final rimPaint = Paint()
      ..color = color?.withValues(alpha: 0.5) ?? const Color(0xFF8A9890)
      ..style = PaintingStyle.fill;
    final holePaint = Paint()
      ..color = const Color(0xFF0D1411)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 1.2);

    for (final y in [centerY - wireHalfHeight, centerY + wireHalfHeight]) {
      final rim = Rect.fromCenter(
        center: Offset(entryX, y),
        width: 8.5,
        height: 5.8,
      );
      final hole = Rect.fromCenter(
        center: Offset(entryX - 0.4, y + 0.3),
        width: 5.2,
        height: 3.2,
      );
      canvas.drawOval(rim, rimPaint);
      canvas.drawOval(hole, holePaint);
    }

    final wire = Path()
      ..moveTo(entryX + 1.2, centerY - wireHalfHeight)
      ..cubicTo(
        20,
        centerY - wireHalfHeight,
        12,
        centerY - 4.2,
        6.5,
        centerY - 2.8,
      )
      ..cubicTo(2.5, centerY - 1.6, 2.5, centerY + 1.6, 6.5, centerY + 2.8)
      ..cubicTo(
        12,
        centerY + 4.2,
        20,
        centerY + wireHalfHeight,
        entryX + 1.2,
        centerY + wireHalfHeight,
      );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.save();
    canvas.translate(1.5, 1.8);
    canvas.drawPath(wire, shadowPaint);
    canvas.restore();

    final wireColors = color != null
        ? [color!.withValues(alpha: 0.8), color!, color!.withValues(alpha: 0.7)]
        : [
            const Color(0xFF7A867F),
            const Color(0xFF0D1411),
            const Color(0xFF252F2A),
          ];

    final wirePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: wireColors,
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromLTWH(2, centerY - 5.5, entryX + 2, 11))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(wire, wirePaint);

    final upperHighlight = Path()
      ..moveTo(entryX - 0.2, centerY - wireHalfHeight - 0.6)
      ..cubicTo(
        20,
        centerY - wireHalfHeight - 0.6,
        12,
        centerY - 4.5,
        6.8,
        centerY - 3.0,
      );
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(upperHighlight, highlightPaint);

    final lowerShade = Path()
      ..moveTo(6.8, centerY + 3.0)
      ..cubicTo(
        12,
        centerY + 4.5,
        20,
        centerY + wireHalfHeight + 0.5,
        entryX - 0.2,
        centerY + wireHalfHeight + 0.5,
      );
    final lowerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(lowerShade, lowerPaint);
  }

  @override
  bool shouldRepaint(covariant _NotebookWireBindingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
