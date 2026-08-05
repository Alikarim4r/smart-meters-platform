import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';

/// Source Health drill-in — clear empty state when no external sources exist.
class SourceHealthScreen extends ConsumerWidget {
  const SourceHealthScreen({
    super.key,
    required this.organizationId,
    required this.sources,
  });

  final String organizationId;
  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    if (sources.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            s.sourceHealthEmptyTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            s.sourceHealthEmptyBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            s.sourceHealthEmptyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sources.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = sources[index];
        final name = (row['name'] ?? row['display_name'] ?? s.sourceHealth)
            .toString();
        final kind = (row['source_type'] ?? row['kind'] ?? '').toString();
        final status = (row['health_status'] ??
                row['status'] ??
                s.sourceHealthNeverSynced)
            .toString();
        return Card(
          child: ListTile(
            leading: Icon(_statusIcon(status)),
            title: Text(name),
            subtitle: Text(
              [
                if (kind.isNotEmpty) kind,
                s.localizeSourceHealthStatus(status),
              ].join(' · '),
            ),
          ),
        );
      },
    );
  }

  IconData _statusIcon(String status) {
    final key = status.toLowerCase();
    if (key.contains('healthy') || key.contains('ok')) {
      return Icons.check_circle_outline;
    }
    if (key.contains('delay')) return Icons.schedule;
    if (key.contains('fail')) return Icons.error_outline;
    return Icons.hourglass_empty;
  }
}
