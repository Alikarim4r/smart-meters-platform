import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../providers/alert_providers.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_breakpoints.dart';
import '../../providers/dashboard_providers.dart';
import '../../utils/site_system_navigation.dart';
import '../alert_widgets.dart';
import '../dashboard_widgets.dart';

class SiteAlertsPanel extends ConsumerWidget {
  const SiteAlertsPanel({
    super.key,
    required this.siteId,
    this.useDesktop = false,
  });

  final String siteId;
  final bool useDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(siteAlertsProvider(siteId));
    final severityFilter = ref.watch(homeAlertSeverityFilterProvider);
    final search = ref.watch(siteAlertSearchProvider(siteId));
    final utilityFilter = ref.watch(siteAlertUtilityFilterProvider(siteId));
    final colors = dashboardColors(context);

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DashboardErrorState(message: '$error'),
      data: (summary) {
        final filtered = filterAlertsForPanel(
          alerts: summary.alerts,
          severity: severityFilter,
          utility: utilityFilter,
          search: search,
        );

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(siteAlertsProvider(siteId)),
          child: ListView(
            padding:
                EdgeInsets.all(DashboardBreakpoints.contentPadding(context)),
            children: [
              CompactAlertSummaryRow(summary: summary),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search alerts',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (value) => ref
                    .read(siteAlertSearchProvider(siteId).notifier)
                    .state = value,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AlertSeverity?>(
                      initialValue: severityFilter,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All severities'),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.critical,
                          child: Text('Critical'),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.warning,
                          child: Text('Warning'),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.info,
                          child: Text('Info'),
                        ),
                      ],
                      onChanged: (value) => ref
                          .read(homeAlertSeverityFilterProvider.notifier)
                          .state = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<UtilitySystemKey?>(
                      initialValue: utilityFilter,
                      decoration: const InputDecoration(
                        labelText: 'Utility',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All utilities'),
                        ),
                        for (final system in UtilitySystemKey.values)
                          DropdownMenuItem(
                            value: system,
                            child: Text(system.label),
                          ),
                      ],
                      onChanged: (value) => ref
                          .read(siteAlertUtilityFilterProvider(siteId).notifier)
                          .state = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                DashboardEmptyState(
                  title: 'No alerts match your filters',
                  subtitle: summary.hasAlerts
                      ? 'Try changing severity, utility, or search.'
                      : 'Alerts are computed from current readings and consumption.',
                )
              else
                for (final alert in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CompactAlertListTile(
                      alert: alert,
                      onTap: () {
                        final target =
                            sectionForAlertCategory(alert.categoryName);
                        if (target != null) {
                          ref
                              .read(siteDashboardSectionProvider.notifier)
                              .state = target;
                        }
                      },
                    ),
                  ),
              if (filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${filtered.length} alert${filtered.length == 1 ? '' : 's'} shown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
