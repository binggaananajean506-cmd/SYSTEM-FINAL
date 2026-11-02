import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../barili_barangays.dart';

/// Centralized registry and cache for resolving publisher, barangay, and civic
/// entity avatar/profile photo URLs throughout the application.
class PublisherAvatarService {
  PublisherAvatarService._();

  static final Map<String, String> _cache = {};
  static final Map<String, ValueNotifier<String?>> _notifiers = {};
  static final Map<String, Future<String?>> _inFlight = {};

  /// Normalizes lookup keys (e.g., "Barangay Vito", "Vito", "vito" -> "vito").
  static String normalizeKey(String key) {
    var raw = key.trim().toLowerCase();
    if (raw.startsWith('barangay ')) raw = raw.substring(9).trim();
    if (raw.startsWith('brgy. ')) raw = raw.substring(6).trim();
    if (raw.startsWith('brgy ')) raw = raw.substring(5).trim();
    return raw.replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Synchronously returns a cached URL if available.
  static String? getCached(String key) {
    final k = normalizeKey(key);
    return k.isEmpty ? null : _cache[k];
  }

  /// Returns a [ValueNotifier] that notifies listeners whenever the avatar URL
  /// for [key] is resolved or updated.
  static ValueNotifier<String?> getNotifier(String key) {
    final k = normalizeKey(key);
    return _notifiers.putIfAbsent(k, () => ValueNotifier<String?>(_cache[k]));
  }

  /// Explicitly caches a photo URL for one or more keys.
  static void remember(String key, String url) {
    final k = normalizeKey(key);
    final trimmedUrl = url.trim();
    if (k.isNotEmpty) {
      _cache[k] = trimmedUrl;
      getNotifier(k).value = trimmedUrl;
    }
  }

  /// Use publisher identity, never a post's target audience, for this lookup.
  static String? barangayProfileId({String? id, String? name}) {
    for (final value in [id, name]) {
      final key = (value ?? '').trim().toLowerCase().replaceFirst(
        RegExp(r'^(?:(?:barangay|brgy|bgy|barili)[\s_:.-]+)+'),
        '',
      ).replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final barangay in bariliBarangays) {
        if (barangay.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') == key) {
          return bariliBarangayId(barangay);
        }
      }
    }
    return null;
  }

  /// Null means no shared profile yet; an empty URL means the photo was removed.
  /// Existing posts can use their saved photo until a shared profile is present.
  static Stream<String?> watchBarangayAvatar({
    String? barangayId,
    String? barangay,
    FirebaseFirestore? firestore,
  }) async* {
    final id = barangayProfileId(id: barangayId, name: barangay);
    if (id == null) {
      yield null;
      return;
    }
    try {
      final source = (firestore ?? FirebaseFirestore.instance)
          .collection('barangay_profiles').doc(id);
      await for (final snapshot in source.snapshots()) {
        String? photo;
        if (snapshot.exists) {
          final data = snapshot.data();
          photo = '';
          for (final field in ['photoUrl', 'profilePhotoUrl', 'logoUrl']) {
            final value = data?[field]?.toString().trim() ?? '';
            if (value.isNotEmpty) {
              photo = value;
              break;
            }
          }
          remember(id, photo ?? '');
        }
        yield photo;
      }
    } catch (error) {
      debugPrint('Barangay publisher photo unavailable: $error');
    }
  }

  /// Asynchronously resolves the avatar URL for a given post or publisher.
  static Future<String?> resolveAvatarUrl({
    String? authorPhotoUrl,
    String? authorId,
    String? barangay,
    String? barangayId,
    String? organizationId,
  }) async {
    final direct = (authorPhotoUrl ?? '').trim();
    if (direct.isNotEmpty) {
      if (authorId != null && authorId.isNotEmpty) remember(authorId, direct);
      if (barangay != null && barangay.isNotEmpty) remember(barangay, direct);
      if (barangayId != null && barangayId.isNotEmpty) remember(barangayId, direct);
      return direct;
    }

    final bgyKey = normalizeKey(
      barangayId?.isNotEmpty == true ? barangayId! : (barangay ?? ''),
    );
    final authKey = normalizeKey(authorId ?? '');
    final orgKey = normalizeKey(organizationId ?? '');

    if (bgyKey.isNotEmpty && _cache.containsKey(bgyKey)) return _cache[bgyKey];
    if (authKey.isNotEmpty && _cache.containsKey(authKey)) return _cache[authKey];
    if (orgKey.isNotEmpty && _cache.containsKey(orgKey)) return _cache[orgKey];

    final lookupKey = bgyKey.isNotEmpty
        ? bgyKey
        : (authKey.isNotEmpty ? authKey : orgKey);
    if (lookupKey.isEmpty) return null;

    if (_inFlight.containsKey(lookupKey)) return _inFlight[lookupKey];

    final future = _fetch(
      authorId: authorId,
      barangayId: barangayId,
      barangay: barangay,
      organizationId: organizationId,
    );
    _inFlight[lookupKey] = future;
    try {
      final res = await future;
      if (res != null && res.isNotEmpty) {
        if (bgyKey.isNotEmpty) remember(bgyKey, res);
        if (authKey.isNotEmpty) remember(authKey, res);
        if (orgKey.isNotEmpty) remember(orgKey, res);
        final canonical = canonicalBariliBarangay(barangay ?? barangayId ?? '');
        if (canonical != null) remember(canonical, res);
      }
      return res;
    } finally {
      _inFlight.remove(lookupKey);
    }
  }

  static Future<String?> _fetch({
    String? authorId,
    String? barangayId,
    String? barangay,
    String? organizationId,
  }) async {
    try {
      final canonical = canonicalBariliBarangay(barangay ?? barangayId ?? '');
      final candidates = <String>{
        if (barangayId != null && barangayId.trim().isNotEmpty)
          normalizeKey(barangayId),
        if (barangay != null && barangay.trim().isNotEmpty)
          normalizeKey(barangay),
        if (canonical != null) normalizeKey(canonical),
        if (canonical != null) canonical.toLowerCase().trim(),
      };

      // 1. Check barangay_profiles collection for any match
      for (final slug in candidates) {
        if (slug.isEmpty) continue;
        final doc = await FirebaseFirestore.instance
            .collection('barangay_profiles')
            .doc(slug)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final url = data?['photoUrl']?.toString() ??
              data?['profilePhotoUrl']?.toString() ??
              data?['logoUrl']?.toString();
          if (url != null && url.trim().isNotEmpty) return url.trim();
        }
      }

      // 2. Check users/{authorId}
      if (authorId != null && authorId.trim().isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(authorId.trim())
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final url = data?['profilePhotoUrl']?.toString() ??
              data?['photoUrl']?.toString() ??
              data?['avatarUrl']?.toString() ??
              data?['profilePicture']?.toString();
          if (url != null && url.trim().isNotEmpty) return url.trim();
        }
      }

      // 3. Check organizations/{organizationId}
      if (organizationId != null && organizationId.trim().isNotEmpty) {
        final orgDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationId.trim())
            .get();
        if (orgDoc.exists) {
          final data = orgDoc.data();
          final url = data?['logoUrl']?.toString() ??
              data?['photoUrl']?.toString() ??
              data?['profilePhotoUrl']?.toString();
          if (url != null && url.trim().isNotEmpty) return url.trim();
        }
      }
    } catch (e) {
      debugPrint('PublisherAvatarService fetch error: $e');
    }
    return null;
  }
}
