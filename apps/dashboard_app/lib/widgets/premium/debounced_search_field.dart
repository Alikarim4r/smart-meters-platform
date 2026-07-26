import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/dashboard_theme.dart';
import 'dashboard_filter_decorations.dart';

/// Search field with 220ms debounce for instant-feel filtering without rebuild storms.
class DebouncedSearchField extends ConsumerStatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.onChanged,
    this.initialValue = '',
    this.hint = 'Search meter name or code (/)',
    this.focusNode,
  });

  final ValueChanged<String> onChanged;
  final String initialValue;
  final String hint;
  final FocusNode? focusNode;

  @override
  ConsumerState<DebouncedSearchField> createState() =>
      _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends ConsumerState<DebouncedSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(DashboardMotion.searchDebounce, () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: premiumFilterDecoration(
        context: context,
        labelText: widget.hint,
        prefixIcon: Icons.search_rounded,
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (value) {
        _onChanged(value);
        setState(() {});
      },
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
    );
  }
}
