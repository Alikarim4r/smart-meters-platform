import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/alert_providers.dart';
import '../providers/dashboard_providers.dart';

/// Pushes critical/warning dashboard alerts to the system shade + widgets.
class DashboardNotificationBridge extends ConsumerStatefulWidget {
  const DashboardNotificationBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DashboardNotificationBridge> createState() =>
      _DashboardNotificationBridgeState();
}

class _DashboardNotificationBridgeState
    extends ConsumerState<DashboardNotificationBridge> {
  String? _startedOrgId;
  final _keys = NotificationDedupe(cooldown: const Duration(hours: 6));

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(dashboardSitesProvider);
    sitesAsync.whenData((sites) {
      if (sites.isEmpty || kIsWeb) return;
      final orgId = sites.first.site.organizationId;
      if (_startedOrgId == orgId) return;
      _startedOrgId = orgId;
      Future.microtask(() async {
        await ensureNotificationSession(
          ref,
          organizationId: orgId,
          androidWidgetNames: AppWidgetNames.dashboard,
        );
        await _syncFromAlerts();
      });
    });

    ref.listen(dashboardHomeAlertsProvider, (prev, next) {
      next.whenData((_) => _syncFromAlerts());
    });

    return widget.child;
  }

  Future<void> _syncFromAlerts() async {
    final session = ref.read(notificationSessionProvider);
    final summary = ref.read(dashboardHomeAlertsProvider).valueOrNull;
    final sites = ref.read(dashboardSitesProvider).valueOrNull;
    if (session == null || summary == null) return;

    final alerts = summary.alerts
        .where(
          (a) =>
              a.severity == AlertSeverity.critical ||
              a.severity == AlertSeverity.warning,
        )
        .toList();

    for (final alert in alerts.take(5)) {
      final type = switch (alert.type) {
        AlertType.missingReading ||
        AlertType.inactiveMeterReading ||
        AlertType.lowCompletion =>
          'data_availability',
        _ => 'data_quality_review',
      };
      final severity = switch (alert.severity) {
        AlertSeverity.critical => 'critical',
        AlertSeverity.warning => 'warning',
        AlertSeverity.info => 'info',
      };
      final key = _keys.eventKey(
        notificationType: type,
        organizationId: session.organizationId,
        siteId: alert.siteId,
        relatedEntityId: alert.meterId ?? alert.id,
        extra: alert.type.name,
      );
      await session.emit(
        NotificationDraft(
          organizationId: session.organizationId,
          siteId: alert.siteId,
          notificationType: type,
          severity: severity,
          title: alert.title,
          body: alert.message,
          eventKey: key,
          relatedEntityType: alert.meterId != null ? 'meter' : 'site',
          relatedEntityId: alert.meterId ?? alert.siteId,
        ),
      );
    }

    final top = alerts.isEmpty ? null : alerts.first;
    final site = sites?.isNotEmpty == true ? sites!.first.site : null;
    final siteName = site == null
        ? '—'
        : (site.nameAr.isNotEmpty ? site.nameAr : site.nameEn);
    await HomeWidgetSync(androidWidgetNames: AppWidgetNames.dashboard)
        .syncDashboard(
      unreadCount: summary.total,
      topTitle: top?.title ?? 'لا تنبيهات',
      topSeverity: top?.severity.name ?? 'info',
      siteName: siteName,
      siteSummary: '${summary.total} تنبيه · ${sites?.length ?? 0} مواقع',
    );
  }
}
