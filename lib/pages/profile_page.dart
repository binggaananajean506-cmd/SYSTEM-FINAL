import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../auth_service.dart';
import '../core/validation/esugid_input_formatters.dart';
import '../core/validation/esugid_validators.dart';
import '../core/widgets/esugid_pull_to_refresh.dart';
import '../features/settings/pages/about_app_page.dart';
import '../features/settings/pages/account_security_page.dart';
import '../features/settings/pages/app_preferences_page.dart';
import '../features/settings/pages/help_support_page.dart';
import '../features/settings/pages/location_settings_page.dart';
import '../features/settings/pages/notifications_settings_page.dart';
import '../features/settings/pages/privacy_settings_page.dart';
import '../features/verification/domain/residency_verification.dart';
import '../session_service.dart';
import '../widgets/user_profile_avatar.dart';

enum _PhotoAction { change, remove }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUpdatingPhoto = false;
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final isResident = user?.role == UserRole.resident;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 130;
    final headerBannerHeight = topPadding + 160;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: ESugidPullToRefresh(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: Column(
            children: [
              // 1. Top Wavy Header with "Profile" & Overlapping Avatar
              SizedBox(
                height: headerBannerHeight + 50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Multi-tone wavy green background painter
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: headerBannerHeight,
                      child: CustomPaint(
                        painter: _WavyHeaderPainter(colors: context.colors),
                      ),
                    ),

                    // Top Left "Profile" Title (No settings icon on right, as requested)
                    Positioned(
                      top: topPadding + 14,
                      left: 20,
                      child: Text(
                        'Profile',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.colors.onAccent,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                    // Center Avatar with camera button (overlapping the wavy banner)
                    Positioned(
                      top: topPadding + 52,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _buildAvatar(user, isResident)),
                    ),
                  ],
                ),
              ),

              // 2. User Identity Section (Name, Verified Badge, Location)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      user?.name.trim().isNotEmpty == true
                          ? user!.name.trim()
                          : 'Barili Resident',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildVerificationPill(user, isDark),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: context.colors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            user?.barangay?.trim().isNotEmpty == true
                                ? 'Barangay ${user!.barangay!.trim()}, Barili'
                                : 'Barili, Cebu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Menu List Cards (Settings options directly displayed on profile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (isResident && user != null)
                      _ProfileMenuCard(
                        icon: Icons.person_rounded,
                        iconColor: context.colors.primaryGreen,
                        iconBgColor: context.colors.surfaceAlt,
                        title: 'Personal Information',
                        subtitle: 'View and manage your personal details',
                        onTap: () => _showPersonalInformation(user),
                      ),

                    // 1. Account & Security
                    _ProfileMenuCard(
                      icon: Icons.lock_rounded,
                      iconColor: context.colors.primaryGreen,
                      iconBgColor: context.colors.surfaceAlt,
                      title: 'Account & Security',
                      subtitle: 'Change password and security settings',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AccountSecurityPage(),
                        ),
                      ),
                    ),

                    // 2. Notifications
                    _ProfileMenuCard(
                      icon: Icons.notifications_rounded,
                      iconColor: context.colors.info,
                      iconBgColor: context.colors.infoSurface,
                      title: 'Notifications',
                      subtitle: 'Manage your notification preferences',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsSettingsPage(),
                        ),
                      ),
                    ),

                    // 3. Location
                    _ProfileMenuCard(
                      icon: Icons.location_on_rounded,
                      iconColor: context.colors.error,
                      iconBgColor: context.colors.errorSurface,
                      title: 'Location',
                      subtitle: 'Manage location permission and map access',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationSettingsPage(),
                        ),
                      ),
                    ),

                    // 4. Privacy
                    _ProfileMenuCard(
                      icon: Icons.shield_rounded,
                      iconColor: context.colors.purple,
                      iconBgColor: context.colors.purpleSurface,
                      title: 'Privacy',
                      subtitle: 'Control your privacy settings and data',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySettingsPage(),
                        ),
                      ),
                    ),

                    // 5. App Preferences
                    _ProfileMenuCard(
                      icon: Icons.palette_rounded,
                      iconColor: context.colors.warning,
                      iconBgColor: context.colors.warningSurface,
                      title: 'App Preferences',
                      subtitle: 'Theme and text size',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppPreferencesPage(),
                        ),
                      ),
                    ),

                    // 6. Help & Support
                    _ProfileMenuCard(
                      icon: Icons.help_rounded,
                      iconColor: context.colors.primaryGreen,
                      iconBgColor: context.colors.surfaceAlt,
                      title: 'Help & Support',
                      subtitle: 'Get help or report a problem',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpSupportPage(),
                        ),
                      ),
                    ),

                    // 7. About
                    _ProfileMenuCard(
                      icon: Icons.info_rounded,
                      iconColor: context.colors.textSecondary,
                      iconBgColor: context.colors.surfaceAlt,
                      title: 'About',
                      subtitle: 'Terms, privacy policy, and app version',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutAppPage()),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _LogoutButton(
                      isLoading: _isLoggingOut,
                      onPressed: _isLoggingOut ? null : _confirmLogout,
                    ),
                    SizedBox(height: bottomClearance),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User? user, bool isResident) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Avatar circle with crisp white border and soft elevation
        Container(
          width: 102,
          height: 102,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.border, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: user == null
                ? Container(
                    color: context.colors.infoSurface,
                    child: Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: context.colors.info,
                    ),
                  )
                : UserProfileAvatar(user: user, size: 95),
          ),
        ),

        // Camera button on bottom right of the avatar
        if (isResident)
          Positioned(
            right: 0,
            bottom: 2,
            child: Material(
              color: context.colors.brand,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isUpdatingPhoto ? () {} : _showPhotoActions,
                child: Container(
                  width: 33,
                  height: 33,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.brand,
                    border: Border.all(color: context.colors.border, width: 2),
                  ),
                  child: Center(
                    child: _isUpdatingPhoto
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.surface,
                            ),
                          )
                        : Icon(
                            Icons.camera_alt_rounded,
                            size: 15.5,
                            color: context.colors.onAccent,
                          ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationPill(User? user, bool isDark) {
    final isVerified = user?.isVerified ?? false;
    final (label, icon, bgColor, textColor, borderColor,
    ) =
        switch (user?.verificationStatus) {
      VerificationStatus.verified => (
        'Verified Resident',
        Icons.check_circle_rounded,
        context.colors.successSurface,
        context.colors.primaryGreen,
        context.colors.primaryGreen,
      ),
      VerificationStatus.submitted || VerificationStatus.underReview => (
        'Pending Verification',
        Icons.schedule_rounded,
        context.colors.warningSurface,
        context.colors.warning,
        context.colors.warning,
      ),
      VerificationStatus.additionalDocumentRequired ||
      VerificationStatus.rejected => (
        'Needs Attention',
        Icons.error_outline_rounded,
        context.colors.errorSurface,
        context.colors.error,
        context.colors.error,
      ),
      _ => (
        isVerified ? 'Verified Resident' : 'Resident of Barili',
        isVerified ? Icons.check_circle_rounded : Icons.shield_outlined,
        context.colors.successSurface,
        context.colors.primaryGreen,
        context.colors.primaryGreen,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: textColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<ESugidRefreshOutcome> _refreshProfile() async {
    final previous = AuthService.currentUser?.toMap().toString() ?? '';
    final refreshed = await AuthService.refreshCurrentUserFromServer();
    if (mounted) setState(() {});
    return previous == refreshed.toMap().toString()
        ? ESugidRefreshOutcome.upToDate
        : ESugidRefreshOutcome.updated;
  }

  Future<void> _showPersonalInformation(User user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalInformationSheet(user: user),
    );
    if (saved == true && mounted) {
      setState(() {});
      _showMessage('Your personal information was updated.',
        kind: FeedbackKind.success,
      );
    }
  }

  Future<void> _showPhotoActions() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final hasPhoto = user.profilePhotoUrl?.trim().isNotEmpty == true;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ActionSheet(
        title: 'Profile photo',
        subtitle: 'Choose a clear photo of yourself.',
        children: [
          _SheetAction(
            icon: Icons.photo_library_outlined,
            title: hasPhoto ? 'Change photo' : 'Upload photo',
            subtitle: 'JPG, PNG, or WebP up to 8 MB',
            onTap: () => Navigator.pop(sheetContext, _PhotoAction.change),
          ),
          if (hasPhoto)
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              iconColor: sheetContext.colors.error,
              title: 'Remove photo',
              subtitle: 'Your initials will be shown instead.',
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
            ),
        ],
      ),
    );
    if (action == _PhotoAction.change) await _pickAndUploadPhoto(user);
    if (action == _PhotoAction.remove) await _removePhoto(user);
  }

  Future<void> _pickAndUploadPhoto(User user) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 84,
        maxWidth: 1440,
        maxHeight: 1440,
      );
      if (image == null) return;
      final byteLength = await image.length();
      final mimeType = _imageMimeType(image);
      if (byteLength > ESugidInputLimits.imageBytes || mimeType == null) {
        _showMessage('Choose a JPG, PNG, or WebP image up to 8 MB.',
          kind: FeedbackKind.warning,
        );
        return;
      }
      setState(() => _isUpdatingPhoto = true);
      final storagePath = 'profile_photos/${user.uid}/avatar';
      final reference = FirebaseStorage.instance.ref().child(storagePath);
      await reference.putData(
        await image.readAsBytes(),
        SettableMetadata(contentType: mimeType),
      );
      final downloadUrl = await reference.getDownloadURL();
      final error = await AuthService.updateResidentProfilePhoto(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
      );
      if (error != null) {
        _showMessage(error, kind: FeedbackKind.error);
        return;
      }
      if (mounted) {
        setState(() {});
        _showMessage('Profile photo updated.', kind: FeedbackKind.success);
      }
    } on FirebaseException catch (error) {
      _showMessage(
        error.code == 'permission-denied'
            ? 'You do not have permission to update this photo.'
            : 'Unable to upload your photo. Please try again.',
        kind: FeedbackKind.error,
      );
    } catch (error) {
      debugPrint('Profile photo upload failed: $error');
      _showMessage('Unable to upload your photo. Please try again.',
        kind: FeedbackKind.error,
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _removePhoto(User user) async {
    setState(() => _isUpdatingPhoto = true);
    final storagePath = 'profile_photos/${user.uid}/avatar';
    try {
      final error = await AuthService.updateResidentProfilePhoto(
        downloadUrl: null,
        storagePath: storagePath,
      );
      if (error != null) {
        _showMessage(error, kind: FeedbackKind.error);
        return;
      }
      try {
        await FirebaseStorage.instance.ref().child(storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          debugPrint('Old profile photo cleanup failed: ${error.code}');
        }
      }
      if (mounted) {
        setState(() {});
        _showMessage('Profile photo removed.', kind: FeedbackKind.success);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  // Enhanced Logout Dialog & Fast Execution
  Future<void> _confirmLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        final colors = Theme.of(modalContext).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: modalContext.colors.shadow.withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 22),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      modalContext.colors.errorSolid.withValues(alpha: 0.18),
                      modalContext.colors.errorSolid.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: modalContext.colors.error.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    color: modalContext.colors.error,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Log out of E-SUGID?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out? You will need your credentials to log back into your Barili resident account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Stay Signed In',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(modalContext, true),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: modalContext.colors.errorSolid,
                        foregroundColor: modalContext.colors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      await SessionService.logout();
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      debugPrint('Logout failed: $error');
      if (mounted) {
        setState(() => _isLoggingOut = false);
        _showMessage('Unable to log out. Please try again.',
          kind: FeedbackKind.error,
        );
      }
    }
  }

  String? _imageMimeType(XFile file) {
    final supplied = file.mimeType?.toLowerCase();
    if (ESugidValidators.isSupportedImageMimeType(supplied)) return supplied!;
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  void _showMessage(String message, {FeedbackKind kind = FeedbackKind.info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppSnackBar(AppSnackBar(content: Text(message), kind: kind));
  }
}

/// Wavy organic layered header matching the photo design
class _WavyHeaderPainter extends CustomPainter {
  final ESugidColors colors;
  const _WavyHeaderPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Dark forest green base gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.brandStrong, colors.brand],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Wave 1: Deep emerald undulating wave
    final wave1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.brandAlt.withValues(alpha: 0.85),
          colors.brandStrong.withValues(alpha: 0.95),
              ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final path1 = Path();
    path1.moveTo(0, h * 0.44);
    path1.cubicTo(
      w * 0.28, h * 0.38,
      w * 0.62, h * 0.58,
      w, h * 0.46);
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();
    canvas.drawPath(path1, wave1Paint);

    // 3. Wave 2: Sage / vibrant mint wave
    final wave2Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          colors.brandAlt.withValues(alpha: 0.70),
          colors.brand.withValues(alpha: 0.80),
              ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final path2 = Path();
    path2.moveTo(0, h * 0.62);
    path2.cubicTo(
      w * 0.35, h * 0.72,
      w * 0.68, h * 0.50,
      w, h * 0.62);
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();
    canvas.drawPath(path2, wave2Paint);

    // 4. Wave 3: Soft pale mint curve
    final wave3Paint = Paint()
      ..color = colors.surfaceAlt;
    final path3 = Path();
    path3.moveTo(0, h * 0.78);
    path3.cubicTo(
      w * 0.25, h * 0.70,
      w * 0.72, h * 0.88,
      w, h * 0.74);
    path3.lineTo(w, h);
    path3.lineTo(0, h);
    path3.close();
    canvas.drawPath(path3, wave3Paint);

    // 5. Wave 4: Bottom curve seamlessly flowing into page background
    final wave4Paint = Paint()
      ..color = colors.background;
    final path4 = Path();
    path4.moveTo(0, h * 0.88);
    path4.cubicTo(
      w * 0.30, h * 0.85,
      w * 0.65, h * 0.98,
      w, h * 0.88);
    path4.lineTo(w, h);
    path4.lineTo(0, h);
    path4.close();
    canvas.drawPath(path4, wave4Paint);
  }

  @override
  bool shouldRepaint(covariant _WavyHeaderPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

/// Floating profile menu card with mint squircle icon, title, subtitle & chevron
class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconBgColor = iconBgColor ??
        (isDark
            ? context.colors.surfaceAlt.withValues(alpha: 0.16)
            : context.colors.surfaceAlt);
    final effectiveIconColor = iconColor ??
        (context.colors.primaryGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border,
          width: 1.1),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: isDark ? 0.22 : 0.035,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: effectiveIconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.info,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Red outlined logout button matching photo
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoading, required this.onPressed});
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.errorSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border,
          width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.errorSolid.withValues(alpha: isDark ? 0.15 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.errorSolid,
                    ),
                  )
                else
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: context.colors.error,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isLoading ? 'Signing out…' : 'Log Out',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      color: context.colors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
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

