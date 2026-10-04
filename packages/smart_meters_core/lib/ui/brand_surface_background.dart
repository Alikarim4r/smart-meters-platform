import 'package:flutter/material.dart';

import '../theme/brand_chrome.dart';

/// Pure `#FFFFFF` light canvas (or midnight dark) with a soft gray meter motif.
///
/// Nested shells must use [showMotif] = false so they do not cover the root motif.
class BrandSurfaceBackground extends StatelessWidget {
  const BrandSurfaceBackground({
    super.key,
    required this.child,
    this.baseColor,
    this.expand = true,
    this.showMotif = true,
  });

  final Widget child;
  final Color? baseColor;
  final bool expand;

  /// When false, passes [child] through with no canvas/motif layers.
  final bool showMotif;

  static const assetPathLegacy =
      'assets/branding/meter_line_art_pattern_md.png';

  /// Falls back to the shipped MD motif until a dedicated gray asset is added.
  static const assetPathGray = 'assets/branding/meter_line_art_pattern_md.png';

  /// Exact bright white — never cream / off-white.
  static const pureWhite = Color(0xFFFFFFFF);

  /// Cool gray strokes — a quiet texture that never competes with content.
  static const motifGray = Color(0xFF9AA3B0);

  @override
  Widget build(BuildContext context) {
    if (!showMotif) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = baseColor ?? (isDark ? BrandChrome.canvasDark : pureWhite);

    return Stack(
      fit: expand ? StackFit.expand : StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        Positioned.fill(
          child: IgnorePointer(child: isDark ? _darkMotif() : _lightMotif()),
        ),
        child,
      ],
    );
  }

  static Widget _lightMotif() {
    return const Opacity(
      opacity: 0.07,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(motifGray, BlendMode.srcIn),
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(assetPathGray, package: 'smart_meters_core'),
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
              scale: 1.4,
              filterQuality: FilterQuality.none,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _darkMotif() {
    return const Opacity(
      opacity: 0.06,
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(assetPathLegacy, package: 'smart_meters_core'),
            repeat: ImageRepeat.repeat,
            alignment: Alignment.topLeft,
            scale: 1.35,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
