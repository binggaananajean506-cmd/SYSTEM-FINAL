import 'dart:async';

import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/core/errors/user_facing_error.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../auth_service.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../../pages/public_user_profile_page.dart';
import '../../../../services/chat_media_service.dart';
import '../../../../services/community_trust_service.dart';
import '../../../../widgets/chat_message_actions.dart';
import '../../../../widgets/esugid_page_header.dart';
import '../../../../widgets/user_profile_avatar.dart';
import '../../models/bayanihan_conversation.dart';
import '../../services/bayanihan_messaging_service.dart';
import '../widgets/cancel_offer_dialog.dart';

class BayanihanConversationPage extends StatefulWidget {
  const BayanihanConversationPage({
    super.key,
    required this.initialConversation,
    this.service,
    this.conversationStream,
    this.messageStream,
    this.onViewRequest,
  });

  final BayanihanConversation initialConversation;
  final BayanihanMessagingService? service;
  final Stream<BayanihanConversation?>? conversationStream;
  final Stream<List<BayanihanMessage>>? messageStream;
  final ValueChanged<String>? onViewRequest;

  @override
  State<BayanihanConversationPage> createState() =>
      _BayanihanConversationPageState();
}

class _BayanihanConversationPageState extends State<BayanihanConversationPage> {
  final _messageController = TextEditingController();
  bool _sending = false;
  late Stream<List<BayanihanMessage>> _effectiveMessageStream;
  StreamSubscription<List<BayanihanMessage>>? _messageSubscription;
  Stream<BayanihanConversation?>? _effectiveConversationStream;
  late BayanihanMessagingService _service;
  String? _streamUserId;

