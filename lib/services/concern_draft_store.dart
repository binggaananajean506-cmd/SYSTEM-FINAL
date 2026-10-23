import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local unfinished concerns, isolated by the authenticated resident.
/// Each draft has its own key so saving one cannot overwrite another.
class ConcernDraftStore {
  ConcernDraftStore(this.preferences, this.userId);

  final SharedPreferences preferences;
  final String userId;
  String get _prefix => 'concern_drafts_v5_${userId}_';

  List<Map<String, dynamic>> list() {
    final drafts = <Map<String, dynamic>>[];
    for (final key in preferences.getKeys().where(
      (k) => k.startsWith(_prefix),
    )) {
      final value = jsonDecode(preferences.getString(key)!);
      if (value is Map<String, dynamic> && value['userId'] == userId) {
        if (value['submitted'] != true) drafts.add(value);
      }
    }
    drafts.sort(
      (a, b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String),
    );
    return drafts;
  }

  Future<void> save(Map<String, dynamic> draft) async {
    if (userId.isEmpty || draft['id'] is! String) {
      throw StateError('A resident and draft ID are required.');
    }
    final saved = await preferences.setString(
      '$_prefix${draft['id']}',
      jsonEncode({...draft, 'userId': userId}),
    );
    if (!saved) throw StateError('Draft could not be saved.');
  }

  Future<void> delete(String id) async {
    if (!await preferences.remove('$_prefix$id')) {
      throw StateError('Draft could not be removed.');
    }
  }
}
