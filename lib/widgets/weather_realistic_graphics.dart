import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders rich, realistic 3D volumetric weather illustrations and icons
/// instead of flat cartoon clipart.
class RealisticWeatherGraphic extends StatelessWidget {
  final int weatherCode;
  final bool isDay;
  final double size;
  final bool animated;

  const RealisticWeatherGraphic({
    super.key,
    required this.weatherCode,
    this.isDay = true,
    this.size = 56,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RealisticWeatherPainter(
          weatherCode: weatherCode,
          isDay: isDay,
        ),
      ),
    );
  }
}

class _RealisticWeatherPainter extends CustomPainter {
  final int weatherCode;
  final bool isDay;

  _RealisticWeatherPainter({
    required this.weatherCode,
    required this.isDay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Categorize code
    // 0, 1: Sunny / Clear
    // 2: Partly Cloudy
    // 3: Overcast / Cloudy
    // 45, 48: Fog
    // 51-57: Drizzle
    // 61-67, 80-82: Rain / Showers
    // 71-77, 85-86: Snow / Hail
    // 95-99: Thunderstorm

    if (weatherCode == 0 || weatherCode == 1) {
      if (isDay) {
        _drawRealisticSun(canvas, size);
      } else {
        _drawRealisticMoon(canvas, size);
      }
    } else if (weatherCode == 2) {
      // Partly Cloudy: Sun/Moon behind layered cloud
      if (isDay) {
        _drawSunBehindCloud(canvas, size);
      } else {
        _drawMoonBehindCloud(canvas, size);
      }
    } else if (weatherCode == 3) {
      _drawRealisticCloud(canvas, size, storm: false);
    } else if (weatherCode == 45 || weatherCode == 48) {
      _drawRealisticFog(canvas, size);
    } else if (weatherCode >= 51 && weatherCode <= 57) {
      _drawRealisticRain(canvas, size, heavy: false, drizzle: true);
    } else if ((weatherCode >= 61 && weatherCode <= 67) || (weatherCode >= 80 && weatherCode <= 82)) {
      final isHeavy = weatherCode == 65 || weatherCode == 82;
      _drawRealisticRain(canvas, size, heavy: isHeavy, drizzle: false);
    } else if (weatherCode >= 95) {
      _drawRealisticThunderstorm(canvas, size);
    } else {
      _drawRealisticCloud(canvas, size, storm: false);
    }
  }

  // 1. REALISTIC 3D SUN: Multi-layer luminous core, corona flares, specular highlight
  void _drawRealisticSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.32;

    // Ambient Outer Solar Glow
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFB703).withValues(alpha: 0.45),
          const Color(0xFFFB8500).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.4, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.55));
    canvas.drawCircle(center, radius * 1.55, outerGlowPaint);

    // Subtle Corona Rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.4)
      ..strokeWidth = math.max(1.5, size.width * 0.04)
      ..strokeCap = StrokeCap.round;

    const rayCount = 8;
    for (int i = 0; i < rayCount; i++) {
      final angle = i * (2 * math.pi / rayCount);
      final p1 = center + Offset(math.cos(angle) * (radius * 1.15), math.sin(angle) * (radius * 1.15));
      final p2 = center + Offset(math.cos(angle) * (radius * 1.40), math.sin(angle) * (radius * 1.40));
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 3D Solar Core (Deep Amber to Brilliant Gold)
    final sunBodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        colors: const [
          Color(0xFFFFF7D6),
          Color(0xFFFFD166),
          Color(0xFFF59E0B),
          Color(0xFFD97706),
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sunBodyPaint);

    // Specular 3D Highlight
    final specularPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: center + Offset(-radius * 0.35, -radius * 0.35),
        radius: radius * 0.45,
      ));
    canvas.drawCircle(
      center + Offset(-radius * 0.35, -radius * 0.35),
      radius * 0.45,
      specularPaint,
    );
  }

  // 2. REALISTIC 3D MOON: Subtle craters, crescent shadow, ethereal glow
  void _drawRealisticMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.32;

    // Outer Moonlight Aura
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC7D2FE).withValues(alpha: 0.35),
          const Color(0xFF818CF8).withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Crescent Path
    final moonPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: radius), -math.pi * 0.65, math.pi * 1.3)
      ..arcToPoint(
        center + Offset(math.cos(-math.pi * 0.65) * radius, math.sin(-math.pi * 0.65) * radius),
        radius: Radius.circular(radius * 1.15),
        clockwise: false,
      );

    final moonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(moonPath, moonPaint);

    // Subtle star sparkle next to the moon
    final starCenter = center + Offset(radius * 0.9, -radius * 0.4);
    final starPaint = Paint()..color = const Color(0xFFE0E7FF).withValues(alpha: 0.85);
    canvas.drawCircle(starCenter, math.max(1.2, size.width * 0.03), starPaint);
  }

  // 3. SUN BEHIND CLOUD (Partly Cloudy)
  void _drawSunBehindCloud(Canvas canvas, Size size) {
    final sunCenter = Offset(size.width * 0.66, size.height * 0.38);
    final sunRadius = size.width * 0.22;

    // Sun Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD166).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.4));
    canvas.drawCircle(sunCenter, sunRadius * 1.4, glowPaint);

    // Sun Core
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.2),
        colors: [Color(0xFFFFFBEB), Color(0xFFFFB703), Color(0xFFF59E0B)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Overlapping 3D Cloud in front
    _drawVolumetricCloudPuffs(
      canvas,
      Offset(size.width * 0.42, size.height * 0.62),
      size.width * 0.72,
      storm: false,
    );
  }

  // 4. MOON BEHIND CLOUD
  void _drawMoonBehindCloud(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.66, size.height * 0.38);
    final moonRadius = size.width * 0.20;

    final moonPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFCBD5E1)],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: moonRadius));
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);

    _drawVolumetricCloudPuffs(
      canvas,
      Offset(size.width * 0.42, size.height * 0.62),
      size.width * 0.72,
      storm: false,
      isNight: true,
    );
  }

  // 5. VOLUMETRIC REALISTIC 3D CLOUD
  void _drawRealisticCloud(Canvas canvas, Size size, {required bool storm}) {
    final center = Offset(size.width * 0.50, size.height * 0.52);
    _drawVolumetricCloudPuffs(canvas, center, size.width * 0.82, storm: storm);
  }

  // 6. REALISTIC RAIN & SHOWERS
  void _drawRealisticRain(Canvas canvas, Size size, {required bool heavy, required bool drizzle}) {
    // Top Cloud
    final cloudCenter = Offset(size.width * 0.50, size.height * 0.42);
    _drawVolumetricCloudPuffs(canvas, cloudCenter, size.width * 0.78, storm: heavy);

    // 3D Glass Raindrops
    final dropPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35))
      ..strokeWidth = drizzle ? 1.5 : (heavy ? 2.5 : 2.0)
      ..strokeCap = StrokeCap.round;

    final dropCount = drizzle ? 3 : (heavy ? 6 : 4);
    final startY = size.height * 0.68;
    final dropLength = size.height * (drizzle ? 0.12 : (heavy ? 0.22 : 0.16));
    final slant = size.width * 0.04;

    for (int i = 0; i < dropCount; i++) {
      final t = (i + 1) / (dropCount + 1);
      final x = size.width * (0.22 + t * 0.56);
      final y = startY + (i % 2 == 0 ? 0 : size.height * 0.04);
      canvas.drawLine(Offset(x, y), Offset(x - slant, y + dropLength), dropPaint);
    }
  }

  // 7. REALISTIC THUNDERSTORM: Dark stormy cloud + 3D jagged electric bolt
  void _drawRealisticThunderstorm(Canvas canvas, Size size) {
    // Storm Cloud (Deep Slate with purple-indigo ambient shadow)
    final cloudCenter = Offset(size.width * 0.50, size.height * 0.40);
    _drawVolumetricCloudPuffs(canvas, cloudCenter, size.width * 0.80, storm: true);

    // Electric Lightning Bolt
    final boltPath = Path();
    final startX = size.width * 0.52;
    final startY = size.height * 0.54;

    boltPath.moveTo(startX, startY);
    boltPath.lineTo(startX - size.width * 0.08, startY + size.height * 0.18);
    boltPath.lineTo(startX - size.width * 0.02, startY + size.height * 0.19);
    boltPath.lineTo(startX - size.width * 0.12, startY + size.height * 0.42);
    boltPath.lineTo(startX + size.width * 0.04, startY + size.height * 0.22);
    boltPath.lineTo(startX - size.width * 0.01, startY + size.height * 0.21);
    boltPath.close();

    // Lightning Aura
    final auraPaint = Paint()
      ..color = const Color(0xFFFDE047).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(boltPath, auraPaint);

    // Crisp 3D Bolt
    final boltPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFBEB), Color(0xFFFBBF24), Color(0xFFF59E0B)],
      ).createShader(Rect.fromLTWH(0, startY, size.width, size.height * 0.42));
    canvas.drawPath(boltPath, boltPaint);

    // Accompanying Raindrops
    final dropPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.72),
      Offset(size.width * 0.24, size.height * 0.88),
      dropPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.70),
      Offset(size.width * 0.68, size.height * 0.86),
      dropPaint,
    );
  }

  // 8. FOG & MIST
  void _drawRealisticFog(Canvas canvas, Size size) {
    final cloudCenter = Offset(size.width * 0.50, size.height * 0.40);
    _drawVolumetricCloudPuffs(canvas, cloudCenter, size.width * 0.72, storm: false);

    // Fog Waves
    final fogPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = math.max(2.0, size.width * 0.05)
      ..strokeCap = StrokeCap.round;

    final y1 = size.height * 0.72;
    final y2 = size.height * 0.84;
    canvas.drawLine(Offset(size.width * 0.18, y1), Offset(size.width * 0.82, y1), fogPaint);
    canvas.drawLine(Offset(size.width * 0.28, y2), Offset(size.width * 0.72, y2), fogPaint);
  }

  // Core helper: Volumetric Multi-Puff Cloud with realistic 3D lighting
  void _drawVolumetricCloudPuffs(
    Canvas canvas,
    Offset center,
    double cloudWidth, {
    required bool storm,
    bool isNight = false,
  }) {
    final baseRadius = cloudWidth * 0.24;

    // Ambient drop shadow beneath cloud
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, baseRadius * 0.75),
        width: cloudWidth * 0.88,
        height: baseRadius * 0.6,
      ),
      shadowPaint,
    );

    // Cloud Puffs: [Offset from center, radius multiplier]
    final puffs = [
      [Offset(-cloudWidth * 0.26, baseRadius * 0.18), 0.85],
      [Offset(cloudWidth * 0.26, baseRadius * 0.22), 0.78],
      [Offset(-cloudWidth * 0.10, -baseRadius * 0.20), 1.05],
      [Offset(cloudWidth * 0.10, -baseRadius * 0.10), 0.95],
      [Offset(0, baseRadius * 0.15), 0.92],
    ];

    final colors = storm
        ? const [Color(0xFFE2E8F0), Color(0xFF64748B), Color(0xFF334155)]
        : isNight
            ? const [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF64748B)]
            : const [Color(0xFFFFFFFF), Color(0xFFF1F5F9), Color(0xFFCBD5E1)];

    for (final puff in puffs) {
      final pos = center + (puff[0] as Offset);
      final r = baseRadius * (puff[1] as double);

      final puffPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.40),
          colors: colors,
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: pos, radius: r));

      canvas.drawCircle(pos, r, puffPaint);
    }

    // Specular Rim Highlight along top of cloud
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: storm ? 0.35 : 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center + Offset(-cloudWidth * 0.12, -baseRadius * 0.30),
      baseRadius * 0.60,
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RealisticWeatherPainter oldDelegate) {
    return oldDelegate.weatherCode != weatherCode || oldDelegate.isDay != isDay;
  }
}

