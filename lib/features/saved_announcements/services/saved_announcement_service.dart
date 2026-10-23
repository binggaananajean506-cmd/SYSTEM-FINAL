import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../community_service.dart';
import '../data/offline_announcement_repository.dart';
import '../data/saved_bookmark_store.dart';
import '../data/saved_image_cache.dart';
import '../domain/offline_announcement.dart';

enum SavedAnnouncementSyncState { complete, offline, partial }

class SavedAnnouncementSaveResult {
  final bool imageAvailableOffline;

  const SavedAnnouncementSaveResult({required this.imageAvailableOffline});
}

class SavedAnnouncementSyncResult {
  final SavedAnnouncementSyncState state;
  final int synchronizedCount;

  const SavedAnnouncementSyncResult(this.state, this.synchronizedCount);

  bool get isOffline => state == SavedAnnouncementSyncState.offline;
}

class SavedAnnouncementException implements Exception {
  final String message;
  const SavedAnnouncementException(this.message);

  @override
  String toString() => message;
}

class SavedAnnouncementService {
  final SavedBookmarkStore bookmarks;
  final OfflineAnnouncementRepository offline;
  final SavedImageCache images;
  final Map<String, Stream<Set<String>>> _bookmarkStreams = {};
  final Set<String> _syncingUsers = {};

  SavedAnnouncementService({
    SavedBookmarkStore? bookmarks,
    OfflineAnnouncementRepository? offline,
    SavedImageCache? images,
  }) : bookmarks = bookmarks ?? FirestoreSavedBookmarkStore(),
       offline = offline ?? PreferencesOfflineAnnouncementRepository(),
       images = images ?? DeviceSavedImageCache();

  static final SavedAnnouncementService instance = SavedAnnouncementService();

  Stream<Set<String>> watchSavedIds(String userId) {
    return _bookmarkStreams.putIfAbsent(
      userId,
      () => bookmarks.watchIds(userId).asBroadcastStream(),
    );
  }

  Stream<List<OfflineAnnouncement>> watchOffline(String userId) =>
      offline.watch(userId);

  Future<List<OfflineAnnouncement>> loadOffline(String userId) =>
      offline.load(userId);

  Future<bool> isSavedLocally(String userId, String announcementId) async =>
      await offline.find(userId, announcementId) != null;

  Future<SavedAnnouncementSaveResult> save({
    required String userId,
    required CommunityPost announcement,
  }) async {
    if (userId.isEmpty || announcement.id.isEmpty) {
      throw const SavedAnnouncementException(
        'This announcement cannot be saved right now.',
      );
    }

    try {
      await bookmarks.save(userId, announcement.id);
    } on FirebaseException catch (error) {
      throw SavedAnnouncementException(_bookmarkError(error, saving: true));
    }

    var record = OfflineAnnouncement.fromPost(
      userId: userId,
      post: announcement,
    );
    try {
      await offline.upsert(record);
    } on Object {
      throw const SavedAnnouncementException(
        'Bookmarked online, but this device could not store the offline copy.',
      );
    }

    var imageAvailable = announcement.imageUrl.trim().isEmpty;
    if (announcement.imageUrl.trim().isNotEmpty) {
      try {
        final path = await images.download(
          userId: userId,
          announcementId: announcement.id,
          imageUrl: announcement.imageUrl,
        );
        imageAvailable = path.isNotEmpty;
        if (path.isNotEmpty) {
          record = record.copyWith(localImagePath: path);
          await offline.upsert(record);
        }
      } on Object catch (error) {
        debugPrint('Saved announcement image cache skipped: $error');
      }
    }
    return SavedAnnouncementSaveResult(imageAvailableOffline: imageAvailable);
  }

  Future<void> unsave({
    required String userId,
    required String announcementId,
  }) async {
    try {
      await bookmarks.remove(userId, announcementId);
    } on FirebaseException catch (error) {
      throw SavedAnnouncementException(_bookmarkError(error, saving: false));
    }
    final removed = await offline.remove(userId, announcementId);
    if (removed != null) {
      try {
        await images.remove(removed.localImagePath);
      } on Object catch (error) {
        debugPrint('Saved announcement image cleanup skipped: $error');
      }
    }
  }

