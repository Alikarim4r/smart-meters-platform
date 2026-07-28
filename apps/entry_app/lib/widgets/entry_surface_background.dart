import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Entry canvas shell — motif is painted once by [MaterialApp.builder].
class EntrySurfaceBackground extends StatelessWidget {
  const EntrySurfaceBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BrandSurfaceBackground(showMotif: false, child: child);
}