class _PersonalInformationSheet extends StatefulWidget {
  const _PersonalInformationSheet({required this.user});
  final User user;

  @override
  State<_PersonalInformationSheet> createState() =>
      _PersonalInformationSheetState();
}

class _PersonalInformationSheetState extends State<_PersonalInformationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthDateController;
  bool _saving = false;
  String? _error;

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          parseResidentBirthDate(_birthDateController.text) ??
          DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected == null) return;
    setState(() {
      _birthDateController.text = registrationBirthDateValue(selected);
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _mobileController = TextEditingController(
      text: ESugidValidators.localPhilippineMobile(
        widget.user.contactNumber ?? '',
      ),
    );
    _addressController = TextEditingController(text: widget.user.address ?? '');
    final birthDate = parseResidentBirthDate(widget.user.birthDate);
    if (birthDate != null) {
      _birthDateController = TextEditingController(
        text: registrationBirthDateValue(birthDate),
      );
    } else {
      final cached = AuthService.getCachedBirthDateFor(
        uid: widget.user.uid,
        email: widget.user.email,
        name: widget.user.name,
      );
      final parsedCached = parseResidentBirthDate(cached);
      _birthDateController = TextEditingController(
        text: parsedCached != null ? registrationBirthDateValue(parsedCached) : '',
      );
      _resolveStoredBirthDate();
    }
  }

  Future<void> _resolveStoredBirthDate() async {
    final recovered = await AuthService.recoverCachedBirthDate(
      uid: widget.user.uid,
      email: widget.user.email,
      name: widget.user.name,
    );
    if (recovered != null && mounted) {
      final parsed = parseResidentBirthDate(recovered);
      if (parsed != null && _birthDateController.text.isEmpty) {
        setState(() {
          _birthDateController.text = registrationBirthDateValue(parsed);
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final mobile = ESugidValidators.normalizePhilippineMobile(
      _mobileController.text,
    );
    if (mobile == null) return;
    final birthDate = parseResidentBirthDate(_birthDateController.text);
    if (birthDate == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    AuthService.cacheBirthDateInMemory(
      wireDate: storedBirthDateValue(birthDate),
      uid: widget.user.uid,
      email: widget.user.email,
      name: widget.user.name,
    );
    final error = await AuthService.updateResidentPersonalInformation(
      name: _nameController.text,
      contactNumber: mobile,
      address: _addressController.text,
      birthDate: storedBirthDateValue(birthDate),
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final barangayName = widget.user.barangay?.trim().isNotEmpty == true
        ? widget.user.barangay!.trim()
        : 'Barili Resident';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              Text(
                'Personal Information',
                style: GoogleFonts.outfit(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Personal details registered to your Barili citizen account.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Registered Account Details (From Account Creation)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? context.colors.surfaceAlt.withValues(alpha: 0.05)
                      : context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? context.colors.border.withValues(alpha: 0.1216)
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_city_rounded,
                        size: 20,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REGISTERED BARANGAY',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Theme.of(context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Barangay $barangayName, Barili, Cebu',
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'REGISTERED',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primaryGreen,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? context.colors.surface.withValues(alpha: 0.05)
                      : context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? context.colors.border.withValues(alpha: 0.1216)
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colors.infoSolid.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.alternate_email_rounded,
                        size: 20,
                        color: context.colors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REGISTERED ACCOUNT EMAIL',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Theme.of(context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.email,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: ESugidInputLimits.fullName,
                decoration: _fieldDecoration(
                  context,
                  'Full name', Icons.person_outline,
                ),
                validator: ESugidValidators.fullName,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                inputFormatters: const [PhilippineMobileInputFormatter()],
                decoration: _fieldDecoration(
                  context,
                  'Mobile number',
                  Icons.phone_outlined,
                ),
                validator: ESugidValidators.philippineMobile,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                maxLength: ESugidInputLimits.address,
                maxLines: 2,
                decoration: _fieldDecoration(
                  context,
                  'Address / Purok',
                  Icons.home_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Purok / Sitio is required';
                  }
                  return ESugidValidators.optionalText(
                    value,
                    label: 'Purok / Sitio',
                    maxLength: ESugidInputLimits.address,
                  );
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _birthDateController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration:
                    _fieldDecoration(
                      context,
                      'Birth date (MM/DD/YYYY)',
                      Icons.cake_outlined,
                    ).copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Choose date',
                        onPressed: _selectBirthDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                validator: validateResidentBirthDate,
              ),
              if (parseResidentBirthDate(_birthDateController.text)
                  case final birthDate?)
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 4),
                  child: Text(
                    'Age: ${residentAge(birthDate)} years old',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Verified barangay, account role, verification status, and permissions are protected and cannot be edited here.',
                        style: GoogleFonts.outfit(fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _InlineError(_error!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.surface,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save changes'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 18),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: (iconColor ?? Theme.of(context).colorScheme.primary).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: iconColor ?? Theme.of(context).colorScheme.primary,
      ),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({required this.currentEmail});
  final String currentEmail;
  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await AuthService.changeEmail(
      currentPassword: _passwordController.text,
      newEmail: _emailController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change Email'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.newUsername],
              decoration: _fieldDecoration(
                context,
                'New email address',
                Icons.alternate_email_rounded,
              ),
              validator: (value) {
                final formatError = ESugidValidators.email(value);
                if (formatError != null) return formatError;
                final suggestion = ESugidValidators.commonEmailDomainSuggestion(
                  value,
                );
                if (suggestion != null) {
                  return 'Did you mean ${suggestion.correctedEmail}?';
                }
                if (ESugidValidators.normalizeEmail(value!) ==
                    ESugidValidators.normalizeEmail(widget.currentEmail)) {
                  return 'Enter a different email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              decoration:
                  _fieldDecoration(
                    context,
                    'Current password',
                    Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
              validator: (value) => value?.isEmpty == true
                  ? 'Current password is required'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(_error!),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Sending…' : 'Send verification'),
      ),
    ],
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _showPasswords = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await AuthService.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change Password'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _passwordField(_currentController, 'Current password'),
            const SizedBox(height: 12),
            _passwordField(
              _newController,
              'New password',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'New password is required';
                }
                if (value.length < 6) {
                  return 'Use at least 6 characters';
                }
                if (value == _currentController.text) {
                  return 'Choose a different password';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _passwordField(
              _confirmController,
              'Confirm new password',
              validator: (value) => value != _newController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(_error!),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Updating…' : 'Update password'),
      ),
    ],
  );

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: controller,
    obscureText: !_showPasswords,
    decoration: _fieldDecoration(context, label, Icons.lock_outline_rounded).copyWith(
      suffixIcon: IconButton(
        onPressed: () => setState(() => _showPasswords = !_showPasswords),
        icon: Icon(
          _showPasswords
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    ),
    validator:
        validator ??
        (value) => value?.isEmpty == true ? '$label is required' : null,
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.error_outline_rounded, size: 17, color: context.colors.error),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          message,
          style: TextStyle(color: context.colors.error, fontSize: 12),
        ),
      ),
    ],
  );
}

InputDecoration _fieldDecoration(
  BuildContext context,
  String label, IconData icon,
) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
    );
