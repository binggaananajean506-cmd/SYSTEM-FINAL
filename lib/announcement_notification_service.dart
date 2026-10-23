import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'barili_barangays.dart';

class AnnouncementNotificationService {
  static final Set<String> _topics = <String>{};
  static String? _syncedUserId;
  static int _generation = 0;

  static Future<void> syncForUser(User user) async {
    if (kIsWeb || (_syncedUserId == user.uid && _topics.isNotEmpty)) return;
    final generation = ++_generation;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final desiredTopics = <String>{'barili_all'};
      final barangay = canonicalBariliBarangay(user.barangay);
      if (barangay != null) desiredTopics.add(_topicForBarangay(barangay));
      await _replaceTopics(messaging, desiredTopics);
      if (generation != _generation) return;
      _syncedUserId = user.uid;
    } catch (error) {
      debugPrint('Announcement notification setup was skipped: $error');
    }
  }

  static Future<void> clear() async {
    _generation++;
    if (kIsWeb || _topics.isEmpty) {
      _syncedUserId = null;
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      for (final topic in _topics.toList()) {
        await messaging.unsubscribeFromTopic(topic);
      }
    } catch (error) {
      debugPrint('Announcement topic cleanup was skipped: $error');
    } finally {
      _topics.clear();
      _syncedUserId = null;
    }
  }

  static Future<void> _replaceTopics(
    FirebaseMessaging messaging,
    Set<String> desired,
  ) async {
    for (final topic in _topics.difference(desired)) {
      await messaging.unsubscribeFromTopic(topic);
    }
    for (final topic in desired.difference(_topics)) {
      await messaging.subscribeToTopic(topic);
    }
    _topics
      ..clear()
      ..addAll(desired);
  }

  static String _topicForBarangay(String barangay) {
    final slug = barangay
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'barangay_$slug';
  }
}
