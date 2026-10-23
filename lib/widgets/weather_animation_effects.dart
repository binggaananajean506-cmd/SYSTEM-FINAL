import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/barili_weather_service.dart';

/// Renders lightweight condition-based weather animations (sunny, rain, thunderstorm, etc.).
///
/// Automatically respects system accessibility settings ([MediaQuery.disableAnimationsOf]).
class WeatherAnimationWidget extends StatefulWidget {
  final WeatherAnimationType type;
  final bool isDay;
  final bool isCompact;

  const WeatherAnimationWidget({
    super.key,
    required this.type,
    this.isDay = true,
    this.isCompact = false,
  });

  @override
  State<WeatherAnimationWidget> createState() => _WeatherAnimationWidgetState();
}

class _WeatherAnimationWidgetState extends State<WeatherAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == WeatherAnimationType.none) {
      return const SizedBox.shrink();
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WeatherPainter(
              type: widget.type,
              isDay: widget.isDay,
              isCompact: widget.isCompact,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final WeatherAnimationType type;
  final bool isDay;
  final bool isCompact;
  final double progress;

  _WeatherPainter({
    required this.type,
    required this.isDay,
    required this.isCompact,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    switch (type) {
      case WeatherAnimationType.sunny:
        _paintSunny(canvas, size);
        break;
      case WeatherAnimationType.cloudy:
        _paintCloudy(canvas, size);
        break;
      case WeatherAnimationType.lightRain:
        _paintRain(canvas, size, heavy: false);
        break;
      case WeatherAnimationType.heavyRain:
        _paintRain(canvas, size, heavy: true);
        break;
      case WeatherAnimationType.thunderstorm:
        _paintThunderstorm(canvas, size);
        break;
      case WeatherAnimationType.fog:
        _paintFog(canvas, size);
        break;
      case WeatherAnimationType.none:
        break;
    }
  }

  void _paintSunny(Canvas canvas, Size size) {
    final center = isCompact
        ? Offset(size.width * 0.85, size.height * 0.5)
        : Offset(size.width * 0.80, size.height * 0.22);
    final baseRadius = isCompact ? 22.0 : (size.width * 0.35);
    final pulse = 1.0 + 0.05 * math.sin(progress * 2 * math.pi);

    // Realistic atmospheric luminous diffusion
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isDay ? const Color(0xFFFFE08A) : const Color(0xFFE2E8F0))
              .withValues(alpha: isCompact ? 0.30 : 0.40),
          (isDay ? const Color(0xFFF59E0B) : const Color(0xFF818CF8))
              .withValues(alpha: isCompact ? 0.12 : 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * pulse));

    canvas.drawCircle(center, baseRadius * pulse, glowPaint);

    // Subtle golden sunrays
    if (!isCompact && isDay) {
      final rayPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFBEB).withValues(alpha: 0.25),
            const Color(0xFFFDE047).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      const rayCount = 10;
      final rayRotation = progress * 2 * math.pi * 0.06;
      for (int i = 0; i < rayCount; i++) {
        final angle = (i * 2 * math.pi / rayCount) + rayRotation;
        final start = center + Offset(math.cos(angle) * (baseRadius * 0.6), math.sin(angle) * (baseRadius * 0.6));
        final end = center + Offset(math.cos(angle) * (baseRadius * 1.25), math.sin(angle) * (baseRadius * 1.25));
        canvas.drawLine(start, end, rayPaint);
      }
    }
  }

  void _paintCloudy(Canvas canvas, Size size) {
    // Realistic organic volumetric clouds with radial gradient falloff instead of flat solid circles
    final count = isCompact ? 2 : 4;
    for (int i = 0; i < count; i++) {
      final speed = 0.025 + (i * 0.015);
      final xOffset = ((progress * speed + (i * 0.32)) % 1.0) * (size.width + 160) - 80;
      final yPos = size.height * (0.15 + (i * 0.20));
      final radius = (isCompact ? 16.0 : 48.0) * (1.0 + (i * 0.12));
      final center = Offset(xOffset, yPos);

      // Soft diffuse cloud shader with soft Gaussian falloff
      final cloudShader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: isCompact ? 0.18 : 0.22),
          Colors.white.withValues(alpha: isCompact ? 0.08 : 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.4));

      final paint = Paint()..shader = cloudShader;
      canvas.drawCircle(center, radius * 1.35, paint);

      // Secondary puff
      final puff2Center = center + Offset(radius * 0.75, radius * 0.15);
      final puff2Shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: isCompact ? 0.14 : 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: puff2Center, radius: radius * 0.95));
      canvas.drawCircle(puff2Center, radius * 0.95, Paint()..shader = puff2Shader);
    }
  }

  void _paintRain(Canvas canvas, Size size, {required bool heavy}) {
    final dropPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isDay ? const Color(0xFFBAE6FD) : const Color(0xFFC7D2FE)).withValues(alpha: 0.2),
          (isDay ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: heavy ? 0.65 : 0.45),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = isCompact ? 1.2 : (heavy ? 2.2 : 1.6)
      ..strokeCap = StrokeCap.round;

    final dropCount = isCompact ? (heavy ? 16 : 10) : (heavy ? 54 : 32);
    final fallSpeed = heavy ? 3.8 : 2.5;
    final slant = heavy ? 0.25 : 0.15;

    for (int i = 0; i < dropCount; i++) {
      final seedX = (math.sin(i * 997.0) * 0.5 + 0.5);
      final seedY = (math.cos(i * 613.0) * 0.5 + 0.5);
      final length = (isCompact ? 8.0 : 16.0) * (0.85 + (seedX * 0.3));

      final currentY = ((seedY + progress * fallSpeed) % 1.0) * (size.height + 30) - 15;
      final currentX = (seedX * size.width + (currentY * slant)) % size.width;

      final start = Offset(currentX, currentY);
      final end = Offset(currentX + (length * slant), currentY + length);

      canvas.drawLine(start, end, dropPaint);
    }
  }

  void _paintThunderstorm(Canvas canvas, Size size) {
    // 1. Heavy rainfall
    _paintRain(canvas, size, heavy: true);

    // 2. Realistic subtle sheet lightning flash
    final flash1 = progress >= 0.28 && progress <= 0.31;
    final flash2 = progress >= 0.72 && progress <= 0.74;
    if (flash1 || flash2) {
      final intensity = flash1
          ? math.sin((progress - 0.28) / 0.03 * math.pi)
          : math.sin((progress - 0.72) / 0.02 * math.pi);

      final flashPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -0.4),
          radius: 1.2,
          colors: [
            const Color(0xFFF8FAFC).withValues(alpha: 0.35 * intensity.clamp(0.0, 1.0)),
            const Color(0xFF818CF8).withValues(alpha: 0.15 * intensity.clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    final mistPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: isCompact ? 0.20 : 0.25),
          Colors.transparent,
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.5));

    final waveOffset = math.sin(progress * 2 * math.pi) * (isCompact ? 8.0 : 25.0);
    final rect1 = Rect.fromLTWH(-30 + waveOffset, size.height * 0.25, size.width + 60, size.height * 0.35);
    final rect2 = Rect.fromLTWH(-30 - waveOffset, size.height * 0.55, size.width + 60, size.height * 0.35);

    canvas.drawOval(rect1, mistPaint);
    canvas.drawOval(rect2, mistPaint);
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.type != type ||
        oldDelegate.isDay != isDay ||
        oldDelegate.isCompact != isCompact;
  }
}
