import 'dart:io';
import 'dart:typed_data';

import 'package:esugid/community_service.dart';
import 'package:esugid/features/saved_announcements/presentation/offline_announcement_image.dart';
import 'package:esugid/services/announcement_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final testBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('announcement_cache_test_');
    await AnnouncementImageCache.initialize(customPath: tempDir.path);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('AnnouncementImageCache', () {
    test('saveImageBytes and getCachedPathSync work deterministically', () async {
      const testUrl = 'https://firebasestorage.googleapis.com/test_announcement_photo.png';

      expect(AnnouncementImageCache.getCachedPathSync(testUrl), isNull);

      final savedPath = await AnnouncementImageCache.saveImageBytes(
        key: testUrl,
        bytes: testBytes,
        extension: '.png',
      );

      expect(File(savedPath).existsSync(), isTrue);

      final syncPath = AnnouncementImageCache.getCachedPathSync(testUrl);
      expect(syncPath, isNotNull);
      expect(syncPath, equals(savedPath));
    });
  });

  group('offlineFirstAnnouncementImage', () {
    testWidgets('renders Image.file synchronously when networkUrl is cached on disk', (tester) async {
      const testUrl = 'https://example.com/cached_announcement.png';
      // File persistence now uses real asynchronous I/O, outside fake test time.
      final savedPath = await tester.runAsync(
        () => AnnouncementImageCache.saveImageBytes(
          key: testUrl,
          bytes: testBytes,
          extension: '.png',
        ),
      );
      final syncPath = AnnouncementImageCache.getCachedPathSync(testUrl);
      expect(syncPath, equals(savedPath));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: offlineFirstAnnouncementImage(
              localPath: '',
              networkUrl: testUrl,
              fit: BoxFit.cover,
              fallback: const Text('FALLBACK_TEXT'),
            ),
          ),
        ),
      );

      // Should render Image.file from disk immediately without showing fallback
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('FALLBACK_TEXT'), findsNothing);
    });
  });

  group('CommunityPost local cache persistence', () {
    test('toLocalCache and fromLocalCache preserve localImagePath', () {
      final post = CommunityPost(
        id: 'post-1',
        title: 'Title',
        content: 'Content',
        authorName: 'Author',
        authorId: 'user-1',
        authorRole: 'lgu',
        authorBarangay: 'Barili',
        authorOrganizationName: 'LGU',
        targetAudience: 'All',
        targetBarangay: 'All Barangays',
        visibility: 'public',
        targetBarangays: const [],
        imageUrl: 'https://example.com/post.jpg',
        localImagePath: '/data/user/0/app/cache/post.jpg',
        createdAt: DateTime(2026, 1, 1),
        status: 'approved',
        tag: 'OFFICIAL',
      );

      final map = post.toLocalCache();
      expect(map['localImagePath'], equals('/data/user/0/app/cache/post.jpg'));

      final restored = CommunityPost.fromLocalCache(map);
      expect(restored.localImagePath, equals('/data/user/0/app/cache/post.jpg'));
    });
  });
}