  Future<SavedAnnouncementSyncResult> sync(String userId) async {
    if (userId.isEmpty || !_syncingUsers.add(userId)) {
      return const SavedAnnouncementSyncResult(
        SavedAnnouncementSyncState.complete,
        0,
      );
    }
    try {
      final remoteBookmarks = await bookmarks.loadFromServer(userId);
      final localRecords = await offline.load(userId);
      final localById = {
        for (final record in localRecords) record.announcementId: record,
      };
      final remoteIds = remoteBookmarks
          .map((bookmark) => bookmark.announcementId)
          .toSet();
      var synchronized = 0;
      var partial = false;

      for (final stale in localRecords.where(
        (record) => !remoteIds.contains(record.announcementId),
      )) {
        await _removeLocalRecord(stale);
      }

      for (final bookmark in remoteBookmarks) {
        final existing = localById[bookmark.announcementId];
        if (existing?.sourceUnavailable == true) continue;
        try {
          final latest = await bookmarks.loadSourceFromServer(
            bookmark.announcementId,
          );
          if (latest == null) {
            if (existing != null) {
              await offline.upsert(
                existing.copyWith(
                  sourceUnavailable: true,
                  lastSyncedAt: DateTime.now().toUtc(),
                ),
              );
            }
            continue;
          }

          final needsRefresh =
              existing == null ||
              latest.updatedAt.isAfter(existing.sourceUpdatedAt) ||
              latest.imageUrl != existing.networkImageUrl ||
              existing.sourceUnavailable;
          if (!needsRefresh) continue;

          var localImagePath = existing?.localImagePath ?? '';
          final imageChanged = existing?.networkImageUrl != latest.imageUrl;
          if (imageChanged && localImagePath.isNotEmpty) {
            await images.remove(localImagePath);
            localImagePath = '';
          }
          var updated = OfflineAnnouncement.fromPost(
            userId: userId,
            post: latest,
            savedAt: existing?.savedAt ?? bookmark.savedAt,
            localImagePath: localImagePath,
          );
          await offline.upsert(updated);

          if (latest.imageUrl.isNotEmpty &&
              (imageChanged || !await images.exists(localImagePath))) {
            try {
              final downloaded = await images.download(
                userId: userId,
                announcementId: latest.id,
                imageUrl: latest.imageUrl,
              );
              if (downloaded.isNotEmpty) {
                updated = updated.copyWith(localImagePath: downloaded);
                await offline.upsert(updated);
              }
            } on Object catch (error) {
              partial = true;
              debugPrint('Saved announcement image refresh skipped: $error');
            }
          }
          synchronized++;
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied') {
            if (existing != null) await _removeLocalRecord(existing);
            try {
              await bookmarks.remove(userId, bookmark.announcementId);
            } on Object catch (cleanupError) {
              debugPrint(
                'Revoked saved announcement bookmark cleanup skipped: $cleanupError',
              );
            }
          } else if (_isNetworkError(error)) {
            return SavedAnnouncementSyncResult(
              SavedAnnouncementSyncState.offline,
              synchronized,
            );
          } else {
            partial = true;
            debugPrint('Saved announcement sync skipped one record: $error');
          }
        } on Object catch (error) {
          partial = true;
          debugPrint('Saved announcement sync skipped one record: $error');
        }
      }
      return SavedAnnouncementSyncResult(
        partial
            ? SavedAnnouncementSyncState.partial
            : SavedAnnouncementSyncState.complete,
        synchronized,
      );
    } on FirebaseException catch (error) {
      if (_isNetworkError(error)) {
        return const SavedAnnouncementSyncResult(
          SavedAnnouncementSyncState.offline,
          0,
        );
      }
      debugPrint('Saved announcement bookmark sync failed: $error');
      return const SavedAnnouncementSyncResult(
        SavedAnnouncementSyncState.partial,
        0,
      );
    } finally {
      _syncingUsers.remove(userId);
    }
  }

  Future<void> _removeLocalRecord(OfflineAnnouncement record) async {
    await offline.remove(record.userId, record.announcementId);
    try {
      await images.remove(record.localImagePath);
    } on Object catch (error) {
      debugPrint('Saved announcement image cleanup skipped: $error');
    }
  }

  bool _isNetworkError(FirebaseException error) =>
      error.code == 'unavailable' ||
      error.code == 'deadline-exceeded' ||
      error.code == 'network-request-failed';

  String _bookmarkError(FirebaseException error, {required bool saving}) {
    if (error.code == 'permission-denied') {
      return 'Verify your account first before saving announcements.';
    }
    if (_isNetworkError(error)) {
      return saving
          ? 'Could not save right now. Check your connection and try again.'
          : 'Could not remove this saved announcement. Check your connection and try again.';
    }
    return saving
        ? 'This announcement could not be saved right now.'
        : 'This announcement could not be removed right now.';
  }
}
