import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'report_export_controller.dart';
import 'report_models.dart';
import '../providers/chart_providers.dart';
import '../utils/site_system_navigation.dart';

ReportType reportTypeForSiteTab(int tabIndex) {
  return switch (tabIndex) {
    2 => ReportType.categoryConsumption,
    4 => ReportType.readings,
    5 => ReportType.readings,
    6 => ReportType.cop,
    _ => ReportType.siteSummary,
  };
}

ReportType reportTypeForSiteSection(SiteDashboardSection section) {
  return switch (section) {
    SiteDashboardSection.btuCooling => ReportType.cop,
    SiteDashboardSection.water ||
    SiteDashboardSection.electricity ||
    SiteDashboardSection.fuel =>
      ReportType.categoryConsumption,
    SiteDashboardSection.reports => ReportType.consumption,
    _ => ReportType.siteSummary,
  };
}

class ReportExportIconButton extends ConsumerWidget {
  const ReportExportIconButton({
    super.key,
    required this.defaultType,
    this.siteId,
    this.categoryId,
    this.defaultPeriod,
  });

  final ReportType defaultType;
  final String? siteId;
  final String? categoryId;
  final ChartPeriod? defaultPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateSelection =
        siteId != null ? ref.watch(siteDateSelectionProvider(siteId!)) : null;

    return IconButton(
      tooltip: 'Export report',
      icon: const Icon(Icons.download_outlined),
      onPressed: () => ReportExportController(ref).showExportDialog(
        context: context,
        defaultType: defaultType,
        siteId: siteId,
        categoryId: categoryId,
        defaultPeriod: defaultPeriod,
        defaultDateSelection: dateSelection,
      ),
    );
  }
}
