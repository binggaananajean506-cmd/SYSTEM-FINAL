import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exit_confirmation_dialog.dart';

/// Handles system back only while this screen is the navigator's root route.
class RootExitPopScope extends StatefulWidget {
  const RootExitPopScope({super.key, required this.child, this.onRootBack});

  final Widget child;
  final bool Function()? onRootBack;

  @override
  State<RootExitPopScope> createState() => _RootExitPopScopeState();
}

class _RootExitPopScopeState extends State<RootExitPopScope> {
  bool _showingExitDialog = false;

  Future<void> _confirmExit() async {
    if (_showingExitDialog) return;
    _showingExitDialog = true;
    try {
      final shouldExit = await showExitConfirmationDialog(context);
      if (shouldExit == true && mounted) {
        await SystemNavigator.pop();
      }
    } finally {
      _showingExitDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRootRoute = ModalRoute.of(context)?.isFirst ?? true;
    return PopScope(
      canPop: !isRootRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !isRootRoute || !mounted || _showingExitDialog) return;
        if (widget.onRootBack?.call() == true) return;
        _confirmExit();
      },
      child: widget.child,
    );
  }
}
