import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'opportunity_detail_screen.dart';

final _siteActionsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  final module = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
  if (!module) return false;
  final opportunities = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.opportunities,
    siteId: siteId,
  );
  if (!opportunities) return false;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.actions,
    siteId: siteId,
  );
});

final _siteActionsProvider =
    FutureProvider.autoDispose.family<List<ConservationAction>, String>((
  ref,
  siteId,
) {
  return ActionRepository(ref.read(supabaseClientProvider)).listForSite(
    siteId,
    limit: 100,
  );
});

enum _ActionFilter { open, overdue, completed }

/// Open / overdue / completed actions for a site.
class ActionsAdminScreen extends ConsumerStatefulWidget {
  const ActionsAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  ConsumerState<ActionsAdminScreen> createState() => _ActionsAdminScreenState();
}

class _ActionsAdminScreenState extends ConsumerState<ActionsAdminScreen> {
  _ActionFilter _filter = _ActionFilter.open;

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteActionsEnabledProvider(widget.siteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'إجراءات الترشيد' : 'Conservation actions'),
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_siteActionsEnabledProvider(widget.siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'الإجراءات غير مفعّلة' : 'Actions disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و opportunities و actions.'
                  : 'Enable conservation_module, opportunities, and actions.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(_siteActionsProvider(widget.siteId));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(_siteActionsProvider(widget.siteId)),
            ),
            data: (all) {
              final today = DateTime.now();
              final todayOnly =
                  DateTime(today.year, today.month, today.day);
              final filtered = all.where((a) {
                switch (_filter) {
                  case _ActionFilter.open:
                    return a.status != ActionStatus.completed &&
                        a.status != ActionStatus.cancelled;
                  case _ActionFilter.overdue:
                    return a.dueDate != null &&
                        a.dueDate!.isBefore(todayOnly) &&
                        a.status != ActionStatus.completed &&
                        a.status != ActionStatus.cancelled;
                  case _ActionFilter.completed:
                    return a.status == ActionStatus.completed;
                }
              }).toList();

              return Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        for (final f in _ActionFilter.values) ...[
                          FilterChip(
                            label: Text(_label(f, s)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? CatalogEmptyState(
                            title: s.isAr ? 'لا إجراءات' : 'No actions',
                            message: s.isAr
                                ? 'أنشئ إجراءات من تفاصيل الفرصة.'
                                : 'Create actions from opportunity detail.',
                            icon: Icons.task_alt_outlined,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final a = filtered[index];
                              final overdue = a.dueDate != null &&
                                  a.dueDate!.isBefore(todayOnly) &&
                                  a.status != ActionStatus.completed;
                              return Card(
                                child: ListTile(
                                  title: Text(a.title),
                                  subtitle: Text(
                                    '${a.status.dbValue} · ${a.actionType.dbValue} · '
                                    '${a.priority.dbValue}'
                                    '${a.dueDate == null ? '' : '\nDue ${_iso(a.dueDate!)}'}'
                                    '${overdue ? '\nOverdue' : ''}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => OpportunityDetailScreen(
                                          opportunityId: a.opportunityId,
                                          siteId: widget.siteId,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(
                                      _siteActionsProvider(widget.siteId),
                                    );
                                  },
                                ),
                              );
                            },
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

  String _label(_ActionFilter f, AdminStrings s) => switch (f) {
        _ActionFilter.open => s.isAr ? 'مفتوحة' : 'Open',
        _ActionFilter.overdue => s.isAr ? 'متأخرة' : 'Overdue',
        _ActionFilter.completed => s.isAr ? 'مكتملة' : 'Completed',
      };

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
