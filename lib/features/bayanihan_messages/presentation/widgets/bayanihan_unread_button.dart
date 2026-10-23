import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';

import '../../../../auth_service.dart';
import '../../services/bayanihan_messaging_service.dart';
import '../pages/bayanihan_messages_page.dart';

class BayanihanUnreadButton extends StatefulWidget {
  const BayanihanUnreadButton({super.key, this.unreadStream, this.onPressed});

  final Stream<int>? unreadStream;
  final VoidCallback? onPressed;

  @override
  State<BayanihanUnreadButton> createState() => _BayanihanUnreadButtonState();
}

class _BayanihanUnreadButtonState extends State<BayanihanUnreadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUser?.uid;
    return StreamBuilder<int>(
      stream:
          widget.unreadStream ??
          (userId == null
              ? Stream.value(0)
              : BayanihanMessagingService().unreadCount(userId)),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return Semantics(
          button: true,
          label: unread == 0
              ? 'Bayanihan messages'
              : 'Bayanihan messages, $unread unread',
          child: Tooltip(
            message: 'Bayanihan messages',
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap:
                  widget.onPressed ??
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BayanihanMessagesPage(),
                    ),
                  ),
              child: AnimatedScale(
                scale: _isPressed ? 0.90 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Symmetrical 3D Glassmorphic Container matching Header Back Button
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.brand,
                              context.colors.brand,
                              context.colors.brandStrong,
                            ],
                            stops: [0.0, 0.65, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.border.withValues(alpha: 0.45,
                            ),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brandStrong.withValues(alpha: 0.40,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: context.colors.shadow.withValues(alpha: 0.20,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: const CivicChatEmblemPainter(),
                          ),
                        ),
                      ),

                      // Candy-Gloss Unread Badge
                      if (unread > 0)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 19),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.errorSolid,
                                  context.colors.errorSolid,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: context.colors.border, width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.errorSolid.withValues(alpha: 0.55,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.colors.onAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A standalone 3D Glassmorphic Civic Messaging Button that can be used
/// across any screen (Marketplace, Bayanihan, Inquiries) for consistent UI.
class CivicMessagingButton extends StatefulWidget {
  const CivicMessagingButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Messages',
    this.unreadCount = 0,
    this.size = 42,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final int unreadCount;
  final double size;

  @override
  State<CivicMessagingButton> createState() => _CivicMessagingButtonState();
}

class _CivicMessagingButtonState extends State<CivicMessagingButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.unreadCount == 0
          ? widget.tooltip
          : '${widget.tooltip}, ${widget.unreadCount} unread',
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _isPressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: widget.size + 2,
              height: widget.size + 2,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.surface.withValues(alpha: 0.22),
                          context.colors.surface.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colors.border.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadow.withValues(alpha: 0.20),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.15,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: Size(widget.size * 0.52, widget.size * 0.52),
                        painter: const CivicChatEmblemPainter(),
                      ),
                    ),
                  ),

                  // Candy-Gloss Unread Badge
                  if (widget.unreadCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 19),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.errorSolid,
                              context.colors.errorSolid,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: context.colors.border, width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.errorSolid.withValues(alpha: 0.55,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.colors.onAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pixel-crafted 3D Real Messenger Emblem with dual conversational bubbles,
/// realistic depth, specular highlights, and crisp emerald chat dots.
class CivicChatEmblemPainter extends CustomPainter {
  const CivicChatEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- 1. Background Secondary Bubble (Translucent White Glass) ---
    final bgBubbleRect = Rect.fromLTWH(w * 0.30, h * 0.05, w * 0.65, h * 0.55);
    final bgBubblePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(bgBubbleRect, Radius.circular(w * 0.22)),
      );
    final bgTail = Path()
      ..moveTo(w * 0.82, h * 0.46)
      ..lineTo(w * 0.98, h * 0.62)
      ..quadraticBezierTo(w * 0.88, h * 0.54, w * 0.70, h * 0.52)
      ..close();
    final fullBgBubble = Path.combine(PathOperation.union, bgBubblePath, bgTail,
    );

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..isAntiAlias = true;

    canvas.drawPath(fullBgBubble, bgPaint);

    // --- 2. Foreground Primary Bubble (3D Solid White with Specular Highlight) ---
    final fgRect = Rect.fromLTWH(0, h * 0.28, w * 0.76, h * 0.64);
    final fgBubblePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(fgRect, Radius.circular(w * 0.25)));

    // Primary Tail (pointing down-left)
    final fgTail = Path()
      ..moveTo(w * 0.18, h * 0.82)
      ..lineTo(w * 0.02, h * 0.98)
      ..quadraticBezierTo(w * 0.14, h * 0.90, w * 0.34, h * 0.88)
      ..close();
    final fullFgBubble = Path.combine(PathOperation.union, fgBubblePath, fgTail,
    );

    // Shadow under foreground bubble
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.save();
    canvas.translate(0, 1.2);
    canvas.drawPath(fullFgBubble, shadowPaint);
    canvas.restore();

    // Fill Primary Bubble with Pearlescent White
    final fgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Color(0xFFF0FDF4),
          Color(0xFFDCFCE7)],
      ).createShader(fgRect)
      ..isAntiAlias = true;
    canvas.drawPath(fullFgBubble, fgPaint);

    // Crisp white border
    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawPath(fullFgBubble, rimPaint);

    // 3. Three Crisp 3D Emerald Chat Dots inside Foreground Bubble
    final dotY = h * 0.58;
    final dotRadius = w * 0.05;
    final dotPaint = Paint()
      ..color = const Color(0xFF047857)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (int i = 0; i < 3; i++) {
      final dotX = w * 0.22 + (i * w * 0.16);
      canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
