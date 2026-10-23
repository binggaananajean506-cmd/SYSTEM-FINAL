import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/core/errors/user_facing_error.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../auth_service.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../../services/community_trust_service.dart';
import '../../../../widgets/esugid_page_header.dart';
import '../../models/bayanihan_conversation.dart';
import '../../services/bayanihan_messaging_service.dart';
import '../widgets/cancel_offer_dialog.dart';
import 'bayanihan_conversation_page.dart';
import '../../../../pages/public_user_profile_page.dart';

class BayanihanMessagesPage extends StatefulWidget {
  const BayanihanMessagesPage({
    super.key,
    this.conversations,
    this.user,
    this.service,
  });

  final Stream<List<BayanihanConversation>>? conversations;
  final User? user;
  final BayanihanMessagingService? service;

  @override
  State<BayanihanMessagesPage> createState() => _BayanihanMessagesPageState();
}

class _BayanihanMessagesPageState extends State<BayanihanMessagesPage> {
  late Stream<List<BayanihanConversation>> _conversations;
  User? get _user => widget.user ?? AuthService.currentUser;
  BayanihanMessagingService? _service;
  String? _streamUserId;

  @override
  void initState() {
    super.initState();
    _resetStream();
  }

  @override
  void didUpdateWidget(BayanihanMessagesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_streamUserId != _user?.uid ||
        oldWidget.service != widget.service ||
        oldWidget.conversations != widget.conversations) {
      _resetStream();
    }
  }

  void _resetStream() {
    _streamUserId = _user?.uid;
    _service = widget.service ?? BayanihanMessagingService();
    if (widget.conversations != null) {
      _conversations = widget.conversations!;
      return;
    }
    final user = _user;
    if (user == null) {
      _conversations = Stream.value(const []);
      return;
    }
    _conversations = _service!.conversationsFor(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildHeader(context),
          ],
          body: const _SignedOutState(),
        ),
      );
    }

    return StreamBuilder<List<BayanihanConversation>>(
      key: ValueKey(_streamUserId),
      stream: _conversations,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            items.isEmpty;

        final pendingItems = items
            .where(
              (item) => item.status == BayanihanConversationStatus.pending)
            .toList();
        final activeItems = items
            .where(
              (item) => item.status == BayanihanConversationStatus.active)
            .toList();
        final archiveItems = items
            .where((item) => item.status.isArchived)
            .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: context.colors.background,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildHeader(context),
                SliverToBoxAdapter(
                  child: _build3DSegmentedTabBar(
                    pendingCount: pendingItems.length,
                    activeCount: activeItems.length,
                  ),
                ),
              ],
              body: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colors.brand,
                      ),
                    )
                  : snapshot.hasError
                      ? AsyncErrorView(
                          onRetry: () => setState(_resetStream))
                      : TabBarView(
                          children: [
                            _ConversationList(
                              conversations: pendingItems,
                              user: user,
                              service: _service,
                              section: _InboxSection.pending,
                            ),
                            _ConversationList(
                              conversations: activeItems,
                              user: user,
                              service: _service,
                              section: _InboxSection.active,
                            ),
                            _ConversationList(
                              conversations: archiveItems,
                              user: user,
                              service: _service,
                              section: _InboxSection.archive,
                            ),
                          ],
                        ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCivicBadge() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.brandStrong.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.85),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.3804),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.warningSolid,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.highlight,
                    blurRadius: 3,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'BARILI CIVIC NETWORK',
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: context.colors.onBrandMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ESugidSliverPageHeader(
      sectionLabelWidget: _buildCivicBadge(),
      title: 'Bayanihan Messages',
      showBackButton: true,
      onBack: () => Navigator.maybePop(context),
    );
  }

  Widget _build3DSegmentedTabBar({
    required int pendingCount,
    required int activeCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.colors.brandStrong.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: context.colors.onAccent,
        unselectedLabelColor: context.colors.textSecondary,
        labelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.brand, context.colors.brand],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.brandStrong.withValues(alpha: 0.38),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: context.colors.highlight.withValues(alpha: 0.35),
              offset: const Offset(0, -1),
              blurRadius: 0,
            ),
          ],
        ),
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.warningSolid,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.brand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: GoogleFonts.outfit(
                          color: context.colors.onAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Archive')),
          ),
        ],
      ),
    );
  }
}

