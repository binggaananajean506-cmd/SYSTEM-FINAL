import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../community_service.dart';

class DashboardAnnouncementCache {
  DashboardAnnouncementCache({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  static const _storageKey = 'dashboard_public_announcements_v1';
  static const _maximumRecords = 20;

  final Future<SharedPreferences> Function() _preferencesFactory;

  Future<List<CommunityPost>> load() async {
    final preferences = await _preferencesFactory();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List<dynamic>) return const [];
      final posts = <CommunityPost>[];
      for (final value in decoded) {
        try {
          if (value is! Map<String, dynamic>) continue;
          final post = CommunityPost.fromLocalCache(value);
          if (post.id.isNotEmpty) posts.add(post);
        } on Object {
          // One stale record must not prevent the rest of the bulletin cache
          // from loading.
        }
      }
      return CommunityService.sortPostsForFeed(posts);
    } on Object {
      return const [];
    }
  }

  Future<void> save(List<CommunityPost> posts) async {
    final sorted = CommunityService.sortPostsForFeed(posts);
    final records = sorted.take(_maximumRecords).toList();
    final preferences = await _preferencesFactory();
    final stored = await preferences.setString(
      _storageKey,
      jsonEncode(records.map((post) => post.toLocalCache()).toList()),
    );
    if (!stored) {
      throw StateError('The dashboard announcement cache could not be saved.');
    }
  }
}
