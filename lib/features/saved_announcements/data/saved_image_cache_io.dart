import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  static const int maximumBytes = 8 * 1024 * 1024;
  final http.Client _client;

  DeviceSavedImageCache({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<String> download({
    required String userId,
    required String announcementId,
    required String imageUrl,
  }) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.isScheme('https')) {
      throw const FormatException('Unsupported announcement image URL.');
    }

    final request = http.Request('GET', uri);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Image download failed (${response.statusCode}).');
    }
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maximumBytes) {
      throw const FileSystemException('Announcement image is too large.');
    }

    final bytes = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      received += chunk.length;
      if (received > maximumBytes) {
        throw const FileSystemException('Announcement image is too large.');
      }
      bytes.add(chunk);
    }

    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}saved_announcements'
      '${Platform.pathSeparator}${_safe(userId)}',
    );
    await directory.create(recursive: true);
    final extension = _extension(response.headers['content-type']);
    final destination = File(
      '${directory.path}${Platform.pathSeparator}${_safe(announcementId)}$extension',
    );
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(bytes.takeBytes(), flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
    return destination.path;
  }

  @override
  Future<bool> exists(String localPath) async {
    if (localPath.isEmpty) return false;
    return File(localPath).exists();
  }

  @override
  Future<void> remove(String localPath) async {
    if (localPath.isEmpty) return;
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  String _extension(String? contentType) =>
      switch (contentType?.split(';').first) {
        'image/png' => '.png',
        'image/webp' => '.webp',
        _ => '.jpg',
      };
}
