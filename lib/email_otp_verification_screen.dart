import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'session_service.dart';
import 'signup_screen.dart';
import 'signup_draft.dart';

class EmailOtpVerificationScreen extends StatefulWidget {
  const EmailOtpVerificationScreen({super.key});

  @override
  State<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends State<EmailOtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  Timer? _countdown;
  RegistrationOtpStatus? _status;
  String? _error;
  bool _sending = false;
  bool _verifying = false;
  bool _switchingEmail = false;
  int _retryAfterSeconds = 0;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(_onFocusChange);
    _codeController.addListener(_onCodeChange);
    unawaited(_initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _codeFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _onCodeChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _codeFocusNode.removeListener(_onFocusChange);
    _codeController.removeListener(_onCodeChange);
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final status = await AuthService.getRegistrationOtpStatus();
      if (!mounted) return;
      if (status.verified) {
        SignupDraftStore.clear();
        await AuthService.refreshCurrentUserFromServer();
        return;
      }
      _applyStatus(status);
      if (!status.hasActiveCode && status.retryAfterSeconds == 0) {
        await _sendCode();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
      });
    }
  }

  void _applyStatus(RegistrationOtpStatus status) {
    _countdown?.cancel();
    setState(() {
      _status = status;
      _retryAfterSeconds = status.retryAfterSeconds;
    });
    if (_retryAfterSeconds > 0) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _retryAfterSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _retryAfterSeconds = 0);
          return;
        }
        setState(() => _retryAfterSeconds--);
      });
    }
  }

  Future<void> _sendCode() async {
    if (_sending || _retryAfterSeconds > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final status = await AuthService.requestRegistrationOtp();
      if (!mounted) return;
      if (status.verified) {
        SignupDraftStore.clear();
        await AuthService.refreshCurrentUserFromServer();
        return;
      }
      _applyStatus(status);
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('A new verification code was sent to your email.'),
          kind: FeedbackKind.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFor(error);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _verifying) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AuthService.verifyRegistrationOtp(code);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Email verified successfully.'),
          kind: FeedbackKind.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final functionsError = error is FirebaseFunctionsException ? error : null;
      if (functionsError?.code == 'deadline-exceeded' ||
          functionsError?.code == 'failed-precondition' ||
          functionsError?.code == 'resource-exhausted') {
        _countdown?.cancel();
        _retryAfterSeconds = 0;
      }
      setState(() => _error = _messageFor(error));
      _codeFocusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _useDifferentEmail() async {
    if (_switchingEmail) return;
    setState(() => _switchingEmail = true);
    final navigator = Navigator.of(context);
    final draft = SignupDraftStore.forEmail(
      AuthService.pendingSignupEmail ?? AuthService.currentUser?.email,
    );
    try {
      if (AuthService.hasPendingSignup) {
        AuthService.cancelPendingSignup();
      } else {
        await SessionService.logout();
      }
      // The auth gate may dispose this screen on logout; its navigator survives.
      if (!navigator.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SignupScreen(focusEmail: true, initialDraft: draft),
        ),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to change email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _switchingEmail = false);
    }
  }

  String _messageFor(Object error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message?.isNotEmpty == true) return message!;
      if (error.code == 'unavailable') {
        return 'Unable to connect. Check your internet and try again.';
      }
    }
    return 'Email verification is temporarily unavailable. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final email =
        _status?.maskedEmail ??
        AuthService.pendingSignupEmail ??
        AuthService.currentUser?.email ??
        'your email address';
    final bool canVerify = _codeController.text.length == 6 && !_verifying;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.colors.background,
                context.colors.background,
                context.colors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (!_codeFocusNode.hasFocus) {
                            _codeFocusNode.requestFocus();
                          }
                          SystemChannels.textInput.invokeMethod(
                            'TextInput.show',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: context.colors.border,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(
                                  alpha: 0.10,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: context.colors.highlight.withValues(
                                  alpha: 0.9,
                                ),
                                blurRadius: 0,
                                offset: const Offset(0, -1.5),
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── 3D Jewel Icon Badge ──
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      context.colors.brand,
                                      context.colors.brandStrong,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.colors.border.withValues(
                                      alpha: 0.65,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.brandStrong
                                          .withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: context.colors.highlight
                                          .withValues(alpha: 0.3),
                                      blurRadius: 0,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.mark_email_read_rounded,
                                    color: context.colors.onBrandMuted,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Title ──
                              Text(
                                'Verify Your Email',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: context.colors.textPrimary,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ── Concise Subtitle with Email Pill ──
                              Text(
                                'Enter the 6-digit code sent to',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: context.colors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 4.5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.colors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  email,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── 6 Individual 3D OTP Boxes ──
                              _buildOtpDigitBoxes(_error != null),

                              // ── Error Banner ──
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.errorSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: context.colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        size: 16,
                                        color: context.colors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.outfit(
                                            color: context.colors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),

                              // ── 3D Elevated Verify Button ──
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: canVerify
                                      ? LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            context.colors.brand,
                                            context.colors.brandStrong,
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [
                                            context.colors.disabledBackground,
                                            context.colors.brand,
                                          ],
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: canVerify
                                          ? context.colors.brandStrong
                                                .withValues(alpha: 0.35)
                                          : Colors.transparent,
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: context.colors.highlight
                                          .withValues(alpha: 0.25),
                                      blurRadius: 0,
                                      offset: const Offset(0, -1.2),
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: canVerify ? _verify : null,
                                    borderRadius: BorderRadius.circular(15),
                                    child: Center(
                                      child: _verifying
                                          ? SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: context.colors.surface,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  color:
                                                      context.colors.onAccent,
                                                  size: 19,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'VERIFY CODE',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.0,
                                                    color:
                                                        context.colors.onAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // ── Resend Code Action ──
                              if (_retryAfterSeconds > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: context.colors.textSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Resend code in ${_retryAfterSeconds}s',
                                        style: GoogleFonts.outfit(
                                          color: context.colors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                TextButton.icon(
                                  onPressed: _sending ? null : _sendCode,
                                  icon: _sending
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            color: context.colors.brand,
                                          ),
                                        )
                                      : Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                          color: context.colors.primaryGreen,
                                        ),
                                  label: Text(
                                    _sending
                                        ? 'Sending new code...'
                                        : 'Resend Code',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.primaryGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 14),

                              // ── Use Different Account ──
                              TextButton.icon(
                                onPressed:
                                    _verifying || _sending || _switchingEmail
                                    ? null
                                    : _useDifferentEmail,
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: context.colors.textSecondary,
                                ),
                                label: Text(
                                  'Use a different email',
                                  style: GoogleFonts.outfit(
                                    color: context.colors.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        context.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildOtpDigitBoxes(bool hasError) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Visual row of 6 elegant 3D boxes (IgnorePointer so all taps hit TextField) ──
          IgnorePointer(
            ignoring: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final text = _codeController.text;
                final bool isFilled = index < text.length;
                final String digit = isFilled ? text[index] : '';
                final bool isCurrent =
                    _codeFocusNode.hasFocus &&
                    (index == text.length || (text.length == 6 && index == 5));

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: index == 0 ? 0 : 3.5,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 56,
                    decoration: BoxDecoration(
                      color: hasError
                          ? context.colors.errorSurface
                          : isCurrent
                          ? context.colors.surfaceAlt
                          : isFilled
                          ? context.colors.surfaceAlt
                          : context.colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasError
                            ? context.colors.error
                            : isCurrent
                            ? context.colors.primaryGreen
                            : isFilled
                            ? context.colors.primaryGreen
                            : context.colors.border,
                        width: isCurrent ? 2.0 : (isFilled ? 1.5 : 1.2),
                      ),
                      boxShadow: [
                        if (isCurrent)
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(
                              alpha: 0.24,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        else if (isFilled)
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        else
                          BoxShadow(
                            color: context.colors.shadow.withValues(
                              alpha: 0.03,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        BoxShadow(
                          color: context.colors.highlight.withValues(
                            alpha: 0.85,
                          ),
                          blurRadius: 0,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isFilled
                          ? Text(
                              digit,
                              style: GoogleFonts.outfit(
                                color: context.colors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : (isCurrent
                                ? const _BlinkingCursor()
                                : const SizedBox.shrink()),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Real, native TextField layered on top to capture all pointer events & trigger keyboard ──
          Positioned.fill(
            child: TextField(
              key: const ValueKey('otp-code-input-field'),
              controller: _codeController,
              focusNode: _codeFocusNode,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableInteractiveSelection: false,
              showCursor: false,
              cursorWidth: 0,
              cursorColor: Colors.transparent,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                height: 1,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                fillColor: Colors.transparent,
                filled: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onTap: () {
                if (!_codeFocusNode.hasFocus) {
                  _codeFocusNode.requestFocus();
                }
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              onChanged: (value) {
                setState(() => _error = null);
                if (value.length == 6 && !_verifying) {
                  unawaited(_verify());
                }
              },
              onSubmitted: (_) {
                if (_codeController.text.length == 6 && !_verifying) {
                  unawaited(_verify());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: context.colors.brand,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
