import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

typedef AppPermissionRequester = Future<void> Function();
typedef AppPermissionAccessChecker =
    Future<RequiredNotificationAccess> Function();
typedef AppPermissionSettingsOpener = Future<void> Function();

const MethodChannel _permissionChannel = MethodChannel(
  'com.esugid.barili/notifications',
);

enum NotificationPermissionState { enabled, notDetermined, denied }

class RequiredNotificationAccess {
  final bool notifications;
  final bool emergencyAlerts;
  final bool emergencyPopups;
  final bool location;
  final NotificationPermissionState notificationState;

  const RequiredNotificationAccess({
    required this.notifications,
    this.emergencyAlerts = true,
    this.emergencyPopups = false,
    this.location = false,
    this.notificationState = NotificationPermissionState.notDetermined,
  });

  bool get granted => notifications;
  bool get notificationWasDenied =>
      !notifications && notificationState == NotificationPermissionState.denied;
}

Future<RequiredNotificationAccess> checkRequiredNotificationAccess() async {
  var notifications = false;
  var notificationState = NotificationPermissionState.notDetermined;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    notifications =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    notificationState = notifications
        ? NotificationPermissionState.enabled
        : settings.authorizationStatus == AuthorizationStatus.notDetermined
        ? NotificationPermissionState.notDetermined
        : NotificationPermissionState.denied;
  } catch (error) {
    debugPrint('Required notification access check failed: $error');
  }

  var emergencyAlerts = true;
  var emergencyPopups = false;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      emergencyAlerts =
          await _permissionChannel.invokeMethod<bool>(
            'canUseFullScreenIntent',
          ) ??
          false;
    } catch (error) {
      emergencyAlerts = false;
      debugPrint('Emergency alert access check failed: $error');
    }
    try {
      emergencyPopups =
          await _permissionChannel.invokeMethod<bool>(
            'canDrawEmergencyOverlay',
          ) ??
          false;
    } catch (error) {
      debugPrint('Emergency popup access check failed: $error');
    }
  }

  var location = false;
  try {
    final permission = await Geolocator.checkPermission();
    location =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  } catch (error) {
    debugPrint('Optional location access check failed: $error');
  }

  return RequiredNotificationAccess(
    notifications: notifications,
    emergencyAlerts: emergencyAlerts,
    emergencyPopups: emergencyPopups,
    location: location,
    notificationState: notificationState,
  );
}

/// Requests only the permission required for application notifications.
/// Location remains optional and is requested by the feature that needs it.
Future<void> requestRequiredAppPermissions() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }
  } catch (error) {
    debugPrint('Notification permission setup was skipped: $error');
  }
}

Future<void> openAppNotificationSettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _permissionChannel.invokeMethod<void>('openNotificationSettings');
}

Future<void> openEmergencyAlertSettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _permissionChannel.invokeMethod<void>('openFullScreenIntentSettings');
}

Future<void> openEmergencyPopupSettings() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await _permissionChannel.invokeMethod<void>('openEmergencyOverlaySettings');
}

class PermissionSetupScreen extends StatefulWidget {
  final Future<void> Function() onComplete;
  final Future<void> Function()? onContinueWithoutAccess;
  final AppPermissionRequester permissionRequester;
  final AppPermissionAccessChecker accessChecker;
  final AppPermissionSettingsOpener notificationSettingsOpener;
  final AppPermissionSettingsOpener emergencySettingsOpener;
  final AppPermissionSettingsOpener popupSettingsOpener;

