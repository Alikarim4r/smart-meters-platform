import 'package:flutter/material.dart';

/// Single-line text safe for DropdownButton / FormField closed values.
Widget dropdownItemText(String label) =>
    Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);

/// Caps dialog content size to the phone viewport.
Size dialogContentSize(
  BuildContext context, {
  double preferredWidth = 560,
  double preferredHeight = 480,
}) {
  final size = MediaQuery.sizeOf(context);
  return Size(
    preferredWidth.clamp(0, size.width - 48).toDouble(),
    preferredHeight.clamp(0, size.height * 0.7).toDouble(),
  );
}
