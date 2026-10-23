import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AnnouncementImageCache {
  AnnouncementImageCache._();

  static const int maximumBytes = 12 * 1024 * 1024; // 12 MB max per image
  static String? _cacheDirectoryPath;
  static final Map<String, Future<String?>> _inFlightDownloads = {};
  static http.Client _client = http.Client();

  @visibleForTesting
  static void setMockClient(http.Client client) {
    _client = client;
  }

  static Future<void> initialize({String? customPath}) async {
    try {
      if (customPath != null) {
        _cacheDirectoryPath = customPath;
      } else {
        final supportDir = await getApplicationSupportDirectory();
        _cacheDirectoryPath =
            '${supportDir.path}${Platform.pathSeparator}announcement_cache';
      }
      final dir = Directory(_cacheDirectoryPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('AnnouncementImageCache initialize error: $e');
    }
  }

  static String _hashUrl(String url) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < url.length; i++) {
      hash ^= url.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _detectExtension(String url, [String? contentType]) {
    if (contentType != null) {
      final lower = contentType.toLowerCase();
      if (lower.contains('png')) return '.png';
      if (lower.contains('webp')) return '.webp';
      if (lower.contains('gif')) return '.gif';
      if (lower.contains('jpeg') || lower.contains('jpg')) return '.jpg';
    }
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.png')) return '.png';
    if (clean.endsWith('.webp')) return '.webp';
    if (clean.endsWith('.gif')) return '.gif';
    return '.jpg';
  }

  static String fileNameFor(String key, [String? extension]) {
    final safeKey = _hashUrl(key);
    final ext = extension ?? _detectExtension(key);
    return 'ann_$safeKey$ext';
  }

  static String? getCachedPathSync(String? imageUrl) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || _cacheDirectoryPath == null) return null;
    final filePath =
        '$_cacheDirectoryPath${Platform.pathSeparator}${fileNameFor(url)}';
    if (File(filePath).existsSync()) {
      return filePath;
    }
    return null;
  }

  static Future<String?> getCachedPath(String? imageUrl) async {
    final syncPath = getCachedPathSync(imageUrl);
    if (syncPath != null) return syncPath;
    if (_cacheDirectoryPath == null) {
      await initialize();
      return getCachedPathSync(imageUrl);
    }
    return null;
  }

  static Future<String> saveImageBytes({
    required String key,
    required Uint8List bytes,
    String? extension,
  }) async {
    if (_cacheDirectoryPath == null) {
      await initialize();
    }
    final dirPath = _cacheDirectoryPath;
    if (dirPath == null) {
      throw StateError('AnnouncementImageCache directory is not available.');
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = fileNameFor(key, extension);
    final destination = File('$dirPath${Platform.pathSeparator}$fileName');
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  static Future<String?> downloadAndCache(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return null;

    final cached = getCachedPathSync(url);
    if (cached != null) return cached;

    if (_inFlightDownloads.containsKey(url)) {
      return _inFlightDownloads[url];
    }

    final completer = Completer<String?>();
    _inFlightDownloads[url] = completer.future;

    unawaited(() async {
      try {
        if (_cacheDirectoryPath == null) {
          await initialize();
        }
        final dirPath = _cacheDirectoryPath;
        if (dirPath == null) {
          completer.complete(null);
          return;
        }

        final uri = Uri.tryParse(url);
        if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
          completer.complete(null);
          return;
        }

        final request = http.Request('GET', uri);
        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          completer.complete(null);
          return;
        }

        final declaredLength = response.contentLength;
        if (declaredLength != null && declaredLength > maximumBytes) {
          completer.complete(null);
          return;
        }

        final builder = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (received > maximumBytes) {
            completer.complete(null);
            return;
          }
          builder.add(chunk);
        }

        final bytes = builder.takeBytes();
        final fileName = fileNameFor(url);
        final destination = File('$dirPath${Platform.pathSeparator}$fileName');
        await destination.writeAsBytes(bytes, flush: true);
        completer.complete(destination.path);
      } catch (error) {
        debugPrint('Announcement image download failed for $url: $error');
        completer.complete(null);
      } finally {
        _inFlightDownloads.remove(url);
      }
    }());

    return completer.future;
  }

  static Future<void> precache(String? imageUrl, BuildContext context) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || !context.mounted) return;

    final cached = getCachedPathSync(url);
    if (cached != null) {
      if (context.mounted) {
        try {
          await precacheImage(FileImage(File(cached)), context);
        } catch (_) {}
      }
      return;
    }

    // Download in background, then precache
    final downloadedPath = await downloadAndCache(url);
    if (downloadedPath != null && context.mounted) {
      try {
        await precacheImage(FileImage(File(downloadedPath)), context);
      } catch (_) {}
    }
  }

  static Future<void> clearCache() async {
    if (_cacheDirectoryPath == null) return;
    try {
      final dir = Directory(_cacheDirectoryPath!);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }
}
