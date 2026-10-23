import 'dart:io';

import 'package:flutter/material.dart';

import 'package:esugid/services/announcement_image_cache.dart';

Widget buildDeviceAnnouncementImage({
  required String localPath,
  required String networkUrl,
  required BoxFit fit,
  int? cacheWidth,
  required Widget fallback,
  Widget? loading,
}) {
  final cleanLocal = localPath.trim();
  if (cleanLocal.isNotEmpty && File(cleanLocal).existsSync()) {
    return Image.file(
      File(cleanLocal),
      fit: fit,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  final cleanUrl = networkUrl.trim();
  if (cleanUrl.isNotEmpty) {
    // Check if URL was already cached to disk synchronously
    final cachedPath = AnnouncementImageCache.getCachedPathSync(cleanUrl);
    if (cachedPath != null && File(cachedPath).existsSync()) {
      return Image.file(
        File(cachedPath),
        fit: fit,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // Not on disk yet: Stream network image and cache to disk for future app launches
    return _CachedNetworkAnnouncementImage(
      networkUrl: cleanUrl,
      fit: fit,
      cacheWidth: cacheWidth,
      fallback: fallback,
      loading: loading,
    );
  }

  return fallback;
}

class _CachedNetworkAnnouncementImage extends StatefulWidget {
  final String networkUrl;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget fallback;
  final Widget? loading;

  const _CachedNetworkAnnouncementImage({
    required this.networkUrl,
    required this.fit,
    this.cacheWidth,
    required this.fallback,
    this.loading,
  });

  @override
  State<_CachedNetworkAnnouncementImage> createState() =>
      _CachedNetworkAnnouncementImageState();
}

class _CachedNetworkAnnouncementImageState
    extends State<_CachedNetworkAnnouncementImage> {
  String? _diskCachedPath;

  @override
  void initState() {
    super.initState();
    _startBackgroundCaching();
  }

  @override
  void didUpdateWidget(covariant _CachedNetworkAnnouncementImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl) {
      _diskCachedPath = null;
      _startBackgroundCaching();
    }
  }

  void _startBackgroundCaching() {
    final url = widget.networkUrl;
    AnnouncementImageCache.downloadAndCache(url).then((savedPath) {
      if (mounted && savedPath != null && widget.networkUrl == url) {
        setState(() {
          _diskCachedPath = savedPath;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localPath = _diskCachedPath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => widget.fallback,
      );
    }

    return Image.network(
      widget.networkUrl,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return widget.loading ?? widget.fallback;
      },
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}
