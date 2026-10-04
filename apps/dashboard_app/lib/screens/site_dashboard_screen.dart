import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../providers/alert_providers.dart';
import '../providers/chart_providers.dart';
import '../providers/dashboard_providers.dart';
import '../reports/report_export_button.dart';
import '../theme/dashboard_palette.dart';
import '../theme/dashboard_theme.dart';
import '../utils/dashboard_breakpoints.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/site_system_navigation.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/premium/dashboard_date_quick_bar.dart';
import '../widgets/premium/dashboard_background.dart';
import '../widgets/premium/utility_system_chip.dart';
import '../widgets/shell/dashboard_alert_bell.dart';
import '../widgets/shell/dashboard_sidebar.dart';
import '../widgets/shell/dashboard_top_header.dart';
import '../widgets/system/site_alerts_panel.dart';
import '../widgets/system/site_overview_panel.dart';
import '../widgets/system/site_reports_panel.dart';
import '../widgets/system/utility_system_panel.dart';
import '../providers/conservation_providers.dart';
import '../widgets/system/site_conservation_panel.dart';

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
    final conservationVisible =
        ref.watch(conservationSectionVisibleProvider(siteId)).valueOrNull ??
        false;
    final section = normalizeSiteDashboardSection(
      rawSection,
      conservationVisible: conservationVisible,
    );
    if (rawSection != section) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(siteDashboardSectionProvider.notifier).state = section;
      });
    }
    final useShellChrome = DashboardBreakpoints.useSidebar(context);
    final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
    // Only fetch categories when export needs a utility category id.
    // Overview/Reports/Conservation panels watch their own providers.
    final needsExportCategory = section.utilityKey != null;
    final exportCategories = needsExportCategory
        ? ref.watch(siteCategoriesSummaryProvider(siteId)).valueOrNull
        : null;
    final exportCategoryId = _exportCategoryId(exportCategories, section);

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
        SiteDashboardSection.conservation => SiteConservationPanel(
          siteId: siteId,
          useDesktop: meterLayoutWide,
        ),
      };
    }

    final body = summaryAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [BrandSkeletonLedger(rows: 6)],
      ),
      error: (error, _) => DashboardErrorState(
        message: AppStrings.of(context).genericError,
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
                onDateSelectionChanged: (value) =>
                    ref.read(siteDateSelectionProvider(siteId).notifier).state =
                        value,
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
                sections: siteDashboardSectionsForFlags(
                  conservationVisible: conservationVisible,
                ),
                onDateChanged: (value) =>
                    ref.read(siteDateSelectionProvider(siteId).notifier).state =
                        value,
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
              toolbarHeight: 72,
              titleSpacing: 4,
              title: summaryAsync.maybeWhen(
                data: (summary) => Text(
                  s.localizedName(
                    en: summary.site.nameEn,
                    ar: summary.site.nameAr,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                orElse: () => Text(
                  fallbackTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
      body: SafeArea(top: false, child: body),
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
    required this.sections,
    required this.onDateChanged,
    required this.onSectionChanged,
  });

  final String siteId;
  final DashboardDateSelection dateSelection;
  final SiteDashboardSection section;
  final List<SiteDashboardSection> sections;
  final ValueChanged<DashboardDateSelection> onDateChanged;
  final ValueChanged<SiteDashboardSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final pad = DashboardBreakpoints.contentPadding(context);
    final colors = dashboardColors(context);
    return Material(
      color: colors.card,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.75)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(pad, 10, pad, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardDateQuickBar(
              selection: dateSelection,
              onChanged: onDateChanged,
              siteId: siteId,
              compact: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = sections[index];
                  return UtilitySystemChip(
                    section: item,
                    selected: section == item,
                    onSelected: onSectionChanged,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
