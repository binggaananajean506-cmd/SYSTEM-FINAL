import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../community_service.dart';

class SavedAnnouncementBookmark {
  final String announcementId;
  final DateTime? savedAt;

  const SavedAnnouncementBookmark({required this.announcementId, this.savedAt});

  factory SavedAnnouncementBookmark.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return SavedAnnouncementBookmark(
      announcementId: data['announcementId']?.toString() ?? snapshot.id,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }
}

abstract interface class SavedBookmarkStore {
  Stream<Set<String>> watchIds(String userId);
  Future<List<SavedAnnouncementBookmark>> loadFromServer(String userId);
  Future<void> save(String userId, String announcementId);
  Future<void> remove(String userId, String announcementId);
  Future<CommunityPost?> loadSourceFromServer(String announcementId);
}

class FirestoreSavedBookmarkStore implements SavedBookmarkStore {
  final FirebaseFirestore _firestore;

  FirestoreSavedBookmarkStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _bookmarks(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_announcements');

  @override
  Stream<Set<String>> watchIds(String userId) {
    return _bookmarks(userId).snapshots().map(
      (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
    );
  }

  @override
  Future<List<SavedAnnouncementBookmark>> loadFromServer(String userId) async {
    final snapshot = await _bookmarks(
      userId,
    ).get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map(SavedAnnouncementBookmark.fromFirestore)
        .toList(growable: false);
  }

  @override
  Future<void> save(String userId, String announcementId) {
    return _bookmarks(userId).doc(announcementId).set({
      'announcementId': announcementId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> remove(String userId, String announcementId) {
    return _bookmarks(userId).doc(announcementId).delete();
  }

  @override
  Future<CommunityPost?> loadSourceFromServer(String announcementId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(announcementId)
        .get(const GetOptions(source: Source.server));
    return snapshot.exists ? CommunityPost.fromDoc(snapshot) : null;
  }
}
