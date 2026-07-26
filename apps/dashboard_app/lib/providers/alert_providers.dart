import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/site_system_navigation.dart';
import 'dashboard_providers.dart';

/// Updated when home alerts finish loading (Alerts tab / bell panel).
final homeAlertsBadgeCountProvider = StateProvider<int>((ref) => 0);

/// Home dashboard alert summary (all accessible sites).
final dashboardHomeAlertsProvider = FutureProvider<AlertSummary>((ref) async {
  final summary =
      await ref.read(alertRepositoryProvider).getAlertSummaryForDashboardHome(
            businessDate: ref.watch(businessDateProvider),
          );
  ref.read(homeAlertsBadgeCountProvider.notifier).state = summary.total;
  return summary;
});

/// Site alert summary — cached for the session (not auto-disposed).
final siteAlertsProvider = FutureProvider.family<AlertSummary, String>(
  (ref, siteId) async {
    final summary = await ref.read(alertRepositoryProvider).getAlertSummaryForSite(
          siteId: siteId,
          businessDate: ref.watch(businessDateProvider),
        );
    ref.read(siteAlertBadgeCountProvider(siteId).notifier).state = summary.total;
    return summary;
  },
);

/// Badge only — does **not** start [siteAlertsProvider] (avoids site open timeout).
final siteAlertBadgeCountProvider =
    StateProvider.family<int, String>((ref, siteId) => 0);

/// Lightweight site alert count for badges.
final siteAlertCountProvider = Provider.family<int, String>((ref, siteId) {
  return ref.watch(siteAlertBadgeCountProvider(siteId));
});

/// Badge count — does **not** start the home alerts fetch (avoids Sites timeout).
final dashboardHomeAlertCountProvider = Provider<int>((ref) {
  return ref.watch(homeAlertsBadgeCountProvider);
});

final homeAlertSeverityFilterProvider =
    StateProvider<AlertSeverity?>((ref) => null);

final siteAlertSearchProvider =
    StateProvider.autoDispose.family<String, String>((ref, siteId) => '');

final siteAlertUtilityFilterProvider =
    StateProvider.autoDispose.family<UtilitySystemKey?, String>(
  (ref, siteId) => null,
);

Color alertSeverityColor(BuildContext context, AlertSeverity severity) {
  final theme = Theme.of(context);
  return switch (severity) {
    AlertSeverity.critical => theme.colorScheme.error,
    AlertSeverity.warning => Colors.orange.shade800,
    AlertSeverity.info => theme.colorScheme.primary,
  };
}

List<DashboardAlert> filterAlertsBySeverity(
  List<DashboardAlert> alerts,
  AlertSeverity? severity,
) {
  if (severity == null) return alerts;
  return alerts.where((alert) => alert.severity == severity).toList();
}

List<DashboardAlert> filterAlertsForPanel({
  required List<DashboardAlert> alerts,
  AlertSeverity? severity,
  UtilitySystemKey? utility,
  String search = '',
}) {
  var result = filterAlertsBySeverity(alerts, severity);
  if (utility != null) {
    result = result.where((a) => alertMatchesUtility(a, utility)).toList();
  }
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return result;
  return result
      .where(
        (a) =>
            a.title.toLowerCase().contains(q) ||
            a.message.toLowerCase().contains(q) ||
            (a.meterCode?.toLowerCase().contains(q) ?? false) ||
            (a.meterName?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}
