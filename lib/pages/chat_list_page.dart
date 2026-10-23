import 'package:flutter/material.dart';

import '../features/bayanihan_messages/presentation/pages/bayanihan_messages_page.dart';

/// Backward-compatible route used by the Profile shortcut.
///
/// All resident messaging is handled by the request-linked Bayanihan inbox.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) => const BayanihanMessagesPage();
}
