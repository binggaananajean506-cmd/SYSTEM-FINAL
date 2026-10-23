import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Keeps `users/{uid}.lastActiveAt` fresh while a resident has the app open so
/// the admin Reports page can count residents who are currently logged in.
///
/// The admin console treats anyone active within the last 15 minutes as logged
/// in, so the heartbeat runs well inside that window and stops while the app is
/// in the background or after sign-out.
abstract final class ResidentPresenceService {
  static const heartbeatInterval = Duration(minutes: 5);

  static String? _userId;
  static Timer? _timer;
  static AppLifecycleListener? _lifecycleListener;

  static void start(String userId) {
    if (_userId == userId) return;
    stop();
    _userId = userId;
    _lifecycleListener = AppLifecycleListener(
      onResume: _resume,
      onHide: _pause,
    );
    _resume();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _userId = null;
  }

  static void _resume() {
    _timer?.cancel();
    unawaited(_beat());
    _timer = Timer.periodic(heartbeatInterval, (_) => unawaited(_beat()));
  }

  static void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _beat() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Resident presence heartbeat skipped: $error');
    }
  }
}