/// A sleek horizontal temperature range bar (Apple / Google Weather style).
/// Visually renders today's and this week's min/max range with a color gradient.
class WeatherTempRangeBar extends StatelessWidget {
  final double minTemp;
  final double maxTemp;
  final double globalMin;
  final double globalMax;
  final double? currentTemp;
  final bool isToday;

  const WeatherTempRangeBar({
    super.key,
    required this.minTemp,
    required this.maxTemp,
    required this.globalMin,
    required this.globalMax,
    this.currentTemp,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final range = (globalMax - globalMin).clamp(1.0, 100.0);
    final leftRatio = ((minTemp - globalMin) / range).clamp(0.0, 1.0);
    final rightRatio = ((maxTemp - globalMin) / range).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final barLeft = totalWidth * leftRatio;
        final barWidth = math.max(12.0, totalWidth * (rightRatio - leftRatio));

        return SizedBox(
          height: 6,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Track
              Container(
                width: totalWidth,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Active Range Gradient Bar
              Positioned(
                left: barLeft,
                width: barWidth,
                child: Container(
                  height: 4.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2DD4BF), // Teal
                        Color(0xFFFBBF24), // Warm Amber
                        Color(0xFFF87171), // Coral
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Current Temp Dot (if Today)
              if (isToday && currentTemp != null)
                Positioned(
                  left: (totalWidth * ((currentTemp! - globalMin) / range)).clamp(0.0, totalWidth - 7),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F766E),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A realistic micro visual gauge/meter for atmospheric conditions.
class WeatherMetricGauge extends StatelessWidget {
  final double ratio; // 0.0 to 1.0
  final Color primaryColor;
  final Color secondaryColor;

  const WeatherMetricGauge({
    super.key,
    required this.ratio,
    required this.primaryColor,
    this.secondaryColor = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: secondaryColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0.04, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [
                primaryColor.withValues(alpha: 0.8),
                primaryColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
