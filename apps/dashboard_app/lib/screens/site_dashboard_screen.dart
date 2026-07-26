import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../providers/alert_providers.dart';
import '../providers/chart_providers.dart';
import '../providers/dashboard_providers.dart';
import '../reports/report_export_button.dart';
import '../theme/dashboard_palette.dart';
import '../theme/design_system/dashboard_design_system.dart';
import '../utils/dashboard_breakpoints.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/dashboard_filters.dart';
import '../utils/site_system_navigation.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/premium/dashboard_date_quick_bar.dart';
import '../widgets/premium/imported_data_info_banner.dart';
import '../widgets/premium/dashboard_background.dart';
import '../widgets/premium/utility_system_chip.dart';
import '../widgets/shell/dashboard_alert_bell.dart';
import '../widgets/shell/dashboard_sidebar.dart';
import '../widgets/shell/dashboard_top_header.dart';
import '../widgets/system/site_alerts_panel.dart';
import '../widgets/system/site_overview_panel.dart';
import '../widgets/system/site_reports_panel.dart';
import '../widgets/system/utility_system_panel.dart';

class SiteDashboardScreen extends ConsumerWidget {
  const SiteDashboardScreen({
    super.key,
    required this.siteId,
    this.initialSite,
    this.embedded = false,
  });

