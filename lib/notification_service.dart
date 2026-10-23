import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'emergency_alert_service.dart';

class NotificationService {
  static const MethodChannel _androidNotifications = MethodChannel(
    'com.esugid.barili/notifications',
  );
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  static final StreamController<RemoteMessage> _foregroundMessages =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _openedMessages =
      StreamController<RemoteMessage>.broadcast();
  static String? _initializedUserId;
  static String? _deviceDocumentId;
  static int _generation = 0;

  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundMessages.stream;
  static Stream<RemoteMessage> get openedMessages => _openedMessages.stream;

  static Future<void> initializeForUser(User user) async {
    if (kIsWeb) return;
    if (_initializedUserId == user.uid) return;
    await clear();
    final generation = _generation;

    try {
      final permission = await _messaging.getNotificationSettings();
      if (permission.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (error) {
      debugPrint('[FCM] Notification permission check deferred: $error');
    }
    if (generation != _generation || AuthService.currentUser?.uid != user.uid) {
      return;
    }

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (error) {
      debugPrint('[FCM] Token recovery deferred: $error');
    }
    if (kDebugMode) {
      debugPrint(
        '[FCM] User device token available: ${token?.isNotEmpty == true ? 'yes' : 'no'}',
      );
    }
    if (generation != _generation || AuthService.currentUser?.uid != user.uid) {
      return;
    }
    if (token != null) {
      try {
        await _saveTokenToUser(user, token);
      } catch (error) {
        debugPrint('[FCM] Token registration deferred: $error');
      }
    }
    if (generation != _generation || AuthService.currentUser?.uid != user.uid) {
      return;
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        _saveTokenToUser(user, token).catchError((error) {
          debugPrint('[FCM] Refreshed token registration deferred: $error');
        });
      },
      onError: (Object error) {
        debugPrint('[FCM] Token refresh listener error: $error');
      },
    );

    _androidNotifications.setMethodCallHandler((call) async {
      if (call.method != 'notificationOpened') return;
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      _openedMessages.add(RemoteMessage(data: arguments));
    });

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openedMessages.add,
    );
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && generation == _generation) {
      scheduleMicrotask(() => _openedMessages.add(initialMessage));
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativeInitial = await _androidNotifications
            .invokeMapMethod<String, dynamic>('getInitialNotificationPayload');
        if (nativeInitial != null && nativeInitial.isNotEmpty) {
          scheduleMicrotask(
            () => _openedMessages.add(RemoteMessage(data: nativeInitial)),
          );
        }
        final emergencyActions = await _androidNotifications
            .invokeMethod<dynamic>('consumeEmergencyActions');
        if (emergencyActions is Map) {
          final silenced = emergencyActions['silenced']?.toString();
          final doNotRemind = emergencyActions['doNotRemind']?.toString();
          if (doNotRemind != null && doNotRemind.isNotEmpty) {
            EmergencyAlertService.markDoNotRemind(doNotRemind).catchError((error) {
              debugPrint('[EMERGENCY] Native do-not-remind sync deferred: $error');
            });
          }
          if (silenced != null && silenced.isNotEmpty) {
            EmergencyAlertService.markSilenced(silenced).catchError((error) {
              debugPrint('[EMERGENCY] Native dismiss sync deferred: $error');
            });
          }
        } else if (emergencyActions is String && emergencyActions.isNotEmpty) {
          EmergencyAlertService.markSilenced(emergencyActions).catchError((error) {
            debugPrint('[EMERGENCY] Native dismiss sync deferred: $error');
          });
        }
      } catch (error) {
        debugPrint('[FCM] Native startup recovery deferred: $error');
      }
    }
    _initializedUserId = user.uid;
  }

  static Future<void> _saveTokenToUser(User user, String token) async {
    if (AuthService.currentUser?.uid != user.uid) return;
    final preferences = await SharedPreferences.getInstance();
    var installationId = preferences.getString('esugid_device_installation_id');
    if (installationId == null || installationId.isEmpty) {
      installationId = const Uuid().v4();
      await preferences.setString(
        'esugid_device_installation_id',
        installationId,
      );
    }
    _deviceDocumentId = installationId;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken(
            true,
          );
          if (AuthService.currentUser?.uid != user.uid) return;
        }
        final response = await _functions
            .httpsCallable('registerResidentDevice')
            .call<dynamic>({
              'installationId': installationId,
              'token': token,
              'platform': defaultTargetPlatform.name,
            });
        final registered =
            response.data is Map && response.data['registered'] == true;
        if (!registered) {
          throw StateError('The backend did not confirm device registration.');
        }
        break;
      } on FirebaseFunctionsException catch (error) {
        final canRetry = const {
          'unauthenticated',
          'unavailable',
          'deadline-exceeded',
          'internal',
        }.contains(error.code);
        if (!canRetry || attempt == 2) rethrow;
        if (kDebugMode) {
          debugPrint(
            '[FCM] Device registration retry ${attempt + 1}/2 after ${error.code}',
          );
        }
      }
    }
    if (kDebugMode) {
      debugPrint('[FCM] User device token registered: yes');
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final diagnostics = await _androidNotifications
              .invokeMapMethod<String, dynamic>('getNotificationDiagnostics');
          debugPrint('[FCM] Android notification diagnostics: $diagnostics');
        } catch (error) {
          debugPrint(
            '[FCM] Android notification diagnostics unavailable: $error',
          );
        }
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    _foregroundMessages.add(message);
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final type =
        message.data['notificationType']?.trim().toLowerCase() ??
        message.data['type']?.trim().toLowerCase();
    // The visible Flutter dialog owns looping audio. A native notification
    // would play a second, short channel sound over it.
    if (type == 'emergency_alert' || type == 'emergency') return;
    final priority = _announcementPriority(message);
    final method = type == 'announcement' || type == 'community_alert'
        ? 'showAnnouncementNotification'
        : null;
    if (method == null) return;

    _androidNotifications
        .invokeMethod<void>(method, {
          'title':
              message.notification?.title ??
              message.data['title'] ??
              'E-Sugid announcement',
          'body':
              message.notification?.body ??
              message.data['body'] ??
              'New community information is available.',
          'priority': priority,
          'referenceId':
              message.data['postId'] ??
              message.data['emergencyId'] ??
              message.data['alertId'] ??
              message.messageId,
          'route': message.data['route'],
        })
        .catchError((error) {
          debugPrint('Foreground notification could not be shown: $error');
        });
  }

  static String _announcementPriority(RemoteMessage message) {
    final type =
        message.data['notificationType']?.trim().toLowerCase() ??
        message.data['type']?.trim().toLowerCase();
    final priority = message.data['priority']?.trim().toLowerCase();
    if (type == 'emergency_alert' || type == 'emergency') return 'emergency';
    if (type == 'community_alert') return priority ?? 'important';
    if (type != 'announcement') return 'regular';
    return priority ?? 'regular';
  }

  static Future<void> unregisterCurrentUser() async {
    final userId = _initializedUserId;
    final installationId = _deviceDocumentId;
    if (userId == null || AuthService.currentUser?.uid != userId) {
      await clear();
      return;
    }
    try {
      if (installationId != null) {
        await _functions.httpsCallable('unregisterResidentDevice').call<void>({
          'installationId': installationId,
        });
      }
    } catch (error) {
      debugPrint('Notification token cleanup was skipped: $error');
    } finally {
      await clear();
    }
  }

  static Future<void> clear() async {
    _generation++;
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedMessageSubscription = null;
    _androidNotifications.setMethodCallHandler(null);
    _initializedUserId = null;
    _deviceDocumentId = null;
  }
}
