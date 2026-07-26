import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Dashboard canvas — same meter line-art motif as Entry.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => BrandSurfaceBackground(child: child);
}
