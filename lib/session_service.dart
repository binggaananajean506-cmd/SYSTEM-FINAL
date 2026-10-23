import 'dart:async';

import 'package:flutter/foundation.dart';

import 'announcement_notification_service.dart';
import 'auth_service.dart';
import 'community_service.dart';
import 'emergency_service.dart';
import 'notification_service.dart';

abstract final class SessionService {
  static Future<void> logout() async {
    // Safely bound device unregister while the original authenticated session is still available
    try {
      await NotificationService.unregisterCurrentUser()
          .timeout(const Duration(milliseconds: 2500));
    } catch (error) {
      debugPrint('FCM unregister error on logout: $error');
    }
    await AnnouncementNotificationService.clear();
    CommunityService.clearCaches();
    EmergencyService.clearCaches();
    await AuthService.logout();
  }
}

