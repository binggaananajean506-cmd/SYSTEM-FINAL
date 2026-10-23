import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esugid/home_screen.dart';
import 'package:esugid/login_screen.dart';
import 'package:esugid/pages/concern_center_page.dart';
import 'package:esugid/pages/submissions_history_page.dart';
import 'package:esugid/pages/barangay_page.dart';
import 'package:esugid/pages/officials_page.dart';
import 'package:esugid/pages/jobs_page.dart' show JobsPage;
import 'package:esugid/pages/marketplace_page.dart';
import 'package:esugid/admin_web_handoff_screen.dart';
import 'package:esugid/auth_service.dart';
import 'package:esugid/email_otp_verification_screen.dart';
import 'package:esugid/pending_approval_screen.dart';
import 'package:esugid/verification_screen.dart';
import 'package:esugid/pages/trust_safety_dashboard.dart';
import 'package:esugid/pages/public_user_profile_page.dart';
import 'package:esugid/app_theme_controller.dart';
import 'package:esugid/features/settings/app_preferences_controller.dart';
import 'package:esugid/features/settings/pages/settings_page.dart';
import 'package:esugid/onboarding_screen.dart';
import 'package:esugid/permission_setup_screen.dart';
import 'package:esugid/app_motion.dart';
import 'package:esugid/announcement_notification_service.dart';
import 'package:esugid/notification_service.dart';
import 'package:esugid/features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';
import 'package:esugid/features/calendar/presentation/calendar_page.dart';
import 'package:esugid/community_service.dart';
import 'package:esugid/emergency_service.dart';
import 'package:esugid/emergency_alarm_service.dart';
import 'package:esugid/emergency_alert_service.dart';
import 'package:esugid/pages/emergency_details_page.dart';
import 'package:esugid/session_service.dart';
import 'package:esugid/app_launch_preferences.dart';
import 'package:esugid/features/home/data/dashboard_announcement_cache.dart';
import 'package:esugid/services/announcement_image_cache.dart';
import 'package:esugid/services/resident_presence_service.dart';
import 'package:esugid/splash_screen.dart';
import 'package:esugid/app/theme/esugid_clay_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final type =
      message.data['notificationType']?.toString().toLowerCase() ??
      message.data['type']?.toString().toLowerCase();
  if (type != 'emergency' && type != 'emergency_alert') return;
  final emergencyId =
      message.data['emergencyId']?.toString() ??
      message.data['alertId']?.toString();
  if (emergencyId == null || emergencyId.isEmpty) return;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('last_background_emergency_id', emergencyId);
  await preferences.setInt(
    'last_background_emergency_received_at',
    DateTime.now().millisecondsSinceEpoch,
  );
  debugPrint(
    '[EMERGENCY] Background message received id=$emergencyId message=${message.messageId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppThemeController.initialize();
  } catch (error) {
    debugPrint(
      'Appearance storage unavailable; using the system theme: $error',
    );
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<AppLaunchState> _initialization = _initialize();

  Future<AppLaunchState> _initialize() async {
    final minimumSplashTime = Future<void>.delayed(
      const Duration(milliseconds: 1150),
    );
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await AppPreferencesController.initialize();
    try {
      await AnnouncementImageCache.initialize();
      final cachedPosts = await DashboardAnnouncementCache().load();
      for (final post in cachedPosts.take(4)) {
        if (post.localImagePath.isEmpty && post.imageUrl.isNotEmpty) {
          unawaited(AnnouncementImageCache.downloadAndCache(post.imageUrl));
        }
      }
    } catch (_) {}
    final savedLaunchState = await AppLaunchPreferences.load();
    final requiredAccess = savedLaunchState.permissionSetupCompleted
        ? await checkRequiredNotificationAccess()
        : null;
    var permissionSetupCompleted = savedLaunchState.permissionSetupCompleted;
    var notificationAccessWasEnabled =
        savedLaunchState.requiredNotificationAccessWasEnabled;
    if (requiredAccess?.granted == true && !notificationAccessWasEnabled) {
      await AppLaunchPreferences.markNotificationAccessEnabled();
      notificationAccessWasEnabled = true;
    } else if (notificationAccessWasEnabled &&
        requiredAccess?.granted == false) {
      // Access was granted previously and has since been disabled, so guide
      // the resident back to setup. Residents who explicitly continued with
      // limited alerts are not trapped on this screen every launch.
      permissionSetupCompleted = false;
    }
    final launchState = AppLaunchState(
      onboardingCompleted: savedLaunchState.onboardingCompleted,
      permissionSetupCompleted: permissionSetupCompleted,
      requiredNotificationAccessWasEnabled: notificationAccessWasEnabled,
    );

    // Pre-warm auth and profile concurrently while splash is showing
    try {
      final fbUser =
          auth.FirebaseAuth.instance.currentUser ??
          await auth.FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(milliseconds: 1000),
            onTimeout: () => null,
          );
      if (fbUser != null) {
        await AuthService.currentUserDocStream.first.timeout(
          const Duration(milliseconds: 1000),
          onTimeout: () => null,
        );
      }
    } catch (_) {
      // Fallback handled safely by _AuthenticatedEntry
    }

    await minimumSplashTime;
    return launchState;
  }

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, mode, child) => FutureBuilder<AppLaunchState>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _lightTheme,
              darkTheme: _darkTheme,
              themeMode: mode,
              themeAnimationDuration: Duration.zero,
              builder: _startupSystemBars,
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 52),
                        const SizedBox(height: 16),
                        const Text(
                          'E-Sugid could not start.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your internet connection, then try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _lightTheme,
              darkTheme: _darkTheme,
              themeMode: mode,
              themeAnimationDuration: Duration.zero,
              builder: _startupSystemBars,
              home: const ESugidSplashScreen(),
            );
          }
          final launchState = snapshot.requireData;
          return ESugidApp(themeMode: mode, initialLaunchState: launchState);
        },
      ),
    );
  }
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final _lightTheme = buildESugidClayTheme(Brightness.light);
final _darkTheme = buildESugidClayTheme(Brightness.dark);