  const PermissionSetupScreen({
    super.key,
    required this.onComplete,
    this.onContinueWithoutAccess,
    this.permissionRequester = requestRequiredAppPermissions,
    this.accessChecker = checkRequiredNotificationAccess,
    this.notificationSettingsOpener = openAppNotificationSettings,
    this.emergencySettingsOpener = openEmergencyAlertSettings,
    this.popupSettingsOpener = openEmergencyPopupSettings,
  });

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  bool _isRequesting = false;
  bool _isChecking = true;
  bool _showNotificationSettingsAction = false;
  String? _message;
  RequiredNotificationAccess _access = const RequiredNotificationAccess(
    notifications: false,
    emergencyAlerts: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<RequiredNotificationAccess> _refreshAccess() async {
    final access = await widget.accessChecker();
    if (mounted) {
      setState(() {
        _access = access;
        _isChecking = false;
        if (access.notifications) {
          _message = null;
          _showNotificationSettingsAction = false;
        }
      });
    }
    return access;
  }

  Future<void> _openNotificationSettings() async {
    try {
      await widget.notificationSettingsOpener();
    } catch (error) {
      debugPrint('Notification settings could not be opened: $error');
      if (mounted) {
        setState(() {
          _message =
              'Open E-SUGID notification settings from Android Settings.';
        });
      }
    }
  }

  Future<void> _requestNotifications() async {
    if (_isRequesting) return;
    setState(() {
      _isRequesting = true;
      _message = null;
      _showNotificationSettingsAction = false;
    });
    try {
      if (_access.notificationWasDenied) {
        setState(() {
          _message =
              'Emergency notifications are disabled. You may miss urgent barangay alerts.';
          _showNotificationSettingsAction = true;
        });
        await _openNotificationSettings();
        return;
      }

      await widget.permissionRequester();
      final access = await _refreshAccess();
      if (!access.notifications && mounted) {
        setState(() {
          _message =
              'Emergency notifications are disabled. You may miss urgent barangay alerts.';
          _showNotificationSettingsAction = access.notificationWasDenied;
        });
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _handleBottomAction() async {
    if (_isRequesting || _isChecking) return;
    if (_access.granted) {
      await widget.onComplete();
      return;
    }
    await _requestNotifications();
  }

  Future<void> _openEmergencySettings() async {
    if (_access.emergencyAlerts) return;
    try {
      await widget.emergencySettingsOpener();
    } catch (error) {
      debugPrint('Emergency alert settings could not be opened: $error');
      if (mounted) {
        setState(() {
          _message =
              'Full-screen access is optional. Emergency alerts will still use a high-priority notification.';
          _showNotificationSettingsAction = false;
        });
      }
    }
  }

  Future<void> _openPopupSettings() async {
    if (_access.emergencyPopups) return;
    try {
      await widget.popupSettingsOpener();
    } catch (error) {
      debugPrint('Emergency popup settings could not be opened: $error');
      if (mounted) {
        setState(() {
          _message =
              'To show emergency popups over other apps, allow Display over other apps in Android Settings.';
        });
      }
    }
  }

  Future<void> _requestLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      await _refreshAccess();
      if (permission == LocationPermission.deniedForever && mounted) {
        setState(() {
          _message =
              'Location permission is permanently denied. You can enable it in Android Settings if needed.';
        });
      }
    } catch (error) {
      debugPrint('Optional location access check failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Ambient soft depth orbs matching E-Sugid aesthetic
          Positioned(
            top: -70,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.brand.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.warningSolid.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brandStrong.withValues(alpha: 0.09,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: context.colors.highlight,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3D Shield security badge
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            ),
                            border: Border.all(
                              color: context.colors.border,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.28,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: context.colors.onAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Allow app access',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.colors.textPrimary,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'E-SUGID uses these permissions so you can receive important community updates and emergency alerts.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                            fontSize: 13.5,
                            height: 1.42,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _PermissionItem(
                          key: const ValueKey('notification-permission-row'),
                          icon: Icons.notifications_active_rounded,
                          title: 'Required notifications',
                          description:
                              'Receive announcements, service updates, and emergency alerts.',
                          status: _access.notifications ? 'Enabled' : 'Required',
                          state: _access.notifications
                              ? _PermissionVisualState.enabled
                              : _PermissionVisualState.required,
                          onTap: _access.notifications
                              ? null
                              : _requestNotifications,
                          onToggle: (val) {
                            if (val && !_access.notifications) {
                              _requestNotifications();
                            } else if (!val && _access.notifications) {
                              _openNotificationSettings();
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _PermissionItem(
                          key: const ValueKey('emergency-permission-row'),
                          icon: Icons.warning_amber_rounded,
                          title: 'Emergency alerts',
                          description:
                              'Allow urgent emergency alerts to appear prominently, including on the lock screen when Android permits it.',
                          status: _access.emergencyAlerts
                              ? 'Enabled'
                              : 'Needs attention',
                          state: _access.emergencyAlerts
                              ? _PermissionVisualState.enabled
                              : _PermissionVisualState.attention,
                          onTap: _access.emergencyAlerts
                              ? null
                              : _openEmergencySettings,
                          onToggle: (val) {
                            if (val && !_access.emergencyAlerts) {
                              _openEmergencySettings();
                            } else if (!val && _access.emergencyAlerts) {
                              _openEmergencySettings();
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _PermissionItem(
                          key: const ValueKey('emergency-popup-permission-row'),
                          icon: Icons.open_in_new_rounded,
                          title: 'Emergency popups',
                          description:
                              'Show a centered emergency alert over the unlocked home screen or other apps. Requires Display over other apps access.',
                          status: _access.emergencyPopups
                              ? 'Enabled'
                              : 'Needs attention',
                          state: _access.emergencyPopups
                              ? _PermissionVisualState.enabled
                              : _PermissionVisualState.attention,
                          onTap: _access.emergencyPopups
                              ? null
                              : _openPopupSettings,
                          onToggle: (val) {
                            if (val && !_access.emergencyPopups) {
                              _openPopupSettings();
                            } else if (!val && _access.emergencyPopups) {
                              _openPopupSettings();
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _PermissionItem(
                          key: const ValueKey('location-permission-row'),
                          icon: Icons.location_on_rounded,
                          title: 'Location',
                          description:
                              'Use your location only when needed for barangay-based services.',
                          status: _access.location ? 'Enabled' : 'Optional',
                          state: _access.location
                              ? _PermissionVisualState.enabled
                              : _PermissionVisualState.optional,
                          onTap: _access.location ? null : _requestLocation,
                          onToggle: (val) {
                            if (val && !_access.location) {
                              _requestLocation();
                            } else if (!val && _access.location && mounted) {
                              ScaffoldMessenger.of(context).showAppSnackBar(
                                AppSnackBar(
                                  content: Text(
                                    'Location can be disabled anytime in Android Settings.',
                                  ),
                                  duration: Duration(seconds: 2),
                                  kind: FeedbackKind.info,
                                ),
                              );
                            }
                          },
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
                            decoration: BoxDecoration(
                              color: context.colors.warningSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _message!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: context.colors.warning,
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_showNotificationSettingsAction)
                                  TextButton.icon(
                                    key: const ValueKey('open-settings-button'),
                                    onPressed: _openNotificationSettings,
                                    icon: const Icon(
                                      Icons.settings_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Open Settings'),
                                  ),
                                if (_showNotificationSettingsAction &&
                                    widget.onContinueWithoutAccess != null)
                                  TextButton(
                                    key: const ValueKey(
                                      'continue-with-limited-alerts-button',
                                    ),
                                    onPressed: widget.onContinueWithoutAccess,
                                    child: const Text(
                                      'Continue with limited alerts',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(alpha: 0.32,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IgnorePointer(
                            ignoring: _isRequesting || _isChecking,
                            child: FilledButton.icon(
                              key: const ValueKey('allow-permissions-button'),
                              onPressed: _handleBottomAction,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: context.colors.onAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _isRequesting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: context.colors.surface,
                                      ),
                                    )
                                  : Icon(
                                      _access.granted
                                          ? Icons.arrow_forward_rounded
                                          : Icons.notifications_active_rounded,
                                    ),
                              label: Text(
                                _isRequesting
                                    ? 'Checking access...'
                                    : _access.granted
                                    ? 'Continue'
                                    : 'Enable required access',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Full-screen presentation is optional. Emergency alerts still use a high-priority notification when it is unavailable.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: context.colors.textSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

enum _PermissionVisualState { enabled, required, attention, optional }

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String status;
  final _PermissionVisualState state;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  const _PermissionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.state,
    this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state == _PermissionVisualState.enabled;
    final optional = state == _PermissionVisualState.optional;

    final Color statusBg;
    final Color statusBorder;
    final Color statusColor;
    final IconData statusIcon;

    if (enabled) {
      statusBg = context.colors.successSurface;
      statusBorder = context.colors.primaryGreen;
      statusColor = context.colors.primaryGreen;
      statusIcon = Icons.check_circle_rounded;
    } else if (optional) {
      statusBg = context.colors.surfaceAlt;
      statusBorder = context.colors.textSecondary;
      statusColor = context.colors.textSecondary;
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusBg = context.colors.warningSurface;
      statusBorder = context.colors.warning;
      statusColor = context.colors.warning;
      statusIcon = Icons.error_outline_rounded;
    }

    final Color iconBoxBg = enabled
        ? context.colors.surfaceAlt
        : optional
        ? context.colors.surfaceAlt
        : context.colors.warningSurface;

    final Color iconColor = enabled
        ? context.colors.primaryGreen
        : optional
        ? context.colors.textSecondary
        : context.colors.warning;

    return Semantics(
      label: '$title, ${status.toLowerCase()}',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? context.colors.surface : context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: enabled ? context.colors.border : context.colors.border,
                width: enabled ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandStrong.withValues(
                    alpha: enabled ? 0.05 : 0.03,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // 3D curved squircle icon tile
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enabled
                          ? context.colors.border
                          : optional
                          ? context.colors.border
                          : context.colors.border,
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),

                const SizedBox(width: 12),

                // Title, Status Pill, Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: context.colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontSize: 11.8,
                          height: 1.34,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Compact status tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusBorder,
                            width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 3.5),
                            Flexible(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Modern Barili-themed Toggle Switch
                Transform.scale(
                  scale: 0.86,
                  child: Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeTrackColor: context.colors.brand,
                    activeThumbColor: context.colors.surface,
                    inactiveTrackColor: context.colors.surfaceAlt,
                    inactiveThumbColor: context.colors.surface,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (_) => Colors.transparent,
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
