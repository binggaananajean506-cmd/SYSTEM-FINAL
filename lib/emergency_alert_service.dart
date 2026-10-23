import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'community_service.dart';
import 'emergency_alarm_service.dart';
import 'firestore_converters.dart';
import 'package:flutter/services.dart';

enum EmergencyAcknowledgementResult { synchronized, queuedOffline }

class ResidentEmergencyStatus {
  final String emergencyId;
  final String residentId;
  final String status;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? silencedAt;
  final DateTime? acknowledgedAt;
  final DateTime? lastReminderSentAt;
  final int reminderCount;

  const ResidentEmergencyStatus({
    required this.emergencyId,
    required this.residentId,
    required this.status,
    this.deliveredAt,
    this.openedAt,
    this.silencedAt,
    this.acknowledgedAt,
    this.lastReminderSentAt,
    this.reminderCount = 0,
  });

  bool get isAcknowledged => acknowledgedAt != null || status == 'acknowledged';

  factory ResidentEmergencyStatus.fromMap(Map<String, dynamic> map) {
    return ResidentEmergencyStatus(
      emergencyId: map['emergencyId']?.toString() ?? '',
      residentId: map['residentId']?.toString() ?? '',
      status: map['status']?.toString().toLowerCase() ?? 'pending',
      deliveredAt: nullableDateTimeFromFirestore(map['deliveredAt']),
      openedAt: nullableDateTimeFromFirestore(map['openedAt']),
      silencedAt: nullableDateTimeFromFirestore(
        map['silencedAt'] ?? map['dismissedAt'],
      ),
      acknowledgedAt: nullableDateTimeFromFirestore(map['acknowledgedAt']),
      lastReminderSentAt: nullableDateTimeFromFirestore(
        map['lastReminderSentAt'],
      ),
      reminderCount: (map['reminderCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class EmergencyAlertService {
  EmergencyAlertService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  static const _cachePrefix = 'emergency_alert_cache_';
  static const _pendingAcknowledgementsKey =
      'pending_emergency_acknowledgements';
  static const _doNotRemindKey = 'esugid_emergency_do_not_remind_ids';
  static const MethodChannel _androidChannel = MethodChannel(
    'com.esugid.barili/notifications',
  );

  static String statusDocumentId(String emergencyId, String residentId) =>
      '${emergencyId}_$residentId';

  @visibleForTesting
  static Stream<CommunityAlert?> Function(String emergencyId)?
      mockWatchAlertHandler;

  static Stream<CommunityAlert?> watchAlert(String emergencyId) {
    if (mockWatchAlertHandler != null) {
      return mockWatchAlertHandler!(emergencyId);
    }
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return Stream.value(null);
    return _firestore.collection('alerts').doc(cleanId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) return null;
      final alert = CommunityAlert.fromMap({...data, 'id': doc.id});
      cacheAlert(alert);
      return alert;
    });
  }

  @visibleForTesting
  static Stream<ResidentEmergencyStatus?> Function(
    String emergencyId,
    String residentId,
  )? mockResidentStatusHandler;

  static Stream<ResidentEmergencyStatus?> watchResidentStatus(
    String emergencyId,
    String residentId,
  ) {
    if (mockResidentStatusHandler != null) {
      return mockResidentStatusHandler!(emergencyId, residentId);
    }
    final cleanId = emergencyId.trim();
    final cleanResidentId = residentId.trim();
    if (cleanId.isEmpty || cleanResidentId.isEmpty) {
      return Stream.value(null);
    }
    return _firestore
        .collection('resident_emergency_statuses')
        .doc(statusDocumentId(cleanId, cleanResidentId))
        .snapshots()
        .map((doc) {
          final data = doc.data();
          return data == null ? null : ResidentEmergencyStatus.fromMap(data);
        });
  }

  static Future<CommunityAlert?> fetchAlert(
    String emergencyId, {
    bool serverOnly = false,
  }) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final snapshot = await _firestore
          .collection('alerts')
          .doc(cleanId)
          .get(serverOnly ? const GetOptions(source: Source.server) : null);
      final data = snapshot.data();
      if (data == null) return await loadCachedAlert(cleanId);
      final alert = CommunityAlert.fromMap({...data, 'id': snapshot.id});
      await cacheAlert(alert);
      return alert;
    } catch (_) {
      return loadCachedAlert(cleanId);
    }
  }

