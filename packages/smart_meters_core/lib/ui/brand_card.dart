import 'package:flutter/material.dart';

import '../theme/brand_chrome.dart';
import '../theme/brand_tokens.dart';

/// Shared content surface: hairline border and quiet tonal fill, without
/// resting elevation.
BoxDecoration brandCardDecoration(
  BuildContext context, {
  double radius = BrandRadius.card,
  double borderWidth = 1,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: BrandChrome.border(isDark: isDark, scheme: theme.colorScheme),
      width: borderWidth,
    ),
    gradient: BrandChrome.cardWash(isDark: isDark),
  );
}

/// Tonal icon well used on selection and list cards.
Widget brandIconWell({
  required BuildContext context,
  required IconData icon,
  double size = 42,
  double iconSize = 22,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(BrandRadius.control - 2),
      gradient: isDark ? null : BrandChrome.iconWellGradient,
      color: isDark
          ? Color.alphaBlend(
              BrandChrome.accent.withValues(alpha: 0.30),
              BrandChrome.surfaceDarkHigh,
            )
          : null,
      border: Border.all(
        color: isDark
            ? BrandChrome.accentSoft.withValues(alpha: 0.14)
            : BrandChrome.accent.withValues(alpha: 0.14),
      ),
    ),
    child: Icon(
      icon,
      size: iconSize,
      color: isDark ? BrandChrome.accentSoft : BrandChrome.iconGlyph,
    ),
  );
}

/// Tappable card with the shared brand wash (matches Entry site/category cards).
class BrandInkCard extends StatelessWidget {
  const BrandInkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.margin,
    this.borderRadius = BrandRadius.card,
    this.borderWidth = 1,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double borderWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final card = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: brandCardDecoration(
            context,
            radius: borderRadius,
            borderWidth: borderWidth,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

/// List-row card: icon well + title/subtitle + trailing chevron.
class BrandListCard extends StatelessWidget {
  const BrandListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = BrandChrome.titleColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );
    final muted = BrandChrome.mutedColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );

    return BrandInkCard(
      onTap: onTap,
      enabled: enabled,
      margin: margin,
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            brandIconWell(context: context, icon: leadingIcon!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: muted),
        ],
      ),
    );
  }
}
