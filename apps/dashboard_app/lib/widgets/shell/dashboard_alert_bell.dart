import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../navigation/dashboard_partner_navigation.dart';
import '../../providers/alert_providers.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_breakpoints.dart';
import '../../providers/dashboard_providers.dart';
import '../../utils/site_system_navigation.dart';
import '../alert_widgets.dart';

/// Header bell for all accessible sites (home dashboard).
class DashboardHomeAlertBellButton extends ConsumerWidget {
  const DashboardHomeAlertBellButton({
    super.key,
    this.onViewAll,
  });

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(dashboardHomeAlertCountProvider);

    return IconButton(
      tooltip: 'Alerts',
      onPressed: () => showHomeAlertQuickPanel(
        context: context,
        ref: ref,
        onViewAll: onViewAll,
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(
          Icons.notifications_outlined,
          color: dashboardColors(context).textPrimary,
        ),
      ),
    );
  }
}

/// Header bell button with badge — opens compact alert panel.
class DashboardAlertBellButton extends ConsumerWidget {
  const DashboardAlertBellButton({
    super.key,
    required this.siteId,
    this.onViewAll,
  });

  final String siteId;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(siteAlertCountProvider(siteId));

    return IconButton(
      tooltip: 'Alerts',
      onPressed: () => showAlertQuickPanel(
        context: context,
        ref: ref,
        siteId: siteId,
        onViewAll: onViewAll,
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(
          Icons.notifications_outlined,
          color: dashboardColors(context).textPrimary,
        ),
      ),
    );
  }
}

Future<void> showAlertQuickPanel({
  required BuildContext context,
  required WidgetRef ref,
  required String siteId,
  VoidCallback? onViewAll,
}) async {
  ref.read(siteAlertsProvider(siteId));

  final isDesktop = DashboardBreakpoints.isDesktop(context);
  if (isDesktop) {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss alerts',
      pageBuilder: (dialogContext, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              height: MediaQuery.sizeOf(dialogContext).height,
              margin: const EdgeInsets.all(0),
              child: AlertQuickPanel(
                siteId: siteId,
                onViewAll: () {
                  Navigator.of(dialogContext).pop();
                  onViewAll?.call();
                },
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => AlertQuickPanel(
          siteId: siteId,
          scrollController: scrollController,
          onViewAll: () {
            Navigator.of(sheetContext).pop();
            onViewAll?.call();
          },
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}

Future<void> showHomeAlertQuickPanel({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onViewAll,
}) async {
  ref.read(dashboardHomeAlertsProvider);

  final isDesktop = DashboardBreakpoints.isDesktop(context);
  if (isDesktop) {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss alerts',
      pageBuilder: (dialogContext, _, _) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 400,
              height: MediaQuery.sizeOf(dialogContext).height,
              child: HomeAlertQuickPanel(
                onViewAll: () {
                  Navigator.of(dialogContext).pop();
                  onViewAll?.call();
                },
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => HomeAlertQuickPanel(
          scrollController: scrollController,
          onViewAll: () {
            Navigator.of(sheetContext).pop();
            onViewAll?.call();
          },
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}

class HomeAlertQuickPanel extends ConsumerWidget {
  const HomeAlertQuickPanel({
    super.key,
    this.onViewAll,
    this.onClose,
    this.scrollController,
  });

  final VoidCallback? onViewAll;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = dashboardColors(context);
    final alertsAsync = ref.watch(dashboardHomeAlertsProvider);
    final severityFilter = ref.watch(homeAlertSeverityFilterProvider);

    return Material(
      color: colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                ),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Center(
                child: Text(
                  'Could not load alerts',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
              data: (summary) {
                if (!summary.hasAlerts) {
                  return Center(
                    child: Text(
                      'No active alerts',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  );
                }

                final filtered = filterAlertsBySeverity(
                  summary.alerts,
                  severityFilter,
                );
                final topAlerts = filtered.take(8).toList();

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    CompactAlertSummaryRow(summary: summary),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AlertSeverity?>(
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
                          child: Text('Critical only'),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.warning,
                          child: Text('Warning only'),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.info,
                          child: Text('Info only'),
                        ),
                      ],
                      onChanged: (value) => ref
                          .read(homeAlertSeverityFilterProvider.notifier)
                          .state = value,
                    ),
                    const SizedBox(height: 12),
                    for (final alert in topAlerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CompactAlertListTile(
                          alert: alert,
                          onTap: () {
                            onClose?.call();
                            openSiteFromHomeAlert(ref, alert);
                          },
                        ),
                      ),
                    if (filtered.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${filtered.length - 8} more alerts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textMuted,
                              ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (onViewAll != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: onViewAll,
                child: const Text('View all alerts'),
              ),
            ),
        ],
      ),
    );
  }
}

class AlertQuickPanel extends ConsumerWidget {
  const AlertQuickPanel({
    super.key,
    required this.siteId,
    this.onViewAll,
    this.onClose,
    this.scrollController,
  });

  final String siteId;
  final VoidCallback? onViewAll;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = dashboardColors(context);
    final alertsAsync = ref.watch(siteAlertsProvider(siteId));

    return Material(
      color: colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                ),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Center(
                child: Text(
                  'Could not load alerts',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
              data: (summary) {
                if (!summary.hasAlerts) {
                  return Center(
                    child: Text(
                      'No active alerts',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  );
                }

                final topAlerts = summary.alerts.take(5).toList();
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    CompactAlertSummaryRow(summary: summary),
                    const SizedBox(height: 12),
                    for (final alert in topAlerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CompactAlertListTile(
                          alert: alert,
                          onTap: () {
                            onClose?.call();
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
                    if (summary.total > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${summary.total - 5} more alerts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textMuted,
                              ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (onViewAll != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: onViewAll,
                child: const Text('View all alerts'),
              ),
            ),
        ],
      ),
    );
  }
}
