import 'package:flutter/material.dart';

import '../../app/theme/semantic_colors.dart';

enum FeedbackKind { success, error, warning, info }

/// One compact, accessible presentation for action results throughout the app.
class AppSnackBar extends SnackBar {
  AppSnackBar({
    super.key,
    required Widget content,
    FeedbackKind kind = FeedbackKind.info,
    Duration? duration,
    super.action,
    super.persist,
    super.onVisible,
    super.animation,
    super.dismissDirection,
    super.clipBehavior,
    super.hitTestBehavior,
    super.actionOverflowThreshold,
    super.showCloseIcon = true,
  }) : super(
         content: _FeedbackContent(kind: kind, child: content),
         behavior: SnackBarBehavior.floating,
         duration:
             duration ??
             (kind == FeedbackKind.error
                 ? const Duration(seconds: 8)
                 : const Duration(seconds: 5)),
       );
}

extension AppFeedbackMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
    AppSnackBar message,
  ) {
    // A new action result replaces stale messages instead of building a queue.
    clearSnackBars();
    removeCurrentSnackBar();
    return showSnackBar(message);
  }
}

class _FeedbackContent extends StatelessWidget {
  const _FeedbackContent({required this.kind, required this.child});

  final FeedbackKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, foreground, background) = switch (kind) {
      FeedbackKind.success => (
        Icons.check_circle_outline_rounded,
        colors.success,
        colors.successSurface,
      ),
      FeedbackKind.error => (
        Icons.error_outline_rounded,
        colors.error,
        colors.errorSurface,
      ),
      FeedbackKind.warning => (
        Icons.warning_amber_rounded,
        colors.warning,
        colors.warningSurface,
      ),
      FeedbackKind.info => (
        Icons.info_outline_rounded,
        colors.info,
        colors.infoSurface,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 21, color: foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.textPrimary, height: 1.4),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stays beside the form action while the user fixes a validation problem.
class FormValidationNotice extends StatelessWidget {
  const FormValidationNotice({
    super.key,
    required this.message,
    required this.onFix,
  });

  final String message;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onFix,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!keyboardOpen) ...[
                        Text(
                          'Please check your details',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        message,
                        style: TextStyle(
                          color: colors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      if (!keyboardOpen) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Go to field',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_upward_rounded, color: colors.error, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
