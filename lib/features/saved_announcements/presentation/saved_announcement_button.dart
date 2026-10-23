import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth_service.dart';
import '../../../community_service.dart';
import '../services/saved_announcement_service.dart';

class SavedAnnouncementButton extends StatefulWidget {
  final CommunityPost announcement;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final double iconSize;

  const SavedAnnouncementButton({
    super.key,
    required this.announcement,
    required this.color,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 21,
  });

  @override
  State<SavedAnnouncementButton> createState() =>
      _SavedAnnouncementButtonState();
}

class _SavedAnnouncementButtonState extends State<SavedAnnouncementButton> {
  SavedAnnouncementService get _service => SavedAnnouncementService.instance;
  StreamSubscription<Set<String>>? _remoteSubscription;
  StreamSubscription<dynamic>? _localSubscription;
  bool _savedLocally = false;
  bool _savedRemotely = false;
  bool _busy = false;

  bool get _saved => _savedLocally || _savedRemotely;

  User? get _user => AuthService.currentUser;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    final user = _user;
    if (user == null || user.role != UserRole.resident) return;
    final local = await _service.isSavedLocally(
      user.uid,
      widget.announcement.id,
    );
    if (mounted) setState(() => _savedLocally = local);
    _localSubscription = _service.watchOffline(user.uid).listen((records) {
      final saved = records.any(
        (record) => record.announcementId == widget.announcement.id,
      );
      if (mounted && saved != _savedLocally) {
        setState(() => _savedLocally = saved);
      }
    });
    _remoteSubscription = _service.watchSavedIds(user.uid).listen((ids) {
      final saved = ids.contains(widget.announcement.id);
      if (mounted && saved != _savedRemotely) {
        setState(() => _savedRemotely = saved);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.lightImpact();
    final user = _user;
    if (user == null || _busy) return;
    if (!user.canUseInteractiveFeatures) {
      _showMessage('Verify your account first before saving announcements.',
        kind: FeedbackKind.info,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (_saved) {
        await _service.unsave(
          userId: user.uid,
          announcementId: widget.announcement.id,
        );
        if (mounted) {
          setState(() {
            _savedLocally = false;
            _savedRemotely = false;
          });
        }
        _showMessage('Removed from Saved.', kind: FeedbackKind.success);
      } else {
        final result = await _service.save(
          userId: user.uid,
          announcement: widget.announcement,
        );
        if (mounted) {
          setState(() {
            _savedLocally = true;
            _savedRemotely = true;
          });
        }
        _showMessage(
          result.imageAvailableOffline
              ? 'Saved. Available offline.'
              : 'Saved. Image will require internet.',
          kind: FeedbackKind.success,
        );
      }
    } on SavedAnnouncementException catch (error) {
      _showMessage(error.message, kind: FeedbackKind.error);
    } on Object {
      _showMessage('Could not update Saved right now. Please try again.',
        kind: FeedbackKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {FeedbackKind kind = FeedbackKind.info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppSnackBar(AppSnackBar(content: Text(message), kind: kind));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null || user.role != UserRole.resident) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: _saved ? 'Remove from saved announcements' : 'Save announcement',
      child: IconButton(
        tooltip: _saved ? 'Saved (Tap to remove)' : 'Save for offline',
        onPressed: _busy ? null : _toggle,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(34, 34),
          backgroundColor: widget.backgroundColor ??
              (_saved
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent),
          foregroundColor: _saved ? widget.color : widget.color.withValues(alpha: 0.7),
          disabledForegroundColor: widget.color.withValues(alpha: 0.45),
          side: widget.borderColor == null
              ? null
              : BorderSide(color: widget.borderColor!, width: 1),
        ),
        icon: _busy
            ? SizedBox.square(
                dimension: widget.iconSize - 4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.color,
                ),
              )
            : Icon(
                _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: widget.iconSize,
              ),
      ),
    );
  }
}
