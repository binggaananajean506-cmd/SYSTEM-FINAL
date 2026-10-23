import 'dart:typed_data';
import 'package:flutter/widgets.dart';

class AnnouncementImageCache {
  AnnouncementImageCache._();

  static Future<void> initialize({String? customPath}) async {}

  static String? getCachedPathSync(String? imageUrl) => null;

  static Future<String?> getCachedPath(String? imageUrl) async => null;

  static Future<String> saveImageBytes({
    required String key,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async => '';

  static Future<String?> downloadAndCache(String? imageUrl) async => null;

  static Future<void> precache(String? imageUrl, BuildContext context) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || !context.mounted) return;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (_) {}
  }

  static Future<void> clearCache() async {}
}
