import 'package:shared_preferences/shared_preferences.dart';

class AppLaunchState {
  final bool onboardingCompleted;
  final bool permissionSetupCompleted;
  final bool requiredNotificationAccessWasEnabled;

  const AppLaunchState({
    required this.onboardingCompleted,
    required this.permissionSetupCompleted,
    this.requiredNotificationAccessWasEnabled = false,
  });
}

class AppLaunchPreferences {
  static const _onboardingCompletedKey = 'esugid_onboarding_completed_v1';
  static const _permissionSetupCompletedKey =
      'esugid_permission_setup_completed_v1';
  static const _notificationAccessWasEnabledKey =
      'esugid_notification_access_was_enabled_v1';

  const AppLaunchPreferences._();

  static Future<AppLaunchState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final permissionSetupCompleted =
        preferences.getBool(_permissionSetupCompletedKey) ?? false;
    return AppLaunchState(
      onboardingCompleted:
          preferences.getBool(_onboardingCompletedKey) ?? false,
      permissionSetupCompleted: permissionSetupCompleted,
      // Existing installations completed the old setup only after granting
      // notifications, so migrate them as previously enabled.
      requiredNotificationAccessWasEnabled:
          preferences.getBool(_notificationAccessWasEnabledKey) ??
          permissionSetupCompleted,
    );
  }

  static Future<void> markOnboardingCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompletedKey, true);
  }

  static Future<void> markPermissionSetupCompleted({
    required bool notificationAccessEnabled,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_permissionSetupCompletedKey, true);
    await preferences.setBool(
      _notificationAccessWasEnabledKey,
      notificationAccessEnabled,
    );
  }

  static Future<void> markNotificationAccessEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationAccessWasEnabledKey, true);
  }
}
