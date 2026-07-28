import 'package:flutter/material.dart';

import '../theme/brand_chrome.dart';

/// Shared asset paths for the METERS wordmark icons (package: smart_meters_core).
abstract final class BrandMarkAssets {
  static const dashboard = 'assets/branding/mark_dashboard.png';
  static const entry = 'assets/branding/mark_entry.png';
  static const admin = 'assets/branding/mark_admin.png';
}

/// Rounded METERS launcher mark used in login and chrome.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.assetPath = BrandMarkAssets.dashboard,
    this.size = 56,
  });

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        assetPath,
        package: 'smart_meters_core',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Backward-compatible alias — now shows the METERS mark (not the old LCD meter).
class DemoBrandMark extends StatelessWidget {
  const DemoBrandMark({
    super.key,
    this.size = 48,
    this.assetPath = BrandMarkAssets.dashboard,
  });

  final double size;
  final String assetPath;

  @override
  Widget build(BuildContext context) =>
      AppBrandMark(assetPath: assetPath, size: size);
}

/// Elevated login panel used by all three apps.
class AppLoginPanel extends StatelessWidget {
  const AppLoginPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.brandMark,
    this.locale,
    this.onLocaleChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? brandMark;
  final Widget child;
  final Locale? locale;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = BrandChrome.titleColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );
    final mutedColor = BrandChrome.mutedColor(
      isDark: isDark,
      scheme: theme.colorScheme,
    );
    final currentLocale = locale ?? Localizations.localeOf(context);
    final isAr = currentLocale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? null : Colors.white,
                  gradient: isDark ? BrandChrome.cardWash(isDark: true) : null,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? BrandChrome.border(
                            isDark: true,
                            scheme: theme.colorScheme,
                          )
                        : BrandChrome.accent.withValues(alpha: 0.28),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BrandChrome.primary.withValues(
                        alpha: isDark ? 0.35 : 0.12,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onLocaleChanged != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _LoginLocaleToggle(
                            isArabic: isAr,
                            onChanged: onLocaleChanged!,
                          ),
                        ),
                      if (onLocaleChanged != null) const SizedBox(height: 8),
                      Center(
                        child:
                            brandMark ??
                            const AppBrandMark(
                              assetPath: BrandMarkAssets.dashboard,
                              size: 72,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 22),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible alias.
typedef DemoLoginPanel = AppLoginPanel;

/// Section title for dashboard chrome.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null)
          Text(subtitle!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Backward-compatible alias.
typedef DemoSectionHeader = AppSectionHeader;


class _LoginLocaleToggle extends StatelessWidget {
  const _LoginLocaleToggle({
    required this.isArabic,
    required this.onChanged,
  });

  final bool isArabic;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangChip(
            label: 'E',
            selected: !isArabic,
            onTap: () => onChanged(const Locale('en')),
          ),
          _LangChip(
            label: 'ع',
            selected: isArabic,
            onTap: () => onChanged(const Locale('ar')),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