Widget _startupSystemBars(BuildContext context, Widget? child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: context.colors.background,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
    child: child!,
  );
}

class ESugidApp extends StatelessWidget {
  final ThemeMode themeMode;
  final AppLaunchState initialLaunchState;

  const ESugidApp({
    super.key,
    this.themeMode = ThemeMode.system,
    this.initialLaunchState = const AppLaunchState(
      onboardingCompleted: false,
      permissionSetupCompleted: false,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'E-Sugid',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: ESugidMotion.enterCurve,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ValueListenableBuilder<double>(
          valueListenable: AppPreferencesController.textScaleFactor,
          builder: (context, textScale, _) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: Theme.of(
                    context,
                  ).scaffoldBackgroundColor,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
      home: _AppEntryGate(initialLaunchState: initialLaunchState),
      routes: {
        '/settings': (context) => const SettingsPage(),
        '/home': (context) => const HomeScreen(),
        '/alerts': (context) => const HomeScreen(initialPage: 1),
        '/emergency': (context) {
          final emergencyId =
              ModalRoute.settingsOf(context)?.arguments?.toString() ?? '';
          return EmergencyDetailsPage(emergencyId: emergencyId);
        },
        '/admin': (context) => const AdminWebHandoffScreen(),
        '/complain': (context) => const ConcernCenterPage(),
        '/submissions': (context) => const SubmissionsHistoryPage(),
        '/barangay': (context) {
          final user = AuthService.currentUser;
          return BarangayPage(
            initialData: user,
            initialPosts: CommunityService.latestBarangayPosts(user?.barangay),
          );
        },
        '/officials': (context) => const OfficialsPage(),
        '/jobs': (context) => JobsPage(
          initialRequestId:
              ModalRoute.settingsOf(context)?.arguments as String?,
        ),
        '/bayanihan-messages': (context) => const BayanihanMessagesPage(),
        '/marketplace': (context) => MarketplacePage(),
        '/calendar': (context) => const CalendarPage(),
        '/verification': (context) => const VerificationScreen(),
        '/trust_safety': (context) => const TrustSafetyDashboard(),
        '/user-profile': (context) {
          final args = ModalRoute.settingsOf(context)?.arguments;
          if (args is Map<String, dynamic>) {
            return PublicUserProfilePage(
              userId: args['userId']?.toString() ?? '',
              initialName: args['name']?.toString(),
              initialPhotoUrl: args['photoUrl']?.toString(),
              initialBarangay: args['barangay']?.toString(),
            );
          }
          return PublicUserProfilePage(userId: args?.toString() ?? '');
        },
      },
    );
  }
}

class _AppEntryGate extends StatefulWidget {
  final AppLaunchState initialLaunchState;

  const _AppEntryGate({required this.initialLaunchState});

  @override
  State<_AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<_AppEntryGate> {
  late _AppEntryStage _stage;

  @override
  void initState() {
    super.initState();
    _stage = _initialStage(widget.initialLaunchState);
  }

  _AppEntryStage _initialStage(AppLaunchState state) {
    if (!state.onboardingCompleted) return _AppEntryStage.onboarding;
    if (!state.permissionSetupCompleted) return _AppEntryStage.permissions;
    return _AppEntryStage.authenticated;
  }

  Future<void> _completeOnboarding() async {
    await AppLaunchPreferences.markOnboardingCompleted();
    if (!mounted) return;
    setState(() => _stage = _AppEntryStage.permissions);
  }

  Future<void> _completePermissionSetup() async {
    await AppLaunchPreferences.markPermissionSetupCompleted(
      notificationAccessEnabled: true,
    );
    if (!mounted) return;
    setState(() => _stage = _AppEntryStage.authenticated);
  }

  Future<void> _continueWithLimitedNotifications() async {
    await AppLaunchPreferences.markPermissionSetupCompleted(
      notificationAccessEnabled: false,
    );
    if (!mounted) return;
    setState(() => _stage = _AppEntryStage.authenticated);
  }

  @override
  Widget build(BuildContext context) {
    return ESugidAnimatedSwap(
      duration: ESugidMotion.emphasized,
      child: switch (_stage) {
        _AppEntryStage.onboarding => KeyedSubtree(
          key: const ValueKey('onboarding-entry'),
          child: OnboardingScreen(onComplete: _completeOnboarding),
        ),
        _AppEntryStage.permissions => KeyedSubtree(
          key: const ValueKey('permission-entry'),
          child: PermissionSetupScreen(
            onComplete: _completePermissionSetup,
            onContinueWithoutAccess: _continueWithLimitedNotifications,
          ),
        ),
        _AppEntryStage.authenticated => const KeyedSubtree(
          key: ValueKey('authenticated-entry'),
          child: _AuthenticatedEntry(),
        ),
      },
    );
  }
}

enum _AppEntryStage { onboarding, permissions, authenticated }

class _AuthenticatedEntry extends StatefulWidget {
  const _AuthenticatedEntry();

  @override
  State<_AuthenticatedEntry> createState() => _AuthenticatedEntryState();
}

class _AuthenticatedEntryState extends State<_AuthenticatedEntry> {
  StreamSubscription<auth.User?>? _authSubscription;
  StreamSubscription<User?>? _profileSubscription;
  StreamSubscription<RemoteMessage>? _foregroundNotificationSubscription;
  StreamSubscription<RemoteMessage>? _openedNotificationSubscription;
  auth.User? _firebaseUser;
  User? _profile;
  Object? _sessionError;
  bool _isLoading = true;
  bool _emergencyDialogVisible = false;
  String? _initializedUserId;
  int _sessionGeneration = 0;
  Timer? _restrictionExpiryTimer;

  @override
  void initState() {
    super.initState();
    final initialFbUser = auth.FirebaseAuth.instance.currentUser;
    final initialProfile = AuthService.currentUser;
    if (initialFbUser != null && initialProfile != null) {
      _firebaseUser = initialFbUser;
      _profile = initialProfile;
      _isLoading = false;
    } else if (initialFbUser == null) {
      _isLoading = false;
    }
    _authSubscription = auth.FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
      onError: _handleSessionError,
    );
    _foregroundNotificationSubscription = NotificationService.foregroundMessages
        .listen((message) async {
          if (!mounted) return;
          final type =
              message.data['notificationType']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              message.data['type']?.toString().trim().toLowerCase();
          if (type == 'bayanihan_new_message') return;
          if (type == 'emergency_alert' || type == 'emergency') {
            final emergencyId =
                (message.data['emergencyId']?.toString() ??
                        message.data['alertId']?.toString() ??
                        message.data['referenceId']?.toString() ??
                        message.data['id']?.toString() ??
                        message.messageId ??
                        '')
                    .trim();
            if (emergencyId.isNotEmpty &&
                await EmergencyAlertService.isDoNotRemind(emergencyId)) {
              debugPrint(
                '[EMERGENCY] Foreground alert suppressed by do-not-remind id=$emergencyId',
              );
              return;
            }
            unawaited(_showEmergencyAlert(message));
            return;
          }
          if (type == 'announcement') {
            // Android presents announcements through their sound-enabled
            // notification channels. Do not duplicate them with a SnackBar.
            return;
          }
          final title = message.notification?.title?.toString();
          final body = message.notification?.body?.toString();
          final text = [
            if (title != null && title.isNotEmpty) title,
            if (body != null && body.isNotEmpty) body,
          ].join(': ');
          if (text.isEmpty) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showAppSnackBar(
              AppSnackBar(
                content: Text(text), kind: FeedbackKind.info),
            );
        });
    _openedNotificationSubscription = NotificationService.openedMessages.listen(
      (message) {
        if (!mounted) return;
        final data = message.data;
        final emergencyId =
            (data['emergencyId']?.toString() ??
                    data['alertId']?.toString() ??
                    data['referenceId']?.toString() ??
                    data['id']?.toString() ??
                    '')
                .trim();
        final resolvedRoute = _resolveNotificationRoute(data) ?? '/home';

        if (resolvedRoute == '/emergency') {
          debugPrint('[EMERGENCY] Notification tapped id=$emergencyId');
          Navigator.of(context).pushNamed('/emergency', arguments: emergencyId);
        } else if (resolvedRoute == '/complain') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConcernCenterPage(
                initialConcernId: emergencyId.isNotEmpty ? emergencyId : null,
                initialCenterTab: 1,
                initialActivitySubTab: 1,
              ),
            ),
          );
        } else if (resolvedRoute == '/jobs') {
          final jobId = (data['jobId'] ?? data['requestId'] ?? emergencyId)
              .toString()
              .trim();
          Navigator.of(
            context,
          ).pushNamed('/jobs', arguments: jobId.isNotEmpty ? jobId : null);
        } else {
          Navigator.of(context).pushNamed(resolvedRoute);
        }
      },
    );
  }

  static const Set<String> _knownRoutes = {
    '/settings',
    '/home',
    '/alerts',
    '/emergency',
    '/admin',
    '/complain',
    '/submissions',
    '/barangay',
    '/officials',
    '/jobs',
    '/bayanihan-messages',
    '/marketplace',
    '/calendar',
    '/verification',
    '/trust_safety',
    '/user-profile',
  };

  static String? _resolveNotificationRoute(Map<String, dynamic> data) {
    final explicitRoute = data['route']?.toString().trim();
    if (explicitRoute != null && _knownRoutes.contains(explicitRoute)) {
      return explicitRoute;
    }

    final type = (data['notificationType'] ?? data['type'] ?? data['action'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (type == null || type.isEmpty) {
      return explicitRoute != null && explicitRoute.isNotEmpty ? '/home' : null;
    }

    if (type == 'emergency' ||
        type == 'emergency_alert' ||
        type == 'community_alert') {
      return '/emergency';
    }
    if (type.startsWith('bayanihan_') || type == 'bayanihan') {
      return '/bayanihan-messages';
    }
    if (type.startsWith('marketplace')) {
      return '/marketplace';
    }
    if (type == 'complaint' || type.startsWith('complaint_')) {
      return '/complain';
    }
    if (type == 'submission' ||
        type == 'submission_update' ||
        type == 'concern' ||
        type == 'complaint') {
      return '/submissions';
    }
    if (type == 'alert' || type == 'announcement') {
      return '/alerts';
    }
    if (type == 'job' || type == 'jobs') {
      return '/jobs';
    }
    if (type == 'calendar' || type == 'event') {
      return '/calendar';
    }
    if (type == 'verification') {
      return '/verification';
    }

    return '/home';
  }

  Future<void> _showEmergencyAlert(RemoteMessage message) async {
    if (!mounted || _emergencyDialogVisible) return;
    final emergencyId =
        (message.data['emergencyId']?.toString() ??
                message.data['alertId']?.toString() ??
                message.data['referenceId']?.toString() ??
                message.data['id']?.toString() ??
                message.messageId ??
                '')
            .trim();
    if (emergencyId.isNotEmpty &&
        await EmergencyAlertService.isDoNotRemind(emergencyId)) {
      debugPrint(
        '[EMERGENCY] Emergency dialog suppressed by do-not-remind id=$emergencyId',
      );
      return;
    }
    _emergencyDialogVisible = true;
    final notificationTitle = message.notification?.title?.trim();
    final dataTitle = message.data['title']?.toString().trim();
    final notificationBody = message.notification?.body?.trim();
    final dataBody = message.data['body']?.toString().trim();
    final title = notificationTitle?.isNotEmpty == true
        ? notificationTitle!
        : dataTitle?.isNotEmpty == true
        ? dataTitle!
        : 'Emergency Alert';
    final body = notificationBody?.isNotEmpty == true
        ? notificationBody!
        : dataBody?.isNotEmpty == true
        ? dataBody!
        : 'Open E-Sugid for current emergency information.';
    final alertType = message.data['alertType']?.toString().trim();
    try {
      await EmergencyAlarmService.startAlarm(emergencyId);
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Dismiss emergency alert',
        barrierColor: context.colors.shadow.withValues(alpha: 0.72),
        transitionDuration: const Duration(milliseconds: 280),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (dialogContext, animation, secondaryAnimation) => SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  color: dialogContext.colors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: dialogContext.colors.error),
                  boxShadow: [
                    BoxShadow(
                      color: dialogContext.colors.shadow.withValues(
                        alpha: 0.4000,
                      ),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: dialogContext.colors.errorSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: dialogContext.colors.error,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EMERGENCY ALERT',
                                style: GoogleFonts.poppins(
                                  color: dialogContext.colors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              if (alertType != null && alertType.isNotEmpty)
                                Text(
                                  alertType,
                                  style: GoogleFonts.poppins(
                                    color: dialogContext.colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: dialogContext.colors.textPrimary,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: GoogleFonts.poppins(
                        color: dialogContext.colors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          unawaited(
                            EmergencyAlarmService.stopAlarm(
                              emergencyId: emergencyId,
                            ),
                          );
                          Navigator.of(dialogContext).pop();
                          Navigator.of(
                            context,
                          ).pushNamed('/emergency', arguments: emergencyId);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: dialogContext.colors.errorSolid,
                          foregroundColor: dialogContext.colors.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.shield_rounded),
                        label: const Text('View Alert'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          unawaited(
                            EmergencyAlarmService.stopAlarm(
                              emergencyId: emergencyId,
                            ),
                          );
                          if (emergencyId.isNotEmpty) {
                            unawaited(
                              EmergencyAlertService.markDoNotRemind(
                                emergencyId,
                              ).catchError((_) {}),
                            );
                          }
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showAppSnackBar(
                            AppSnackBar(
                              content: Text(
                                'Reminders stopped for this emergency alert.',
                              ),
                              kind: FeedbackKind.success,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: dialogContext.colors.error,
                          side: BorderSide(color: dialogContext.colors.error),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.notifications_off_outlined,
                          size: 18,
                        ),
                        label: const Text("Don't Remind Again"),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          unawaited(
                            EmergencyAlarmService.stopAlarm(
                              emergencyId: emergencyId,
                            ),
                          );
                          if (emergencyId.isNotEmpty) {
                            unawaited(
                              EmergencyAlertService.markSilenced(
                                emergencyId,
                              ).catchError((_) {}),
                            );
                          }
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Dismiss'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      await EmergencyAlarmService.stopAlarm(emergencyId: emergencyId);
      _emergencyDialogVisible = false;
    }
  }

  Future<void> _handleAuthChanged(auth.User? firebaseUser) async {
    final generation = ++_sessionGeneration;
    await _profileSubscription?.cancel();
    if (!mounted || generation != _sessionGeneration) return;
    _profileSubscription = null;
    if (firebaseUser == null) {
      _restrictionExpiryTimer?.cancel();
      _restrictionExpiryTimer = null;
      ResidentPresenceService.stop();
      await NotificationService.clear();
      if (!mounted || generation != _sessionGeneration) return;
      await AnnouncementNotificationService.clear();
      if (!mounted || generation != _sessionGeneration) return;
      CommunityService.clearCaches();
      EmergencyService.clearCaches();
      AuthService.currentUser = null;
      _initializedUserId = null;
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _firebaseUser = null;
        _profile = null;
        _sessionError = null;
        _isLoading = false;
      });
      return;
    }

    if (mounted && generation == _sessionGeneration) {
      setState(() {
        _firebaseUser = firebaseUser;
        if (_profile == null || _profile!.uid != firebaseUser.uid) {
          _profile = AuthService.currentUser?.uid == firebaseUser.uid
              ? AuthService.currentUser
              : null;
          _isLoading = _profile == null;
        }
        _sessionError = null;
      });
    }
    _profileSubscription = AuthService.currentUserDocStream.listen(
      (user) => _handleProfileChanged(user, generation),
      onError: _handleSessionError,
    );
  }

  Future<void> _handleProfileChanged(User? user, int generation) async {
    if (!mounted || generation != _sessionGeneration) return;
    setState(() {
      _profile = user;
      _sessionError = null;
      _isLoading = false;
    });
    _restrictionExpiryTimer?.cancel();
    _restrictionExpiryTimer = null;
    if (user != null && user.isRestricted) {
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    if (user != null && user.isRestricted && user.restrictionEndDate != null) {
      final remaining = user.restrictionEndDate!.difference(DateTime.now());
      if (remaining > Duration.zero) {
        _restrictionExpiryTimer = Timer(
          remaining + const Duration(seconds: 1),
          () {
            if (mounted) {
              setState(() {});
            }
          },
        );
      }
    }

    if ((user == null ||
            !user.isActive ||
            user.isRestricted ||
            !user.hasCompletedRegistrationEmailVerification) &&
        _initializedUserId != null) {
      ResidentPresenceService.stop();
      await NotificationService.unregisterCurrentUser();
      if (!mounted || generation != _sessionGeneration) return;
      await AnnouncementNotificationService.clear();
      if (!mounted || generation != _sessionGeneration) return;
      _initializedUserId = null;
      return;
    }
    if (user != null &&
        user.isActive &&
        !user.isRestricted &&
        user.hasCompletedRegistrationEmailVerification &&
        _initializedUserId != user.uid) {
      _initializedUserId = user.uid;
      if (user.role == UserRole.resident) {
        ResidentPresenceService.start(user.uid);
      }
      await NotificationService.initializeForUser(user);
      if (!mounted || generation != _sessionGeneration) {
        await NotificationService.clear();
        return;
      }
      await EmergencyAlertService.retryPendingAcknowledgements();
      if (!mounted || generation != _sessionGeneration) {
        await NotificationService.clear();
        return;
      }
      if (user.role == UserRole.resident) {
        unawaited(_recoverActiveEmergency(user, generation));
      }
      await AnnouncementNotificationService.syncForUser(user);
      if (!mounted || generation != _sessionGeneration) {
        await AnnouncementNotificationService.clear();
      }
    }
  }

  Future<void> _recoverActiveEmergency(User user, int generation) async {
    final alerts =
        await EmergencyAlertService.getActiveEmergenciesForResident();
    if (!mounted ||
        generation != _sessionGeneration ||
        AuthService.currentUser?.uid != user.uid ||
        alerts.isEmpty) {
      return;
    }
    // The backend already returns only relevant/unacknowledged records. The
    // client applies the same deterministic newest-first ordering and rings
    // only the first alert; all others remain available in Notifications.
    final alert = alerts.first;
    if (await EmergencyAlertService.isDoNotRemind(alert.id)) {
      debugPrint(
        '[EMERGENCY] Recovered alert suppressed by do-not-remind id=${alert.id}',
      );
      return;
    }
    debugPrint('[EMERGENCY] Surfacing recovered active alert id=${alert.id}');
    await _showEmergencyAlert(
      RemoteMessage(
        data: {
          'notificationType': 'emergency',
          'type': 'emergency_alert',
          'emergencyId': alert.id,
          'alertId': alert.id,
          'title': alert.title,
          'body': alert.message,
          'alertType': alert.alertType,
          'route': '/emergency',
          'recovered': 'true',
        },
      ),
    );
  }

  void _handleSessionError(Object error) {
    if (!mounted) return;
    setState(() {
      _sessionError = error;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _restrictionExpiryTimer?.cancel();
    ResidentPresenceService.stop();
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _foregroundNotificationSubscription?.cancel();
    _openedNotificationSubscription?.cancel();
    super.dispose();
  }

  Widget _buildSessionContent() {
    if (_isLoading) {
      return const ESugidSplashScreen(key: ValueKey('splash_screen'));
    }
    if (_sessionError != null) {
      return Scaffold(
        key: const ValueKey('session_error_screen'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your account could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: SessionService.logout,
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_firebaseUser == null) {
      return const LoginScreen(key: ValueKey('login_screen'));
    }
    final user = _profile;
    if (user == null) {
      return Scaffold(
        key: const ValueKey('missing_profile_screen'),
        body: Center(
          child: OutlinedButton(
            onPressed: SessionService.logout,
            child: const Text('Profile missing — back to login'),
          ),
        ),
      );
    }
    if (user.role == UserRole.resident &&
        !user.hasCompletedRegistrationEmailVerification) {
      return const EmailOtpVerificationScreen(
        key: ValueKey('email_otp_verification_screen'),
      );
    }
    switch (sessionDestinationFor(user)) {
      case SessionDestination.unavailable:
        return PendingApprovalScreen(
          key: const ValueKey('pending_approval_screen'),
          user: user,
        );
      case SessionDestination.adminWeb:
        return const AdminWebHandoffScreen(
          key: ValueKey('admin_handoff_screen'),
        );
      case SessionDestination.home:
        return const HomeScreen(key: ValueKey('home_screen'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _buildSessionContent(),
    );
  }
}
