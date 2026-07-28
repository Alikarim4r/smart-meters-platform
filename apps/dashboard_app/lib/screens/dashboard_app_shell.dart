import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../providers/alert_providers.dart';
import '../navigation/dashboard_partner_navigation.dart';
import '../providers/chart_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/locale_provider.dart';
import '../reports/report_export_button.dart';
import '../reports/report_models.dart';
import '../theme/dashboard_theme.dart';
import '../utils/dashboard_breakpoints.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/site_system_navigation.dart';
import '../widgets/premium/dashboard_background.dart';
import '../providers/shell_providers.dart';
import '../widgets/shell/dashboard_alert_bell.dart';
import '../widgets/shell/dashboard_keyboard_shortcuts.dart';
import '../widgets/shell/dashboard_sidebar.dart';
import '../widgets/shell/dashboard_top_header.dart';
import 'dashboard_home_screen.dart';
import 'site_dashboard_screen.dart';

class DashboardAppShell extends ConsumerWidget {
  const DashboardAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DashboardBreakpoints.useSidebar(context)) {
      return PartnerLinkListener(
        expectedScheme: PartnerAppLinks.dashboardScheme,
        onLink: (intent) => applyDashboardPartnerLink(ref, intent),
        child: const _MobileDashboardShell(),
      );
    }

    final selectedSiteId = ref.watch(selectedSiteIdProvider);
    final section = ref.watch(dashboardShellSectionProvider);

    Future<void> refreshCurrent() async {
      if (selectedSiteId != null) {
        ref.invalidate(siteDashboardSummaryProvider(selectedSiteId));
      } else {
        ref.invalidate(dashboardSitesProvider);
        ref.invalidate(dashboardHomeAlertsProvider);
      }
    }

    Widget body;
    if (selectedSiteId != null) {
      body = SiteDashboardScreen(
        siteId: selectedSiteId,
        embedded: true,
      );
    } else if (section == DashboardShellSection.alerts) {
      body = const DashboardHomeScreen(
        embedded: true,
        alertsFocus: true,
      );
    } else {
      body = DashboardHomeScreen(
        embedded: true,
        onSiteSelected: (siteId) {
          ref.read(selectedSiteIdProvider.notifier).state = siteId;
          ref.read(siteDashboardSectionProvider.notifier).state =
              SiteDashboardSection.water;
          ref.read(siteDateSelectionProvider(siteId).notifier).state =
              defaultDateSelectionForSite(
            siteId,
            ref.read(businessDateProvider),
          );
        },
      );
    }

    return PartnerLinkListener(
      expectedScheme: PartnerAppLinks.dashboardScheme,
      onLink: (intent) => applyDashboardPartnerLink(ref, intent),
      child: DashboardKeyboardShortcuts(
        onRefresh: refreshCurrent,
        onFocusSearch: () =>
            ref.read(meterSearchFocusNodeProvider).requestFocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Size to sidebar width — do not expand into the content pane.
              BrandSurfaceBackground(
                expand: false,
                showMotif: false,
                child: DashboardSidebar(
                  onSignOut: () => ref.read(authProvider.notifier).signOut(),
                ),
              ),
              Expanded(
                child: DashboardBackground(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selectedSiteId == null)
                        DashboardTopHeader(
                          onRefresh: refreshCurrent,
                          onViewAlerts: () {
                            ref
                                .read(dashboardShellSectionProvider.notifier)
                                .state = DashboardShellSection.alerts;
                          },
                        ),
                      // Fill the pane — avoid centered max-width gutters of empty motif.
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone / narrow layout: drawer navigation (settings, utilities) + site body.
class _MobileDashboardShell extends ConsumerWidget {
  const _MobileDashboardShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings(ref.watch(localeProvider));
    final selectedSiteId = ref.watch(selectedSiteIdProvider);
    final summaryAsync = selectedSiteId == null
        ? null
        : ref.watch(siteDashboardSummaryProvider(selectedSiteId));
    final section = ref.watch(siteDashboardSectionProvider);
    final exportCategoryId = _mobileExportCategoryId(
      summaryAsync?.valueOrNull,
      section,
      selectedSiteId == null
          ? null
          : ref.watch(siteCategoriesSummaryProvider(selectedSiteId)).valueOrNull,
    );

    Future<void> refreshCurrent() async {
      if (selectedSiteId != null) {
        ref.invalidate(siteDashboardSummaryProvider(selectedSiteId));
        ref.invalidate(siteAlertsProvider(selectedSiteId));
        ref.invalidate(siteCategoriesSummaryProvider(selectedSiteId));
      } else {
        ref.invalidate(dashboardSitesProvider);
        ref.invalidate(dashboardHomeAlertsProvider);
      }
    }

    void openSite(String siteId) {
      ref.read(selectedSiteIdProvider.notifier).state = siteId;
      ref.read(siteDashboardSectionProvider.notifier).state =
          SiteDashboardSection.water;
      ref.read(siteDateSelectionProvider(siteId).notifier).state =
          defaultDateSelectionForSite(
        siteId,
        ref.read(businessDateProvider),
      );
    }

    final title = selectedSiteId == null
        ? s.sites
        : summaryAsync?.maybeWhen(
              data: (summary) => s.localizedName(
                en: summary.site.nameEn,
                ar: summary.site.nameAr,
              ),
              orElse: () => s.appTitle,
            ) ??
            s.appTitle;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: BrandSurfaceBackground(
          showMotif: false,
          child: DashboardSidebar(
            asDrawer: true,
            onSignOut: () => ref.read(authProvider.notifier).signOut(),
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: dashboardColors(context).background,
        actions: [
          if (selectedSiteId != null) ...[
            IconButton(
              tooltip: s.refresh,
              onPressed: refreshCurrent,
              icon: const Icon(Icons.refresh_rounded),
            ),
            DashboardAlertBellButton(
              siteId: selectedSiteId,
              onViewAll: () {
                ref.read(siteDashboardSectionProvider.notifier).state =
                    SiteDashboardSection.alerts;
              },
            ),
            ReportExportIconButton(
              defaultType: reportTypeForSiteSection(section),
              siteId: selectedSiteId,
              categoryId: exportCategoryId,
            ),
          ] else ...[
            ReportExportIconButton(defaultType: ReportType.allSitesSummary),
            IconButton(
              tooltip: s.refresh,
              onPressed: refreshCurrent,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom > 0
              ? 0
              : 8,
        ),
        child: DashboardBackground(
          child: selectedSiteId == null
              ? DashboardHomeScreen(
                  embedded: true,
                  onSiteSelected: openSite,
                )
              : SiteDashboardScreen(
                  siteId: selectedSiteId,
                  embedded: true,
                ),
        ),
      ),
    );
  }

  String? _mobileExportCategoryId(
    SiteDashboardSummary? summary,
    SiteDashboardSection section,
    List<SiteCategorySummary>? categories,
  ) {
    if (categories == null) return null;
    final utility = section.utilityKey;
    if (utility == null) return null;
    return categorySummaryForUtility(categories, utility)?.category.id;
  }
}
