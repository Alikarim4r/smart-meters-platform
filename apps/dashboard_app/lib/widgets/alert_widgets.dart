import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../providers/alert_providers.dart';
import '../theme/dashboard_theme.dart';
import 'dashboard_widgets.dart';

/// Compact severity counts for overview and quick panel.
class CompactAlertSummaryRow extends StatelessWidget {
  const CompactAlertSummaryRow({
    super.key,
    required this.summary,
    this.onViewAll,
  });

  final AlertSummary summary;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _CountChip(
                  label: s.critical,
                  count: summary.critical,
                  color: Theme.of(context).colorScheme.error,
                ),
                _CountChip(
                  label: s.warning,
                  count: summary.warning,
                  color: Colors.orange.shade800,
                ),
                _CountChip(
                  label: s.info,
                  count: summary.info,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text(s.viewAll),
            ),
        ],
      ),
    );
  }
}

class CompactAlertListTile extends StatelessWidget {
  const CompactAlertListTile({
    super.key,
    required this.alert,
    this.onTap,
  });

  final DashboardAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final s = AppStrings.of(context);
    final severityColor = alertSeverityColor(context, alert.severity);
    return Material(
      color: colors.cardElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.alertTitle(alert),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.alertMessage(alert),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                        height: 1.25,
                      ),
                    ),
                    if (alert.meterCode != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${alert.meterCode}${alert.meterName != null ? ' · ${alert.meterName}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlertSummaryCard extends StatelessWidget {
  const AlertSummaryCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final AlertSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Active alerts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.total}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(
                    label: 'Critical',
                    count: summary.critical,
                    color: theme.colorScheme.error,
                  ),
                  _CountChip(
                    label: 'Warning',
                    count: summary.warning,
                    color: Colors.orange.shade800,
                  ),
                  _CountChip(
                    label: 'Info',
                    count: summary.info,
                    color: theme.colorScheme.primary,
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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashboardStatusBadge(
      label: '$label: $count',
      color: color,
    );
  }
}

class AlertListTile extends StatelessWidget {
  const AlertListTile({
    super.key,
    required this.alert,
    this.onTap,
  });

  final DashboardAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = alertSeverityColor(context, alert.severity);
    final s = AppStrings.of(context);
    final severityLabel = switch (alert.severity) {
      AlertSeverity.critical => s.critical,
      AlertSeverity.warning => s.warning,
      AlertSeverity.info => s.info,
    };
    return DashboardCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DashboardStatusBadge(
                    label: severityLabel,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.alertTitle(alert),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(s.alertMessage(alert)),
              if (alert.meterName != null)
                Text('${alert.meterName} (${alert.meterCode ?? ''})'),
              if (alert.categoryName != null)
                Text(
                  s.isAr
                      ? 'الفئة: ${alert.categoryName}'
                      : 'Category: ${alert.categoryName}',
                ),
              if (alert.readingDate != null)
                Text(
                  s.isAr
                      ? 'التاريخ: ${formatBusinessDate(alert.readingDate!)}'
                      : 'Date: ${formatBusinessDate(alert.readingDate!)}',
                ),
              if (alert.suggestedAction != null) ...[
                const SizedBox(height: 6),
                Text(
                  s.isAr
                      ? 'الإجراء: ${alert.suggestedAction}'
                      : 'Action: ${alert.suggestedAction}',
                  style: TextStyle(
                    fontSize: 12,
                    color: dashboardColors(context).textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CriticalAlertsBanner extends StatelessWidget {
  const CriticalAlertsBanner({
    super.key,
    required this.alerts,
    this.onViewAll,
  });

  final List<DashboardAlert> alerts;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final critical = alerts
        .where((a) => a.severity == AlertSeverity.critical)
        .take(3)
        .toList();
    if (critical.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                s.isAr ? 'تنبيهات حرجة' : 'Critical alerts',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.error,
                ),
              ),
              const Spacer(),
              if (onViewAll != null)
                TextButton(onPressed: onViewAll, child: Text(s.viewAll)),
            ],
          ),
          const SizedBox(height: 8),
          for (final alert in critical)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${s.alertTitle(alert)}: ${s.alertMessage(alert)}',
              ),
            ),
        ],
      ),
    );
  }
}
