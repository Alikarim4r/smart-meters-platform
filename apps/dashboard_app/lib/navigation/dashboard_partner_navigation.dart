import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/chart_providers.dart';
import '../providers/dashboard_providers.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/site_system_navigation.dart';
import '../widgets/shell/dashboard_sidebar.dart';

final pendingDashboardPartnerLinkProvider =
    StateProvider<PartnerLinkIntent?>((ref) => null);

void applyDashboardPartnerLink(WidgetRef ref, PartnerLinkIntent intent) {
  if (intent.kind != PartnerLinkKind.dashboardSite) return;

  ref.read(selectedSiteIdProvider.notifier).state = intent.siteId;
  ref.read(dashboardShellSectionProvider.notifier).state =
      DashboardShellSection.sites;

  final section = siteDashboardSectionFromPartnerCode(intent.section);
  if (section != null) {
    ref.read(siteDashboardSectionProvider.notifier).state = section;
  }

  if (intent.readingDate != null && intent.readingDate!.isNotEmpty) {
    final parsed = DateTime.tryParse(intent.readingDate!);
    if (parsed != null) {
      ref.read(siteDateSelectionProvider(intent.siteId).notifier).state =
          DashboardDateSelection.singleDay(
            day: normalizeDashboardDate(parsed),
          );
    }
  }
}

SiteDashboardSection? siteDashboardSectionFromPartnerCode(String? code) {
  if (code == null || code.isEmpty) return null;
  return switch (code.toLowerCase()) {
    'overview' => SiteDashboardSection.overview,
    'water' => SiteDashboardSection.water,
    'electricity' => SiteDashboardSection.electricity,
    'btu' || 'cooling' || 'btucooling' => SiteDashboardSection.btuCooling,
    'fuel' || 'diesel' => SiteDashboardSection.fuel,
    'alerts' => SiteDashboardSection.alerts,
    'reports' => SiteDashboardSection.reports,
    _ => null,
  };
}

String? partnerCategoryCodeForSection(SiteDashboardSection section) {
  return section.utilityKey?.categoryCode;
}

void openSiteFromHomeAlert(WidgetRef ref, DashboardAlert alert) {
  final siteId = alert.siteId;
  if (siteId.isEmpty) return;

  ref.read(selectedSiteIdProvider.notifier).state = siteId;
  ref.read(dashboardShellSectionProvider.notifier).state =
      DashboardShellSection.sites;

  final utilitySection = sectionForAlertCategory(alert.categoryName);
  ref.read(siteDashboardSectionProvider.notifier).state =
      utilitySection ?? SiteDashboardSection.alerts;
}
