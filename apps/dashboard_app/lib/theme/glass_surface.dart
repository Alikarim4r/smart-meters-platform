import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'design_system/dashboard_design_system.dart';

/// Brand cream/gold surface — matches Entry selection cards.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.borderRadius = DashboardRadius.card,
    this.borderColor,
    this.tintOpacity,
    this.useBlur = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Color? borderColor;
  final double? tintOpacity;
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final decoration = brandCardDecoration(
      context,
      radius: borderRadius,
    ).copyWith(
      border: Border.all(
        color: borderColor ??
            BrandChrome.border(
              isDark: isDark,
              scheme: Theme.of(context).colorScheme,
            ),
        width: 1.2,
      ),
      color: tintOpacity == null
          ? null
          : (isDark ? BrandChrome.surfaceDark : Colors.white)
              .withValues(alpha: tintOpacity!),
    );

    final surface = Container(
      margin: margin,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (!useBlur) return surface;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: surface,
      ),
    );
  }
}
