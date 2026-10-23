import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/core/errors/user_facing_error.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../auth_service.dart';
import '../core/validation/esugid_validators.dart';
import '../core/widgets/async_error_view.dart';
import '../marketplace_service.dart';
import '../pages/public_user_profile_page.dart';
import '../services/chat_media_service.dart';
import '../services/community_trust_service.dart';
import '../widgets/chat_message_actions.dart';
import '../widgets/user_profile_avatar.dart';

class MarketplaceConversationPage extends StatefulWidget {
  const MarketplaceConversationPage({
    super.key,
    required this.request,
    this.conversationStream,
    this.messageStream,
  });

  final MarketplaceInterestRequest request;
  final Stream<MarketplaceInterestRequest?>? conversationStream;
  final Stream<List<Map<String, dynamic>>>? messageStream;

  @override
  State<MarketplaceConversationPage> createState() =>
      _MarketplaceConversationPageState();
}

class _MarketplaceConversationPageState
    extends State<MarketplaceConversationPage> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _reviewing = false;
  bool _confirming = false;
  late Stream<MarketplaceInterestRequest?> _conversationStream;
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  StreamSubscription<MarketplaceInterestRequest?>? _conversationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  String? _streamUserId;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _markRead();
  }

  void _markRead() {
    final user = AuthService.currentUser;
    if (user != null) {
      MarketplaceService.markRead(widget.request.id, user.uid,
      ).catchError((_) {});
    }
  }

  @override
  void didUpdateWidget(MarketplaceConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_streamUserId != AuthService.currentUser?.uid ||
        oldWidget.request.id != widget.request.id ||
        oldWidget.conversationStream != widget.conversationStream ||
        oldWidget.messageStream != widget.messageStream) {
      _initStreams();
      _markRead();
    }
  }

  void _initStreams() {
    _streamUserId = AuthService.currentUser?.uid;
    _conversationSubscription?.cancel();
    _messagesSubscription?.cancel();
    _conversationSubscription = null;
    _messagesSubscription = null;
    // The banner and body share one source; composer and messages share another.
    // Keep their upstream subscriptions owned by this page until replacement/disposal.
    _conversationStream = (widget.conversationStream ??
        MarketplaceService.conversationStream(widget.request.id)).asBroadcastStream(
      onListen: (subscription) {
        _conversationSubscription = subscription;
        if (subscription.isPaused) subscription.resume();
      },
      onCancel: (subscription) => subscription.pause(),
    );
    _messagesStream = (widget.messageStream ??
        MarketplaceService.messagesStream(widget.request.id)).asBroadcastStream(
      onListen: (subscription) {
        _messagesSubscription = subscription;
        if (subscription.isPaused) subscription.resume();
      },
      onCancel: (subscription) => subscription.pause(),
    );
  }

  void _retry() => setState(_initStreams);

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _messagesSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is StateError
        ? error.message
        : userFacingError(error);
    ScaffoldMessenger.of(
      context).showAppSnackBar(
      AppSnackBar(content: Text(message.toString()), kind: FeedbackKind.error),
    );
  }

  Future<void> _handleAttachPhoto({
    bool isLimited = false,
    int messagesLeft = 3,
  }) async {
    if (_sending) return;
    if (isLimited && messagesLeft <= 0) {
      _showError(
        'You have reached the 3-message limit while waiting for approval.',
      );
      return;
    }
    final file = await ChatMediaService.pickChatImage(context);
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        throw StateError('Please sign in again.');
      }
      final url = await ChatMediaService.uploadChatImage(
        file: file,
        userId: user.uid,
        conversationId: widget.request.id,
      );
      await MarketplaceService.sendImageMessage(
        widget.request.id,
        senderId: user.uid,
        imageUrl: url,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final user = AuthService.currentUser;
    final draft = _controller.text;
    final value = draft.trim();
    final conversationId = widget.request.id;
    if (user == null || value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MarketplaceService.sendMessage(
        conversationId,
        senderId: user.uid,
        text: value,
      );
      if (mounted && widget.request.id == conversationId &&
          _controller.text == draft) {
        _controller.clear();
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _review(bool accept) async {
    final user = AuthService.currentUser;
    if (user == null || _reviewing) return;
    setState(() => _reviewing = true);
    try {
      if (accept) {
        await MarketplaceService.acceptInterestRequest(
          conversationId: widget.request.id,
          sellerId: user.uid,
        );
      } else {
        await MarketplaceService.declineInterestRequest(
          conversationId: widget.request.id,
          sellerId: user.uid,
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _confirmHandoff(bool isSeller) async {
    if (_confirming) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isSeller ? 'Item handed over?' : 'Item received?'),
        content: const Text(
          'Confirm only after the handoff has happened. Reviews open when both people confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirming = true);
    try {
      await MarketplaceService.confirmTrade(widget.request.id);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Widget _handoffAction(MarketplaceInterestRequest request, bool isSeller) {
    final confirmed = isSeller
        ? request.sellerConfirmed
        : request.buyerConfirmed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: confirmed
          ? Text(
              'Handoff confirmed. Waiting for the other person to confirm.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirming ? null : () => _confirmHandoff(isSeller),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  isSeller
                      ? 'Confirm item handed over'
                      : 'Confirm item received',
                ),
              ),
            ),
    );
  }

  Future<void> _handleMenuAction(
    String action, {
    required String otherId,
    required String otherName,
  }) async {
    if (action == 'view_profile') {
      await PublicUserProfilePage.show(context, otherId);
      return;
    }
    if (action == 'accept_request') {
      await _review(true);
      return;
    }
    if (action == 'decline_request') {
      await _review(false);
      return;
    }
    if (action == 'cancel_request') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Cancel Request?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to cancel your purchase inquiry?',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: context.colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                foregroundColor: context.colors.onAccent,

                backgroundColor: context.colors.errorSolid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _review(false);
      }
      return;
    }
    if (action == 'clear_chat') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Clear My Messages?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will unsend and remove your sent messages in this conversation.',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: context.colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                foregroundColor: context.colors.onAccent,

                backgroundColor: context.colors.errorSolid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final user = AuthService.currentUser;
        if (user != null) {
          await MarketplaceService.clearConversationMessages(
            widget.request.id,
            user.uid,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showAppSnackBar(
              AppSnackBar(
                content: Text('Your messages have been cleared.'),
                kind: FeedbackKind.success,
              ),
            );
          }
        }
      }
      return;
    }
    if (action == 'block_user') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Block $otherName?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'They will no longer be able to message you or see your listings.',
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: context.colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                foregroundColor: context.colors.onAccent,

                backgroundColor: context.colors.errorSolid,
              ),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('$otherName has been blocked.'),
            kind: FeedbackKind.success,
          ),
        );
      }
      return;
    }
    // report_user
    if (!mounted) return;
    await showReportUserSheet(
      context,
      reportedUserId: otherId,
      reportedUserName: otherName,
      conversationId: widget.request.id,
      context_: TrustContext.market,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUser?.uid ?? '';
    final isSeller = widget.request.isSeller(userId);
    final otherName = isSeller
        ? widget.request.buyerName
        : widget.request.sellerName;
    final otherId = isSeller ? widget.request.buyerId : widget.request.sellerId;
    final otherPhotoUrl = isSeller
        ? widget.request.buyerPhotoUrl
        : widget.request.sellerPhotoUrl;

    return Scaffold(
      body: Column(
        children: [
          _ChatTopBar(
            name: otherName,
            photoUrl: otherPhotoUrl,
            onBack: () => Navigator.maybePop(context),
            onProfileTap: () => PublicUserProfilePage.show(context, otherId),
            onMenuSelected: (value) => _handleMenuAction(
              value,
              otherId: otherId,
              otherName: otherName,
            ),
            menuActions: [
              PopupMenuItem(
                value: 'view_profile',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: context.colors.primaryGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'View Profile',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.request.status == MarketplaceInterestStatus.pending &&
                  isSeller) ...[
                PopupMenuItem(
                  value: 'accept_request',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: context.colors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Accept & Chat',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.colors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'decline_request',
                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: context.colors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Decline Request',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.request.status == MarketplaceInterestStatus.pending &&
                  !isSeller)
                PopupMenuItem(
                  value: 'cancel_request',
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app_rounded,
                        size: 18,
                        color: context.colors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cancel Request',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.colors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(
                      Icons.cleaning_services_rounded,
                      size: 18,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clear My Messages',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report_user',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Report User',
                        style: GoogleFonts.outfit(
                          color: context.colors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block_user',
                child: Row(
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 18,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Block User',
                        style: GoogleFonts.outfit(
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StreamBuilder<MarketplaceInterestRequest?>(
            key: ObjectKey(_conversationStream),
            stream: _conversationStream,
            initialData: widget.request,
            builder: (context, requestSnapshot) {
              final request = requestSnapshot.data ?? widget.request;
              return _PinnedMarketItemBanner(
                request: request);
            },
          ),
          Expanded(
            child: StreamBuilder<MarketplaceInterestRequest?>(
              key: ObjectKey(_conversationStream),
              stream: _conversationStream,
              initialData: widget.request,
              builder: (context, requestSnapshot) {
                if (requestSnapshot.hasError) {
                  return AsyncErrorView(onRetry: _retry);
                }
                final request = requestSnapshot.data ?? widget.request;
                return Column(
                  children: [
                    _statusNotice(request, isSeller),
                    if (request.status == MarketplaceInterestStatus.accepted)
                      _handoffAction(request, isSeller),
                    Expanded(child: _messages(userId)),
                    // Rating prompt when completed
                    if (request.status == MarketplaceInterestStatus.completed &&
                        userId.isNotEmpty &&
                        otherId.isNotEmpty)
                      CommunityRatingPrompt(
                        sourceId: widget.request.id,
                        targetUserId: otherId,
                        targetUserName: otherName,
                        context: TrustContext.market,
                      ),
                    _bottomAction(request, isSeller, otherName),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusNotice(MarketplaceInterestRequest request, bool isSeller) {
    final status = request.status;
    final (icon, color, title, body) = switch (status) {
      MarketplaceInterestStatus.pending => (
        Icons.schedule_rounded,
        context.colors.warning,
        isSeller ? 'Buyer is waiting for your reply' : 'Waiting for seller approval',
        isSeller
            ? 'Accept the request to chat freely with the buyer.'
            : 'You can send up to 3 messages while waiting for the seller to accept your request.',
      ),
      MarketplaceInterestStatus.accepted => (
        Icons.verified_rounded,
        context.colors.primaryGreen,
        'Conversation open',
        'Discuss availability, quantity, price, and pickup. Both of you can chat freely.',
      ),
      MarketplaceInterestStatus.declined => (
        Icons.cancel_outlined,
        context.colors.error,
        'Request declined',
        'This conversation is closed. No more messages can be sent.',
      ),
      MarketplaceInterestStatus.completed => (
        Icons.check_circle_outline_rounded,
        context.colors.textPrimary,
        'Trade completed',
        'This trade has been marked as completed. Conversation is closed.',
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messages(String userId) {
    final isSeller = widget.request.isSeller(userId);
    final otherName = isSeller ? widget.request.buyerName : widget.request.sellerName;

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ObjectKey(_messagesStream),
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return AsyncErrorView(onRetry: _retry);
        final messages = snapshot.data ?? const [];
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.colors.warningSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: context.colors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.request.initialMessage.isNotEmpty
                        ? widget.request.initialMessage
                        : 'Send a message to start chatting!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: messages.length,
          itemBuilder: (_, index) {
            final message = messages[index];
            final messageId = message['id']?.toString() ?? '';
            final mine = message['senderId'] == userId;
            final isUnsent = message['isUnsent'] == true;
            final text = '${message['text'] ?? ''}';
            final imageUrl = message['imageUrl'] as String?;
            final hasImage = imageUrl != null && imageUrl.isNotEmpty;
            final hasText = text.isNotEmpty;
            final isEdited = message['isEdited'] == true;
            final rawReactions = message['reactions'];
            final reactions = rawReactions is Map
                ? rawReactions.map(
                    (k, v) => MapEntry(k.toString(), v.toString()),
                  )
                : <String, String>{};
            final hasReactions = reactions.isNotEmpty;
            final timestamp = message['createdAt'];
            String timeFormatted = '';
            if (timestamp is Timestamp) {
              timeFormatted = DateFormat.jm().format(timestamp.toDate());
            }

            void openMenu() {
              showChatMessageActionMenu(
                context,
                messageId: messageId,
                text: text,
                imageUrl: imageUrl,
                isMine: mine,
                isUnsent: isUnsent,
                currentReactions: reactions,
                currentUserId: userId,
                onReactionSelected: (emoji) async {
                  try {
                    await MarketplaceService.toggleReaction(
                      widget.request.id,
                      messageId,
                      userId,
                      emoji,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(e is StateError ? e.message.toString() : userFacingError(e, fallback: 'Could not update reaction. Try again.')),
                          kind: FeedbackKind.error,
                        ),
                      );
                    }
                  }
                },
                onEdit: (newText) async {
                  try {
                    await MarketplaceService.editMessage(
                      widget.request.id,
                      messageId,
                      newText,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text('Message updated'),
                          duration: Duration(seconds: 2),
                          kind: FeedbackKind.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(e is StateError ? e.message.toString() : userFacingError(e, fallback: 'Could not edit message. Try again.')),
                          kind: FeedbackKind.error,
                        ),
                      );
                    }
                  }
                },
                onUnsend: () async {
                  try {
                    await MarketplaceService.unsendMessage(
                      widget.request.id,
                      messageId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text('Message unsent'),
                          duration: Duration(seconds: 2),
                          kind: FeedbackKind.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(e is StateError ? e.message.toString() : userFacingError(e, fallback: 'Could not unsend message. Try again.')),
                          kind: FeedbackKind.error,
                        ),
                      );
                    }
                  }
                },
              );
            }

            if (isUnsent) {
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 14,
                        color: context.colors.info,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mine
                            ? 'You unsent a message'
                            : '$otherName unsent a message',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: openMenu,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                      ),
                      child: Container(
                        margin: EdgeInsets.only(bottom: hasReactions ? 14 : 10),
                        padding: EdgeInsets.symmetric(
                          horizontal: hasImage && !hasText ? 6 : 14,
                          vertical: hasImage && !hasText ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? context.colors.warningSolid
                              : context.colors.surface,
                          borderRadius: mine
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(4),
                                )
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(4),
                                  bottomRight: Radius.circular(18),
                                ),
                          border: mine
                              ? null
                              : Border.all(color: context.colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: mine
                                  ? context.colors.highlight.withValues(alpha: 0.22,
                                    )
                                  : context.colors.shadow.withValues(alpha: 0.04,
                                    ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (hasImage) ...[
                              GestureDetector(
                                onTap: () => ChatMediaService.openFullScreenImage(
                                  context,
                                  imageUrl,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: 220,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 220,
                                        height: 180,
                                        color: context.colors.surfaceAlt,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => Container(
                                      width: 220,
                                      height: 120,
                                      color: context.colors.surfaceAlt,
                                      child: Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: context.colors.info,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (hasText) const SizedBox(height: 6),
                            ],
                            if (hasText)
                              Text(
                                text,
                                style: GoogleFonts.outfit(
                                  color: mine
                                      ? context.colors.textPrimary
                                      : context.colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight:
                                      mine ? FontWeight.w500 : FontWeight.w400,
                                  height: 1.35,
                                ),
                              ),
                            if (timeFormatted.isNotEmpty || isEdited) ...[
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (timeFormatted.isNotEmpty)
                                    Text(
                                      timeFormatted,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: mine
                                            ? context.colors.error.withValues(alpha: 0.8,
                                              )
                                            : context.colors.info,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (isEdited) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• Edited',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: mine
                                            ? context.colors.error.withValues(alpha: 0.8,
                                              )
                                            : context.colors.info,
                                      ),
                                    ),
                                  ],
                                  if (mine) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 13,
                                      color: context.colors.error.withValues(alpha: 0.8,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (hasReactions)
                      Positioned(
                        bottom: -4,
                        right: mine ? 6 : null,
                        left: mine ? null : 6,
                        child: ChatMessageReactionPill(
                          reactions: reactions,
                          currentUserId: userId,
                          onTap: openMenu,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _bottomAction(
    MarketplaceInterestRequest request,
    bool isSeller,
    String otherName,
  ) {
    if (request.status == MarketplaceInterestStatus.completed) {
      return const _ReadOnlyNotice(
        message: 'This conversation is read-only. No more messages can be sent.',
      );
    }

    if (request.status == MarketplaceInterestStatus.declined) {
      return const _ReadOnlyNotice(
        message: 'This conversation is read-only. No more messages can be sent.',
      );
    }

    if (request.status == MarketplaceInterestStatus.pending && isSeller) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reviewing ? null : () => _review(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                    side: BorderSide(color: context.colors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Decline',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _reviewing ? null : () => _review(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.warningSolid,
                    foregroundColor: context.colors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _reviewing
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onAccent,
                          ),
                        )
                      : const Icon(Icons.chat_rounded, size: 18),
                  label: Text(
                    _reviewing ? 'Accepting…' : 'Accept & Chat',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ObjectKey(_messagesStream),
      stream: _messagesStream,
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const [];
        final isPending = request.status == MarketplaceInterestStatus.pending;

        // Pending buyer limit: count buyer's sent messages (including initial offer)
        final buyerMessagesSent = messages
            .where((m) => m['senderId'] == request.buyerId)
            .length;
        const maxPendingMessages = 3;
        final messagesLeft =
            (maxPendingMessages - buyerMessagesSent).clamp(0, maxPendingMessages,
        );
        final isLimitReached = isPending && !isSeller && messagesLeft == 0;

        // When all 3 messages are used, hide or disable the message box until accepted!
        if (isLimitReached) {
          return SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.colors.warningSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.warningSolid.withValues(alpha: 0.10,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.colors.warningSolid.withValues(alpha: 0.20,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: context.colors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0 messages left • Waiting for seller approval',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You've used all 3 messages. Messages unlock freely once $otherName accepts your offer.",
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: context.colors.warning,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(
                top: BorderSide(
                  color: context.colors.border,
                  width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // If in pending state, show how many messages are left!
                if (isPending && !isSeller)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.infoSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_send_rounded,
                          color: context.colors.info,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$messagesLeft ${messagesLeft == 1 ? 'message' : 'messages'} left • Waiting for seller approval',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: context.colors.info,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Attachment button
                    Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                        onPressed: _sending
                            ? null
                            : () => _handleAttachPhoto(
                                  isLimited: isPending && !isSeller,
                                  messagesLeft: messagesLeft,
                                ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Attach photo',
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: ESugidInputLimits.chatMessage,
                        buildCounter: (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                        textInputAction: TextInputAction.newline,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: isPending && !isSeller
                              ? 'Message seller ($messagesLeft left)…'
                              : 'Type a message...',
                          hintStyle: GoogleFonts.outfit(
                            color: context.colors.info,
                            fontSize: 13.5,
                          ),
                          filled: true,
                          fillColor: context.colors.inputBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: context.colors.border,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _sending ? null : _send,
                        borderRadius: BorderRadius.circular(24),
                        child: Tooltip(
                          message: 'Send message',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.warningSolid,
                                  context.colors.warningSolid,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.warningSolid.withValues(alpha: 0.30,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _sending
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        color: context.colors.surface,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_upward_rounded,
                                      color: context.colors.onAccent,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.name,
    this.photoUrl,
    required this.onBack,
    required this.onProfileTap,
    required this.menuActions,
    required this.onMenuSelected,
  });

  final String name;
  final String? photoUrl;
  final VoidCallback onBack;
  final VoidCallback onProfileTap;
  final List<PopupMenuEntry<String>> menuActions;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: context.colors.textPrimary,
              ),
              onPressed: onBack,
              tooltip: 'Back',
            ),
            GestureDetector(
              onTap: onProfileTap,
              child: BayanihanUserAvatar(
                name: name,
                photoUrl: photoUrl,
                size: 40,
                showVerifiedBadge: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onProfileTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isEmpty ? 'User' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: context.colors.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Active now',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More options',
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.colors.textSecondary,
                size: 22,
              ),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              onSelected: onMenuSelected,
              itemBuilder: (_) => menuActions,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedMarketItemBanner extends StatelessWidget {
  const _PinnedMarketItemBanner({
    required this.request});

  final MarketplaceInterestRequest request;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.status) {
      MarketplaceInterestStatus.pending => context.colors.warning,
      MarketplaceInterestStatus.accepted => context.colors.primaryGreen,
      MarketplaceInterestStatus.declined => context.colors.error,
      MarketplaceInterestStatus.completed => context.colors.info,
    };

    final statusText = switch (request.status) {
      MarketplaceInterestStatus.pending => 'Pending Review',
      MarketplaceInterestStatus.accepted => 'Active Trade',
      MarketplaceInterestStatus.declined => 'Declined',
      MarketplaceInterestStatus.completed => 'Completed',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.border,
            width: 1),
        ),
      ),
      child: Row(
        children: [
          // Picture thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: request.itemImageUrl.isNotEmpty
                ? Image.network(
                    request.itemImageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildItemPlaceholder(context),
                  )
                : _buildItemPlaceholder(context),
          ),
          const SizedBox(width: 12),
          // Title & details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  request.itemName.isEmpty
                      ? 'Marketplace item'
                      : request.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Local Market',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.colors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildItemPlaceholder(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.colors.warningSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: context.colors.warning,
          size: 24,
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