  final String siteId;
  final Site? initialSite;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final summaryAsync = ref.watch(siteDashboardSummaryProvider(siteId));
    final rawSection = ref.watch(siteDashboardSectionProvider);
    final section = normalizeSiteDashboardSection(rawSection);
    if (rawSection != section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(siteDashboardSectionProvider.notifier).state = section;
      });
    }
    final categoriesAsync = ref.watch(siteCategoriesSummaryProvider(siteId));
    // Desktop chrome only when the permanent sidebar is visible.
    // On phones, parent [_MobileDashboardShell] owns the AppBar + drawer.
    final useShellChrome = DashboardBreakpoints.useSidebar(context);
    final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
    final exportCategoryId =
        _exportCategoryId(categoriesAsync.valueOrNull, section);

    Future<void> refreshSite() async {
      ref.read(dashboardRepositoryProvider).invalidateSiteCaches(siteId);
      ref.invalidate(siteDashboardSummaryProvider(siteId));
      ref.invalidate(siteAlertsProvider(siteId));
      ref.invalidate(siteCategoriesSummaryProvider(siteId));
      ref.invalidate(siteCategoriesSummaryForMonthProvider(siteId));
    }

    void openSection(SiteDashboardSection value) {
      ref.read(siteDashboardSectionProvider.notifier).state = value;
    }

    Widget buildSectionContent(
      SiteDashboardSummary summary, {
      required bool meterLayoutWide,
    }) {
      return switch (section) {
        SiteDashboardSection.overview => SiteOverviewPanel(
            siteId: siteId,
            summary: summary,
            useDesktop: meterLayoutWide,
            onOpenAlerts: () => openSection(SiteDashboardSection.alerts),
            onOpenSystem: openSection,
          ),
        SiteDashboardSection.water => UtilitySystemPanel(
            siteId: siteId,
            system: UtilitySystemKey.water,
            useDesktop: meterLayoutWide,
          ),
        SiteDashboardSection.electricity => UtilitySystemPanel(
            siteId: siteId,
            system: UtilitySystemKey.electricity,
            useDesktop: meterLayoutWide,
          ),
        SiteDashboardSection.btuCooling => UtilitySystemPanel(
            siteId: siteId,
            system: UtilitySystemKey.btu,
            useDesktop: meterLayoutWide,
            showCopSection: true,
          ),
        SiteDashboardSection.fuel => UtilitySystemPanel(
            siteId: siteId,
            system: UtilitySystemKey.fuel,
            useDesktop: meterLayoutWide,
          ),
        SiteDashboardSection.network => UtilitySystemPanel(
            siteId: siteId,
            system: UtilitySystemKey.water,
            useDesktop: meterLayoutWide,
          ),
        SiteDashboardSection.alerts => SiteAlertsPanel(
            siteId: siteId,
            useDesktop: meterLayoutWide,
          ),
        SiteDashboardSection.reports => SiteReportsPanel(
            siteId: siteId,
            useDesktop: meterLayoutWide,
          ),
      };
    }

    final body = summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DashboardErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(siteDashboardSummaryProvider(siteId)),
      ),
      data: (summary) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (useShellChrome)
              DashboardTopHeader(
                site: summary.site,
                siteId: siteId,
                exportType: reportTypeForSiteSection(section),
                exportCategoryId: exportCategoryId,
                dateSelection: dateSelection,
                onDateSelectionChanged: (value) => ref
                    .read(siteDateSelectionProvider(siteId).notifier)
                    .state = value,
                onRefresh: refreshSite,
                onViewAlerts: () => openSection(SiteDashboardSection.alerts),
                onBack: embedded
                    ? () {
                        ref.read(selectedSiteIdProvider.notifier).state = null;
                      }
                    : null,
              ),
            if (!useShellChrome)
              _MobileToolbar(
                siteId: siteId,
                dateSelection: dateSelection,
                section: section,
                onDateChanged: (value) => ref
                    .read(siteDateSelectionProvider(siteId).notifier)
                    .state = value,
                onSectionChanged: openSection,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final meterLayoutWide =
                      constraints.maxWidth >= 560 &&
                      DashboardBreakpoints.useSidebar(context);
                  return DashboardBackground(
                    child: buildSectionContent(
                      summary,
                      meterLayoutWide: meterLayoutWide,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (embedded) {
      return body;
    }

    final fallbackTitle = initialSite != null
        ? s.localizedName(en: initialSite!.nameEn, ar: initialSite!.nameAr)
        : s.appTitle;

    return Scaffold(
      backgroundColor: DashboardPalette.background,
      appBar: useShellChrome
          ? null
          : AppBar(
              title: summaryAsync.maybeWhen(
                data: (summary) => Text(
                  s.localizedName(
                    en: summary.site.nameEn,
                    ar: summary.site.nameAr,
                  ),
                ),
                orElse: () => Text(fallbackTitle),
              ),
              actions: [
                IconButton(
                  tooltip: s.refresh,
                  onPressed: refreshSite,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                DashboardAlertBellButton(
                  siteId: siteId,
                  onViewAll: () => openSection(SiteDashboardSection.alerts),
                ),
                ReportExportIconButton(
                  defaultType: reportTypeForSiteSection(section),
                  siteId: siteId,
                  categoryId: exportCategoryId,
                ),
              ],
            ),
      body: SafeArea(
        top: false,
        child: body,
      ),
    );
  }

  String? _exportCategoryId(
    List<SiteCategorySummary>? categories,
    SiteDashboardSection section,
  ) {
    if (categories == null) return null;
    final utility = section.utilityKey;
    if (utility == null) return null;
    return categorySummaryForUtility(categories, utility)?.category.id;
  }
}

/// Compact phone chrome: date + section chips (no duplicate site title).
class _MobileToolbar extends StatelessWidget {
  const _MobileToolbar({
    required this.siteId,
    required this.dateSelection,
    required this.section,
    required this.onDateChanged,
    required this.onSectionChanged,
  });

  final String siteId;
  final DashboardDateSelection dateSelection;
  final SiteDashboardSection section;
  final ValueChanged<DashboardDateSelection> onDateChanged;
  final ValueChanged<SiteDashboardSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final pad = DashboardBreakpoints.contentPadding(context);
    return Material(
      color: DashboardColors.card(context),
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DashboardDateQuickBar(
                selection: dateSelection,
                onChanged: onDateChanged,
                siteId: siteId,
                compact: true,
              ),
            ),
            if (siteHasImportedHistoricalMonths(siteId)) ...[
              const SizedBox(height: 6),
              const ImportedDataInfoBanner(),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in mobileSiteDashboardSections) ...[
                    UtilitySystemChip(
                      section: item,
                      selected: section == item,
                      onSelected: onSectionChanged,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
