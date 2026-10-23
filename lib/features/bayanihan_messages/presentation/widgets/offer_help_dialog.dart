import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../jobs_service.dart';
import '../../../../widgets/esugid_page_header.dart';
import '../../services/bayanihan_messaging_service.dart';

class OfferHelpDialog extends StatefulWidget {
  const OfferHelpDialog({super.key, required this.request, this.service});

  final JobItem request;
  final BayanihanMessagingService? service;

  static Future<String?> show(
    BuildContext context, {
    required JobItem request,
    BayanihanMessagingService? service,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OfferHelpDialog(
        request: request,
        service: service ?? BayanihanMessagingService(),
      ),
    );
  }

  @override
  State<OfferHelpDialog> createState() => _OfferHelpDialogState();
}

class _OfferHelpDialogState extends State<OfferHelpDialog> {
  final _messageController = TextEditingController();
  final _availabilityController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offer Help',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell the requester how you can help.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _messageController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Initial message',
                  hintText:
                      'Hi! I can help Saturday morning. I can arrive around 7 AM.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _availabilityController,
                maxLength: 240,
                decoration: InputDecoration(
                  labelText: 'Availability (optional)',
                  hintText: 'Saturday, 7 AM–11 AM',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: context.colors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onAccent,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: const Text('Send Offer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'An initial message is required.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final conversationId = await widget.service!.sendOffer(
        requestId: widget.request.id,
        initialMessage: message,
        availability: _availabilityController.text,
      );
      if (mounted) Navigator.pop(context, conversationId);
    } on BayanihanMessagingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
