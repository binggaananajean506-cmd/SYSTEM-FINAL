import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  final bool showLogo;
  final bool showBackButton;
  final bool useFrostedPanel;
  final bool centeredGlassCard;
  final double logoSize;

  const AuthBackground({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
    this.showLogo = false,
    this.showBackButton = false,
    this.useFrostedPanel = false,
    this.centeredGlassCard = false,
    this.logoSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    if (centeredGlassCard) {
      return _CenteredGlassAuthLayout(
        title: title,
        subtitle: subtitle,
        showLogo: showLogo,
        showBackButton: showBackButton,
        logoSize: logoSize,
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: context.colors.brand,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.brand,
                    context.colors.brand,
                    context.colors.brand,
                  ],
                  stops: [0, 0.6, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -105,
            right: -65,
            child: _GlowOrb(size: 255, color: context.colors.brand.withValues(alpha: 0.2000),
            ),
          ),
          Positioned(
            top: 165,
            left: -85,
            child: _GlowOrb(size: 190, color: context.colors.surface.withValues(alpha: 0.1216),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                if (showBackButton)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: context.colors.onAccent,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                if (showLogo) ...[
                  Container(
                    width: logoSize,
                    height: logoSize,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: context.colors.surface.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.32),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/resident_dashboard/pinakafinal.png',
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        semanticLabel: 'E-SUGID logo',
                        errorBuilder: (_, _, _) => Icon(
                          Icons.hub_rounded,
                          size: 42,
                          color: context.colors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: context.colors.onAccent,
                    letterSpacing: 2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: context.colors.onAccent.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: useFrostedPanel ? 20 : 32),
                Expanded(
                  child: _AuthContentPanel(
                    frosted: useFrostedPanel,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredGlassAuthLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  final bool showLogo;
  final bool showBackButton;
  final double logoSize;

  const _CenteredGlassAuthLayout({
    required this.child,
    required this.title,
    required this.subtitle,
    required this.showLogo,
    required this.showBackButton,
    required this.logoSize,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: context.colors.brandStrong,
      body: Stack(
        children: [
          // 1. Rich multi-stop civic gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.colors.brandStrong,
                    context.colors.brandStrong,
                    context.colors.brandStrong,
                    context.colors.brandStrong,
                  ],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
          ),

          // 2. Flowing organic ribbon waves matching the picture
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AuthFlowingWavesPainter()),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    14 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showBackButton)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: context.colors.onAccent,
                                  ),
                                ),
                              ),
                            if (showLogo) _buildLogo(context),
                            if (showLogo) const SizedBox(height: 14),

                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: context.colors.onAccent,
                                fontSize: 28,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                // A dark shadow in both modes: textPrimary turns
                                // near-white in dark mode and made a glow.
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  subtitle!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.onAccent.withValues(alpha: 0.88,
                                    ),
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _buildGlassCard(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Container(
      width: logoSize,
      height: logoSize,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            context.colors.warningSolid,
            context.colors.brand,
            context.colors.warningSolid,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.40),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.brandStrong,
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/resident_dashboard/pinakafinal.png',
            fit: BoxFit.cover,
            cacheWidth: 480,
            semanticLabel: 'E-SUGID logo',
            errorBuilder: (_, _, _) =>
                Icon(Icons.hub_rounded, color: context.colors.onAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        enabled: MediaQuery.viewInsetsOf(context).bottom == 0,
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colors.surface.withValues(alpha: 0.13),
                context.colors.surface.withValues(alpha: 0.06),
                context.colors.brandStrong.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.24),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthFlowingWavesPainter extends CustomPainter {
  const _AuthFlowingWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Upper-Right Organic Flowing Ribbon Wave ──────────────────────────
    final upperRightPath = Path()
      ..moveTo(w * 0.58, 0)
      ..cubicTo(
        w * 0.62,
        h * 0.07,
        w * 0.54,
        h * 0.15,
        w * 0.66,
        h * 0.23)
      ..cubicTo(
        w * 0.82,
        h * 0.33,
        w * 0.70,
        h * 0.42,
        w * 0.88,
        h * 0.50)
      ..lineTo(w, h * 0.44)
      ..lineTo(w, 0)
      ..close();

    final upperRightShader = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0x4034D399),
        Color(0x2810B981),
        Color(0x0E059669)],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(upperRightPath, Paint()..shader = upperRightShader);

    final upperRightCrest = Path()
      ..moveTo(w * 0.58, 0)
      ..cubicTo(
        w * 0.62,
        h * 0.07,
        w * 0.54,
        h * 0.15,
        w * 0.66,
        h * 0.23)
      ..cubicTo(
        w * 0.82,
        h * 0.33,
        w * 0.70,
        h * 0.42,
        w * 0.88,
        h * 0.50);

    canvas.drawPath(
      upperRightCrest,
      Paint()
        ..color = const Color(0x30A7F3D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // ── 2. Right-Side Mid Wave (flowing behind card) ───────────────────────
    final midRightPath = Path()
      ..moveTo(w, h * 0.50)
      ..cubicTo(
        w * 0.80,
        h * 0.56,
        w * 0.74,
        h * 0.66,
        w * 0.86,
        h * 0.74)
      ..lineTo(w, h * 0.76)
      ..close();

    final midRightShader = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0x3010B981),
        Color(0x10059669)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(midRightPath, Paint()..shader = midRightShader);

    // ── 3. Left-Side Organic Wave ──────────────────────────────────────────
    final leftPath = Path()
      ..moveTo(0, h * 0.64)
      ..cubicTo(
        w * 0.16,
        h * 0.70,
        w * 0.20,
        h * 0.79,
        0,
        h * 0.85)
      ..close();

    final leftShader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0x2810B981),
        Color(0x08059669)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(leftPath, Paint()..shader = leftShader);

    // ── 4. Bottom Rolling Waves (Back Layer) ───────────────────────────────
    final bottomBackPath = Path()
      ..moveTo(0, h * 0.88)
      ..cubicTo(
        w * 0.30,
        h * 0.83,
        w * 0.60,
        h * 0.91,
        w,
        h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bottomBackShader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x5013583C),
        Color(0x3C1D744F),
        Color(0x280D3D29)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(bottomBackPath, Paint()..shader = bottomBackShader);

    // ── 5. Bottom Rolling Waves (Front Layer) ──────────────────────────────
    final bottomFrontPath = Path()
      ..moveTo(0, h * 0.93)
      ..cubicTo(
        w * 0.30,
        h * 0.96,
        w * 0.66,
        h * 0.90,
        w,
        h * 0.94)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bottomFrontShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x5C196846),
        Color(0x48114E34)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(bottomFrontPath, Paint()..shader = bottomFrontShader);

    final bottomCrest = Path()
      ..moveTo(0, h * 0.93)
      ..cubicTo(
        w * 0.30,
        h * 0.96,
        w * 0.66,
        h * 0.90,
        w,
        h * 0.94);

    canvas.drawPath(
      bottomCrest,
      Paint()
        ..color = const Color(0x356EE7B7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _AuthFlowingWavesPainter oldDelegate) => false;
}



class _AuthContentPanel extends StatelessWidget {
  final Widget child;
  final bool frosted;

  const _AuthContentPanel({required this.child, required this.frosted});

  static const BorderRadius _radius = BorderRadius.vertical(
    top: Radius.circular(34),
  );

  @override
  Widget build(BuildContext context) {
    final shadows = [
      BoxShadow(
        color: context.colors.shadow.withValues(alpha: 0.14),
        blurRadius: 30,
        offset: const Offset(0, -5),
      ),
    ];

    if (!frosted) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: _radius, boxShadow: shadows),
        child: ClipRRect(
          key: const ValueKey('auth-content-clip'),
          borderRadius: _radius,
          child: ColoredBox(color: context.colors.surface, child: child),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: _radius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          enabled: MediaQuery.viewInsetsOf(context).bottom == 0,
          filter: ImageFilter.blur(sigmaX: 19, sigmaY: 19),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.surface.withValues(alpha: 0.58),
                  context.colors.surfaceAlt.withValues(alpha: 0.42),
                  context.colors.surfaceAlt.withValues(alpha: 0.34),
                ],
                stops: const [0, 0.58, 1],
              ),
              border: Border(
                top: BorderSide(
                  color: context.colors.border.withValues(alpha: 0.72),
                  width: 1.2,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 105,
                  right: -74,
                  child: _GlassOrb(
                    size: 190,
                    color: context.colors.brand.withValues(alpha: 0.18),
                  ),
                ),
                Positioned(
                  bottom: -90,
                  left: -75,
                  child: _GlassOrb(
                    size: 225,
                    color: context.colors.brand.withValues(alpha: 0.15),
                  ),
                ),
                Positioned.fill(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: context.colors.border.withValues(alpha: 0.24),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
