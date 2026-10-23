import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Predefined quick cancellation reasons with polite, courteous message templates.
class CancelOfferReasonOption {
  const CancelOfferReasonOption({
    required this.label,
    required this.defaultMessage,
  });

  final String label;
  final String defaultMessage;
}

const List<CancelOfferReasonOption> kCancelOfferReasons = [
  CancelOfferReasonOption(
    label: 'Schedule conflict',
    defaultMessage:
        "I'm sorry, an unexpected schedule conflict came up and I won't be able to help with your request. Sincere apologies for the inconvenience.",
  ),
  CancelOfferReasonOption(
    label: 'Emergency / Urgent matter',
    defaultMessage:
        'I am very sorry, but an unexpected personal emergency arose and I am unable to attend. I hope you find another volunteer soon.',
  ),
  CancelOfferReasonOption(
    label: 'No longer in area',
    defaultMessage:
        'I will no longer be available in the area on the requested date. Apologies for any inconvenience caused.',
  ),
  CancelOfferReasonOption(
    label: 'Other personal reason',
    defaultMessage:
        'I am unable to fulfill this help offer at this time. Thank you for your understanding.',
  ),
];

/// Displays a modal dialog prompting the user to provide a proper message
/// when cancelling an offer. Returns the message string, or `null` if aborted.
Future<String?> showBayanihanCancelOfferDialog(
  BuildContext context, {
  required String recipientName,
  String? requestTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogCtx) => BayanihanCancelOfferDialog(
      recipientName: recipientName,
      requestTitle: requestTitle,
    ),
  );
}

class BayanihanCancelOfferDialog extends StatefulWidget {
  const BayanihanCancelOfferDialog({
    super.key,
    required this.recipientName,
    this.requestTitle,
  });

  final String recipientName;
  final String? requestTitle;

  @override
  State<BayanihanCancelOfferDialog> createState() =>
      _BayanihanCancelOfferDialogState();
}

class _BayanihanCancelOfferDialogState
    extends State<BayanihanCancelOfferDialog> {
  late final TextEditingController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: kCancelOfferReasons[_selectedIndex].defaultMessage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectReason(int index) {
    setState(() {
      _selectedIndex = index;
      _controller.text = kCancelOfferReasons[index].defaultMessage;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cleanRecipient = widget.recipientName.trim().isNotEmpty
        ? widget.recipientName.trim()
        : 'the requester';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colors.errorSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              color: context.colors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel Help Offer',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Send a message to $cleanRecipient',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              'Select a reason or customize your message below:',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Quick select reason chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(kCancelOfferReasons.length, (index) {
                final isSelected = _selectedIndex == index;
                return ChoiceChip(
                  label: Text(
                    kCancelOfferReasons[index].label,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.onAccent
                          : context.colors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: context.colors.errorSolid,
                  backgroundColor: context.colors.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? context.colors.error
                          : context.colors.border,
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2,
                  ),
                  onSelected: (selected) {
                    if (selected) _selectReason(index);
                  },
                );
              }),
            ),

            const SizedBox(height: 14),

            // Message box
            Text(
              'Your Message:',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return TextField(
                  controller: _controller,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    height: 1.4,
                    color: context.colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a polite message explaining why...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: context.colors.info,
                    ),
                    filled: true,
                    fillColor: context.colors.inputBackground,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.colors.error,
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 4),

            // Informative note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.warningSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: context.colors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This message will be sent to $cleanRecipient so they know you are no longer available.',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.colors.error,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(
            'Keep Offer',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final isValid = value.text.trim().isNotEmpty;
            return FilledButton(
              onPressed: isValid
                  ? () => Navigator.pop(context, _controller.text.trim())
                  : null,
              style: FilledButton.styleFrom(
                foregroundColor: context.colors.onAccent,

                backgroundColor: context.colors.errorSolid,
                disabledBackgroundColor: context.colors.disabledBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
            );
          },
        ),
      ],
    );
  }
}