  User? get _user => AuthService.currentUser;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BayanihanMessagingService();
    _initStreams();
    _service.markRead(widget.initialConversation.id).catchError((_) {});
    _preloadOtherUserProfile();
  }

  @override
  void didUpdateWidget(BayanihanConversationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_streamUserId != _user?.uid ||
        oldWidget.service != widget.service ||
        oldWidget.conversationStream != widget.conversationStream ||
        oldWidget.messageStream != widget.messageStream ||
        oldWidget.initialConversation.id != widget.initialConversation.id) {
      _service = widget.service ?? BayanihanMessagingService();
      _initStreams();
      _service.markRead(widget.initialConversation.id).catchError((_) {});
      _preloadOtherUserProfile();
    }
  }

  void _initStreams() {
    _streamUserId = _user?.uid;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    final convId = widget.initialConversation.id;
    _effectiveConversationStream = widget.conversationStream ??
        (convId.isNotEmpty ? _service.conversation(convId) : null);
    final base = widget.messageStream ??
        (convId.isNotEmpty ? _service.messages(convId) : const Stream<List<BayanihanMessage>>.empty());
    _effectiveMessageStream = base.asBroadcastStream(
      onListen: (subscription) {
        _messageSubscription = subscription;
        if (subscription.isPaused) subscription.resume();
      },
      onCancel: (subscription) => subscription.pause(),
    );
  }

  void _preloadOtherUserProfile() {
    if (Firebase.apps.isEmpty) return;
    final userId = _user?.uid ?? '';
    final otherId = widget.initialConversation.isRequester(userId)
        ? widget.initialConversation.helperId
        : widget.initialConversation.requesterId;
    if (otherId.isNotEmpty &&
        CommunityTrustService.getCachedProfile(otherId) == null) {
      CommunityTrustService().getTrustProfile(otherId).then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BayanihanConversation?>(
      key: ValueKey((widget.initialConversation.id, _streamUserId)),
      initialData: widget.initialConversation,
      stream: _effectiveConversationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: AsyncErrorView(onRetry: () => setState(_initStreams)));
        }
        final conversation = snapshot.data ?? widget.initialConversation;
        final userId = _user?.uid ?? '';
        final otherId = conversation.isRequester(userId)
            ? conversation.helperId
            : conversation.requesterId;
        final otherName = conversation.otherParticipantName(userId);
        final otherPhotoUrl = conversation.otherParticipantPhotoUrl(userId) ??
            CommunityTrustService.getCachedProfile(otherId)?.profilePhotoUrl;
        return Scaffold(
          backgroundColor: context.colors.background,
          body: Column(
            children: [
              _ChatTopBar(
                name: otherName,
                photoUrl: otherPhotoUrl,
                onBack: () => Navigator.maybePop(context),
                onProfileTap: () => PublicUserProfilePage.show(
                  context,
                  otherId,
                  initialName: otherName,
                ),
                onMenuSelected: (value) => _handleAction(
                  value,
                  conversation,
                  otherUserId: otherId,
                  otherUserName: otherName,
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
                            'View profile',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (conversation.status ==
                          BayanihanConversationStatus.pending &&
                      conversation.isRequester(_user?.uid ?? '')) ...[
                    PopupMenuItem(
                      value: 'accept_offer',
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
                      value: 'decline_offer',
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
                              'Decline offer',
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
                  if (conversation.status ==
                          BayanihanConversationStatus.pending &&
                      conversation.helperId == _user?.uid)
                    PopupMenuItem(
                      value: 'cancel_offer',
                      child: Row(
                        children: [
                          Icon(
                            Icons.exit_to_app_rounded,
                            size: 18,
                            color: context.colors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cancel offer',
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
                  if (conversation.status ==
                          BayanihanConversationStatus.active &&
                      conversation.isRequester(_user?.uid ?? ''))
                    PopupMenuItem(
                      value: 'complete_request',
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
                              'Mark as completed',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (conversation.status ==
                          BayanihanConversationStatus.active &&
                      conversation.helperId == _user?.uid)
                    PopupMenuItem(
                      value: 'withdraw',
                      child: Row(
                        children: [
                          Icon(
                            Icons.exit_to_app_rounded,
                            size: 18,
                            color: context.colors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Withdraw from request',
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
                            'Clear my messages',
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
                    value: 'report_conversation',
                    child: Row(
                      children: [
                        Icon(
                          Icons.report_outlined,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Report conversation',
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
                            'Report user',
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
                            'Block user',
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
              _PinnedBayanihanRequestBanner(
                conversation: conversation,
                onViewRequest: () {
                  final handler = widget.onViewRequest;
                  if (handler != null) {
                    handler(conversation.requestId);
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    '/jobs',
                    arguments: conversation.requestId,
                  );
                },
              ),
              Expanded(
                child: _MessageHistory(
                  conversation: conversation,
                  messages: _effectiveMessageStream,
                  currentUserId: userId,
                  service: _service,
                ),
              ),
              // Rating prompt shown after completion
              if (conversation.status ==
                      BayanihanConversationStatus.completed &&
                  userId.isNotEmpty &&
                  otherId.isNotEmpty)
                CommunityRatingPrompt(
                  sourceId: conversation.id,
                  targetUserId: otherId,
                  targetUserName: otherName,
                  context: TrustContext.bayanihan,
                ),
              _buildBottomArea(conversation),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomArea(BayanihanConversation conversation) {
    final user = _user;
    final myUid = user?.uid ?? '';
    final isRequester = conversation.isRequester(myUid);
    final isHelper = !isRequester;

    // 1. If conversation is completed, declined, cancelled, or withdrawn:
    // Once marked Completed, conversation automatically closes and no more messages can be sent.
    if (conversation.status != BayanihanConversationStatus.pending &&
        conversation.status != BayanihanConversationStatus.active) {
      final msg = switch (conversation.status) {
        BayanihanConversationStatus.completed =>
          'This conversation is read-only. No more messages can be sent.',
        BayanihanConversationStatus.declined =>
          'This help offer was declined. This conversation is read-only.',
        BayanihanConversationStatus.cancelled =>
          'This help request was cancelled. This conversation is read-only.',
        BayanihanConversationStatus.withdrawn =>
          'The helper withdrew from this request. This conversation is read-only.',
        _ => 'This conversation is read-only. No more messages can be sent.',
      };
      return _ReadOnlyNotice(message: msg);
    }

    // 2. Pending offer & current user is the requester -> Show Accept / Decline action bar
    if (conversation.status == BayanihanConversationStatus.pending &&
        isRequester) {
      return _PendingOfferActions(
        busy: _sending,
        onAccept: () => _runAction(
          () => _service.acceptOffer(conversation.id),
          success: 'Offer accepted. Messaging is now available.',
        ),
        onDecline: () => _showDeclineDialog(conversation),
      );
    }

    // 3. For Active (unlimited for both) or Pending (up to 3 messages for helper while waiting):
    final otherName = conversation.otherParticipantName(myUid);
    final messagesStream = _effectiveMessageStream;

    return StreamBuilder<List<BayanihanMessage>>(
      stream: messagesStream,
      builder: (context, msgSnapshot) {
        final messages = msgSnapshot.data ?? [];
        final isPending =
            conversation.status == BayanihanConversationStatus.pending;

        // Pending helper limit: count helper's sent messages (including initial offer)
        final helperMessagesSent = messages
            .where((m) => m.senderId == conversation.helperId)
            .length;
        const maxPendingMessages = 3;
        final messagesLeft =
            (maxPendingMessages - helperMessagesSent).clamp(0, maxPendingMessages,
        );
        final isLimitReached = isPending && isHelper && messagesLeft == 0;

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
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.08),
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
                        color: context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: context.colors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0 messages left • Waiting for requester approval',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: context.colors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "You've used all 3 messages. Messages unlock freely once $otherName accepts your offer.",
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: context.colors.primaryGreen,
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
                top: BorderSide(color: context.colors.border, width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // If in pending state, show how many messages are left!
                if (isPending && isHelper)
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
                            '$messagesLeft ${messagesLeft == 1 ? 'message' : 'messages'} left • Waiting for requester approval',
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
                                  conversation.id,
                                  isLimited: isPending && isHelper,
                                  messagesLeft: messagesLeft,
                                ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Attach photo',
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: isPending && isHelper
                              ? 'Message requester ($messagesLeft left)…'
                              : 'Type a message...',
                          hintStyle: GoogleFonts.outfit(
                            color: context.colors.info,
                            fontSize: 13.5,
                          ),
                          counterText: '',
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
                              color: context.colors.primaryGreen,
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
                        onTap: _sending
                            ? null
                            : () => _send(
                                  conversation.id,
                                  isLimited: isPending && isHelper,
                                  messagesLeft: messagesLeft,
                                ),
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
                                  context.colors.brand,
                                  context.colors.brand,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.brandStrong.withValues(alpha: 0.30,
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

  Future<void> _handleAttachPhoto(
    String conversationId, {
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
      final user = _user ?? AuthService.currentUser;
      final userId = user?.uid ?? auth.FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw const BayanihanMessagingException('Please sign in again.');
      }
      final url = await ChatMediaService.uploadChatImage(
        file: file,
        userId: userId,
        conversationId: conversationId,
      );
      await _service
          .sendImageMessage(
            conversationId,
            imageUrl: url,
            userId: userId)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              throw const BayanihanMessagingException(
                'Photo upload timed out. Please check your connection.',
              );
            },
          );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send(
    String conversationId, {
    bool isLimited = false,
    int messagesLeft = 3,
  }) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    if (isLimited && messagesLeft <= 0) {
      _showError(
        'You have reached the 3-message limit while waiting for approval.',
      );
      return;
    }
    _messageController.clear(); // Clear immediately for snappy, fluid response
    setState(() => _sending = true);
    try {
      await _service
          .sendMessage(conversationId, text)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw const BayanihanMessagingException(
                'Message sending timed out. Please check your connection.',
              );
            },
          );
    } catch (error) {
      if (mounted && widget.initialConversation.id == conversationId &&
          _messageController.text.isEmpty) {
        _messageController.text = text;
      }
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await action().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw const BayanihanMessagingException(
            'Action took too long to complete. Please check your connection.',
          );
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text(success),
            duration: const Duration(seconds: 3),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showDeclineDialog(BayanihanConversation conversation) async {
    final reason = await _reasonDialog(
      title: 'Decline offer',
      options: const [
        'Already have enough volunteers',
        'Schedule does not match',
        'Request is no longer needed',
        'Other',
      ],
    );
    if (reason == null) return;
    await _runAction(
      () => _service.declineOffer(conversation.id, reason: reason),
      success: 'Offer declined.',
    );
  }

  Future<void> _handleAction(
    String action,
    BayanihanConversation conversation, {
    String otherUserId = '',
    String otherUserName = '',
  }) async {
    if (action == 'view_profile') {
      await PublicUserProfilePage.show(
        context,
        otherUserId,
        initialName: otherUserName,
      );
      return;
    }
    if (action == 'accept_offer') {
      await _runAction(
        () => _service.acceptOffer(conversation.id),
        success: 'Offer accepted! You can now freely chat.',
      );
      return;
    }
    if (action == 'decline_offer') {
      await _showDeclineDialog(conversation);
      return;
    }
    if (action == 'cancel_offer') {
      final message = await showBayanihanCancelOfferDialog(
        context,
        recipientName: otherUserName,
        requestTitle: conversation.requestTitle,
      );
      if (message != null && message.trim().isNotEmpty) {
        await _runAction(
          () async {
            try {
              await _service.sendMessage(
                conversation.id,
                '📢 Offer cancelled: ${message.trim()}',
              );
            } catch (_) {}
            await _service.withdraw(conversation.id, reason: message.trim());
          },
          success: 'Offer cancelled. Your message was sent to $otherUserName.',
        );
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
        await _service.clearConversationMessages(conversation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showAppSnackBar(
            AppSnackBar(
              content: Text('Your messages have been cleared.'),
              kind: FeedbackKind.success,
            ),
          );
        }
      }
      return;
    }
    if (action == 'complete_request') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Complete Help Request?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Marking this request as completed will award civic points to the helper and automatically close this conversation.',
            style: GoogleFonts.outfit(fontSize: 13.5),
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

                backgroundColor: context.colors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Mark Completed'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _runAction(
          () => _service.closeRequest(conversation.requestId, completed: true),
          success: 'Help request marked as completed! Conversation closed.',
        );
      }
      return;
    }
    if (action == 'withdraw') {
      final message = await showBayanihanCancelOfferDialog(
        context,
        recipientName: otherUserName,
        requestTitle: conversation.requestTitle,
      );
      if (message != null && message.trim().isNotEmpty) {
        await _runAction(
          () async {
            try {
              await _service.sendMessage(
                conversation.id,
                '📢 Withdrawn from request: ${message.trim()}',
              );
            } catch (_) {}
            await _service.withdraw(conversation.id, reason: message.trim());
          },
          success: 'You withdrew from this request.');
      }
      return;
    }
    if (action == 'report_user') {
      if (!mounted) return;
      await showReportUserSheet(
        context,
        reportedUserId: otherUserId,
        reportedUserName: otherUserName,
        conversationId: conversation.id,
        context_: TrustContext.bayanihan,
      );
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
            'Block $otherUserName?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'They will no longer be able to message you or interact with your requests.',
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
            content: Text('$otherUserName has been blocked.'),
            kind: FeedbackKind.success,
          ),
        );
      }
      return;
    }
    // report_conversation (legacy)
    final details = await _textDialog(
      title: 'Report conversation',
      hint: 'Tell the LGU what happened (optional)',
    );
    if (details != null) {
      await _runAction(
        () => _service.reportConversation(conversation, details),
        success: 'Report sent to the E-Sugid helpdesk.',
      );
    }
  }

  Future<String?> _reasonDialog({
    required String title,
    required List<String> options,
  }) async {
    String selected = options.first;
    final custom = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: options
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(
                            option,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selected = value ?? selected),
                ),
                if (selected == 'Other')
                  TextField(
                    controller: custom,
                    maxLength: 240,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = selected == 'Other'
                    ? custom.text.trim()
                    : selected;
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    custom.dispose();
    return result;
  }

  Future<String?> _textDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is BayanihanMessagingException
        ? error.message
        : userFacingError(error, fallback: 'The action could not be completed. Try again.');
    ScaffoldMessenger.of(context).showAppSnackBar(
      AppSnackBar(
        content: Text(message), kind: FeedbackKind.error),
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
                        Flexible(
                          child: Text(
                            'Active now',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textSecondary,
                            ),
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

class _PinnedBayanihanRequestBanner extends StatelessWidget {
  const _PinnedBayanihanRequestBanner({
    required this.conversation,
    required this.onViewRequest,
  });

  final BayanihanConversation conversation;
  final VoidCallback onViewRequest;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (conversation.status) {
      BayanihanConversationStatus.pending => context.colors.textPrimary,
      BayanihanConversationStatus.active => context.colors.primaryGreen,
      BayanihanConversationStatus.completed => context.colors.info,
      _ => context.colors.textSecondary,
    };

    final showCompletionHint =
        conversation.status == BayanihanConversationStatus.active;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final iconBox = Container(
                width: isVeryNarrow ? 38 : 48,
                height: isVeryNarrow ? 38 : 48,
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.colors.border,
                    width: 1),
                ),
                child: Center(
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: context.colors.primaryGreen,
                    size: isVeryNarrow ? 20 : 24,
                  ),
                ),
              );

              final textInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.requestTitle.isEmpty
                        ? 'Bayanihan Request'
                        : conversation.requestTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          conversation.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Bayanihan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final viewBtn = TextButton(
                onPressed: onViewRequest,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Request',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primaryGreen,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.colors.primaryGreen,
                    ),
                  ],
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconBox,
                        const SizedBox(width: 8),
                        Expanded(child: textInfo),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: viewBtn),
                  ],
                );
              }

              return Row(
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  Expanded(child: textInfo),
                  const SizedBox(width: 4),
                  viewBtn,
                ],
              );
            },
          ),
          if (showCompletionHint) ...[
            const SizedBox(height: 6),
            Text(
              'Open the request to mark the help as completed.',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageHistory extends StatelessWidget {
  const _MessageHistory({
    required this.conversation,
    required this.messages,
    required this.currentUserId,
    this.service,
  });
  final BayanihanConversation conversation;
  final Stream<List<BayanihanMessage>> messages;
  final String currentUserId;
  final BayanihanMessagingService? service;

  @override
  Widget build(BuildContext context) {
    final activeService = service ?? BayanihanMessagingService();

    return StreamBuilder<List<BayanihanMessage>>(
      stream: messages,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Messages could not be loaded.'));
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
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
                      color: context.colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.volunteer_activism_outlined,
                      color: context.colors.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No messages in this offer yet.',
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
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final message = items[index];
            final mine = message.senderId == currentUserId;
            final isUnsent = message.isUnsent;
            final hasImage = message.imageUrl != null && message.imageUrl!.isNotEmpty;
            final hasText = message.text.isNotEmpty;
            final hasReactions = message.reactions.isNotEmpty;

            void openMenu() {
              showChatMessageActionMenu(
                context,
                messageId: message.id,
                text: message.text,
                imageUrl: message.imageUrl,
                isMine: mine,
                isUnsent: isUnsent,
                currentReactions: message.reactions,
                currentUserId: currentUserId,
                onReactionSelected: (emoji) async {
                  try {
                    await activeService.toggleReaction(
                      conversation.id,
                      message.id,
                      emoji,
                      userId: currentUserId,
                    );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(error is BayanihanMessagingException ? error.message : userFacingError(error, fallback: 'Could not update reaction. Try again.')),
                          kind: FeedbackKind.error,
                        ),
                      );
                    }
                  }
                },
                onEdit: (newText) async {
                  try {
                    await activeService.editMessage(
                      conversation.id,
                      message.id,
                      newText,
                      userId: currentUserId,
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
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(error is BayanihanMessagingException ? error.message : userFacingError(error, fallback: 'Could not edit message. Try again.')),
                          kind: FeedbackKind.error,
                        ),
                      );
                    }
                  }
                },
                onUnsend: () async {
                  try {
                    await activeService.unsendMessage(
                      conversation.id,
                      message.id,
                      userId: currentUserId,
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
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        AppSnackBar(
                          content: Text(error is BayanihanMessagingException ? error.message : userFacingError(error, fallback: 'Could not unsend message. Try again.')),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9,
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
                            : '${conversation.otherParticipantName(currentUserId)} unsent a message',
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
                          color: mine ? context.colors.brand
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
                                  ? context.colors.brandStrong.withValues(alpha: 0.22,
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
                                  message.imageUrl!,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    message.imageUrl!,
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
                                message.text,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: mine
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  height: 1.35,
                                  color: mine
                                      ? context.colors.onAccent
                                      : context.colors.textPrimary,
                                ),
                              ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeago.format(message.sentAt),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: mine
                                        ? context.colors.onAccent.withValues(alpha: 0.75,
                                          )
                                        : context.colors.info,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (message.isEdited) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '• Edited',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: mine
                                          ? context.colors.onAccent.withValues(alpha: 0.85,
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
                                    color: context.colors.primaryGreen,
                                  ),
                                ],
                              ],
                            ),
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
                          reactions: message.reactions,
                          currentUserId: currentUserId,
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
}

class _PendingOfferActions extends StatelessWidget {
  const _PendingOfferActions({
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final maxPanelHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      260.0,
      420.0,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.fromLTRB(18, 42, 18, 16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border.all(color: context.colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Review this offer',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Accept to start chatting, or decline this offer.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final decline = OutlinedButton.icon(
                          onPressed: busy ? null : onDecline,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(
                              color: context.colors.border,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Decline'),
                        );
                        final accept = DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.colors.brand,
                                context.colors.brand,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brandStrong.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: FilledButton.icon(
                            onPressed: busy ? null : onAccept,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              foregroundColor: context.colors.onAccent,
                              disabledForegroundColor: context.colors.disabled,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: busy
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.colors.surface,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(busy ? 'Accepting…' : 'Accept Offer'),
                          ),
                        );
                        if (constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              decline,
                              const SizedBox(height: 10),
                              accept,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: decline),
                            const SizedBox(width: 10),
                            Expanded(child: accept),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Keep our community safe and respectful.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.brandStrong.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: context.colors.primaryGreen,
                  size: 29,
                ),
              ),
            ],
          ),
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
