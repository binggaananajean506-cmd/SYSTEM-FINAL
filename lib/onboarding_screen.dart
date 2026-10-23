import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;
  bool _isFinishing = false;

  static const _pages = [
    _OnboardingData(
      tagline: 'Kasayuran nga klaro ug kasaligan.',
      description: 'Verified nga pahibalo, makita sa usa ka lugar.',
      imagePath: 'assets/images/onboarding/verified-information.png',
      illustration: _IllustrationType.verifiedInformation,
    ),
    _OnboardingData(
      tagline: 'Ang matag barangay, konektado.',
      description: 'Balita para sa imong barangay ug tibuok Barili.',
      imagePath: 'assets/images/onboarding/connected-community.png',
      illustration: _IllustrationType.connectedCommunity,
    ),
    _OnboardingData(
      tagline: 'Serbisyo sa komunidad, duol kanimo.',
      description: 'Alerts, concerns, ug serbisyo nga sayon ma-access.',
      imagePath: 'assets/images/onboarding/community-services.png',
      illustration: _IllustrationType.communityServices,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_pageIndex == _pages.length - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.onComplete();
    if (mounted) setState(() => _isFinishing = false);
  }

  Future<void> _skip() async {
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _pageIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.background,
                    context.colors.background,
                    context.colors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -85,
            right: -75,
            child: _BackgroundOrb(
              size: 250,
              color: context.colors.brand.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            bottom: 90,
            left: -110,
            child: _BackgroundOrb(
              size: 270,
              color: context.colors.brand.withValues(alpha: 0.14),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 12, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.16,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/resident_dashboard/pinakafinal.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'E-SUGID',
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      if (!isLastPage)
                        TextButton(
                          onPressed: _isFinishing ? null : _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemBuilder: (_, index) => _OnboardingPage(
                      data: _pages[index],
                      pageNumber: index + 1,
                    ),
                  ),
                ),
                _BottomControls(
                  pageIndex: _pageIndex,
                  pageCount: _pages.length,
                  isBusy: _isFinishing,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final int pageNumber;

  const _OnboardingPage({required this.data, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(29),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Semantics(
                        image: true,
                        label: data.tagline,
                        child: Image.asset(
                          data.imagePath,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          cacheWidth: 1200,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(18),
                            child: CustomPaint(
                              painter: _CommunityVectorPainter(
                                data.illustration,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Text(
                            '$pageNumber / 3',
                            style: GoogleFonts.outfit(
                              color: context.colors.primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 21),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface,
                        context.colors.surfaceAlt,
                      ],
                    ),
                    border: Border(top: BorderSide(color: context.colors.border),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.tagline,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 23,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        data.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final int pageIndex;
  final int pageCount;
  final bool isBusy;
  final VoidCallback onNext;

  const _BottomControls({
    required this.pageIndex,
    required this.pageCount,
    required this.isBusy,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = pageIndex == pageCount - 1;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            17,
            20,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.82),
            border: Border(
              top: BorderSide(color: context.colors.border.withValues(alpha: 0.90),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pageCount,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: index == pageIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == pageIndex
                          ? context.colors.brand
                          : context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: ValueKey(isLast ? 'get-started-button' : 'next-button'),
                  onPressed: isBusy ? null : onNext,
                  style: FilledButton.styleFrom(
                    foregroundColor: context.colors.onAccent,

                    backgroundColor: context.colors.brand,
                    disabledBackgroundColor: context.colors.disabledBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isBusy
                      ? SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(strokeWidth: 2.3),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Sugdi' : 'Sunod',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
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

enum _IllustrationType {
  verifiedInformation,
  connectedCommunity,
  communityServices,
}

class _CommunityVectorPainter extends CustomPainter {
  final _IllustrationType type;

  const _CommunityVectorPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final dark = Paint()..color = const Color(0xFF14543D);
    final green = Paint()..color = const Color(0xFF2C8B63);
    final mint = Paint()..color = const Color(0xFFBDE8CE);
    final white = Paint()..color = const Color(0xFFF8FFFA);
    final gold = Paint()..color = const Color(0xFFF2C96D);
    final line = Paint()
      ..color = const Color(0xFF79C69A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale * 0.018
      ..strokeCap = StrokeCap.round;

    final canvasBounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(scale * 0.06),
    );
    canvas.drawRRect(canvasBounds, Paint()..color = const Color(0xFFF8FFF7));

    final topWave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.29)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.45,
        size.width * 0.42,
        size.height * 0.16,
        0,
        size.height * 0.38,
      )
      ..close();
    canvas.drawPath(topWave, Paint()..color = const Color(0xFF69C95B));

    final highlightWave = Path()
      ..moveTo(size.width * 0.58, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.30,
        size.width * 0.58,
        0,
      )
      ..close();
    canvas.drawPath(highlightWave, Paint()..color = const Color(0xFF8CDD73));

    canvas.drawCircle(
      center,
      scale * 0.40,
      mint..color = const Color(0xFFE2F6E6),
    );
    canvas.drawCircle(
      center.translate(scale * 0.22, -scale * 0.25),
      scale * 0.13,
      mint..color = const Color(0xFFBFE5CE),
    );

    switch (type) {
      case _IllustrationType.verifiedInformation:
        _drawPhone(canvas, center, scale, dark, white, green, gold, line);
        break;
      case _IllustrationType.connectedCommunity:
        _drawCommunity(canvas, center, scale, dark, white, green, gold, line);
        break;
      case _IllustrationType.communityServices:
        _drawServices(canvas, center, scale, dark, white, green, gold, line);
        break;
    }
  }

  void _drawPhone(
    Canvas canvas,
    Offset center,
    double scale,
    Paint dark,
    Paint white,
    Paint green,
    Paint gold,
    Paint line,
  ) {
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: scale * 0.43,
        height: scale * 0.68,
      ),
      Radius.circular(scale * 0.07),
    );
    canvas.drawRRect(phone, dark);
    final screen = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -scale * 0.01),
        width: scale * 0.35,
        height: scale * 0.56,
      ),
      Radius.circular(scale * 0.045),
    );
    canvas.drawRRect(screen, white);
    canvas.drawCircle(center.translate(0, -scale * 0.10), scale * 0.095, green);
    final check = Path()
      ..moveTo(center.dx - scale * 0.045, center.dy - scale * 0.10)
      ..lineTo(center.dx - scale * 0.012, center.dy - scale * 0.065)
      ..lineTo(center.dx + scale * 0.055, center.dy - scale * 0.14);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.025
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center.dx - scale * 0.12,
            center.dy + scale * (0.04 + i * 0.07),
            scale * (i == 2 ? 0.15 : 0.24),
            scale * 0.025,
          ),
          Radius.circular(scale * 0.02),
        ),
        i == 0 ? gold : green,
      );
    }
    canvas.drawCircle(center.translate(-scale * 0.31, 0), scale * 0.045, green);
    canvas.drawCircle(center.translate(scale * 0.31, 0), scale * 0.045, green);
    canvas.drawLine(
      center.translate(-scale * 0.27, 0),
      center.translate(-scale * 0.22, 0),
      line,
    );
    canvas.drawLine(
      center.translate(scale * 0.22, 0),
      center.translate(scale * 0.27, 0),
      line,
    );
  }

  void _drawCommunity(
    Canvas canvas,
    Offset center,
    double scale,
    Paint dark,
    Paint white,
    Paint green,
    Paint gold,
    Paint line,
  ) {
    final nodes = [
      center.translate(0, -scale * 0.26),
      center.translate(-scale * 0.29, scale * 0.20),
      center.translate(scale * 0.29, scale * 0.20),
    ];
    for (final node in nodes) {
      canvas.drawLine(center, node, line);
    }
    canvas.drawCircle(center, scale * 0.15, dark);
    _drawPerson(canvas, center, scale * 1.05, white, gold);
    for (final node in nodes) {
      canvas.drawCircle(node, scale * 0.105, white);
      _drawPerson(canvas, node, scale * 0.72, green, dark);
    }
    canvas.drawCircle(
      center,
      scale * 0.19,
      Paint()
        ..color = const Color(0xFF2C8B63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.018,
    );
  }

  void _drawServices(
    Canvas canvas,
    Offset center,
    double scale,
    Paint dark,
    Paint white,
    Paint green,
    Paint gold,
    Paint line,
  ) {
    canvas.drawCircle(center, scale * 0.20, dark);
    final shield = Path()
      ..moveTo(center.dx, center.dy - scale * 0.13)
      ..lineTo(center.dx + scale * 0.12, center.dy - scale * 0.07)
      ..lineTo(center.dx + scale * 0.09, center.dy + scale * 0.08)
      ..quadraticBezierTo(
        center.dx,
        center.dy + scale * 0.17,
        center.dx - scale * 0.09,
        center.dy + scale * 0.08,
      )
      ..lineTo(center.dx - scale * 0.12, center.dy - scale * 0.07)
      ..close();
    canvas.drawPath(shield, white);
    canvas.drawCircle(center, scale * 0.035, gold);
    final items = [
      (
        center.translate(-scale * 0.30, -scale * 0.18),
        Icons.notifications_none_rounded,
      ),
      (
        center.translate(scale * 0.30, -scale * 0.18),
        Icons.description_outlined,
      ),
      (
        center.translate(-scale * 0.30, scale * 0.22),
        Icons.work_outline_rounded,
      ),
      (center.translate(scale * 0.30, scale * 0.22), Icons.storefront_outlined),
    ];
    for (final item in items) {
      canvas.drawLine(center, item.$1, line);
      canvas.drawCircle(item.$1, scale * 0.105, white);
      _drawIcon(canvas, item.$2, item.$1, scale * 0.11, green.color);
    }
  }

  void _drawPerson(
    Canvas canvas,
    Offset center,
    double scale,
    Paint body,
    Paint head,
  ) {
    canvas.drawCircle(center.translate(0, -scale * 0.045), scale * 0.035, head);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, scale * 0.035),
          width: scale * 0.105,
          height: scale * 0.075,
        ),
        Radius.circular(scale * 0.04),
      ),
      body,
    );
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CommunityVectorPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _hasConsent = false;

  void _showDocument(BuildContext context, LegalDocument document) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalDocumentPage(document: document)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.brandStrong,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('consent-back-button'),
                      tooltip: 'Back to introduction',
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.policy_outlined,
                        color: context.colors.primaryGreen,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Terms & Privacy',
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  children: [
                    Text(
                      'E-SUGID uses the following information only to provide its community services:',
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 17),
                    const _PermissionItem(
                      icon: Icons.person_outline_rounded,
                      title: 'ACCOUNT INFORMATION',
                      body:
                          'Your name, Gmail, barangay, contact details, and account role are used to create and manage your account.',
                    ),
                    const _PermissionItem(
                      icon: Icons.photo_camera_outlined,
                      title: 'CAMERA & PHOTOS',
                      body:
                          'Only photos you capture or select are used for concerns, announcements, listings, and verification.',
                    ),
                    const _PermissionItem(
                      icon: Icons.description_outlined,
                      title: 'DOCUMENTS',
                      body:
                          'Verification files are reviewed only by authorized personnel for account approval.',
                    ),
                    const _PermissionItem(
                      icon: Icons.route_outlined,
                      title: 'COMMUNITY SUBMISSIONS',
                      body:
                          'Alerts and concerns may be sent to the barangay, office, or organization responsible for responding.',
                    ),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'E-SUGID does not access your entire gallery or files. You choose what to upload.',
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _showDocument(context, LegalDocument.terms),
                          child: const Text('Read Terms'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _showDocument(context, LegalDocument.privacy),
                          child: const Text('Privacy Policy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  MediaQuery.paddingOf(context).bottom + 18,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          key: const ValueKey('consent-checkbox'),
                          value: _hasConsent,
                          onChanged: (value) =>
                              setState(() => _hasConsent = value ?? false),
                          activeColor: context.colors.brand,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'I have read and agree to the E-SUGID Terms and Privacy Policy.',
                            style: GoogleFonts.outfit(
                              color: context.colors.textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey('consent-continue-button'),
                        onPressed: _hasConsent
                            ? () => Navigator.pop(context, true)
                            : null,
                        style: FilledButton.styleFrom(
                          foregroundColor: context.colors.onAccent,

                          backgroundColor: context.colors.brand,
                          disabledBackgroundColor:
                              context.colors.disabledBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
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

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.colors.primaryGreen, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
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

enum LegalDocument { terms, privacy, cookies }

class LegalDocumentPage extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentPage({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final (title, sections) = switch (document) {
      LegalDocument.terms => ('Terms and Conditions', _termsSections),
      LegalDocument.privacy => ('Privacy Policy', _privacySections),
      LegalDocument.cookies => ('Cookies Policy', _cookiesSections),
    };

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.colors.surfaceAlt,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Effective July 29, 2026',
            style: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    section.body,
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _OnboardingData {
  final String tagline;
  final String description;
  final String imagePath;
  final _IllustrationType illustration;

  const _OnboardingData({
    required this.tagline,
    required this.description,
    required this.imagePath,
    required this.illustration,
  });
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection(this.title, this.body);
}

const _termsSections = [
  _LegalSection(
    '1. Responsible use',
    'Use E-SUGID for lawful community communication. Do not submit false emergencies, misleading announcements, harassment, or content that may harm another person.',
  ),
  _LegalSection(
    '2. Account information',
    'Provide accurate registration details and protect your password. Barangay officials and partner organizations may be asked for documents before receiving verified privileges.',
  ),
  _LegalSection(
    '3. Information and emergencies',
    'Announcements are provided by their identified source. E-SUGID supports communication but does not replace emergency responders. For immediate danger, call the appropriate emergency hotline.',
  ),
  _LegalSection(
    '4. Community submissions',
    'Concerns, alerts, job posts, market listings, and uploaded files may be reviewed or routed to the relevant office or organization. Inappropriate or fraudulent submissions may be removed.',
  ),
  _LegalSection(
    '5. Availability and changes',
    'Features may be updated, interrupted, or changed to improve security and service. Material changes to these terms should require a new agreement version.',
  ),
];

const _privacySections = [
  _LegalSection(
    '1. Information collected',
    'E-SUGID may collect registration details, barangay, contact information, account role, concerns, alerts, posts, verification documents, and files you choose to upload.',
  ),
  _LegalSection(
    '2. How information is used',
    'Information is used to operate accounts, deliver relevant announcements, verify authorized organizations, route community requests, prevent misuse, and improve the service.',
  ),
  _LegalSection(
    '3. When information is shared',
    'A concern or alert may be shared with the barangay, municipal office, emergency agency, or partner organization selected or required to respond. Information is not intended for unrelated advertising.',
  ),
  _LegalSection(
    '4. Storage and protection',
    'Reasonable technical and administrative safeguards should protect stored information. No digital service can guarantee absolute security, so users should avoid unnecessary sensitive details.',
  ),
  _LegalSection(
    '5. Your choices',
    'Users may request help correcting account information or ask the system administrator about access and deletion options, subject to legal and official-record requirements.',
  ),
];

const _cookiesSections = [
  _LegalSection(
    '1. Mobile application storage',
    'E-SUGID does not use advertising cookies inside the mobile application. It may store essential local settings, such as whether onboarding has been completed and your selected app preferences.',
  ),
  _LegalSection(
    '2. Authentication sessions',
    'Firebase and Google authentication may use secure tokens or equivalent session technologies to keep an authorized account signed in and protect access to the service.',
  ),
  _LegalSection(
    '3. External pages',
    'If E-SUGID opens an external website, that website may use its own cookies. Its separate cookie and privacy policies apply while you use that website.',
  ),
  _LegalSection(
    '4. Your control',
    'You may remove locally stored application data through your device settings. Doing so can sign you out and cause the first-launch introduction to appear again.',
  ),
];