enum _InboxSection { pending, active, archive }

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.user,
    required this.section,
    this.service,
  });

  final List<BayanihanConversation> conversations;
  final User user;
  final _InboxSection section;
  final BayanihanMessagingService? service;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const _BayanihanEmptyState();
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _BayanihanConversationCard(
          conversation: conversations[index],
          user: user,
          section: section,
          service: service,
        );
      },
    );
  }
}

class _BayanihanConversationCard extends StatefulWidget {
  const _BayanihanConversationCard({
    required this.conversation,
    required this.user,
    required this.section,
    this.service,
  });

  final BayanihanConversation conversation;
  final User user;
  final _InboxSection section;
  final BayanihanMessagingService? service;

  @override
  State<_BayanihanConversationCard> createState() =>
      _BayanihanConversationCardState();
}

class _BayanihanConversationCardState
    extends State<_BayanihanConversationCard> {
  static final Map<String, String?> _photoCache = {};
  String? _photoUrl;
  bool _busy = false;

  String get _otherUserId {
    final isRequester = widget.conversation.isRequester(widget.user.uid);
    return isRequester
        ? widget.conversation.helperId
        : widget.conversation.requesterId;
  }

  String get _otherUserName =>
      widget.conversation.otherParticipantName(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant _BayanihanConversationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id ||
        oldWidget.user.uid != widget.user.uid) {
      _resolvePhoto();
    }
  }

  void _resolvePhoto() {
    final otherId = _otherUserId.trim();
    final direct = widget.conversation
        .otherParticipantPhotoUrl(widget.user.uid)
        ?.trim();
    if (direct != null && direct.isNotEmpty) {
      _photoUrl = direct;
      if (otherId.isNotEmpty) {
        _photoCache[otherId] = direct;
      }
      return;
    }

    if (otherId.isNotEmpty && _photoCache.containsKey(otherId)) {
      _photoUrl = _photoCache[otherId];
      return;
    }

    final cached = CommunityTrustService.getCachedProfile(otherId);
    if (cached?.profilePhotoUrl != null &&
        cached!.profilePhotoUrl!.isNotEmpty) {
      _photoUrl = cached.profilePhotoUrl;
      _photoCache[otherId] = _photoUrl;
      return;
    }

    _fetchPhoto(otherId);
  }

  Future<void> _fetchPhoto(String id) async {
    if (id.isEmpty) return;
    try {
      if (Firebase.apps.isEmpty) return;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        final photo = data?['profilePhotoUrl']?.toString() ??
            data?['photoUrl']?.toString() ??
            data?['avatarUrl']?.toString();
        if (photo != null && photo.trim().isNotEmpty) {
          _photoCache[id] = photo.trim();
          if (mounted) {
            setState(() => _photoUrl = photo.trim());
          }
          return;
        }
      }

      final trust = await CommunityTrustService().getTrustProfile(id);
      final photo = trust?.profilePhotoUrl;
      if (photo != null && photo.trim().isNotEmpty) {
        _photoCache[id] = photo.trim();
        if (mounted) {
          setState(() => _photoUrl = photo.trim());
        }
      }
    } catch (_) {}
  }

  Widget _buildAvatarFallback(String name) {
    final initials = _getInitials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.surfaceAlt, context.colors.surfaceAlt],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) return 'B';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BayanihanConversationPage(
          initialConversation: widget.conversation,
          service: widget.service ?? BayanihanMessagingService(),
        ),
      ),
    );
  }

  Future<void> _review(bool accept) async {
    if (_busy) return;
    final service = widget.service ?? BayanihanMessagingService();
    setState(() => _busy = true);
    try {
      if (accept) {
        await service.acceptOffer(widget.conversation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text(
                    'Offer accepted! Moved to Active.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
              kind: FeedbackKind.success,
            ),
          );
          _open();
        }
      } else {
        await service.declineOffer(
          widget.conversation.id,
          reason: 'Offer declined by requester',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text(
                'Offer declined.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              kind: FeedbackKind.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Could not update this offer. Please try again.'),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdrawOffer() async {
    if (_busy) return;
    final message = await showBayanihanCancelOfferDialog(
      context,
      recipientName: _otherUserName,
      requestTitle: widget.conversation.requestTitle,
    );
    if (message == null || message.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final service = widget.service ?? BayanihanMessagingService();
      // Send a polite cancellation notice into the chat thread so the requester sees it
      try {
        await service.sendMessage(
          widget.conversation.id,
          '📢 Offer cancelled: ${message.trim()}',
        );
      } catch (_) {}
      await service.withdraw(
        widget.conversation.id,
        reason: message.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(
                    'Offer cancelled. Your message was sent to $_otherUserName.',
                    style: GoogleFonts.outfit(
                fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(e is BayanihanMessagingException ? e.message : userFacingError(e, fallback: 'Could not cancel offer. Try again.')),
            kind: FeedbackKind.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final user = widget.user;
    final unread = conversation.unreadCountFor(user.uid);
    final isRequester = conversation.isRequester(user.uid);
    final isPending = widget.section == _InboxSection.pending;
    final otherName = _otherUserName;
    final otherId = _otherUserId;

    final messageText = (conversation.lastMessage ?? conversation.initialMessage).trim();
    final displayText = messageText.isNotEmpty
        ? messageText
        : 'Help offer on ${conversation.requestTitle}';
    final timeText = timeago.format(
      conversation.lastMessageAt ?? conversation.createdAt,
    );

    // For the "Active" tab, render ONLY the user account same as Messenger with badge number
    if (widget.section == _InboxSection.active) {
      return Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread > 0
                ? context.colors.primaryGreen.withValues(alpha: 0.35)
                : context.colors.border,
            width: unread > 0 ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: unread > 0
                  ? context.colors.brandStrong.withValues(alpha: 0.08)
                  : context.colors.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Circular Profile Avatar with Verified Badge (same as Messenger)
                  GestureDetector(
                    onTap: otherId.isNotEmpty
                        ? () => PublicUserProfilePage.show(
                              context,
                              otherId,
                              initialName: otherName,
                              initialPhotoUrl: _photoUrl,
                            )
                        : null,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.surfaceAlt,
                              border: Border.all(
                                color: context.colors.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.15,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (_photoUrl != null &&
                                      _photoUrl!.isNotEmpty)
                                  ? Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      width: 50,
                                      height: 50,
                                      errorBuilder: (_, _, _) =>
                                          _buildAvatarFallback(otherName),
                                    )
                                  : _buildAvatarFallback(otherName),
                            ),
                          ),
                          // Verified Blue Badge
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: context.colors.infoSolid,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.border,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.highlight.withValues(
                                      alpha: 0.2000,
                                    ),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 10.5,
                                  color: context.colors.onAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Account Name & Last message snippet • time (same as Messenger)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: context.colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayText.isNotEmpty
                              ? '$displayText • $timeText'
                              : timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: unread > 0
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Messenger Badge Number on the right edge
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.errorSolid,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.highlight.withValues(alpha: 0.35,
                            ),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: GoogleFonts.outfit(
                            color: context.colors.onAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.colors.info,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final (statusLabel, statusColor, statusBgColor) = switch (widget.section) {
      _InboxSection.pending => isRequester
          ? (
              'Waiting for your review',
                context.colors.warning,
                context.colors.warningSurface,
            )
          : (
              'Waiting for requester',
                context.colors.warning,
                context.colors.warningSurface,
            ),
      _InboxSection.active => (
          'Active Chat',
        context.colors.primaryGreen,
        context.colors.successSurface,
        ),
      _InboxSection.archive => switch (conversation.status) {
          BayanihanConversationStatus.declined => (
              'Declined',
          context.colors.error,
          context.colors.errorSurface,
            ),
          BayanihanConversationStatus.completed => (
              'Completed',
          context.colors.info,
          context.colors.infoSurface,
            ),
          _ => (
              conversation.status.label,
          context.colors.textSecondary,
          context.colors.surfaceAlt,
            ),
        },
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPending ? context.colors.border : context.colors.border,
          width: isPending ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? context.colors.brandStrong.withValues(alpha: 0.08)
                : context.colors.shadow.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular Profile Avatar (48x48) with Verified Blue Badge
                    GestureDetector(
                      onTap: otherId.isNotEmpty
                          ? () => PublicUserProfilePage.show(
                                context,
                                otherId,
                                initialName: otherName,
                                initialPhotoUrl: _photoUrl,
                              )
                          : null,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.colors.surfaceAlt,
                                border: Border.all(
                                  color: context.colors.border,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.brandStrong
                                        .withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: (_photoUrl != null &&
                                        _photoUrl!.isNotEmpty)
                                    ? Image.network(
                                        _photoUrl!,
                                        fit: BoxFit.cover,
                                        width: 48,
                                        height: 48,
                                        errorBuilder: (_, _, _) =>
                                            _buildAvatarFallback(otherName),
                                      )
                                    : _buildAvatarFallback(otherName),
                              ),
                            ),
                            // Verified Blue Badge
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: context
                                      .colors
                                      .infoSolid, // Verified Blue Badge
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.colors.border,
                                    width: 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.highlight
                                          .withValues(alpha: 0.2000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 10.5,
                                    color: context.colors.onAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Top: Name & Status, Subtitle: Help Request Title & Timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final nameWidget = GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: otherId.isNotEmpty
                                    ? () => PublicUserProfilePage.show(
                                          context,
                                          otherId,
                                          initialName: otherName,
                                          initialPhotoUrl: _photoUrl,
                                        )
                                    : null,
                                child: Text(
                                  otherName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: context.colors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              );

                              final statusWidget = ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.52,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      statusLabel,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              return Row(
                                children: [
                                  Expanded(child: nameWidget),
                                  const SizedBox(width: 6),
                                  if (unread > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.errorSolid,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.colors.highlight
                                                .withValues(alpha: 0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$unread',
                                        style: GoogleFonts.outfit(
                                          color: context.colors.onAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  statusWidget,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 4),

                          // Subtitle: Help Request Title & Time
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final titleWidget = Text(
                                conversation.requestTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primaryGreen,
                                ),
                              );

                              final timeWidget = ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.38,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    timeText,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              );

                              return Row(
                                children: [
                                  Icon(
                                    Icons.volunteer_activism_rounded,
                                    size: 14,
                                    color: context.colors.primaryGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(child: titleWidget),
                                  const SizedBox(width: 6),
                                  timeWidget,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Message snippet bubble
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: context.colors.border,
                      width: 1),
                  ),
                  child: Text(
                    displayText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      height: 1.35,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Pending Actions (Decline & Accept) or Status
                if (isPending) ...[
                  const SizedBox(height: 14),
                  if (isRequester)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _review(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.textSecondary,
                              side: BorderSide(
                                color: context.colors.border,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 11),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Decline',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.35,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _busy ? null : () => _review(true),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_busy)
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: context.colors.surface,
                                            ),
                                          )
                                        else ...[
                                          Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: context.colors.onAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Accept & Chat',
                                            style: GoogleFonts.outfit(
                                              color: context.colors.onAccent,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              size: 14,
                              color: context.colors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Waiting for requester to review your offer',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : _withdrawOffer,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.colors.textSecondary,
                                  side: BorderSide(
                                    color: context.colors.border,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  'Cancel Offer',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: _open,
                                style: FilledButton.styleFrom(
                                  foregroundColor: context.colors.onAccent,

                                  backgroundColor: context.colors.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  'Open Chat',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.errorSolid,
                                context.colors.errorSolid,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread new message${unread > 1 ? 's' : ''}',
                            style: GoogleFonts.outfit(
                              color: context.colors.onAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          Text(
                            'Open conversation',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: context.colors.primaryGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BayanihanEmptyState extends StatelessWidget {
  const _BayanihanEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3D Layered Chat Medallion
            Stack(
              alignment: Alignment.center,
              children: [
                // Ambient pulsating radial halo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        context.colors.brand.withValues(alpha: 0.22),
                        context.colors.brand.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // 3D Frosted Glass Medallion
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colors.surface,
                        context.colors.surfaceAlt,
                        context.colors.surfaceAlt,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.colors.border, width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brandStrong.withValues(alpha: 0.18,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: context.colors.shadow.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(44, 44),
                      painter: _CivicChatHavenPainter(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Exact required text for tests & clarity
            Text(
              'No Bayanihan conversations yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: context.colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Conversations will appear here when you offer help or someone offers help on your request.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  height: 1.5,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Direct CTA Button
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.colors.brand, context.colors.brand],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: context.colors.highlight.withValues(alpha: 0.3),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      color: context.colors.onAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Explore Help Requests',
                      style: GoogleFonts.outfit(
                        color: context.colors.onAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering a rich 3D civic messaging emblem
class _CivicChatHavenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Back Bubble (Mint-emerald gradient)
    final bgRect = Rect.fromLTWH(w * 0.32, h * 0.06, w * 0.64, h * 0.54);
    final bgBubble = Path()
      ..addRRect(RRect.fromRectAndRadius(bgRect, Radius.circular(w * 0.22)));
    final bgTail = Path()
      ..moveTo(w * 0.82, h * 0.44)
      ..lineTo(w * 0.98, h * 0.60)
      ..quadraticBezierTo(w * 0.88, h * 0.54, w * 0.70, h * 0.52)
      ..close();
    final fullBg = Path.combine(PathOperation.union, bgBubble, bgTail);

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      ).createShader(bgRect)
      ..isAntiAlias = true;

    canvas.drawPath(fullBg, bgPaint);

    // 2. Front Bubble (3D Pearlescent White)
    final fgRect = Rect.fromLTWH(0, h * 0.32, w * 0.74, h * 0.62);
    final fgBubble = Path()
      ..addRRect(RRect.fromRectAndRadius(fgRect, Radius.circular(w * 0.24)));
    final fgTail = Path()
      ..moveTo(w * 0.20, h * 0.82)
      ..lineTo(w * 0.04, h * 0.98)
      ..quadraticBezierTo(w * 0.16, h * 0.92, w * 0.36, h * 0.88)
      ..close();
    final fullFg = Path.combine(PathOperation.union, fgBubble, fgTail);

    // Drop shadow under foreground
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(fullFg, shadowPaint);
    canvas.restore();

    // Foreground Fill
    final fgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF0FDF4), Color(0xFFD1FAE5)],
      ).createShader(fgRect)
      ..isAntiAlias = true;
    canvas.drawPath(fullFg, fgPaint);

    // Specular Highlight on front bubble
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.36, w, h * 0.24));

    final glossPath = Path()
      ..addOval(Rect.fromLTWH(w * 0.08, h * 0.36, w * 0.58, h * 0.24));

    canvas.save();
    canvas.clipPath(fullFg);
    canvas.drawPath(glossPath, glossPaint);
    canvas.restore();

    // Front Bubble Bevel Rim
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(fullFg, rimPaint);

    // 3 Conversation Dots
    final dotPaint = Paint()
      ..color = const Color(0xFF047857)
      ..style = PaintingStyle.fill;
    final dotY = h * 0.60;
    final dotR = w * 0.045;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * 0.22 + (i * w * 0.15), dotY),
        dotR,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Please sign in to view Bayanihan messages.'));
}
