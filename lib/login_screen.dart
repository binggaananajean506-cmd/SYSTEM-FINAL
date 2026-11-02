import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'core/validation/esugid_validators.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'widgets/root_exit_pop_scope.dart';
import 'widgets/auth_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.loginHandler = AuthService.login});

  final LoginHandler loginHandler;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  String? _authError;
  EmailDomainSuggestion? _emailDomainSuggestion;

  bool get _isBusy => _isLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String value) {
    if (value.trim().isEmpty) return 'Email address is required.';
    if (ESugidValidators.email(value) != null) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required.';
    return null;
  }

  bool _validateInputs() {
    final formatError = _validateEmail(_emailController.text);
    final domainSuggestion = formatError == null
        ? ESugidValidators.commonEmailDomainSuggestion(_emailController.text)
        : null;
    final emailError = domainSuggestion == null
        ? formatError
        : 'Check your email address. Did you mean ${domainSuggestion.correctedEmail}?';
    final passwordError = _validatePassword(_passwordController.text);
    setState(() {
      _emailError = emailError;
      _emailDomainSuggestion = domainSuggestion;
      _passwordError = passwordError;
      _authError = null;
    });
    if (emailError != null) {
      _emailFocus.requestFocus();
    } else if (passwordError != null) {
      _passwordFocus.requestFocus();
    }
    return emailError == null && passwordError == null;
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isBusy || !_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    LoginResult result;
    try {
      result = await widget.loginHandler(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );
    } catch (error) {
      debugPrint('Unhandled login error: $error');
      result = const LoginResult.failure(LoginFailureType.general);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      TextInput.finishAutofillContext();
      return;
    }

    setState(() {
      switch (result.failureType) {
        case LoginFailureType.invalidEmail:
          _emailDomainSuggestion = null;
          _emailError = 'Enter a valid email address.';
        case LoginFailureType.accountNotFound:
          _emailDomainSuggestion = null;
          _emailError = 'Account not found.';
        case LoginFailureType.incorrectPassword:
          _passwordController.clear();
          _passwordError = 'Incorrect password. Please try again.';
        case LoginFailureType.network:
          _authError =
              'Unable to connect. Check your internet connection and try again.';
        case LoginFailureType.general:
          _authError =
              result.message ?? 'Something went wrong. Please try again.';
        case LoginFailureType.underageAccount:
          // Handled below via dialog – no inline field error.
          break;
        case null:
          break;
      }
    });

    // Show a dedicated blocking dialog for underage accounts.
    if (result.failureType == LoginFailureType.underageAccount) {
      _showUnderageDialog();
      return;
    }

    if (result.failureType == LoginFailureType.incorrectPassword) {
      _passwordFocus.requestFocus();
    } else if (result.failureType == LoginFailureType.invalidEmail ||
        result.failureType == LoginFailureType.accountNotFound) {
      _emailFocus.requestFocus();
    }
  }

  // ── Underage account dialog ────────────────────────────────────────────────

  void _showUnderageDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: context.colors.surface,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: context.colors.warningSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: context.colors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Age Requirement Not Met',
                    style: GoogleFonts.poppins(
                      color: context.colors.warning,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          'You must be at least $minimumResidentAge years old to access E-Sugid. '
          'This system is available to residents aged $minimumResidentAge and above.',
          style: GoogleFonts.poppins(
            color: context.colors.textPrimary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('underage-back-to-login-btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: context.colors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Back to Login',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearEmailError(String _) {
    if (_emailError == null && _authError == null) return;
    setState(() {
      _emailError = null;
      _emailDomainSuggestion = null;
      _authError = null;
    });
  }

  void _applyEmailDomainSuggestion() {
    final suggestion = _emailDomainSuggestion;
    if (suggestion == null) return;
    _emailController.value = TextEditingValue(
      text: suggestion.correctedEmail,
      selection: TextSelection.collapsed(
        offset: suggestion.correctedEmail.length,
      ),
    );
    setState(() {
      _emailError = null;
      _emailDomainSuggestion = null;
      _authError = null;
    });
    _emailFocus.requestFocus();
  }

  void _clearPasswordError(String _) {
    if (_passwordError == null && _authError == null) return;
    setState(() {
      _passwordError = null;
      _authError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RootExitPopScope(
      child: AuthBackground(
      title: 'Maayong pag-abot!',
      subtitle: 'Ang imong kasaligan nga kauban sa komunidad.',
      showLogo: true,
      useFrostedPanel: true,
      centeredGlassCard: true,
      logoSize: 152,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: AutofillGroup(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _authError == null
                      ? const SizedBox.shrink()
                      : _LoginMessage(
                          key: ValueKey(_authError),
                          message: _authError!,
                        ),
                ),
                if (_authError != null) const SizedBox(height: 12),
                _buildFieldLabel('Email address'),
                const SizedBox(height: 7),
                _buildTextField(
                  key: const ValueKey('login-email-field'),
                  controller: _emailController,
                  focusNode: _emailFocus,
                  hint: 'name@example.com',
                  icon: Icons.alternate_email_rounded,
                  errorText: _emailError,
                  suggestedEmail: _emailDomainSuggestion?.correctedEmail,
                  onSuggestedEmailTap: _applyEmailDomainSuggestion,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onChanged: _clearEmailError,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildFieldLabel('Password')),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.outfit(
                          color: context.colors.onBrandMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _buildTextField(
                  key: const ValueKey('login-password-field'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: 'Enter your password',
                  icon: Icons.lock_outline_rounded,
                  errorText: _passwordError,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onChanged: _clearPasswordError,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 20),
                DecoratedBox(
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
                        color: context.colors.brandStrong.withValues(alpha: 0.45,
                          ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                        BoxShadow(
                        color: context.colors.highlight.withValues(
                            alpha: 0.2196,
                          ),
                        blurRadius: 0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _isBusy ? null : _login,
                      style: FilledButton.styleFrom(
                          foregroundColor: context.colors.onAccent,

                          backgroundColor: Colors.transparent,
                        disabledBackgroundColor:
                              context.colors.disabledBackground,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isLoading
                            ? Row(
                                key: const ValueKey('login-progress'),
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    'Logging in...',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('login-label'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Log In',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent.withValues(alpha: 0.82,
                          ),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.onAccent,
                        disabledForegroundColor: context.colors.onBrandMuted,
                      ),
                      child: Text(
                        'Create account',
                        style: GoogleFonts.outfit(
                            fontSize: 13.5,
                          fontWeight: FontWeight.w800,
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

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: context.colors.onAccent.withValues(alpha: 0.92),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required String? errorText,
    required TextInputAction textInputAction,
    required Iterable<String> autofillHints,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? suggestedEmail,
    VoidCallback? onSuggestedEmailTap,
  }) {
    final hasError = errorText != null;
    final borderRadius = BorderRadius.circular(15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !isPassword,
          inputFormatters: [
            LengthLimitingTextInputFormatter(
              isPassword ? 128 : ESugidInputLimits.email,
            ),
          ],
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: GoogleFonts.manrope(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(icon, color: context.colors.primaryGreen, size: 20),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 48,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    tooltip: _isPasswordVisible
                        ? 'Hide password'
                        : 'Show password',
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 48),
                      side: BorderSide.none,
                    ),
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 21,
                    ),
                  )
                : null,
            suffixIconConstraints: isPassword
                ? const BoxConstraints(minWidth: 52, minHeight: 48)
                : null,
            filled: true,
            fillColor: context.colors.inputBackground.withValues(alpha: 0.94),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 17,
              horizontal: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: hasError
                    ? context.colors.error : context.colors.border,
                width: hasError ? 1.35 : 1.15,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: hasError ? context.colors.error
                    : context.colors.primaryGreen,
                width: 1.8,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: errorText == null
              ? const SizedBox.shrink()
              : Semantics(
                  key: ValueKey(errorText),
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 3),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.errorSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Icon(
                          Icons.warning_amber_rounded,
                          color: context.colors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child:
                              suggestedEmail != null &&
                                  onSuggestedEmailTap != null
                              ? TextButton(
                                  key: const ValueKey('login-email-suggestion',
                                    ),
                                  onPressed: onSuggestedEmailTap,
                                  style: TextButton.styleFrom(
                                    foregroundColor: context.colors.error,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      text:
                                          'Check your email address. Did you mean ',
                                      children: [
                                        TextSpan(
                                          text: '$suggestedEmail?',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            decorationThickness: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: GoogleFonts.manrope(
                                      color: context.colors.error,
                                      fontSize: 12,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Text(
                                  errorText,
                                  style: GoogleFonts.manrope(
                                    color: context.colors.error,
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        ),
      ],
    );
  }
}

class _LoginMessage extends StatelessWidget {
  final String message;

  const _LoginMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.errorSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: context.colors.error,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: context.colors.error,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

