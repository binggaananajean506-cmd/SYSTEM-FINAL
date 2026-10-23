import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/offline_announcement.dart';

abstract interface class OfflineAnnouncementRepository {
  Future<List<OfflineAnnouncement>> load(String userId);
  Stream<List<OfflineAnnouncement>> watch(String userId);
  Future<OfflineAnnouncement?> find(String userId, String announcementId);
  Future<void> upsert(OfflineAnnouncement announcement);
  Future<OfflineAnnouncement?> remove(String userId, String announcementId);
}

class PreferencesOfflineAnnouncementRepository
    implements OfflineAnnouncementRepository {
  static const _keyPrefix = 'saved_announcements_v1:';
  final Future<SharedPreferences> Function() _preferencesFactory;
  final Map<String, StreamController<List<OfflineAnnouncement>>> _controllers =
      {};
  Future<void> _pendingWrite = Future.value();

  PreferencesOfflineAnnouncementRepository({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  String _key(String userId) => '$_keyPrefix$userId';

  @override
  Future<List<OfflineAnnouncement>> load(String userId) async {
    if (userId.trim().isEmpty) return const [];
    final preferences = await _preferencesFactory();
    final encoded = preferences.getString(_key(userId));
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<dynamic>) return const [];
      final records = <OfflineAnnouncement>[];
      for (final value in decoded) {
        try {
          if (value is! Map<String, dynamic>) continue;
          final record = OfflineAnnouncement.fromLocal(value);
          if (record.userId == userId && record.announcementId.isNotEmpty) {
            records.add(record);
          }
        } on Object {
          // Keep valid records if one old/corrupt entry cannot be decoded.
        }
      }
      records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return records;
    } on Object {
      return const [];
    }
  }

  @override
  Stream<List<OfflineAnnouncement>> watch(String userId) async* {
    yield await load(userId);
    yield* (_controllers[userId] ??=
            StreamController<List<OfflineAnnouncement>>.broadcast())
        .stream;
  }

  @override
  Future<OfflineAnnouncement?> find(
    String userId,
    String announcementId,
  ) async {
    final records = await load(userId);
    for (final record in records) {
      if (record.announcementId == announcementId) return record;
    }
    return null;
  }

  @override
  Future<void> upsert(OfflineAnnouncement announcement) {
    return _serializeWrite(() async {
      final records = await load(announcement.userId);
      final byId = {
        for (final record in records) record.announcementId: record,
        announcement.announcementId: announcement,
      };
      await _persist(announcement.userId, byId.values.toList());
    });
  }

  @override
  Future<OfflineAnnouncement?> remove(
    String userId,
    String announcementId,
  ) async {
    OfflineAnnouncement? removed;
    await _serializeWrite(() async {
      final records = await load(userId);
      for (final record in records) {
        if (record.announcementId == announcementId) removed = record;
      }
      if (removed == null) return;
      records.removeWhere((record) => record.announcementId == announcementId);
      await _persist(userId, records);
    });
    return removed;
  }

  Future<void> _serializeWrite(Future<void> Function() operation) {
    final result = _pendingWrite.then((_) => operation());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  Future<void> _persist(
    String userId,
    List<OfflineAnnouncement> records,
  ) async {
    records.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final preferences = await _preferencesFactory();
    final succeeded = await preferences.setString(
      _key(userId),
      jsonEncode(records.map((record) => record.toLocal()).toList()),
    );
    if (!succeeded) {
      throw StateError('The offline announcement could not be stored.');
    }
    _controllers[userId]?.add(List.unmodifiable(records));
  }
}
