import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Desktop shortcuts: R refresh, / focus search, Esc dismiss.
class DashboardKeyboardShortcuts extends StatelessWidget {
  const DashboardKeyboardShortcuts({
    super.key,
    required this.child,
    this.onRefresh,
    this.onFocusSearch,
  });

  final Widget child;
  final VoidCallback? onRefresh;
  final VoidCallback? onFocusSearch;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyR): _RefreshIntent(),
        SingleActivator(LogicalKeyboardKey.slash): _SearchIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: {
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              onRefresh?.call();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              onFocusSearch?.call();
              return null;
            },
          ),
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