  static Future<void> cacheAlert(CommunityAlert alert) async {
    if (alert.id.trim().isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_cachePrefix${alert.id.trim()}',
      jsonEncode(alert.toMap()),
    );
  }

  static Future<CommunityAlert?> loadCachedAlert(String emergencyId) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_cachePrefix$cleanId');
    if (encoded == null) return null;
    try {
      return CommunityAlert.fromMap(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns only server-confirmed, active, relevant, and unacknowledged
  /// emergencies. Cached details remain available for reading, but are never
  /// used by themselves to restart an alarm because they may have ended while
  /// the device was offline.
  static Future<List<CommunityAlert>> getActiveEmergenciesForResident() async {
    final user = AuthService.currentUser;
    if (user == null || user.role != UserRole.resident || !user.isActive) {
      return const [];
    }
    try {
      final response = await _functions
          .httpsCallable('getActiveEmergenciesForResident')
          .call<dynamic>();
      final responseData = response.data;
      if (responseData is! Map) return const [];
      final rawEmergencies = responseData['emergencies'];
      if (rawEmergencies is! List) return const [];
      final alerts = rawEmergencies
          .whereType<Map>()
          .map(
            (item) => CommunityAlert.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
      final preferences = await SharedPreferences.getInstance();
      final pendingAcknowledgements =
          preferences.getStringList(_pendingAcknowledgementsKey)?.toSet() ??
          const <String>{};
      final doNotRemindIds =
          preferences.getStringList(_doNotRemindKey)?.toSet() ??
          const <String>{};
      final prioritized = prioritizeRecoverableAlerts(
        alerts.where(
          (alert) =>
              !pendingAcknowledgements.contains(alert.id) &&
              !doNotRemindIds.contains(alert.id),
        ),
        user,
      );
      for (final alert in prioritized) {
        await cacheAlert(alert);
      }
      debugPrint(
        '[EMERGENCY] Active startup recovery count=${prioritized.length}',
      );
      return prioritized;
    } catch (error) {
      debugPrint('[EMERGENCY] Active startup recovery deferred: $error');
      return const [];
    }
  }

  @visibleForTesting
  static List<CommunityAlert> prioritizeRecoverableAlerts(
    Iterable<CommunityAlert> alerts,
    User resident,
  ) {
    final result = alerts
        .where(
          (alert) =>
              alert.isEmergency &&
              alert.isCurrentlyActive &&
              alert.isVisibleTo(resident),
        )
        .toList();
    result.sort((left, right) {
      final rightTime = right.publishedAt ?? right.startAt ?? right.createdAt;
      final leftTime = left.publishedAt ?? left.startAt ?? left.createdAt;
      final byNewest = rightTime.compareTo(leftTime);
      return byNewest != 0 ? byNewest : left.id.compareTo(right.id);
    });
    return result;
  }

  static Future<void> markOpened(String emergencyId) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return;
    await _call('markEmergencyAlertOpened', cleanId);
    debugPrint('[EMERGENCY] Opened id=$cleanId');
  }

  static Future<void> markSilenced(String emergencyId) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return;
    await _call('silenceEmergencyAlert', cleanId);
    debugPrint('[EMERGENCY] Dismissed/silenced id=$cleanId');
  }

  static Future<void> markDoNotRemind(String emergencyId) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return;

    // 1. Persist locally in Flutter SharedPreferences
    final preferences = await SharedPreferences.getInstance();
    final list = preferences.getStringList(_doNotRemindKey) ?? <String>[];
    if (!list.contains(cleanId)) {
      list.add(cleanId);
      await preferences.setStringList(_doNotRemindKey, list);
    }

    // 2. Stop audio alarm
    await EmergencyAlarmService.stopAlarm(emergencyId: cleanId);

    // 3. Inform Android native side to permanently suppress native notifications/services/alarms
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _androidChannel.invokeMethod<void>(
          'markEmergencyDoNotRemind',
          {'referenceId': cleanId},
        ).catchError((error) {
          debugPrint(
            '[EMERGENCY] Native markEmergencyDoNotRemind deferred: $error',
          );
        }),
      );
    }

    // 4. Acknowledge with backend so Cloud Functions stop reminder pushes
    unawaited(
      acknowledge(cleanId).catchError((error) {
        debugPrint('[EMERGENCY] Acknowledge on do-not-remind deferred: $error');
        return EmergencyAcknowledgementResult.queuedOffline;
      }),
    );
  }

  static Future<bool> isDoNotRemind(String emergencyId) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return false;
    final preferences = await SharedPreferences.getInstance();
    final list = preferences.getStringList(_doNotRemindKey) ?? <String>[];
    return list.contains(cleanId);
  }

  static Future<Set<String>> getDoNotRemindIds() async {
    final preferences = await SharedPreferences.getInstance();
    final list = preferences.getStringList(_doNotRemindKey) ?? <String>[];
    return list.toSet();
  }

  static Future<EmergencyAcknowledgementResult> acknowledge(
    String emergencyId,
  ) async {
    final cleanId = emergencyId.trim();
    if (cleanId.isEmpty) return EmergencyAcknowledgementResult.synchronized;
    try {
      await _call('acknowledgeEmergencyAlert', cleanId);
      await _removePendingAcknowledgement(cleanId);
      debugPrint('[EMERGENCY] Acknowledged id=$cleanId');
      return EmergencyAcknowledgementResult.synchronized;
    } catch (error) {
      if (error is FirebaseFunctionsException &&
          !const {
            'unavailable',
            'deadline-exceeded',
            'internal',
          }.contains(error.code)) {
        rethrow;
      }
      await _queueAcknowledgement(emergencyId);
      return EmergencyAcknowledgementResult.queuedOffline;
    }
  }

  static Future<void> retryPendingAcknowledgements() async {
    if (AuthService.currentUser?.uid == null) return;
    final preferences = await SharedPreferences.getInstance();
    final pending =
        preferences.getStringList(_pendingAcknowledgementsKey) ?? [];
    for (final emergencyId in List<String>.from(pending)) {
      try {
        await _call('acknowledgeEmergencyAlert', emergencyId);
        await _removePendingAcknowledgement(emergencyId);
      } catch (error) {
        debugPrint(
          '[EMERGENCY] Pending acknowledgement retry deferred: $error',
        );
      }
    }
  }

  @visibleForTesting
  static Future<void> Function(String name, String emergencyId)? mockCallHandler;

  static Future<void> _call(String name, String emergencyId) async {
    if (mockCallHandler != null) {
      await mockCallHandler!(name, emergencyId);
      return;
    }
    if (AuthService.currentUser?.uid == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in is required.',
      );
    }
    await _functions.httpsCallable(name).call<void>({
      'emergencyId': emergencyId,
    }).timeout(const Duration(seconds: 4));
  }

  static Future<void> _queueAcknowledgement(String emergencyId) async {
    final preferences = await SharedPreferences.getInstance();
    final pending =
        preferences.getStringList(_pendingAcknowledgementsKey) ?? [];
    if (!pending.contains(emergencyId)) pending.add(emergencyId);
    await preferences.setStringList(_pendingAcknowledgementsKey, pending);
  }

  static Future<void> _removePendingAcknowledgement(String emergencyId) async {
    final preferences = await SharedPreferences.getInstance();
    final pending =
        preferences.getStringList(_pendingAcknowledgementsKey) ?? [];
    pending.remove(emergencyId);
    await preferences.setStringList(_pendingAcknowledgementsKey, pending);
  }
}
