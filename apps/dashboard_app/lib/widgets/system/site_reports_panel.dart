import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/conservation_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../reports/report_export_controller.dart';
import '../../reports/report_models.dart';
import '../../utils/dashboard_breakpoints.dart';
import '../../utils/site_system_navigation.dart';
import '../dashboard_widgets.dart';
import '../premium/premium_section_header.dart';

/// Per-utility and full-site report export entry points.
class SiteReportsPanel extends ConsumerWidget {
  const SiteReportsPanel({
    super.key,
    required this.siteId,
    required this.useDesktop,
  });

  final String siteId;
  final bool useDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final padding = DashboardBreakpoints.contentPadding(context);
    final categoriesAsync = ref.watch(siteCategoriesSummaryProvider(siteId));
    final conservationReportsOn =
        ref.watch(conservationReportsEnabledProvider(siteId)).valueOrNull ??
        false;

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          DashboardErrorState(message: AppStrings.of(context).genericError),
      data: (categories) {
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            PremiumSectionHeader(
              title: s.reportsPanelTitle,
              subtitle: s.reportsPanelSubtitle,
            ),
            _ReportTile(
              title: s.reportSiteOverview,
              subtitle: s.reportSiteOverviewSubtitle,
              icon: Icons.dashboard_outlined,
              onTap: () => _export(context, ref, type: ReportType.siteSummary),
            ),
            for (final system in UtilitySystemKey.values) ...[
              if (categorySummaryForUtility(categories, system) != null)
                _ReportTile(
                  title: s.reportUtilityTitle(system),
                  subtitle: s.reportUtilitySubtitle(system),
                  icon: system == UtilitySystemKey.water
                      ? Icons.water_drop_outlined
                      : system == UtilitySystemKey.electricity
                      ? Icons.bolt_outlined
                      : system == UtilitySystemKey.btu
                      ? Icons.ac_unit_outlined
                      : Icons.local_gas_station_outlined,
                  onTap: () => _export(
                    context,
                    ref,
                    type: ReportType.categoryConsumption,
                    categoryId: categorySummaryForUtility(
                      categories,
                      system,
                    )!.category.id,
                  ),
                ),
            ],
            _ReportTile(
              title: s.reportBtuCop,
              subtitle: s.reportBtuCopSubtitle,
              icon: Icons.show_chart_outlined,
              onTap: () => _export(context, ref, type: ReportType.cop),
            ),
            if (conservationReportsOn)
              _ReportTile(
                title: s.reportConservation,
                subtitle: s.reportConservationSubtitle,
                icon: Icons.eco_outlined,
                onTap: () =>
                    _export(context, ref, type: ReportType.conservation),
              ),
            _ReportTile(
              title: s.reportReadingsExport,
              subtitle: s.reportReadingsExportSubtitle,
              icon: Icons.table_rows_outlined,
              onTap: () => _export(context, ref, type: ReportType.readings),
            ),
            _ReportTile(
              title: s.reportFullSite,
              subtitle: s.reportFullSiteSubtitle,
              icon: Icons.folder_open_outlined,
              onTap: () => _export(context, ref, type: ReportType.consumption),
            ),
          ],
        );
      },
    );
  }

  void _export(
    BuildContext context,
    WidgetRef ref, {
    required ReportType type,
    String? categoryId,
  }) {
    ReportExportController(ref).showExportDialog(
      context: context,
      defaultType: type,
      siteId: siteId,
      categoryId: categoryId,
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        child: ListTile(
          leading: Icon(icon, color: AppColors.navy),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
