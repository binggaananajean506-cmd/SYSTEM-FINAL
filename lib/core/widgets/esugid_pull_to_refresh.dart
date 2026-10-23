import 'package:esugid/app/theme/semantic_colors.dart';
import 'dart:async';

import 'package:flutter/material.dart';

enum ESugidRefreshOutcome { upToDate, updated }

typedef ESugidRefreshCallback = Future<ESugidRefreshOutcome> Function();

/// Shared pull-to-refresh behavior for E-SUGID pages.
///
/// The wrapped page keeps rendering its existing data while [onRefresh]
/// performs a server check. The indicator only listens to vertical scrolls
/// that are already at their leading edge, including lists nested in tabs.
class ESugidPullToRefresh extends StatefulWidget {
  const ESugidPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.statusTopInset = 12,
  });

  final ESugidRefreshCallback onRefresh;
  final Widget child;
  final double statusTopInset;

  @override
  State<ESugidPullToRefresh> createState() => _ESugidPullToRefreshState();
}

enum _RefreshPhase { idle, refreshing, success, failure }

class _ESugidPullToRefreshState extends State<ESugidPullToRefresh> {
  Future<void>? _inFlightRefresh;
  Timer? _statusTimer;
  _RefreshPhase _phase = _RefreshPhase.idle;
  ESugidRefreshOutcome _outcome = ESugidRefreshOutcome.upToDate;

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() {
    final running = _inFlightRefresh;
    if (running != null) return running;

    final refresh = _performRefresh();
    _inFlightRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_inFlightRefresh, refresh)) _inFlightRefresh = null;
    });
  }

  Future<void> _performRefresh() async {
    _statusTimer?.cancel();
    if (mounted) setState(() => _phase = _RefreshPhase.refreshing);

    try {
      final outcome = await widget.onRefresh();
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _phase = _RefreshPhase.success;
      });
      _scheduleStatusDismiss(const Duration(milliseconds: 1600));
    } catch (error, stackTrace) {
      debugPrint('Page refresh failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _phase = _RefreshPhase.failure);
      _scheduleStatusDismiss(const Duration(milliseconds: 2600));
    }
  }

  void _scheduleStatusDismiss(Duration delay) {
    _statusTimer?.cancel();
    _statusTimer = Timer(delay, () {
      if (mounted) setState(() => _phase = _RefreshPhase.idle);
    });
  }

  bool _acceptScrollNotification(ScrollNotification notification) {
    return notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentBefore <= 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          notificationPredicate: _acceptScrollNotification,
          triggerMode: RefreshIndicatorTriggerMode.onEdge,
          color: context.colors.primaryGreen,
          backgroundColor: Theme.of(context).colorScheme.surface,
          displacement: 44,
          child: widget.child,
        ),
        Positioned(
          top: widget.statusTopInset,
          left: 20,
          right: 20,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _phase == _RefreshPhase.idle
                    ? const SizedBox.shrink()
                    : Center(child: _buildStatusPill()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill() {
    final isFailure = _phase == _RefreshPhase.failure;
    final foreground = isFailure ? context.colors.error
        : context.colors.primaryGreen;
    final background = isFailure
        ? context.colors.errorSurface
        : context.colors.surfaceAlt;
    final text = switch (_phase) {
      _RefreshPhase.refreshing => 'Refreshing...',
      _RefreshPhase.success =>
        _outcome == ESugidRefreshOutcome.updated
            ? '✓ Latest updates loaded'
            : "✓ You're up to date",
      _RefreshPhase.failure => "Couldn't refresh. Pull down to try again.",
      _RefreshPhase.idle => '',
    };

    return Material(
      key: ValueKey(_phase),
      color: background,
      elevation: 5,
      shadowColor: context.colors.shadow.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_phase == _RefreshPhase.refreshing)
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else if (isFailure)
              Icon(Icons.cloud_off_rounded, size: 16, color: foreground)
            else
              Icon(Icons.check_circle_rounded, size: 16, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
