import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../submission_service.dart';
import '../../../widgets/esugid_page_header.dart';

typedef NotificationStreamFactory =
    Stream<List<ResidentNotification>> Function();
typedef NotificationOpenCallback =
    Future<void> Function(ResidentNotification notification);

class NotificationInbox extends StatefulWidget {
  const NotificationInbox({
    super.key,
    required this.watchNotifications,
    required this.onOpen,
    this.showBackButton = false,
    this.onBack,
    this.includeHeader = false,
  });

  final NotificationStreamFactory watchNotifications;
  final NotificationOpenCallback onOpen;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool includeHeader;

  @override
  State<NotificationInbox> createState() => _NotificationInboxState();
}

class _NotificationInboxState extends State<NotificationInbox> {
  bool _unreadOnly = false;
  bool _markingAllRead = false;
  late Stream<List<ResidentNotification>> _notificationsStream;
  List<ResidentNotification> _cachedNotifications = const [];
  final Set<String> _openingNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _notificationsStream = widget.watchNotifications();
  }

  void _retry() {
    setState(() {
      _openingNotificationIds.clear();
      _notificationsStream = widget.watchNotifications();
    });
  }

  @override
  void didUpdateWidget(NotificationInbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchNotifications != widget.watchNotifications) {
      _cachedNotifications = const [];
      _openingNotificationIds.clear();
      _notificationsStream = widget.watchNotifications();
    }
  }

  Future<void> _markAllRead(List<ResidentNotification> notifications) async {
    if (_markingAllRead) return;
    final unreadIds = notifications
        .where((notification) => !notification.read)
        .map((notification) => notification.id)
        .toList(growable: false);
    if (unreadIds.isEmpty) return;

    setState(() => _markingAllRead = true);
    try {
      await SubmissionService.markNotificationsRead(unreadIds);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not mark notifications as read. Try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _open(ResidentNotification notification) async {
    if (!_openingNotificationIds.add(notification.id)) return;
    final source = _notificationsStream;
    try {
      await widget.onOpen(notification);
    } catch (_) {
      if (!mounted || !identical(source, _notificationsStream)) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        AppSnackBar(
          content: Text('Could not open this notification. Please try again.'),
          kind: FeedbackKind.error,
        ),
      );
    } finally {
      if (identical(source, _notificationsStream)) {
        _openingNotificationIds.remove(notification.id);
      }
    }
  }

  Widget _buildHeader() {
    return ESugidSliverPageHeader(
      pinned: true,
      showBackButton: widget.showBackButton,
      onBack: widget.onBack,
      title: 'Notifications',
      sectionLabelWidget: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 3.5),
        decoration: BoxDecoration(
          color: context.colors.brandStrong.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.75),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.warningSolid,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'UPDATES & ALERTS',
              style: GoogleFonts.outfit(
                color: context.colors.onBrandMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      subtitle: null,
      icon: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ResidentNotification>>(
      key: ObjectKey(_notificationsStream),
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedNotifications = snapshot.data!;
        }
        final notifications = snapshot.data ?? _cachedNotifications;
        if (snapshot.connectionState == ConnectionState.waiting &&
            notifications.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (widget.includeHeader) _buildHeader(),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NotificationLoadingState(),
              ),
            ],
          );
        }
        if (snapshot.hasError && notifications.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              if (widget.includeHeader) _buildHeader(),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _NotificationErrorState(onRetry: _retry),
              ),
            ],
          );
        }

        final visibleNotifications = _unreadOnly
            ? notifications
                  .where((notification) => !notification.read)
                  .toList(growable: false)
            : notifications;
        final hasUnread = notifications.any(
          (notification) => !notification.read,
        );

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            if (widget.includeHeader) _buildHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.hasError)
                      const _InlineNotificationError()
                    else
                      const SizedBox(height: 2),
                    _InboxControls(
                      unreadOnly: _unreadOnly,
                      hasUnread: hasUnread,
                      markingAllRead: _markingAllRead,
                      onFilterChanged: (value) =>
                          setState(() => _unreadOnly = value),
                      onMarkAllRead: () => _markAllRead(notifications),
                    ),
                  ],
                ),
              ),
            ),
            if (visibleNotifications.isEmpty)
              SliverToBoxAdapter(
                child: _NotificationEmptyState(unreadOnly: _unreadOnly),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _buildGroupedNotifications(visibleNotifications),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGroupedNotifications(
    List<ResidentNotification> notifications,
  ) {
    final today = <ResidentNotification>[];
    final yesterday = <ResidentNotification>[];
    final earlier = <ResidentNotification>[];
    final now = DateTime.now();
    final yesterdayDate = now.subtract(const Duration(days: 1));

    for (final notification in notifications) {
      final createdAt = notification.createdAt.toLocal();
      if (DateUtils.isSameDay(createdAt, now)) {
        today.add(notification);
      } else if (DateUtils.isSameDay(createdAt, yesterdayDate)) {
        yesterday.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final widgets = <Widget>[];
    void addGroup(String label, List<ResidentNotification> items) {
      if (items.isEmpty) return;
      widgets.add(_NotificationGroupLabel(label));
      widgets.add(const SizedBox(height: 9));
      widgets.addAll(
        items.map(
          (notification) => _NotificationCard(
            notification: notification,
            onTap: () => _open(notification),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 7));
    }

    addGroup('TODAY', today);
    addGroup('YESTERDAY', yesterday);
    addGroup('EARLIER', earlier);
    return widgets;
  }
}

class _InboxControls extends StatelessWidget {
  const _InboxControls({
    required this.unreadOnly,
    required this.hasUnread,
    required this.markingAllRead,
    required this.onFilterChanged,
    required this.onMarkAllRead,
  });

  final bool unreadOnly;
  final bool hasUnread;
  final bool markingAllRead;
  final ValueChanged<bool> onFilterChanged;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filters = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterButton(
            label: 'All',
            selected: !unreadOnly,
            onTap: () => onFilterChanged(false),
          ),
          _FilterButton(
            label: 'Unread',
            selected: unreadOnly,
            onTap: () => onFilterChanged(true),
          ),
        ],
      ),
    );
    final markAll = hasUnread
        ? TextButton(
            onPressed: markingAllRead ? null : onMarkAllRead,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: markingAllRead
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Mark all as read',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 310 && markAll != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filters,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: markAll),
            ],
          );
        }
        return Row(children: [filters, const Spacer(), ?markAll]);
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: selected
                  ? context.colors.textPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationGroupLabel extends StatelessWidget {
  const _NotificationGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Theme.of(context,
              )
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.45),
              thickness: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final ResidentNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presentation = _presentationFor(context, notification.type);
    final unread = !notification.read;
    final isEmergency = notification.isEmergency ||
        notification.type.toLowerCase().contains('emergency') ||
        notification.title.toLowerCase().contains('emergency');

    final Color accentColor =
        isEmergency ? context.colors.error
        : presentation.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: accentColor.withValues(alpha: 0.12),
          highlightColor: accentColor.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: unread
                  ? ((isEmergency
                          ? context.colors.errorSurface
                        : context.colors.surfaceAlt))
                  : (context.colors.surface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unread
                    ? (isEmergency
                        ? context.colors.error.withValues(alpha: 0.8)
                        : context.colors.primaryGreen.withValues(alpha: 0.45))
                    : (context.colors.border),
                width: unread ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isEmergency
                      ? context.colors.errorSolid.withValues(
                          alpha: unread ? 0.12 : 0.04,
                        )
                      : (isDark
                          ? context.colors.brandStrong.withValues(alpha: 0.3)
                          : context.colors.brandStrong.withValues(
                              alpha: unread ? 0.08 : 0.035,
                            )),
                  blurRadius: unread ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D Category Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isEmergency
                          ? [
                              context.colors.errorSolid,
                              context.colors.errorSolid,
                            ]
                          : [
                              presentation.color.withValues(alpha: 0.88),
                              presentation.color,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isEmergency
                                ? context.colors.errorSolid
                                    : presentation.color)
                            .withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      presentation.icon,
                      color: context.colors.onAccent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with NEW pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: colors.onSurface,
                                fontSize: 14,
                                height: 1.22,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.30),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    'NEW',
                                    style: GoogleFonts.outfit(
                                      color: accentColor,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Display message
                      if (notification.displayMessage.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          notification.displayMessage,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: colors.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      // Footer: Category tag + timestamp wrapped
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 3,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isEmergency
                                  ? 'EMERGENCY'
                                  : presentation.label.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            '• ${notificationTimeLabel(notification.createdAt)}',
                            style: GoogleFonts.outfit(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text('Loading notifications...'),
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              "Couldn't load notifications.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotificationError extends StatelessWidget {
  const _InlineNotificationError();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 17,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't refresh. Showing saved notifications.",
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colors.primaryGreen.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 35,
              color: context.colors.primaryGreen,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            unreadOnly ? "You're all caught up" : 'No notifications yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            unreadOnly
                ? 'You have no unread notifications.'
                : 'Updates about your account, barangay, services, and requests will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String notificationTimeLabel(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final difference = current.difference(local);
  if (!difference.isNegative && difference.inMinutes < 1) return 'Just now';
  if (!difference.isNegative && difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (!difference.isNegative && difference.inHours < 6) {
    return difference.inHours == 1
        ? '1 hour ago'
        : '${difference.inHours} hours ago';
  }
  if (DateUtils.isSameDay(local, current)) {
    return DateFormat('h:mm a').format(local);
  }
  if (local.year == current.year) return DateFormat('MMM d').format(local);
  return DateFormat('MMM d, y').format(local);
}

({IconData icon, Color color, String label}) _presentationFor(
  BuildContext context,
  String type,
) {
  final normalized = type.trim().toLowerCase();
  if (normalized.contains('verification')) {
    return (
      icon: Icons.verified_user_outlined,
      color: context.colors.primaryGreen,
      label: 'Verification',
    );
  }
  if (normalized.contains('account')) {
    return (
      icon: Icons.manage_accounts_outlined,
      color: context.colors.primaryGreen,
      label: 'Account',
    );
  }
  if (normalized.contains('announcement') ||
      normalized.contains('post_review')) {
    return (
      icon: Icons.campaign_outlined,
      color: context.colors.primaryGreen,
      label: 'Announcement',
    );
  }
  if (normalized.contains('document') || normalized.contains('service')) {
    return (
      icon: Icons.description_outlined,
      color: context.colors.info,
      label: 'Service',
    );
  }
  if (normalized.contains('concern') || normalized.contains('helpdesk')) {
    return (
      icon: Icons.mark_chat_unread_outlined,
      color: context.colors.warning,
      label: 'Concern',
    );
  }
  if (normalized.contains('emergency')) {
    return (
      icon: Icons.warning_amber_rounded,
      color: context.colors.error,
      label: 'Emergency',
    );
  }
  if (normalized.startsWith('bayanihan_') ||
      normalized.contains('help_interest')) {
    return (
      icon: Icons.volunteer_activism_outlined,
      color: context.colors.primaryGreen,
      label: 'Bayanihan',
    );
  }
  return (
    icon: Icons.notifications_none_rounded,
    color: context.colors.textSecondary,
    label: 'Update',
  );
}
