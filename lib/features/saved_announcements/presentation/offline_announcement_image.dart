import 'package:flutter/material.dart';

import 'offline_announcement_image_stub.dart'
    if (dart.library.io) 'offline_announcement_image_io.dart';

Widget offlineFirstAnnouncementImage({
  required String localPath,
  required String networkUrl,
  required BoxFit fit,
  int? cacheWidth,
  required Widget fallback,
  Widget? loading,
}) {
  return buildDeviceAnnouncementImage(
    localPath: localPath,
    networkUrl: networkUrl,
    fit: fit,
    cacheWidth: cacheWidth,
    fallback: fallback,
    loading: loading,
  );
}
