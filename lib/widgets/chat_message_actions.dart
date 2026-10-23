import 'package:esugid/core/widgets/app_feedback.dart';
import 'package:esugid/app/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'esugid_page_header.dart';

/// Available emojis for reactions (matching Messenger)
const List<String> kMessengerReactions = ['❤️', '👍', '😂', '😮', '😢', '😡'];

/// A reaction pill displayed at the bottom corner of a message bubble
class ChatMessageReactionPill extends StatelessWidget {
  const ChatMessageReactionPill({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onTap,
  });

  final Map<String, String> reactions; // userId -> emoji
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group emojis to find distinct ones
    final distinctEmojis = reactions.values.toSet().toList();
    final count = reactions.length;
    final userEmoji = reactions[currentUserId];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: userEmoji != null
                ? context.colors.primaryGreen.withValues(alpha: 0.5)
                : context.colors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...distinctEmojis.take(3).map(
                  (emoji) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 12)),
                  ),
                ),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: userEmoji != null
                      ? context.colors.primaryGreen
                      : context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Messenger-style message options bottom sheet
Future<void> showChatMessageActionMenu(
  BuildContext context, {
  required String messageId,
  required String text,
  String? imageUrl,
  required bool isMine,
  required bool isUnsent,
  required Map<String, String> currentReactions,
  required String currentUserId,
  required ValueChanged<String> onReactionSelected,
  required ValueChanged<String> onEdit,
  required VoidCallback onUnsend,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Material(
      color: sheetContext.colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(sheetContext).padding.bottom + 16,
      ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: sheetContext.colors.infoSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Messenger-style floating emoji reaction bar
          if (!isUnsent) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: sheetContext.colors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: sheetContext.colors.border),
                boxShadow: [
                  BoxShadow(
                    color: sheetContext.colors.shadow.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: kMessengerReactions.map((emoji) {
                  final isSelected = currentReactions[currentUserId] == emoji;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReactionSelected(emoji);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? sheetContext.colors.brand.withValues(alpha: 0.18)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: sheetContext.colors.primaryGreen,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        emoji,
                        style: TextStyle(
                          fontSize: isSelected ? 26 : 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action items
          if (text.isNotEmpty && !isUnsent)
            ListTile(
              leading: Icon(
                Icons.copy_rounded,
                color: sheetContext.colors.textSecondary,
                size: 22,
              ),
              title: Text(
                'Copy text',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showAppSnackBar(
                  AppSnackBar(
                    content: Text('Message copied to clipboard'),
                    duration: Duration(seconds: 2),
                    kind: FeedbackKind.success,
                  ),
                );
              },
            ),

          // Edit Message (only for sender and text messages)
          if (isMine && !isUnsent && text.isNotEmpty)
            ListTile(
              leading: Icon(
                Icons.edit_note_rounded,
                color: sheetContext.colors.info,
                size: 24,
              ),
              title: Text(
                'Edit message',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: sheetContext.colors.textPrimary,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final newText = await showEditMessageDialog(context, initialText: text,
                );
                if (newText != null && newText.trim().isNotEmpty && newText.trim() != text) {
                  onEdit(newText.trim());
                }
              },
            ),

          // Unsend Message (for sender)
          if (isMine && !isUnsent)
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: sheetContext.colors.error,
                size: 22,
              ),
              title: Text(
                'Unsend message',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: sheetContext.colors.error,
                ),
              ),
              subtitle: Text(
                'Remove this message for everyone',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: sheetContext.colors.info,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      'Unsend message?',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      'This will unsend the message for all participants in this chat.',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        color: ctx.colors.info,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          foregroundColor: ctx.colors.onAccent,

                          backgroundColor: ctx.colors.errorSolid,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Unsend'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  onUnsend();
                }
              },
            ),
        ],
      ),
      ),
    ),
  );
}

/// Dialog to edit message text
Future<String?> showEditMessageDialog(
  BuildContext context, {
  required String initialText,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditMessageDialog(initialText: initialText),
  );
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Edit Message',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'Edit your message...',
          filled: true,
          fillColor: ctx.colors.inputBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ctx.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: ctx.colors.primaryGreen,
              width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          style: FilledButton.styleFrom(
            foregroundColor: ctx.colors.onAccent,

            backgroundColor: ctx.colors.brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
