import 'package:flutter/material.dart';

import '../../theme/dashboard_theme.dart';

InputDecoration premiumFilterDecoration({
  required BuildContext context,
  required String labelText,
  IconData? prefixIcon,
  Widget? suffixIcon,
}) {
  final colors = dashboardColors(context);
  return InputDecoration(
    labelText: labelText,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 20, color: colors.textMuted)
        : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.inputFill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    labelStyle: TextStyle(color: colors.textMuted, fontSize: 13),
    hintStyle: TextStyle(color: colors.textMuted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border.withValues(alpha: 0.85)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colors.navy.withValues(alpha: 0.55),
        width: 1.2,
      ),
    ),
  );
}
