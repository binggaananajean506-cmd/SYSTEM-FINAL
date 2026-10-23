import 'dart:async';

import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app_motion.dart';
import '../../auth_service.dart';
import 'app_assistant_dock.dart';
import 'app_assistant_service.dart';

/// Compact, resting launcher. The assistant expands only when opened.
class AppAssistantLauncher extends StatefulWidget {
  const AppAssistantLauncher({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  final User user;
  final ValueChanged<AssistantNavigationAction> onNavigate;

  @override
  State<AppAssistantLauncher> createState() => _AppAssistantLauncherState();
}

class _AppAssistantLauncherState extends State<AppAssistantLauncher> {
  Timer? _idleTimer;
  bool _idle = true;
  bool _focused = false;
  bool _hovered = false;
  bool _open = false;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _openAssistant() async {
    if (_open) return;
    _idleTimer?.cancel();
    setState(() {
      _open = true;
      _idle = false;
    });
    HapticFeedback.selectionClick();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: context.colors.shadow.withValues(alpha: 0.58),
        builder: (_) => AppAssistantSheet(
          user: widget.user,
          onNavigate: widget.onNavigate,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _open = false);
        _idleTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _idle = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: 'E-SUGID Assistant · Drag to move',
      child: Semantics(
        button: true,
        label: 'Open E-SUGID AI Assistant',
        child: SizedBox.square(
          dimension: AppAssistantDock.targetSize,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openAssistant,
              onFocusChange: (value) => setState(() => _focused = value),
              onHover: (value) => setState(() => _hovered = value),
              focusColor: colors.primaryGreen.withValues(alpha: 0.25),
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _idle && !_focused && !_hovered ? 0.96 : 1,
                  child: AnimatedContainer(
                    key: const ValueKey('assistant-floating-icon'),
                    duration: const Duration(milliseconds: 200),
                    width: _idle ? 56 : 60,
                    height: _idle ? 56 : 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [colors.brandAlt, colors.brandStrong],
                      ),
                      border: Border.all(
                        color: _focused
                            ? colors.primaryGreen
                            : colors.warning.withValues(alpha: 0.65),
                        width: _focused ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: colors.primaryGreen.withValues(alpha: 0.12),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/resident_dashboard/pinakafinal_backup.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified, Classy "One-Page" 3D AI Assistant modal interface.
class AppAssistantSheet extends StatefulWidget {
  const AppAssistantSheet({
    super.key,
    required this.user,
    required this.onNavigate,
    this.service,
  });

  final User user;
  final ValueChanged<AssistantNavigationAction> onNavigate;
  final AppAssistantService? service;

  @override
  State<AppAssistantSheet> createState() => _AppAssistantSheetState();
}

class _AppAssistantSheetState extends State<AppAssistantSheet> {
  late final AppAssistantService _service;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<AssistantMessage> _messages = [
    const AssistantMessage(
      text:
          'Maayong adlaw! I am your E-SUGID AI Assistant. Ask me anything about municipal services, filing concerns, or getting barangay assistance.',
      isUser: false,
    ),
  ];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AppAssistantService();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedQuestion]) async {
    final question = (suggestedQuestion ?? _controller.text).trim();
    if (question.isEmpty || _isSending) return;
    final history = List<AssistantMessage>.from(_messages);
    _controller.clear();
    setState(() {
      _messages.add(AssistantMessage(text: question, isUser: true));
      _isSending = true;
    });
    _scrollToEnd();

    try {
      final reply = await _service.ask(
        question: question,
        user: widget.user,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          AssistantMessage(
            text: reply.text,
            isUser: false,
            action: reply.action,
            actionLabel: reply.actionLabel,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const AssistantMessage(
            text:
                'I could not reach the assistant right now. You can still tap the quick questions below, or try again when your connection is stable.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: ESugidMotion.standard,
        curve: ESugidMotion.enterCurve,
      );
    });
  }

  void _navigate(AssistantNavigationAction action) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
    widget.onNavigate(action);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;

    return AnimatedPadding(
      duration: ESugidMotion.standard,
      curve: ESugidMotion.enterCurve,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: keyboardOpen ? 1 : 0.88,
          child: Container(
            key: const Key('assistant-sheet'),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
              // 3D Top Notch & Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? context.colors.surfaceAlt.withValues(alpha: 0.2392)
                          : context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // 1. 3D Hero Header
                _buildUnifiedHeader(isDark, compact: keyboardOpen),

              // 2. Chat Conversation Area
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _ThinkingBubble();
                      }
                      return _MessageBubble(
                        message: _messages[index],
                        onNavigate: _navigate,
                      );
                    },
                  ),
                ),

              // 3. Quick Topics Hub (Classy 3D Chips)
                _buildQuickQuestions(isDark),

              // 4. 3D Floating Glass Composer Dock
                _buildComposer(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(bool isDark, {required bool compact}) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, compact ? 6 : 10, 14, compact ? 8 : 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.primaryGreen.withValues(
              alpha: isDark ? 0.20 : 0.10,
            ),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D E-SUGID AI Emblem
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.colors.brand, context.colors.brand],
              ),
              border: Border.all(color: context.colors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: context.colors.brandStrong,
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/resident_dashboard/pinakafinal.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.colors.surface.withValues(alpha: 0.40),
                            context.colors.surface.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'E-SUGID Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.colors.primaryGreen.withValues(alpha: 0.4,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: context.colors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: GoogleFonts.outfit(
                              color: context.colors.primaryGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Intelligent Municipal & Barangay Guide',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Close button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? context.colors.surfaceAlt.withValues(alpha: 0.1020)
                      : context.colors.surfaceAlt,
                  border: Border.all(
                    color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                        : context.colors.border,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions(bool isDark) {
    return Container(
      key: const Key('assistant-quick-questions'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 12,
                color: context.colors.primaryGreen,
              ),
              const SizedBox(width: 5),
              Text(
                'QUICK INQUIRIES',
                style: GoogleFonts.outfit(
                  color: context.colors.textSecondary,
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: AppAssistantService.quickQuestions
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isSending ? null : () => _send(question),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7.5,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.colors.primaryGreen.withValues(
                                  alpha: isDark ? 0.35 : 0.22,
                                ),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(
                                    alpha: isDark ? 0.12 : 0.05,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  question ==
                                          AppAssistantService
                                              .quickQuestions
                                              .first
                                      ? Icons.assignment_outlined
                                      : question.contains('hotlines')
                                      ? Icons.call_outlined
                                      : Icons.apps_rounded,
                                  size: 15,
                                  color: context.colors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  question,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    final compact = MediaQuery.sizeOf(context).width < 340;
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('assistant-composer'),
        padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 8, compact ? 10 : 14, 10,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(
              color: context.colors.primaryGreen.withValues(
                alpha: isDark ? 0.18 : 0.10,
              ),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.shadow.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  key: const Key('assistant-input'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask anything about E-SUGID or Barili…',
                    hintStyle: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: context.colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    constraints: const BoxConstraints(minHeight: 48),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: isDark
                            ? context.colors.border.withValues(alpha: 0.1216)
                            : context.colors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: context.colors.primaryGreen,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.colors.brand,
                      context.colors.brand,
                      context.colors.brand,
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? context.colors.border.withValues(alpha: 0.75)
                        : context.colors.border.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isDark) ...[
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.55,
                        ),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.40),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] else ...[
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.42,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: context.colors.highlight.withValues(alpha: 0.55),
                        blurRadius: 4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 3D Glass Specular Highlight Curve on upper hemisphere
                      Positioned(
                        top: 2,
                        left: 6,
                        right: 6,
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                context.colors.surface.withValues(alpha: 0.45),
                                context.colors.surface.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('assistant-send'),
                        tooltip: 'Send question',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: context.colors.onAccent,
                          disabledBackgroundColor: Colors.transparent,
                          disabledForegroundColor: context.colors.disabled,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          shape: const CircleBorder(),
                        ),
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: context.colors.surface,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                color: context.colors.onAccent,
                                size: 23,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onNavigate});

  final AssistantMessage message;
  final ValueChanged<AssistantNavigationAction> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAction =
        !message.isUser && message.destination != AssistantDestination.none;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isUser
              ? context.colors.brand
              : context.colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 6),
            bottomRight: Radius.circular(message.isUser ? 6 : 20),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                      : context.colors.border,
                  width: 1.1,
                ),
          boxShadow: [
            BoxShadow(
              color: message.isUser
                  ? context.colors.brandStrong.withValues(alpha: 0.25)
                  : context.colors.shadow.withValues(alpha: isDark ? 0.20 : 0.04,
                    ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: context.colors.primaryGreen,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'E-SUGID AI',
                    style: GoogleFonts.outfit(
                      color: context.colors.primaryGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.text,
              style: GoogleFonts.outfit(
                color: message.isUser
                    ? context.colors.onAccent
                    : context.colors.textPrimary,
                fontSize: 14,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brand],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.30,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => onNavigate(message.action),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    iconAlignment: IconAlignment.end,
                    label: Text(
                      message.actionLabel?.trim().isNotEmpty == true
                          ? message.actionLabel!
                          : 'Open page',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: context.colors.onAccent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? context.colors.border.withValues(alpha: 0.1216)
                : context.colors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.brand,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'Thinking…',
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
