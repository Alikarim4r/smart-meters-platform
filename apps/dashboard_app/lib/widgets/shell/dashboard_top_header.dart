import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../reports/report_export_button.dart';
import '../../reports/report_models.dart';
import '../../theme/dashboard_spacing.dart';
import '../../theme/dashboard_theme.dart';
import '../../theme/glass_surface.dart';
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

    return GlassSurface(
      borderRadius: 0,
      useBlur: false,
      tintOpacity: 0.94,
      padding: EdgeInsets.fromLTRB(
        padding,
        DashboardSpacing.lg,
        padding,
        DashboardSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: s.backToSites,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ],
          Expanded(
            child: Text(
              site != null
                  ? s.localizedName(en: site!.nameEn, ar: site!.nameAr)
                  : (title ?? s.appTitle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
            ),
          ),
          if (dateSelection != null && onDateSelectionChanged != null)
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: DashboardDateQuickBar(
                    selection: dateSelection!,
                    onChanged: onDateSelectionChanged!,
                    siteId: siteId,
                    compact: true,
                  ),
                ),
              ),
            ),
          if (siteId != null) ...[
            const SizedBox(width: DashboardSpacing.xs),
            DashboardAlertBellButton(
              siteId: siteId!,
              onViewAll: onViewAlerts,
            ),
          ] else ...[
            const SizedBox(width: DashboardSpacing.xs),
            DashboardHomeAlertBellButton(onViewAll: onViewAlerts),
          ],
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
      ),
    );
  }
}
