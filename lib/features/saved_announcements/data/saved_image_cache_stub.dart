abstract interface class SavedImageCache {
  Future<String> download({
    required String userId,
    required String announcementId,
    required String imageUrl,
  });
  Future<void> remove(String localPath);
  Future<bool> exists(String localPath);
}

class DeviceSavedImageCache implements SavedImageCache {
  @override
  Future<String> download({
    required String userId,
    required String announcementId,
    required String imageUrl,
  }) async => '';

  @override
  Future<bool> exists(String localPath) async => false;

  @override
  Future<void> remove(String localPath) async {}
}
