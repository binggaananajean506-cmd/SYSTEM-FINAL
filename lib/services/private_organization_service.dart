import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../community_service.dart';
import '../models/private_organization.dart';

class FollowException implements Exception {
  const FollowException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Follows are saved on the resident's `users/{uid}` document by the
/// `setOrganizationFollow` function, so they follow the account across
/// devices and drive each organization's follower count. Without Firebase
/// (unit tests) follows stay on the device.
class PrivateOrganizationService {
  PrivateOrganizationService._();
  static final PrivateOrganizationService instance =
      PrivateOrganizationService._();

  static const String _prefPrefix = 'esugid_followed_private_orgs_';
  static const String _migratedPrefPrefix =
      'esugid_followed_private_orgs_migrated_';

  final ValueNotifier<Set<String>> followedIdsNotifier = ValueNotifier<Set<String>>({});

  /// IDs of the organizations listed in the Private Organizations directory,
  /// or null until loaded. Only their posts depend on following.
  final ValueNotifier<Set<String>?> privateOrganizationIdsNotifier =
      ValueNotifier<Set<String>?>(null);

  /// Notifies when anything that decides feed visibility changes.
  late final Listenable feedFilterChanges = Listenable.merge([
    followedIdsNotifier,
    privateOrganizationIdsNotifier,
  ]);

  String _currentUserId = '';
  bool _initialized = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _followSubscription;
  final Set<String> _pendingToggles = {};

  /// Follows as they were when organization follower counts were last loaded.
  Set<String> _followedWhenCountsLoaded = {};

  Set<String> get followedIds => followedIdsNotifier.value;

  bool get _usesFirebase => Firebase.apps.isNotEmpty;

  /// Initializes the followed organizations set for the logged-in user.
  Future<void> init([String? userId]) async {
    final effectiveUid = userId ?? AuthService.currentUser?.uid ?? '';
    if (effectiveUid != _currentUserId) {
      await _followSubscription?.cancel();
      _followSubscription = null;
      followedIdsNotifier.value = {};
    }
    _currentUserId = effectiveUid;
    if (effectiveUid.isEmpty) {
      _initialized = true;
      return;
    }

    final cached = await _readLocalFollows(effectiveUid);
    if (_followSubscription == null) followedIdsNotifier.value = cached;
    _initialized = true;
    if (!_usesFirebase) return;

    unawaited(loadPrivateOrganizationIds());
    _followSubscription ??= FirebaseFirestore.instance
        .collection('users')
        .doc(effectiveUid)
        .snapshots()
        .listen((snapshot) {
          final raw = snapshot.data()?['followedOrganizationIds'];
          final serverIds = raw is List
              ? raw.whereType<String>().toSet()
              : <String>{};
          if (_pendingToggles.isEmpty) followedIdsNotifier.value = serverIds;
          unawaited(_writeLocalFollows(effectiveUid, serverIds));
          unawaited(_migrateDeviceFollows(effectiveUid, cached, serverIds));
        }, onError: (_) {});
  }

  Future<Set<String>> _readLocalFollows(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('$_prefPrefix$uid') ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLocalFollows(String uid, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_prefPrefix$uid', ids.toList());
    } catch (_) {}
  }

  /// Follows made before they were saved to the account lived only on this
  /// device; send them up once.
  Future<void> _migrateDeviceFollows(
    String uid,
    Set<String> deviceIds,
    Set<String> serverIds,
  ) async {
    final missing = deviceIds.difference(serverIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('$_migratedPrefPrefix$uid') == true) return;
      await prefs.setBool('$_migratedPrefPrefix$uid', true);
    } catch (_) {
      return;
    }
    for (final orgId in missing) {
      try {
        await _saveFollow(orgId, follow: true);
      } catch (_) {
        // Organizations that no longer exist are simply dropped.
      }
    }
  }

