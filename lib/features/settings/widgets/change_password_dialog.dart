import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth_service.dart';
import '../../../core/validation/esugid_validators.dart';

/// Enhanced, functional Change Password dialog matching Barili registration rules.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_onNewPasswordChanged);
  }

  void _onNewPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newController.removeListener(_onNewPasswordChanged);
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    // Reset top-level error before re-validating
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentPass = _currentController.text;
    final newPass = _newController.text;

    if (currentPass == newPass) {
      setState(() {
        _errorMessage = 'New password cannot be the same as your current password.';
      });
      return;
    }

    setState(() => _saving = true);

    try {
      final error = await AuthService.changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _saving = false;
          _errorMessage = error;
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Unable to update password. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newText = _newController.text;

    final hasMinLength = ESugidValidators.hasPasswordMinLength(newText);
    final hasLetter = ESugidValidators.hasPasswordLetter(newText);
    final hasNumber = ESugidValidators.hasPasswordNumber(newText);
    final hasSymbol = ESugidValidators.hasPasswordSymbol(newText);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: context.colors.border,
            width: 1.2),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: isDark ? 0.45 : 0.14,
              ),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Icon & Title ─────────────────────────────────
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.surfaceAlt,
                            context.colors.surfaceAlt,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.primaryGreen.withValues(alpha: 0.35,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.2 : 0.12,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: context.colors.primaryGreen,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Change Password',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Enter your current password and choose a secure new one to protect your account.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Error Banner ─────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: context.colors.errorSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.colors.error.withValues(alpha: 0.55),
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.colors.error,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.outfit(
                                color: context.colors.error,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Current Password Field ──────────────────────────────
                  _buildPasswordField(
                    controller: _currentController,
                    labelText: 'Current Password',
                    hintText: 'Enter current password',
                    prefixIcon: Icons.lock_outline_rounded,
                    isObscured: _obscureCurrent,
                    onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    isDark: isDark,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── New Password Field ──────────────────────────────────
                  _buildPasswordField(
                    controller: _newController,
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    prefixIcon: Icons.key_rounded,
                    isObscured: _obscureNew,
                    onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                    isDark: isDark,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'New password is required';
                      }
                      return ESugidValidators.validateRegistrationPassword(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Live Security Criteria Checklist (Registration Match)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Requirements (Registration Standard):',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _buildRuleItem('8+ characters', hasMinLength, isDark,
                            ),
                            _buildRuleItem('Letters (a-z)', hasLetter, isDark),
                            _buildRuleItem('Numbers (0-9)', hasNumber, isDark),
                            _buildRuleItem('Special symbol', hasSymbol, isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Confirm New Password Field ───────────────────────────
                  _buildPasswordField(
                    controller: _confirmController,
                    labelText: 'Confirm New Password',
                    hintText: 'Re-type new password',
                    prefixIcon: Icons.verified_user_outlined,
                    isObscured: _obscureConfirm,
                    onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    isDark: isDark,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (val != _newController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // ── Actions: Cancel & Save Password ──────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: context.colors.border,
                              width: 1.1,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: _saving ? 0.15 : 0.35,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: context.colors.onAccent,

                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              disabledForegroundColor: context.colors.disabled,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _saving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Text(
                                    'Save Password',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
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
    );
  }

  Widget _buildRuleItem(String label, bool isSatisfied, bool isDark) {
    final activeColor = context.colors.primaryGreen;
    final inactiveColor = context.colors.info;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13.5,
          color: isSatisfied ? activeColor : inactiveColor,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSatisfied ? FontWeight.w700 : FontWeight.w500,
            color: isSatisfied ? activeColor : inactiveColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    required bool isDark,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscured,
      style: GoogleFonts.outfit(
        fontSize: 14.5,
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13.5,
          color: context.colors.textSecondary,
        ),
        hintStyle: GoogleFonts.outfit(
          fontSize: 13,
          color: context.colors.info),
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: context.colors.primaryGreen,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: context.colors.textSecondary,
          ),
          onPressed: onToggleObscure,
          splashRadius: 20,
          tooltip: isObscured ? 'Show password' : 'Hide password',
        ),
        filled: true,
        fillColor: context.colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.border,
            width: 1.1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.border,
            width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.primaryGreen,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.error,
            width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: context.colors.error,
            width: 1.8),
        ),
      ),
      validator: validator,
    );
  }
}
