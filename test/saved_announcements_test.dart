import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:esugid/community_service.dart';
import 'package:esugid/features/saved_announcements/data/offline_announcement_repository.dart';
import 'package:esugid/features/saved_announcements/data/saved_bookmark_store.dart';
import 'package:esugid/features/saved_announcements/data/saved_image_cache.dart';
import 'package:esugid/features/saved_announcements/domain/offline_announcement.dart';
import 'package:esugid/features/saved_announcements/services/saved_announcement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CommunityPost post({
    String id = 'assembly',
    String title = 'Barangay Assembly',
    String content = 'Residents are invited to attend.',
    String status = 'approved',
    String imageUrl = '',
    String category = 'Events',
    String customCategory = '',
    DateTime? updatedAt,
  }) {
    final created = DateTime.utc(2026, 8, 30, 9);
    return CommunityPost(
      id: id,
      title: title,
      content: content,
      authorName: 'Barangay Vito',
      authorId: 'official',
      authorRole: 'barangay_captain',
      authorBarangay: 'Vito',
      authorOrganizationName: '',
      targetAudience: 'All Residents',
      targetBarangay: 'Vito',
      visibility: 'targeted',
      targetBarangays: const ['Vito'],
      imageUrl: imageUrl,
      createdAt: created,
      updatedAt: updatedAt ?? created,
      status: status,
      tag: 'OFFICIAL',
      category: category,
      customCategory: customCategory,
      location: 'Barangay Hall',
    );
  }

  test('offline model round-trips and searches local fields', () {
    final record = OfflineAnnouncement.fromPost(
      userId: 'resident-a',
      post: post(),
    );
    final decoded = OfflineAnnouncement.fromLocal(record.toLocal());

    expect(decoded.announcementId, 'assembly');
    expect(decoded.toPost().location, 'Barangay Hall');
    expect(decoded.matchesSearch('assembly'), isTrue);
    expect(decoded.matchesSearch('barangay hall'), isTrue);
    expect(decoded.matchesSearch('medical mission'), isFalse);
  });

  test('custom announcement category is displayed and retained offline', () {
    final announcement = post(
      category: 'Other Notice',
      customCategory: 'Transportation Update',
    );
    final cached = CommunityPost.fromLocalCache(announcement.toLocalCache());
    final offline = OfflineAnnouncement.fromPost(
      userId: 'resident-a',
      post: announcement,
    );

    expect(announcement.displayCategory, 'Transportation Update');
    expect(cached.displayCategory, 'Transportation Update');
    expect(offline.category, 'Transportation Update');
  });

  test('local records use announcement id as a duplicate-safe key', () async {
    final repository = PreferencesOfflineAnnouncementRepository();
    await repository.upsert(
      OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
    );
    await repository.upsert(
      OfflineAnnouncement.fromPost(
        userId: 'resident-a',
        post: post(title: 'Updated Assembly'),
      ),
    );

    final records = await repository.load('resident-a');
    expect(records, hasLength(1));
    expect(records.single.title, 'Updated Assembly');
  });

  test('offline records are isolated by authenticated UID', () async {
    final repository = PreferencesOfflineAnnouncementRepository();
    await repository.upsert(
      OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
    );
    await repository.upsert(
      OfflineAnnouncement.fromPost(
        userId: 'resident-b',
        post: post(id: 'health'),
      ),
    );

    expect(
      (await repository.load('resident-a')).map((item) => item.announcementId),
      ['assembly'],
    );
    expect(
      (await repository.load('resident-b')).map((item) => item.announcementId),
      ['health'],
    );
  });

  test('save and unsave persist one bookmark and clean local image', () async {
    final remote = _FakeBookmarkStore();
    final local = PreferencesOfflineAnnouncementRepository();
    final images = _FakeImageCache(path: 'device/assembly.jpg');
    final service = SavedAnnouncementService(
      bookmarks: remote,
      offline: local,
      images: images,
    );

    await service.save(
      userId: 'resident-a',
      announcement: post(imageUrl: 'https://example.com/assembly.jpg'),
    );
    await service.save(
      userId: 'resident-a',
      announcement: post(imageUrl: 'https://example.com/assembly.jpg'),
    );

    expect(remote.idsFor('resident-a'), {'assembly'});
    expect(remote.lastSavedDocumentId, 'assembly');
    expect(await local.load('resident-a'), hasLength(1));
    expect((await local.load('resident-a')).single.localImagePath, isNotEmpty);

    await service.unsave(userId: 'resident-a', announcementId: 'assembly');
    expect(remote.idsFor('resident-a'), isEmpty);
    expect(await local.load('resident-a'), isEmpty);
    expect(images.removedPaths, contains('device/assembly.jpg'));
  });

  test('image failure keeps the saved text available offline', () async {
    final remote = _FakeBookmarkStore();
    final local = PreferencesOfflineAnnouncementRepository();
    final service = SavedAnnouncementService(
      bookmarks: remote,
      offline: local,
      images: _FakeImageCache(failDownload: true),
    );

    final result = await service.save(
      userId: 'resident-a',
      announcement: post(imageUrl: 'https://example.com/assembly.jpg'),
    );

    expect(result.imageAvailableOffline, isFalse);
    final stored = (await local.load('resident-a')).single;
    expect(stored.content, 'Residents are invited to attend.');
    expect(stored.localImagePath, isEmpty);
  });

  test(
    'saved content loads from local storage when Firebase is unavailable',
    () async {
      final remote = _FakeBookmarkStore(
        loadError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      final local = PreferencesOfflineAnnouncementRepository();
      await local.upsert(
        OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
      );
      final service = SavedAnnouncementService(
        bookmarks: remote,
        offline: local,
        images: _FakeImageCache(),
      );

      final result = await service.sync('resident-a');

      expect(result.isOffline, isTrue);
      expect(await service.loadOffline('resident-a'), hasLength(1));
    },
  );

  test('newer Firebase source updates the local snapshot', () async {
    final remote = _FakeBookmarkStore();
    remote.save('resident-a', 'assembly');
    remote.sources['assembly'] = post(
      title: 'Assembly Rescheduled',
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    final local = PreferencesOfflineAnnouncementRepository();
    await local.upsert(
      OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
    );
    final service = SavedAnnouncementService(
      bookmarks: remote,
      offline: local,
      images: _FakeImageCache(),
    );

    final result = await service.sync('resident-a');

    expect(result.synchronizedCount, 1);
    expect(
      (await local.load('resident-a')).single.title,
      'Assembly Rescheduled',
    );
  });

  test('cancelled source remains saved and is clearly updated', () async {
    final remote = _FakeBookmarkStore();
    remote.save('resident-a', 'assembly');
    remote.sources['assembly'] = post(
      status: 'cancelled',
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    final local = PreferencesOfflineAnnouncementRepository();
    await local.upsert(
      OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
    );
    final service = SavedAnnouncementService(
      bookmarks: remote,
      offline: local,
      images: _FakeImageCache(),
    );

    await service.sync('resident-a');

    expect((await local.load('resident-a')).single.status, 'cancelled');
  });

  test('deleted source is retained as unavailable without crashing', () async {
    final remote = _FakeBookmarkStore();
    remote.save('resident-a', 'assembly');
    final local = PreferencesOfflineAnnouncementRepository();
    await local.upsert(
      OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
    );
    final service = SavedAnnouncementService(
      bookmarks: remote,
      offline: local,
      images: _FakeImageCache(),
    );

    await service.sync('resident-a');

    expect((await local.load('resident-a')).single.sourceUnavailable, isTrue);
  });

  test(
    'revoked source access purges private local content and bookmark',
    () async {
      final remote = _FakeBookmarkStore(
        sourceLoadError: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      await remote.save('resident-a', 'assembly');
      final local = PreferencesOfflineAnnouncementRepository();
      await local.upsert(
        OfflineAnnouncement.fromPost(userId: 'resident-a', post: post()),
      );
      final service = SavedAnnouncementService(
        bookmarks: remote,
        offline: local,
        images: _FakeImageCache(),
      );

      await service.sync('resident-a');

      expect(await local.load('resident-a'), isEmpty);
      expect(remote.idsFor('resident-a'), isEmpty);
    },
  );
}

class _FakeBookmarkStore implements SavedBookmarkStore {
  final Map<String, Set<String>> _ids = {};
  final Map<String, CommunityPost> sources = {};
  final FirebaseException? loadError;
  final FirebaseException? sourceLoadError;
  String? lastSavedDocumentId;

  _FakeBookmarkStore({this.loadError, this.sourceLoadError});

  Set<String> idsFor(String userId) => _ids[userId] ?? <String>{};

  @override
  Future<List<SavedAnnouncementBookmark>> loadFromServer(String userId) async {
    if (loadError != null) throw loadError!;
    return idsFor(userId)
        .map((id) => SavedAnnouncementBookmark(announcementId: id))
        .toList(growable: false);
  }

  @override
  Future<CommunityPost?> loadSourceFromServer(String announcementId) async {
    if (sourceLoadError != null) throw sourceLoadError!;
    return sources[announcementId];
  }

  @override
  Future<void> remove(String userId, String announcementId) async {
    idsFor(userId).remove(announcementId);
  }

  @override
  Future<void> save(String userId, String announcementId) async {
    lastSavedDocumentId = announcementId;
    (_ids[userId] ??= <String>{}).add(announcementId);
  }

  @override
  Stream<Set<String>> watchIds(String userId) =>
      Stream.value(Set.unmodifiable(idsFor(userId)));
}

class _FakeImageCache implements SavedImageCache {
  final String path;
  final bool failDownload;
  final List<String> removedPaths = [];

  _FakeImageCache({this.path = '', this.failDownload = false});

  @override
  Future<String> download({
    required String userId,
    required String announcementId,
    required String imageUrl,
  }) async {
    if (failDownload) throw StateError('download failed');
    return path;
  }

  @override
  Future<bool> exists(String localPath) async => localPath.isNotEmpty;

  @override
  Future<void> remove(String localPath) async {
    if (localPath.isNotEmpty) removedPaths.add(localPath);
  }
}
