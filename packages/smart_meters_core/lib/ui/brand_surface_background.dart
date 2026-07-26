import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand_chrome.dart';

/// Shared cream/midnight canvas with the meter line-art motif
/// (pipes, valves, gauges, digital meters) used by Entry, Admin, and Dashboard.
class BrandSurfaceBackground extends StatelessWidget {
  const BrandSurfaceBackground({
    super.key,
    required this.child,
    this.baseColor,
    this.expand = true,
  });

  final Widget child;

  /// Optional override (e.g. dashboard sidebar navy). Defaults to brand canvas.
  final Color? baseColor;

  /// When false, sizes to [child] (safe inside Row/unbounded parents).
  final bool expand;

  static const assetPath = 'assets/branding/meter_line_art_pattern_md.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base =
        baseColor ??
        (isDark ? BrandChrome.canvasDark : BrandChrome.canvasLight);

    final motif = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(assetPath, package: 'smart_meters_core'),
            repeat: ImageRepeat.repeat,
            alignment: Alignment.topLeft,
            opacity: isDark ? 0.28 : 0.55,
            scale: 1.35,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    final wash = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -0.85),
            radius: 1.05,
            colors: [
              AppColors.gold.withValues(alpha: isDark ? 0.12 : 0.06),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );

    return Stack(
      fit: expand ? StackFit.expand : StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        Positioned.fill(child: motif),
        Positioned.fill(child: wash),
        child,
      ],
    );
  }
}
