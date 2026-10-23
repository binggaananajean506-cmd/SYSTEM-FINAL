import 'package:flutter/material.dart';

Widget buildDeviceAnnouncementImage({
  required String localPath,
  required String networkUrl,
  required BoxFit fit,
  int? cacheWidth,
  required Widget fallback,
  Widget? loading,
}) {
  final cleanUrl = networkUrl.trim();
  if (cleanUrl.isEmpty) return fallback;
  return Image.network(
    cleanUrl,
    fit: fit,
    cacheWidth: cacheWidth,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) {
        return child;
      }
      return loading ?? fallback;
    },
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}
