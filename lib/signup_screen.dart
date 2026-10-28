import 'dart:async';
import 'dart:math';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_policy.dart';
import 'auth_service.dart';
import 'email_otp_verification_screen.dart';
import 'barili_barangays.dart';
import 'core/validation/esugid_validators.dart';
import 'features/verification/domain/residency_verification.dart';
import 'onboarding_screen.dart';
import 'signup_draft.dart';
import 'widgets/esugid_page_header.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const int _kMinAge = 13;
final DateFormat _kBirthdateFormat = DateFormat('MM/dd/yyyy');

/// Keeps digits only and inserts the slashes: 05141998 -> 05/14/1998.
class _BirthdateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final kept = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < kept.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(kept[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

const List<String?> _kSuffixOptions = [
  null,
  'Jr.',
  'Sr.',
  'II',
  'III',
  'IV',
  'V',
];

// ---------------------------------------------------------------------------
// SignupScreen
// ---------------------------------------------------------------------------
class SignupScreen extends StatefulWidget {
  final bool focusEmail;
  final SignupDraft? initialDraft;
  const SignupScreen({super.key, this.focusEmail = false, this.initialDraft});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

// ---------------------------------------------------------------------------
// _PolicyLink
// ---------------------------------------------------------------------------
class _PolicyLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PolicyLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: context.colors.primaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: context.colors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SignupScreenState
// ---------------------------------------------------------------------------
class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Shake animation controller for error effect
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Name controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Other controllers
  final _emailController = TextEditingController();
  final _emailFieldKey = GlobalKey();
  final _emailFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _barangayController = TextEditingController();
  final _birthdateController = TextEditingController();

  // Dropdown state
  String? _selectedSuffix; // null = "None"

  // DOB / Age state
  DateTime? _selectedBirthdate;
  int? _calculatedAge;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedPolicies = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
    final draft = widget.initialDraft;
    if (draft != null) {
      _firstNameController.text = draft.firstName;
      _middleNameController.text = draft.middleName;
      _lastNameController.text = draft.lastName;
      _selectedSuffix = draft.suffix;
      _emailController.text = draft.email;
      _passwordController.text = draft.password;
      _confirmPasswordController.text = draft.confirmPassword;
      _barangayController.text = draft.barangay;
      _selectedBirthdate = draft.birthDate;
      _acceptedPolicies = draft.acceptedPolicies;
      if (draft.birthDate != null) {
        _birthdateController.text = _kBirthdateFormat.format(draft.birthDate!);
        _calculatedAge = _computeAge(draft.birthDate!);
      }
    } else {
      AuthService.cancelPendingSignup();
    }
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
    if (widget.focusEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final fieldContext = _emailFieldKey.currentContext;
        if (fieldContext != null) {
          await Scrollable.ensureVisible(
            fieldContext,
            alignment: 0.25,
            duration: const Duration(milliseconds: 250),
          );
        }
        if (!mounted) return;
        _emailFocusNode.requestFocus();
        _emailController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _emailController.text.length,
        );
      });
    }
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  void _triggerAgeShake() {
    _shakeController.forward(from: 0.0);
    HapticFeedback.mediumImpact();
  }

  // ── Password Security Helpers ──────────────────────────────────────────────

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSymbol => RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]\\;/]',
  ).hasMatch(_passwordController.text);
  bool get _isPasswordSecure =>
      _hasMinLength && _hasLetter && _hasNumber && _hasSymbol;

  // ── Derived helpers ────────────────────────────────────────────────────────

  /// Assembles the full display name from individual parts.
  String get _fullName {
    final parts = [
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty)
        _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      ?_selectedSuffix,
    ];
    return parts.join(' ');
  }

  bool get _isTooYoung => _calculatedAge != null && _calculatedAge! < _kMinAge;

  bool get _isSignUpDisabled => _isLoading || !_acceptedPolicies || _isTooYoung;

  // ── Age calculation ────────────────────────────────────────────────────────

  /// Proper age calculation: checks whether the birthday has passed this year.
  int _computeAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (birthDate.month > today.month ||
        (birthDate.month == today.month && birthDate.day > today.day)) {
      age--;
    }
    return age;
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final initialDate =
        _selectedBirthdate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      // Typing happens in the sign-up field, which formats MM/DD/YYYY.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme,
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primaryGreen,
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      _birthdateController.text = _kBirthdateFormat.format(picked);
      _applyBirthdate(picked);
    }
  }

  /// Typed dates count only when complete and real (no 02/30, no future).
  void _onBirthdateTyped(String value) {
    DateTime? parsed;
    if (value.length == 10) {
      try {
        parsed = _kBirthdateFormat.parseStrict(value);
      } on FormatException {
        parsed = null;
      }
      if (parsed != null &&
          (parsed.isAfter(DateTime.now()) || parsed.year < 1900)) {
        parsed = null;
      }
    }
    if (parsed != null) {
      _applyBirthdate(parsed);
    } else if (_selectedBirthdate != null || _calculatedAge != null) {
      setState(() {
        _selectedBirthdate = null;
        _calculatedAge = null;
      });
    }
  }

  void _applyBirthdate(DateTime picked) {
    final calculated = _computeAge(picked);
    setState(() {
      _selectedBirthdate = picked;
      _calculatedAge = calculated;
    });

    final wireDate = storedBirthDateValue(picked);
    AuthService.cacheBirthDateInMemory(wireDate: wireDate);
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setString('last_signup_birth_date', wireDate);
          final email = _emailController.text.trim().toLowerCase();
          if (email.isNotEmpty) {
            prefs.setString('user_birth_date_$email', wireDate);
          }
          final name = _fullName.trim().toLowerCase();
          if (name.isNotEmpty) {
            prefs.setString('user_birth_date_$name', wireDate);
          }
        })
        .catchError((_) {});

    if (calculated < _kMinAge) {
      _triggerAgeShake();
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onPasswordChanged);
    _shakeController.dispose();
    _emailFocusNode.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _barangayController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  // ── Sign-up handler ────────────────────────────────────────────────────────

  Future<void> _handleSignup() async {
    if (_isLoading) return;

    // 1. If underage, trigger the error shake effect and show explicit message
    if (_isTooYoung) {
      _triggerAgeShake();
      _showSnackBar(
        'Registration restricted: You must be at least $_kMinAge years old to sign up.',
        isError: true,
      );
      return;
    }

    // 2. Check if birthdate is selected
    if (_selectedBirthdate == null) {
      _showSnackBar(
        'Please select your Date of Birth to proceed.',
        isError: true,
      );
      return;
    }

    // 3. Form fields validation
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        'Please complete all required fields correctly.',
        isError: true,
      );
      return;
    }

    // 4. Check password security rules
    if (!_isPasswordSecure) {
      _showSnackBar(
        'Password must be at least 8 characters and include letters, numbers, and symbols.',
        isError: true,
      );
      return;
    }

    // 5. Barangay validation
    if (_barangayController.text.trim().isEmpty) {
      _showSnackBar(
        'Please select your Barangay from the list.',
        isError: true,
      );
      return;
    }

    // 6. Terms and Policies validation
    if (!_acceptedPolicies) {
      _showSnackBar(
        'Please accept the Terms & Privacy Policy to create an account.',
        isError: true,
      );
      return;
    }

    // Proceed with registration
    setState(() => _isLoading = true);
    String? errorMessage;
    final wireDate = _selectedBirthdate != null
        ? storedBirthDateValue(_selectedBirthdate!)
        : null;
    if (wireDate != null) {
      final emailKey = ESugidValidators.normalizeEmail(
        _emailController.text,
      ).toLowerCase();
      final nameKey = _fullName.trim().toLowerCase();
      AuthService.cacheBirthDateInMemory(
        email: emailKey,
        name: nameKey,
        wireDate: wireDate,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_signup_birth_date', wireDate);
        if (emailKey.isNotEmpty) {
          await prefs.setString('user_birth_date_$emailKey', wireDate);
        }
        if (nameKey.isNotEmpty) {
          await prefs.setString('user_birth_date_$nameKey', wireDate);
        }
      } catch (_) {}
    }
    try {
      errorMessage = await AuthService.register(
        email: ESugidValidators.normalizeEmail(_emailController.text),
        password: _passwordController.text,
        name: _fullName,
        role: UserRole.resident,
        barangay: _barangayController.text.trim(),
        address: _barangayController.text.trim(),
        birthDate: wireDate ?? _selectedBirthdate?.toIso8601String(),
        acceptedPolicyVersion: currentPolicyVersion,
        policyAcceptedAt: DateTime.now().toUtc().toIso8601String(),
      ).timeout(const Duration(seconds: 100));
    } on TimeoutException {
      errorMessage =
          'Registration took too long. Check your connection and try again.';
    } catch (error) {
      debugPrint('Unexpected signup error: $error');
      errorMessage = 'Unable to create the account. Please try again.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    if (errorMessage == null) {
      SignupDraftStore.remember(
        SignupDraft(
          firstName: _firstNameController.text,
          middleName: _middleNameController.text,
          lastName: _lastNameController.text,
          suffix: _selectedSuffix,
          email: _emailController.text,
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
          birthDate: _selectedBirthdate,
          barangay: _barangayController.text,
          acceptedPolicies: _acceptedPolicies,
        ),
      );
      _showSnackBar('Verify your email to finish setting up your account.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const EmailOtpVerificationScreen(),
        ),
      );
    } else {
      _showSnackBar(errorMessage, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        duration: Duration(seconds: isError ? 8 : 5),
        kind: isError ? FeedbackKind.error : FeedbackKind.success,
      ),
    );
  }

  void _openPolicy(LegalDocument document) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalDocumentPage(document: document)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // 1. Clean Collapsible Sliver Header (icon & subtitle removed per request)
          ESugidSliverPageHeader(
            sectionLabelWidget: _buildHeaderCivicBadge(),
            title: 'Sign Up',
            showBackButton: true,
            onBack: () => Navigator.maybePop(context),
            pinned: true,
          ),

          // 2. 3D Tactile Form Card Body
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    key: const ValueKey('auth-content-clip'),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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
                            alpha: 0.08,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(
                            alpha: 0.03,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 460;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Section 1: Resident Details ──
                              _buildFormSectionLabel(
                                'YOUR DETAILS',
                                Icons.badge_outlined,
                              ),
                              const SizedBox(height: 16),

                              // Name fields (First, Middle, Last, Suffix)
                              _buildNameSection(isWide),

                              const SizedBox(height: 14),

                              // Date of Birth + Age (Responsive with Error Effect)
                              _buildDobAgeSection(isWide),

                              // ── Warning card ONLY appears when age is below 13 (NO card if 13+) ──
                              if (_isTooYoung) ...[
                                const SizedBox(height: 12),
                                _buildAgeRequirementSection(),
                              ],

                              const SizedBox(height: 16),

                              // ── Dependent Fields (Disabled and Locked when Underage) ──
                              _buildDependentFieldsSection(),

                              const SizedBox(height: 20),

                              // Sign In Link
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Already a member? ',
                                      style: GoogleFonts.outfit(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => Navigator.of(
                                        context,
                                      ).popUntil((route) => route.isFirst),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          'Sign in',
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
                              ),
                            ],
                          );
                        },
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

  // ── Underage Tap Feedback & Error Handling ──────────────────────────────────

  void _showUnderageWarning() {
    _shakeController.forward(from: 0.0);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(
        content: Text(
          'Must be at least $_kMinAge years old to sign up.',
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 3),
        kind: FeedbackKind.warning,
      ),
    );
  }

  // ── Dependent Fields Section (Locked/Disabled when Underage) ────────────────

  Widget _buildDependentFieldsSection() {
    final bool isBlocked = _isTooYoung;

    final hasPasswordText = _passwordController.text.isNotEmpty;
    final passwordBorderColor = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? context.colors.primaryGreen
              : context.colors.error);
    final passwordFillColor = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? context.colors.surfaceAlt
              : context.colors.errorSurface);
    final passwordIconColor = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? context.colors.primaryGreen
              : context.colors.error);
    final passwordNoteText = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? 'Password meets all security requirements.'
              : 'Required: At least 8 characters with letters, numbers & symbols.');
    final passwordNoteIcon = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded);
    final passwordNoteColor = !hasPasswordText
        ? null
        : (_isPasswordSecure
              ? context.colors.primaryGreen
              : context.colors.error);

    final hasConfirmText = _confirmPasswordController.text.isNotEmpty;
    final confirmMatches =
        _confirmPasswordController.text == _passwordController.text &&
        _isPasswordSecure;
    final confirmBorderColor = !hasConfirmText
        ? null
        : (confirmMatches ? context.colors.primaryGreen : context.colors.error);
    final confirmFillColor = !hasConfirmText
        ? null
        : (confirmMatches
              ? context.colors.surfaceAlt
              : context.colors.errorSurface);
    final confirmIconColor = !hasConfirmText
        ? null
        : (confirmMatches ? context.colors.primaryGreen : context.colors.error);
    final confirmNoteText = !hasConfirmText
        ? null
        : (confirmMatches ? 'Passwords match.' : 'Passwords do not match.');
    final confirmNoteIcon = !hasConfirmText
        ? null
        : (confirmMatches
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded);
    final confirmNoteColor = !hasConfirmText
        ? null
        : (confirmMatches ? context.colors.primaryGreen : context.colors.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barangay Picker
        _buildBarangayDropdown(
          enabled: !isBlocked,
          onDisabledTap: isBlocked ? _showUnderageWarning : null,
        ),

        const SizedBox(height: 14),

        // Email Address
        _buildResidentField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          hintText: 'example@email.com',
          enabled: !isBlocked,
          onDisabledTap: isBlocked ? _showUnderageWarning : null,
          inputFormatters: [
            LengthLimitingTextInputFormatter(ESugidInputLimits.email),
          ],
          validator: isBlocked ? (_) => null : ESugidValidators.email,
        ),

        const SizedBox(height: 26),

        // ── Section 2: Security ──
        _buildFormSectionLabel('SECURE YOUR ACCOUNT', Icons.security_rounded),
        const SizedBox(height: 16),

        _buildResidentField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          hintText: 'Min. 8 chars, letters, numbers & symbols',
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          enabled: !isBlocked,
          onDisabledTap: isBlocked ? _showUnderageWarning : null,
          customBorderColor: passwordBorderColor,
          customFillColor: passwordFillColor,
          customPrefixIconColor: passwordIconColor,
          noteText: passwordNoteText,
          noteIcon: passwordNoteIcon,
          noteColor: passwordNoteColor,
          onToggleVisibility: isBlocked
              ? null
              : () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          validator: isBlocked
              ? (_) => null
              : (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                    return 'Password must contain at least one letter';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Password must contain at least one number';
                  }
                  if (!RegExp(
                    r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]\\;/]',
                  ).hasMatch(value)) {
                    return 'Password must contain at least one symbol';
                  }
                  return null;
                },
        ),

        const SizedBox(height: 14),

        // Confirm Password
        _buildResidentField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          hintText: 'Re-enter your password',
          isPassword: true,
          isPasswordVisible: _isConfirmPasswordVisible,
          enabled: !isBlocked,
          onDisabledTap: isBlocked ? _showUnderageWarning : null,
          customBorderColor: confirmBorderColor,
          customFillColor: confirmFillColor,
          customPrefixIconColor: confirmIconColor,
          noteText: confirmNoteText,
          noteIcon: confirmNoteIcon,
          noteColor: confirmNoteColor,
          onToggleVisibility: isBlocked
              ? null
              : () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                ),
          validator: isBlocked
              ? (_) => null
              : (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
        ),

        const SizedBox(height: 22),

        // Terms & Conditions
        _buildPolicyAgreement(
          enabled: !isBlocked,
          onDisabledTap: isBlocked ? _showUnderageWarning : null,
        ),

        const SizedBox(height: 22),

        // ── 3D Elevated Sign Up Button ──
        _build3DSignUpButton(isBlocked: isBlocked),
      ],
    );
  }

  // ── Header Civic Badge (Matching the App's other top pages) ───────────────

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
          const SizedBox(width: 5),
          Text(
            'RESIDENT REGISTRATION',
            style: GoogleFonts.outfit(
              color: context.colors.onBrandMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Name section (responsive) ──────────────────────────────────────────────

  Widget _buildNameSection(bool isWide) {
    final firstName = _buildResidentField(
      controller: _firstNameController,
      label: 'First Name *',
      icon: Icons.person_outline_rounded,
      hintText: 'Enter first name',
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        LengthLimitingTextInputFormatter(ESugidInputLimits.fullName),
      ],
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'First name is required' : null,
    );

    final middleName = _buildResidentField(
      controller: _middleNameController,
      label: 'Middle Name',
      icon: Icons.person_outline_rounded,
      hintText: 'Enter middle name',
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        LengthLimitingTextInputFormatter(ESugidInputLimits.fullName),
      ],
      validator: (_) => null,
      helperText: 'Optional',
    );

    final lastName = _buildResidentField(
      controller: _lastNameController,
      label: 'Last Name *',
      icon: Icons.badge_outlined,
      hintText: 'Enter last name',
      textCapitalization: TextCapitalization.words,
      inputFormatters: [
        LengthLimitingTextInputFormatter(ESugidInputLimits.fullName),
      ],
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Last name is required' : null,
    );

    final suffix = _buildSuffixDropdown();

    if (isWide) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: firstName),
              const SizedBox(width: 14),
              Expanded(child: middleName),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: lastName),
              const SizedBox(width: 14),
              Expanded(child: suffix),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        firstName,
        const SizedBox(height: 14),
        middleName,
        const SizedBox(height: 14),
        lastName,
        const SizedBox(height: 14),
        suffix,
      ],
    );
  }

  // ── Suffix dropdown ────────────────────────────────────────────────────────

  Widget _buildSuffixDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suffix / Extension',
          style: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: _selectedSuffix,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.label_outline_rounded,
              color: context.colors.primaryGreen,
              size: 19,
            ),
            filled: true,
            fillColor: context.colors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: context.colors.primaryGreen,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.error, width: 1.8),
            ),
            helperText: 'Optional',
            helperStyle: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.unfold_more_rounded,
            color: context.colors.textSecondary,
            size: 20,
          ),
          items: _kSuffixOptions.map((suffix) {
            return DropdownMenuItem<String?>(
              value: suffix,
              child: Text(
                suffix ?? 'None',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: suffix == null
                      ? context.colors.textSecondary
                      : context.colors.textPrimary,
                  fontWeight: suffix == null
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedSuffix = value),
          validator: (_) => null,
        ),
      ],
    );
  }

  // ── DOB + Age section (responsive with error shake effect) ──────────────────

  Widget _buildDobAgeSection(bool isWide) {
    final dobField = _buildDobField();
    final ageField = _buildAgeField();

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: dobField),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: ageField),
        ],
      );
    }

    return Column(children: [dobField, const SizedBox(height: 14), ageField]);
  }

  // ── Date of Birth field ────────────────────────────────────────────────────

  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth *',
          style: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const ValueKey('signup-dob-field'),
          controller: _birthdateController,
          keyboardType: TextInputType.number,
          inputFormatters: [_BirthdateInputFormatter()],
          onChanged: _onBirthdateTyped,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Date of birth is required';
            }
            if (_selectedBirthdate == null) {
              return 'Enter a real date as MM/DD/YYYY';
            }
            if (_isTooYoung) {
              return 'Must be at least $_kMinAge years old';
            }
            return null;
          },
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'MM/DD/YYYY',
            hintStyle: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 12.5,
            ),
            prefixIcon: Icon(
              Icons.cake_outlined,
              color: context.colors.primaryGreen,
              size: 19,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                tooltip: 'Pick date of birth',
                onPressed: _pickBirthdate,
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: context.colors.primaryGreen,
                    size: 18,
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: context.colors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: context.colors.primaryGreen,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.error, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: context.colors.error, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  // ── Read-only Age field with Error Shake & Glow Effect ─────────────────────

  Widget _buildAgeField() {
    final String ageText = _calculatedAge != null ? '${_calculatedAge!}' : '';

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final double offset = _isTooYoung
            ? sin(_shakeAnimation.value * 3 * pi) *
                  6 *
                  (1 - _shakeAnimation.value)
            : 0.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Age',
            style: GoogleFonts.outfit(
              color: context.colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isTooYoung ? _showUnderageWarning : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                boxShadow: _isTooYoung
                    ? [
                        BoxShadow(
                          color: context.colors.errorSolid.withValues(
                            alpha: 0.18,
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                readOnly: true,
                enabled: false,
                controller: TextEditingController(text: ageText),
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: _isTooYoung
                      ? context.colors.error
                      : context.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '—',
                  hintStyle: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    _isTooYoung
                        ? Icons.error_outline_rounded
                        : Icons.hourglass_bottom_rounded,
                    color: _isTooYoung
                        ? context.colors.error
                        : context.colors.primaryGreen,
                    size: 19,
                  ),
                  filled: true,
                  fillColor: _isTooYoung
                      ? context.colors.inputBackground
                      : context.colors.inputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(
                      color: _isTooYoung
                          ? context.colors.error
                          : context.colors.border,
                      width: _isTooYoung ? 1.6 : 1.2,
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

  // ── Minimum Age Warning Card (ONLY displayed if Age < 13) ─────────────────

  Widget _buildAgeRequirementSection() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final double offset = _isTooYoung
            ? sin(_shakeAnimation.value * 3 * pi) *
                  6 *
                  (1 - _shakeAnimation.value)
            : 0.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _buildRequirementCardContent(),
      ),
    );
  }

  Widget _buildRequirementCardContent() {
    // 1. Underage (< 13): Concise, impactful warning card (NO overflow)
    if (_isTooYoung) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showUnderageWarning,
        child: Container(
          key: const ValueKey('age-underage-warning'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: context.colors.warningSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: context.colors.warningSolid.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.colors.warningSolid,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.warningSolid.withValues(
                        alpha: 0.25,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: context.colors.onAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Minimum Age Requirement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: context.colors.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Must be at least $_kMinAge years old to sign up.',
                      style: GoogleFonts.outfit(
                        color: context.colors.error,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // When age is valid (13+) or not yet selected: NO card is attached at all.
    return const SizedBox.shrink(key: ValueKey('no-age-card'));
  }

  // ── Shared field builder with 3D tactile styling ───────────────────────────

  Widget _buildResidentField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? hintText,
    String? helperText,
    bool enabled = true,
    VoidCallback? onDisabledTap,
    Color? customBorderColor,
    Color? customFillColor,
    Color? customPrefixIconColor,
    String? noteText,
    IconData? noteIcon,
    Color? noteColor,
    FocusNode? focusNode,
  }) {
    final fieldInput = TextFormField(
      key: focusNode == _emailFocusNode ? _emailFieldKey : null,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      obscureText: isPassword && !isPasswordVisible,
      validator:
          validator ??
          (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled
            ? (context.colors.textPrimary)
            : (context.colors.textSecondary),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(
          color: context.colors.textSecondary,
          fontSize: 12.5,
        ),
        prefixIcon: Icon(
          icon,
          color: !enabled
              ? context.colors.textSecondary
              : (customPrefixIconColor ?? context.colors.primaryGreen),
          size: 19,
        ),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: enabled ? onToggleVisibility : null,
                splashRadius: 18,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                icon: Icon(
                  isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: !enabled
                      ? context.colors.textSecondary
                      : context.colors.textSecondary,
                  size: 20,
                ),
              )
            : null,
        filled: true,
        fillColor: !enabled
            ? (context.colors.inputBackground)
            : (customFillColor ?? (context.colors.inputBackground)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: customBorderColor ?? (context.colors.border),
            width: customBorderColor != null ? 1.6 : 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: customBorderColor ?? context.colors.primaryGreen,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: context.colors.error, width: 1.8),
        ),
        helperText: helperText,
        helperStyle: GoogleFonts.outfit(
          color: context.colors.textSecondary,
          fontSize: 11,
        ),
      ),
    );

    final interactiveInput = (!enabled && onDisabledTap != null)
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDisabledTap,
            child: IgnorePointer(ignoring: true, child: fieldInput),
          )
        : fieldInput;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Theme.of(context).brightness == Brightness.dark
                ? context.colors.textSecondary
                : context.colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        interactiveInput,
        if (noteText != null && noteText.isNotEmpty) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(
                  noteIcon ?? Icons.info_outline_rounded,
                  size: 13,
                  color: noteColor ?? context.colors.error,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    noteText,
                    style: GoogleFonts.outfit(
                      color: noteColor ?? context.colors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Section label with 3D tactile mini-badge & fine gradient divider ───────

  Widget _buildFormSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5.5),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandStrong.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Icon(icon, size: 14, color: context.colors.primaryGreen),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: context.colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.surfaceAlt,
                  context.colors.surfaceAlt.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Barangay dropdown ──────────────────────────────────────────────────────

  Widget _buildBarangayDropdown({
    bool enabled = true,
    VoidCallback? onDisabledTap,
  }) {
    return FormField<String>(
      initialValue: _barangayController.text.isEmpty
          ? null
          : _barangayController.text,
      validator: (value) => enabled && (value == null || value.isEmpty)
          ? 'Please select a barangay'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Barangay',
                style: GoogleFonts.outfit(
                  color: context.colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' *',
                style: GoogleFonts.outfit(
                  color: context.colors.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('signup-barangay-selector'),
              borderRadius: BorderRadius.circular(13),
              onTap: enabled
                  ? () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            _BarangayPickerSheet(selectedBarangay: field.value),
                      );
                      if (selected == null) return;
                      _barangayController.text = selected;
                      field.didChange(selected);
                    }
                  : onDisabledTap,
              child: Ink(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: enabled
                      ? context.colors.surface
                      : context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: !enabled
                        ? context.colors.border
                        : field.hasError
                        ? context.colors.error
                        : field.value == null
                        ? context.colors.border
                        : context.colors.primaryGreen,
                    width: field.value == null ? 1.2 : 1.6,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: enabled
                          ? context.colors.primaryGreen
                          : context.colors.textSecondary,
                      size: 19,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        field.value ?? 'Choose your barangay',
                        style: GoogleFonts.outfit(
                          color: !enabled
                              ? context.colors.textSecondary
                              : field.value == null
                              ? context.colors.textSecondary
                              : context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: field.value == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.unfold_more_rounded,
                      color: enabled
                          ? context.colors.textSecondary
                          : context.colors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                field.errorText!,
                style: GoogleFonts.outfit(
                  color: context.colors.error,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Policy agreement with 3D rounded panel ─────────────────────────────────

  Widget _buildPolicyAgreement({
    bool enabled = true,
    VoidCallback? onDisabledTap,
  }) {
    final agreementWidget = Semantics(
      label:
          'By signing up, you agree to our Terms, Privacy Policy, and Cookies Policy.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          color: enabled
              ? context.colors.surfaceAlt
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? context.colors.border : context.colors.border,
            width: 1.1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: context.colors.brandStrong.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const ValueKey('signup-policy-checkbox'),
              value: _acceptedPolicies,
              onChanged: enabled && !_isLoading
                  ? (value) =>
                        setState(() => _acceptedPolicies = value ?? false)
                  : null,
              activeColor: context.colors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.5),
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By signing up, you agree to our',
                    style: GoogleFonts.outfit(
                      color: context.colors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PolicyLink(
                        label: 'Terms',
                        onTap: () => _openPolicy(LegalDocument.terms),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      _PolicyLink(
                        label: 'Privacy Policy',
                        onTap: () => _openPolicy(LegalDocument.privacy),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      _PolicyLink(
                        label: 'Cookies Policy',
                        onTap: () => _openPolicy(LegalDocument.cookies),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!enabled && onDisabledTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDisabledTap,
        child: agreementWidget,
      );
    }

    return agreementWidget;
  }

  // ── 3D Realistic Button with User Feedback on Tap ──────────────────────────

  Widget _build3DSignUpButton({bool isBlocked = false}) {
    final bool disabled = _isSignUpDisabled || isBlocked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: disabled
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.colors.disabledBackground,
                  context.colors.disabledBackground,
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [context.colors.brand, context.colors.brandStrong],
              ),
        boxShadow: [
          BoxShadow(
            color: disabled
                ? context.colors.brandStrong.withValues(alpha: 0.15)
                : context.colors.brandStrong.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: context.colors.highlight.withValues(alpha: 0.25),
            blurRadius: 0,
            offset: const Offset(0, -1.2),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('signup-submit-button'),
          onTap: _isLoading
              ? null
              : isBlocked
              ? _showUnderageWarning
              : (_isSignUpDisabled ? null : _handleSignup),
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: context.colors.surface,
                      strokeWidth: 2.4,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.how_to_reg_rounded,
                        color: disabled
                            ? context.colors.disabled
                            : context.colors.onAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'CREATE ACCOUNT',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: disabled
                              ? context.colors.disabled
                              : context.colors.onAccent,
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

// ---------------------------------------------------------------------------
// Creative 3D Barangay Picker Sheet
// ---------------------------------------------------------------------------
class _BarangayPickerSheet extends StatefulWidget {
  final String? selectedBarangay;
  const _BarangayPickerSheet({this.selectedBarangay});

  @override
  State<_BarangayPickerSheet> createState() => _BarangayPickerSheetState();
}

class _BarangayPickerSheetState extends State<_BarangayPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = bariliBarangays.where((b) {
      return b.toLowerCase().contains(_query);
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Material(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Creative 3D Emerald Header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colors.brandStrong,
                    context.colors.brandStrong,
                    context.colors.brand,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Specular Rim Light
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.surface.withValues(alpha: 0.0),
                            context.colors.surface.withValues(alpha: 0.45),
                            context.colors.surface.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Watermark Seal
                  Positioned(
                    top: -10,
                    right: 15,
                    child: Opacity(
                      opacity: 0.08,
                      child: Image.asset(
                        'assets/images/resident_dashboard/pinakafinal.png',
                        width: 140,
                        fit: BoxFit.contain,
                        color: context.colors.surface,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: context.colors.warningSolid.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title Bar
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.colors.surface.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.colors.border.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.location_city_rounded,
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
                                    'Select your barangay',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent,
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    'Choose from 42 Barili barangays',
                                    style: GoogleFonts.outfit(
                                      color: context.colors.onAccent.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.colors.surface.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: context.colors.onAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Search Bar Inside Header
                        Container(
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.shadow.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            key: const ValueKey('barangay-search-field'),
                            controller: _searchController,
                            autofocus: false,
                            onChanged: (v) =>
                                setState(() => _query = v.trim().toLowerCase()),
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search barangay name...',
                              hintStyle: GoogleFonts.outfit(
                                color: context.colors.textSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: context.colors.primaryGreen,
                                size: 21,
                              ),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: context.colors.textSecondary,
                                      ),
                                    )
                                  : null,
                              filled: true,
                              fillColor: context.colors.inputBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── 3D Barangay Cards List ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_off_outlined,
                              size: 36,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No barangay found',
                            style: GoogleFonts.outfit(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your search query',
                            style: GoogleFonts.outfit(
                              color: context.colors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final barangay = filtered[index];
                        final bool isSelected =
                            barangay == widget.selectedBarangay;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(context, barangay);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            context.colors.brand,
                                            context.colors.brandStrong,
                                          ],
                                        )
                                      : null,
                                  color: isSelected
                                      ? null
                                      : context.colors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? context.colors.primaryGreen
                                        : context.colors.border,
                                    width: isSelected ? 1.5 : 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? context.colors.brandStrong
                                                .withValues(alpha: 0.28)
                                          : context.colors.brandStrong
                                                .withValues(alpha: 0.04),
                                      blurRadius: isSelected ? 10 : 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 3D Avatar / Icon Badge
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? context.colors.surface.withValues(
                                                alpha: 0.20,
                                              )
                                            : context.colors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.location_on_outlined,
                                        color: isSelected
                                            ? context.colors.warning
                                            : context.colors.primaryGreen,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Barangay Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            barangay,
                                            style: GoogleFonts.outfit(
                                              color: isSelected
                                                  ? context.colors.onAccent
                                                  : context.colors.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Barili, Cebu',
                                            style: GoogleFonts.outfit(
                                              color: isSelected
                                                  ? context.colors.onAccent
                                                        .withValues(alpha: 0.8)
                                                  : context
                                                        .colors
                                                        .textSecondary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Status Badge / Arrow
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.colors.warningSolid,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'SELECTED',
                                          style: GoogleFonts.outfit(
                                            color: context.colors.onAccent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: context.colors.textSecondary,
                                      ),
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
      ),
    );
  }
}