  /// Loads which organizations are private (followable) for feed filtering.
  Future<void> loadPrivateOrganizationIds() async {
    if (!_usesFirebase) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .where('organizationSector', isEqualTo: 'private')
          .get();
      privateOrganizationIdsNotifier.value =
          snapshot.docs.map((doc) => doc.id).toSet();
    } catch (_) {
      // Keep null: organization posts stay limited to followed ones.
    }
  }

  /// Checks if a private organization is currently followed.
  bool isFollowed(String orgId) {
    return followedIdsNotifier.value.contains(orgId);
  }

  /// Toggles the follow status of an organization and updates subscribers.
  /// The change shows at once; if saving fails it is undone and a
  /// [FollowException] is thrown.
  Future<bool> toggleFollow(String orgId, {String? userId}) async {
    final effectiveUid = (userId != null && userId.isNotEmpty)
        ? userId
        : (_currentUserId.isNotEmpty
            ? _currentUserId
            : (AuthService.currentUser?.uid ?? ''));
    _currentUserId = effectiveUid;

    final previous = followedIdsNotifier.value;
    final current = Set<String>.from(previous);
    final willFollow = !current.contains(orgId);

    if (willFollow) {
      current.add(orgId);
    } else {
      current.remove(orgId);
    }

    followedIdsNotifier.value = current;

    if (!_usesFirebase) {
      if (effectiveUid.isNotEmpty) {
        await _writeLocalFollows(effectiveUid, current);
      }
      return willFollow;
    }

    _pendingToggles.add(orgId);
    try {
      await _saveFollow(orgId, follow: willFollow);
    } on FollowException {
      final reverted = Set<String>.from(followedIdsNotifier.value);
      if (willFollow) {
        reverted.remove(orgId);
      } else {
        reverted.add(orgId);
      }
      followedIdsNotifier.value = reverted;
      rethrow;
    } finally {
      _pendingToggles.remove(orgId);
    }
    return willFollow;
  }

  Future<void> _saveFollow(String orgId, {required bool follow}) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('setOrganizationFollow')
          .call<Object?>({'organizationId': orgId, 'follow': follow});
    } on FirebaseFunctionsException catch (error) {
      throw FollowException(switch (error.code) {
        'not-found' || 'resource-exhausted' || 'invalid-argument' =>
          error.message ?? 'This organization cannot be followed.',
        'unauthenticated' => 'Sign in to follow organizations.',
        _ => 'Could not save. Check your connection and try again.',
      });
    } catch (_) {
      throw const FollowException(
        'Could not save. Check your connection and try again.',
      );
    }
  }

  /// What to add to an organization's loaded follower count so it reflects
  /// follows made since it was loaded.
  int followerOffsetFor(PrivateOrganization org) {
    final followedNow = isFollowed(org.id) ? 1 : 0;
    // Device-only follows are never counted by the server.
    if (!_usesFirebase) return followedNow;
    final followedThen = _followedWhenCountsLoaded.contains(org.id) ? 1 : 0;
    return followedNow - followedThen;
  }

  /// Cache of recently loaded organizations by ID
  final Map<String, PrivateOrganization> _orgCache = {};

  /// Returns private organizations from Firestore filtered by search query and category.
  Future<List<PrivateOrganization>> getOrganizations({
    String? query,
    String? category,
  }) async {
    if (!_initialized) {
      await init();
    }

    final allOrgs = <String, PrivateOrganization>{};
    _followedWhenCountsLoaded = Set<String>.from(followedIds);

    try {
      // 1. Primary query: Query private sector organizations
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .where('organizationSector', isEqualTo: 'private')
            .get();
      } catch (_) {
        // Fallback: If organizationSector index is pending, get collection and filter in memory
        snapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .limit(100)
            .get();
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sector = (data['organizationSector'] ?? data['sector'] ?? '').toString().toLowerCase();
        // If sector is specified as public or lgu, skip
        if (sector == 'public' || sector == 'lgu' || sector == 'barangay') {
          continue;
        }

        final status = data['status']?.toString().toLowerCase() ?? 'verified';
        if (status == 'deactivated' || status == 'inactive' || status == 'rejected') {
          continue;
        }

        final org = PrivateOrganization.fromFirestore(doc.id, data);
        allOrgs[org.id] = org;
        _orgCache[org.id] = org;
      }
    } catch (_) {
      // In offline / unit-test environments where Firebase is not initialized,
      // gracefully populate from approvedOrganizations
      if (allOrgs.isEmpty) {
        for (final org in PrivateOrganization.approvedOrganizations) {
          allOrgs[org.id] = org;
          _orgCache[org.id] = org;
        }
      }
    }

    // Also check posts collection to attach real updates to each organization
    if (allOrgs.isNotEmpty) {
      try {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('status', isEqualTo: 'approved')
            .limit(50)
            .get();

        final updatesByOrg = <String, List<PrivateOrganizationUpdate>>{};
        for (final doc in postsSnapshot.docs) {
          final data = doc.data();
          final publisherId = data['publisherEntityId']?.toString() ?? data['authorId']?.toString() ?? '';
          if (publisherId.isEmpty || !allOrgs.containsKey(publisherId)) continue;

          final update = PrivateOrganizationUpdate(
            id: doc.id,
            organizationId: publisherId,
            title: data['title']?.toString() ?? 'Community Advisory',
            content: data['content']?.toString() ?? '',
            date: (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            imageUrl: data['imageUrl']?.toString(),
            category: data['category']?.toString() ?? 'Advisory',
            priority: data['priority']?.toString() ?? 'regular',
          );

          updatesByOrg.putIfAbsent(publisherId, () => []).add(update);
        }

        // Re-construct organizations with their real updates
        for (final entry in updatesByOrg.entries) {
          final existing = allOrgs[entry.key];
          if (existing != null) {
            allOrgs[entry.key] = PrivateOrganization(
              id: existing.id,
              name: existing.name,
              category: existing.category,
              shortDescription: existing.shortDescription,
              about: existing.about,
              address: existing.address,
              website: existing.website,
              logoAsset: existing.logoAsset,
              logoUrl: existing.logoUrl,
              coverImageUrl: existing.coverImageUrl,
              fallbackIcon: existing.fallbackIcon,
              brandColor: existing.brandColor,
              baseFollowerCount: existing.baseFollowerCount,
              isVerified: existing.isVerified,
              updates: entry.value,
            );
            _orgCache[entry.key] = allOrgs[entry.key]!;
          }
        }
      } catch (_) {}
    }

    var list = allOrgs.values.toList();

    // Filter by category
    if (category != null && category.trim().isNotEmpty && category.trim() != 'All') {
      final normCat = category.trim().toLowerCase();
      list = list.where((org) {
        final orgCat = org.category.toLowerCase();
        if (normCat == 'others') {
          return orgCat == 'others' ||
              (!orgCat.contains('bank') &&
                  !orgCat.contains('school') &&
                  !orgCat.contains('health') &&
                  !orgCat.contains('util') &&
                  !orgCat.contains('telecom') &&
                  !orgCat.contains('transport'));
        }
        return orgCat.contains(normCat) || normCat.contains(orgCat);
      }).toList();
    }

    // Filter by search query
    if (query != null && query.trim().isNotEmpty) {
      final cleanQuery = query.trim().toLowerCase();
      list = list.where((org) {
        return org.name.toLowerCase().contains(cleanQuery) ||
            org.category.toLowerCase().contains(cleanQuery) ||
            org.shortDescription.toLowerCase().contains(cleanQuery) ||
            org.about.toLowerCase().contains(cleanQuery) ||
            org.address.toLowerCase().contains(cleanQuery);
      }).toList();
    }

    return list;
  }

  /// Finds a specific private organization by ID (from cache or Firestore).
  Future<PrivateOrganization?> fetchOrganizationById(String orgId) async {
    if (_orgCache.containsKey(orgId)) {
      return _orgCache[orgId];
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
      if (doc.exists && doc.data() != null) {
        final org = PrivateOrganization.fromFirestore(doc.id, doc.data()!);
        _orgCache[orgId] = org;
        return org;
      }
    } catch (_) {}
    return null;
  }

  /// Synchronous lookup from memory cache.
  PrivateOrganization? getOrganizationById(String orgId) {
    return _orgCache[orgId];
  }

  /// Checks whether a [CommunityPost] originates from a private organization.
  /// Organization posts count as private until the directory's organization
  /// list has loaded, after which public-sector organizations are excluded.
  bool isPrivateOrganizationPost(CommunityPost post) {
    if (post.publisherEntityType == 'private_organization') return true;

    final role = post.authorRole.toLowerCase();
    final fromOrganization = post.publisherEntityType == 'organization' ||
        role == 'organization' ||
        role == 'partner' ||
        post.tag.toUpperCase() == 'PARTNER';
    if (!fromOrganization) return false;

    final privateIds = privateOrganizationIdsNotifier.value;
    if (privateIds == null) return true;
    return privateIds.contains(post.publisherEntityId) ||
        privateIds.contains(post.authorId);
  }

  /// Keeps the posts a resident should see in Home and Updates.
  List<CommunityPost> visiblePosts(Iterable<CommunityPost> posts) {
    final followed = followedIds;
    return posts
        .where((post) => shouldShowPostInUpdates(post, followed))
        .toList();
  }

  /// Determines if a post should be shown in the Home and Updates feeds:
  /// - Public / Barangay / LGU / Public Organization posts remain ALWAYS visible.
  /// - Private Organization posts appear ONLY if followed.
  bool shouldShowPostInUpdates(CommunityPost post, Set<String> followedIds) {
    // Private organization posts need a follow, whatever their tag says;
    // the organization's own staff always see them.
    if (isPrivateOrganizationPost(post)) {
      final me = AuthService.currentUser;
      final myOrganizationId = me?.organizationId ?? '';
      if (me != null &&
          (post.authorId == me.uid ||
              (myOrganizationId.isNotEmpty &&
                  post.publisherEntityId == myOrganizationId))) {
        return true;
      }
      return followedIds.contains(post.publisherEntityId) ||
          followedIds.contains(post.authorId);
    }
    // Municipal, barangay, public-agency and other posts are always visible.
    return true;
  }
}
