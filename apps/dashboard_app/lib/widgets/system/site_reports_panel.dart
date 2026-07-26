import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

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
    final padding = DashboardBreakpoints.contentPadding(context);
    final categoriesAsync = ref.watch(siteCategoriesSummaryProvider(siteId));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DashboardErrorState(message: '$e'),
      data: (categories) {
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            const PremiumSectionHeader(
              title: 'Reports',
              subtitle:
                  'Export site overview or utility-specific reports. Full report uses clearly separated sections.',
            ),
            _ReportTile(
              title: 'Site overview',
              subtitle: 'Operational summary PDF/Excel',
              icon: Icons.dashboard_outlined,
              onTap: () => _export(
                context,
                ref,
                type: ReportType.siteSummary,
              ),
            ),
            for (final system in UtilitySystemKey.values) ...[
              if (categorySummaryForUtility(categories, system) != null)
                _ReportTile(
                  title: '${system.label} report',
                  subtitle: 'Consumption in ${system.defaultUnit} only',
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
                    categoryId:
                        categorySummaryForUtility(categories, system)!
                            .category
                            .id,
                  ),
                ),
            ],
            _ReportTile(
              title: 'BTU / COP report',
              subtitle: 'Cooling performance',
              icon: Icons.show_chart_outlined,
              onTap: () => _export(context, ref, type: ReportType.cop),
            ),
            _ReportTile(
              title: 'Readings export',
              subtitle: 'Excel readings for selected period',
              icon: Icons.table_rows_outlined,
              onTap: () => _export(context, ref, type: ReportType.readings),
            ),
            _ReportTile(
              title: 'Full site report',
              subtitle: 'All utilities in separate sections',
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
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
