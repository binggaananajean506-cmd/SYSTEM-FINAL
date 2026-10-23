import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth_service.dart';
import '../community_service.dart';
import '../core/errors/user_facing_error.dart';
import '../widgets/esugid_page_header.dart';
import '../core/validation/esugid_validators.dart';

class HelpdeskPage extends StatefulWidget {
  const HelpdeskPage({super.key, this.ticketsForUser, this.createTicket});

  final Stream<List<HelpdeskTicket>> Function(String userId)? ticketsForUser;
  final Future<void> Function(HelpdeskTicket ticket)? createTicket;

  @override
  State<HelpdeskPage> createState() => _HelpdeskPageState();
}

class _HelpdeskPageState extends State<HelpdeskPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _ticketsUserId;
  Stream<List<HelpdeskTicket>>? _ticketsStream;
  Stream<List<HelpdeskTicket>> Function(String)? _ticketsSource;
  int _ticketsGeneration = 0;

  void _bindTicketStream(User? user, {bool force = false}) {
    final source = widget.ticketsForUser ?? CommunityService.ticketsForUser;
    if (!force && _ticketsUserId == user?.uid && _ticketsSource == source) {
      return;
    }
    _ticketsUserId = user?.uid;
    _ticketsSource = source;
    _ticketsStream = user == null ? null : source(user.uid);
    _ticketsGeneration++;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    _bindTicketStream(user);
    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          const ESugidSliverPageHeader(
            sectionLabel: 'Services',
            title: 'Citizen Helpdesk',
            subtitle: 'Create a ticket and track LGU replies.',
            icon: Icons.support_agent_rounded,
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How can we help?',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Post your questions or concerns to the local government.',
                    style: GoogleFonts.outfit(
                      color: context.colors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFormContainer(context, user),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Popular Topics'),
                  const SizedBox(height: 16),
                  _buildFaqItem(context, 'How to apply for a business permit?'),
                  _buildFaqItem(context, 'Where to pay real property taxes?'),
                  _buildFaqItem(context, 'What are the requirements for Cedula?',
                  ),
                  _buildFaqItem(context, 'How to report a power outage?'),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'My Tickets'),
                  const SizedBox(height: 12),
                  if (user != null)
                    StreamBuilder<List<HelpdeskTicket>>(
                      key: ValueKey(_ticketsGeneration),
                      stream: _ticketsStream,
                      builder: (context, snapshot) {
                        final tickets = snapshot.data ?? [];
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              Text(
                                userFacingError(
                                  snapshot.error!,
                                  fallback: 'Could not load your tickets. Please try again.',
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _bindTicketStream(
                                    AuthService.currentUser,
                                    force: true,
                                  );
                                }),
                                child: const Text('Retry'),
                              ),
                            ],
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: context.colors.primaryGreen,
                              ),
                            ),
                          );
                        }
                        if (tickets.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: context.colors.border),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  color: context.colors.textSecondary,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No tickets yet',
                                  style: GoogleFonts.outfit(
                                    color: context.colors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: tickets.map((t) => _buildTicketCard(context, t)).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFormContainer(BuildContext context, User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? context.colors.brandStrong.withValues(alpha: 0.25)
                : context.colors.brandStrong.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(_subjectController, 'Subject', Icons.title_rounded),
          const SizedBox(height: 16),
          _buildTextField(
            _messageController,
            'Describe your question...',
            Icons.chat_bubble_outline_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: user == null || _isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: context.colors.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isSubmitting ? 'SUBMITTING...' : 'CREATE TICKET',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;
    final user = AuthService.currentUser;
    if (user == null) return;
    final subjectError = ESugidValidators.requiredText(
      _subjectController.text,
      label: 'Subject',
      minLength: 3,
      maxLength: ESugidInputLimits.helpdeskSubject,
    );
    final messageError = ESugidValidators.requiredText(
      _messageController.text,
      label: 'Message',
      minLength: 10,
      maxLength: ESugidInputLimits.description,
    );
    if (subjectError != null || messageError != null) {
      ScaffoldMessenger.of(
        context).showAppSnackBar(
        AppSnackBar(content: Text(subjectError ?? messageError!),
          kind: FeedbackKind.error,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final subjectDraft = _subjectController.text;
    final messageDraft = _messageController.text;
    try {
      await (widget.createTicket ?? CommunityService.createHelpdeskTicket)(
        HelpdeskTicket(
          id: 'TKT-${DateTime.now().millisecondsSinceEpoch}',
          userId: user.uid,
          subject: subjectDraft.trim(),
          message: messageDraft.trim(),
          status: 'Open',
          createdAt: DateTime.now(),
        ),
      );
      if (mounted && AuthService.currentUser?.uid == user.uid) {
        if (_subjectController.text == subjectDraft) _subjectController.clear();
        if (_messageController.text == messageDraft) _messageController.clear();
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar(
            content: Text('Ticket created.'),
            kind: FeedbackKind.success,
          ),
        );
      }
    } catch (error) {
      if (mounted && AuthService.currentUser?.uid == user.uid) {
        ScaffoldMessenger.of(context).showAppSnackBar(AppSnackBar(
          content: Text(userFacingError(
            error,
            fallback: 'Could not create the ticket. Please try again.',
          )),
          kind: FeedbackKind.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildTicketCard(BuildContext context, HelpdeskTicket ticket) {
    final isOpen = ticket.status.toLowerCase() == 'open';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: context.colors.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOpen ? context.colors.warningSolid
                            : context.colors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ticket.status.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Text(
            question,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          trailing: Icon(
            Icons.add_circle_outline_rounded,
            size: 22,
            color: context.colors.primaryGreen,
          ),
          onTap: () => _subjectController.text = question,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    final limit = maxLines == 1
        ? ESugidInputLimits.helpdeskSubject
        : ESugidInputLimits.description;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: [LengthLimitingTextInputFormatter(limit)],
      style: GoogleFonts.outfit(
        fontSize: 14,
        color: context.colors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          color: context.colors.textSecondary),
        prefixIcon: Icon(icon, color: context.colors.primaryGreen, size: 20),
        filled: true,
        fillColor: context.colors.inputBackground.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.primaryGreen, width: 1.5,
          ),
        ),
      ),
    );
  }
}
