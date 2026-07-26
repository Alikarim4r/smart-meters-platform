import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';

import '../theme/glass_surface.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      borderRadius: 16,
      useBlur: false,
      child: child,
    );
  }
}

class DashboardSummaryTile extends StatelessWidget {
  const DashboardSummaryTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: accent),
          if (icon != null) const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardStatusBadge extends StatelessWidget {
  const DashboardStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardErrorState extends StatelessWidget {
  const DashboardErrorState({
    super.key,
    this.title = 'Could not load data',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إعادة المحاولة'
                      : 'Retry',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardSiteListTile extends StatelessWidget {
  const DashboardSiteListTile({
    super.key,
    required this.overview,
    required this.onTap,
  });

  final DashboardSiteOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final site = overview.site;
    final theme = Theme.of(context);

    return DashboardCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.localizedName(en: site.nameEn, ar: site.nameAr),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DashboardStatusBadge(
                    label: site.isActive ? s.active : s.inactive,
                    color: site.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${s.zoneDisplayName(site.displayZoneName)} · ${s.siteTypeLabel(site.siteType)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              if (site.location != null && site.location!.isNotEmpty)
                Text(
                  site.location!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ChipLabel(
                    icon: Icons.speed,
                    label: s.metersCount(overview.meterCount),
                  ),
                  _ChipLabel(
                    icon: Icons.category_outlined,
                    label: s.categoriesCount(overview.categories.length),
                  ),
                  _ChipLabel(
                    icon: Icons.today_outlined,
                    label: s.todayProgress(
                      overview.readingsSubmittedToday,
                      overview.entryEligibleMeterCount,
                    ),
                  ),
                  if (overview.lastReadingDate != null)
                      _ChipLabel(
                        icon: Icons.history,
                        label: s.isAr
                            ? 'آخر قراءة: ${formatBusinessDate(overview.lastReadingDate!)}'
                            : 'Last: ${formatBusinessDate(overview.lastReadingDate!)}',
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}

class DashboardReadingThumbnail extends StatelessWidget {
  const DashboardReadingThumbnail({
    super.key,
    this.imageUrl,
    this.onTap,
    this.size = 56,
  });

  final String? imageUrl;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image_outlined, size: size * 0.36),
          ),
        ),
      ),
    );
  }
}
