import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../reports/report_export_button.dart';
import '../../reports/report_models.dart';
import '../../theme/dashboard_spacing.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_breakpoints.dart';
import '../../utils/dashboard_date_range.dart';
import '../shell/dashboard_alert_bell.dart';
import '../premium/dashboard_date_quick_bar.dart';

class DashboardTopHeader extends ConsumerWidget {
  const DashboardTopHeader({
    super.key,
    this.site,
    this.siteId,
    this.onRefresh,
    this.onBack,
    this.exportType = ReportType.allSitesSummary,
    this.exportCategoryId,
    this.dateSelection,
    this.onDateSelectionChanged,
    this.title,
    this.subtitle,
    this.onViewAlerts,
  });

  final Site? site;
  final String? siteId;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onViewAlerts;
  final ReportType exportType;
  final String? exportCategoryId;
  final DashboardDateSelection? dateSelection;
  final ValueChanged<DashboardDateSelection>? onDateSelectionChanged;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = DashboardBreakpoints.contentPadding(context);
    final colors = dashboardColors(context);
    final s = AppStrings(ref.watch(localeProvider));

    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          site != null
              ? s.localizedName(en: site!.nameEn, ar: site!.nameAr)
              : (title ?? s.appTitle),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: colors.textPrimary),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: DashboardSpacing.xxs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (siteId != null)
          DashboardAlertBellButton(siteId: siteId!, onViewAll: onViewAlerts)
        else
          DashboardHomeAlertBellButton(onViewAll: onViewAlerts),
        ReportExportIconButton(
          defaultType: exportType,
          siteId: siteId,
          categoryId: exportCategoryId,
        ),
        IconButton(
          tooltip: s.refresh,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );

    final dateBar = dateSelection != null && onDateSelectionChanged != null
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DashboardDateQuickBar(
              selection: dateSelection!,
              onChanged: onDateSelectionChanged!,
              siteId: siteId,
              compact: true,
            ),
          )
        : null;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            padding,
            DashboardSpacing.md,
            padding,
            DashboardSpacing.sm,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onBack != null)
                        IconButton(
                          tooltip: s.backToSites,
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Expanded(child: heading),
                      if (!compact && dateBar != null) ...[
                        const SizedBox(width: DashboardSpacing.md),
                        Flexible(child: dateBar),
                      ],
                      const SizedBox(width: DashboardSpacing.xs),
                      actions,
                    ],
                  ),
                  if (compact && dateBar != null) ...[
                    const SizedBox(height: DashboardSpacing.xs),
                    dateBar,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
