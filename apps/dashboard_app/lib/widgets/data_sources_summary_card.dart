import 'package:flutter/material.dart';

/// Compact dashboard summary for Phase 6 source health (flag-gated).
/// Mount only when `source_health` platform flag is ON.
class DataSourcesSummaryCard extends StatelessWidget {
  const DataSourcesSummaryCard({
    super.key,
    required this.healthy,
    required this.delayed,
    required this.importsPending,
    required this.availabilityAlerts,
    this.latestSync,
    this.onOpenDetails,
  });

  final int healthy;
  final int delayed;
  final int importsPending;
  final int availabilityAlerts;
  final DateTime? latestSync;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data sources', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _chip('Healthy', healthy, Colors.green),
                  _chip('Delayed', delayed, Colors.orange),
                  _chip('Imports pending', importsPending, Colors.blueGrey),
                  _chip(
                    'Availability alerts',
                    availabilityAlerts,
                    Colors.redAccent,
                  ),
                ],
              ),
              if (latestSync != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Latest sync: ${latestSync!.toLocal()}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Details in drill-down. Data Availability ≠ Equipment Fault.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}
