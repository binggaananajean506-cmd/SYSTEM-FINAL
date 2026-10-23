import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'core/errors/user_facing_error.dart';
import 'core/validation/esugid_validators.dart';
import 'widgets/esugid_page_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.sendPasswordResetEmail});

  final Future<String?> Function(String email)? sendPasswordResetEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final email = ESugidValidators.normalizeEmail(_emailController.text);
    String? error;
    try {
      error = await (widget.sendPasswordResetEmail ??
          AuthService.sendPasswordResetEmail)(email);
    } catch (failure) {
      error = userFacingError(failure);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text(
            error,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13,
            ),
          ),
          kind: FeedbackKind.error,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: dialogContext.colors.surface,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    dialogContext.colors.surfaceAlt,
                    dialogContext.colors.surfaceAlt,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dialogContext.colors.border),
                boxShadow: [
                  BoxShadow(
                    color: dialogContext.colors.brandStrong.withValues(alpha: 0.12,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.mark_email_read_rounded,
                color: dialogContext.colors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset Link Sent',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: dialogContext.colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Check your email inbox',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: dialogContext.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          'We have dispatched a password reset link to $email. Open the link in your email to choose a new password.',
          style: GoogleFonts.outfit(
            color: dialogContext.colors.textPrimary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.colors.brand,
                foregroundColor: dialogContext.colors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Back to Login',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  Widget _buildHeaderCivicBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: context.colors.brandStrong.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.75),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.2588),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.warningSolid,
              boxShadow: [
                BoxShadow(
                  color: context.colors.highlight,
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'MUNICIPALITY OF BARILI',
            style: GoogleFonts.outfit(
              color: context.colors.onBrandMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Collapsible header matching other app headers
          ESugidSliverPageHeader(
            sectionLabelWidget: _buildHeaderCivicBadge(),
            title: 'Forgot Password',
            showBackButton: true,
            onBack: () => Navigator.maybePop(context),
            pinned: true,
          ),

          // 3D Tactile Form Card Body
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.10,
                          ),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.04,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 3D Embossed Lock Medallion
                          Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  context.colors.surfaceAlt,
                                  context.colors.surfaceAlt,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: context.colors.border,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                                BoxShadow(
                                  color: context.colors.highlight,
                                  blurRadius: 0,
                                  offset: Offset(0, -1),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.colors.surface.withValues(alpha: 0.8,
                                ),
                              ),
                              child: Icon(
                                Icons.lock_reset_rounded,
                                size: 38,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Security Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.colors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 13,
                                  color: context.colors.textPrimary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ACCOUNT RECOVERY PORTAL',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Forgot Password?',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? context.colors.onAccent
                                  : context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Enter your registered email address and we will send you an official link to securely reset your password.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                color: context.colors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // 3D Elevated Email Field
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email Address',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _resetPassword(),
                            validator: ESugidValidators.email,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? context.colors.textPrimary
                                  : context.colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'name@example.com',
                              hintStyle: GoogleFonts.outfit(
                                color: (context.colors.textSecondary),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                ),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.alternate_email_rounded,
                                  color: context.colors.textPrimary,
                                  size: 19,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 54,
                                minHeight: 48,
                              ),
                              filled: true,
                              fillColor: context.colors.inputBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: context.colors.border,
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: context.colors.primaryGreen,
                                  width: 1.8,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: context.colors.error,
                                  width: 1.3,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: context.colors.error,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 3D "Send Reset Link" Button
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.colors.brand,
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.38,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: context.colors.onAccent,

                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Sending link...',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Send Reset Link',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,

                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,

                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Back to Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Remember your password? ',
                                style: GoogleFonts.outfit(
                                  color: context.colors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'Log in',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.primaryGreen,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
