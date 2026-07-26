import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Entry canvas — shared meter line-art motif.
class EntrySurfaceBackground extends StatelessWidget {
  const EntrySurfaceBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => BrandSurfaceBackground(child: child);
}
