import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central state manager for application-wide user preferences including
/// language, text scale, notification toggles, location, and privacy settings.
class AppPreferencesController {
  AppPreferencesController._();

  // Keys
  static const _langKey = 'esugid_pref_language';
  static const _textSizeKey = 'esugid_pref_text_size';
  static const _announcementsKey = 'pref_notify_announcements';
  static const _advisoriesKey = 'pref_notify_advisories';
  static const _eventsKey = 'pref_notify_events';
  static const _concernUpdatesKey = 'pref_notify_concern_updates';
  static const _complaintUpdatesKey = 'pref_notify_complaint_updates';
  static const _orgUpdatesKey = 'pref_notify_org_updates';
  static const _highAccuracyGpsKey = 'pref_location_high_accuracy';
  static const _communityVisibilityKey = 'pref_privacy_community_visibility';
  static const _activityLoggingKey = 'pref_privacy_activity_logging';

  // Notifiers
  static final ValueNotifier<String> language = ValueNotifier<String>('en');
  static final ValueNotifier<String> textSize = ValueNotifier<String>('default');
  static final ValueNotifier<double> textScaleFactor = ValueNotifier<double>(1.0);

  // Notification Notifiers
  static final ValueNotifier<bool> barangayAnnouncements = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> publicAdvisories = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> eventsActivities = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> concernUpdates = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> complaintUpdates = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> organizationUpdates = ValueNotifier<bool>(true);

  // Location Notifiers
  static final ValueNotifier<bool> highAccuracyGps = ValueNotifier<bool>(true);

  // Privacy Notifiers
  static final ValueNotifier<bool> communityVisibility = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> activityLogging = ValueNotifier<bool>(true);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Language
    language.value = prefs.getString(_langKey) ?? 'en';

    // Text Size
    final savedTextSize = prefs.getString(_textSizeKey) ?? 'default';
    textSize.value = savedTextSize;
    textScaleFactor.value = _scaleForSize(savedTextSize);

    // Notifications
    barangayAnnouncements.value = prefs.getBool(_announcementsKey) ?? true;
    publicAdvisories.value = prefs.getBool(_advisoriesKey) ?? true;
    eventsActivities.value = prefs.getBool(_eventsKey) ?? true;
    concernUpdates.value = prefs.getBool(_concernUpdatesKey) ?? true;
    complaintUpdates.value = prefs.getBool(_complaintUpdatesKey) ?? true;
    organizationUpdates.value = prefs.getBool(_orgUpdatesKey) ?? true;

    // Location
    highAccuracyGps.value = prefs.getBool(_highAccuracyGpsKey) ?? true;

    // Privacy
    communityVisibility.value = prefs.getBool(_communityVisibilityKey) ?? true;
    activityLogging.value = prefs.getBool(_activityLoggingKey) ?? true;
  }

  static double _scaleForSize(String size) {
    switch (size) {
      case 'small':
        return 0.88;
      case 'large':
        return 1.15;
      case 'default':
      default:
        return 1.0;
    }
  }

  static Future<void> setLanguage(String lang) async {
    language.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  static Future<void> setTextSize(String size) async {
    textSize.value = size;
    textScaleFactor.value = _scaleForSize(size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textSizeKey, size);
  }

  static Future<void> setBarangayAnnouncements(bool val) async {
    barangayAnnouncements.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_announcementsKey, val);
  }

  static Future<void> setPublicAdvisories(bool val) async {
    publicAdvisories.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_advisoriesKey, val);
  }

  static Future<void> setEventsActivities(bool val) async {
    eventsActivities.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eventsKey, val);
  }

  static Future<void> setConcernUpdates(bool val) async {
    concernUpdates.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_concernUpdatesKey, val);
  }

  static Future<void> setComplaintUpdates(bool val) async {
    complaintUpdates.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_complaintUpdatesKey, val);
  }

  static Future<void> setOrganizationUpdates(bool val) async {
    organizationUpdates.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orgUpdatesKey, val);
  }

  static Future<void> setHighAccuracyGps(bool val) async {
    highAccuracyGps.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highAccuracyGpsKey, val);
  }

  static Future<void> setCommunityVisibility(bool val) async {
    communityVisibility.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityVisibilityKey, val);
  }

  static Future<void> setActivityLogging(bool val) async {
    activityLogging.value = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activityLoggingKey, val);
  }
}
