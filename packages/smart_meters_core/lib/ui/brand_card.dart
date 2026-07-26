import 'package:flutter/material.dart';

import '../theme/brand_chrome.dart';

/// Entry-matching card shell: cream→gold wash, thin border, soft gold shadow.
BoxDecoration brandCardDecoration(
  BuildContext context, {
  double radius = 16,
  double borderWidth = 1.2,
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
    boxShadow: [
      BoxShadow(
        color: BrandChrome.accent.withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

/// Cream→gold icon well used on Entry selection cards.
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
      borderRadius: BorderRadius.circular(12),
      gradient: BrandChrome.iconWellGradient,
      border: Border.all(color: BrandChrome.accent.withValues(alpha: 0.35)),
    ),
    child: Icon(
      icon,
      size: iconSize,
      color: isDark ? BrandChrome.onAccent : BrandChrome.iconGlyph,
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
    this.borderRadius = 16,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
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
          decoration: brandCardDecoration(context, radius: borderRadius),
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
                    fontWeight: FontWeight.w800,
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
          trailing ??
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: muted),
        ],
      ),
    );
  }
}
