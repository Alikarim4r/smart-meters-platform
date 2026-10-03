import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/correction_providers.dart';

class ReadingAuditHistoryScreen extends ConsumerWidget {
  const ReadingAuditHistoryScreen({super.key, required this.readingId});

  final String readingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(readingAuditHistoryProvider(readingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(adminText(context, 'Audit history', 'سجل التدقيق')),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(adminUserError(context))),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text(
                adminText(
                  context,
                  'No audit history for this reading.',
                  'لا يوجد سجل تدقيق لهذه القراءة.',
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final who =
                  entry.changedByName ?? entry.changedByEmail ?? 'Unknown user';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.action.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        _formatTimestamp(entry.changedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('By $who', style: Theme.of(context).textTheme.bodySmall),
                  if (entry.oldValue != null || entry.newValue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Value: ${entry.oldValue ?? '—'} → ${entry.newValue ?? '—'}',
                      ),
                    ),
                  if (entry.oldNote != null || entry.newNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Note: ${entry.oldNote ?? '—'} → ${entry.newNote ?? '—'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (entry.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(entry.reason!.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
