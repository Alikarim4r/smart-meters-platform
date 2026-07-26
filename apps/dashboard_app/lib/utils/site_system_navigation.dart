import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../widgets/premium/utility_colors.dart';

/// Site-level navigation sections (utility-separated IA).
enum SiteDashboardSection {
  overview,
  water,
  electricity,
  btuCooling,
  fuel,
  network,
  alerts,
  reports,
}

extension SiteDashboardSectionMeta on SiteDashboardSection {
  String get label => switch (this) {
        SiteDashboardSection.overview => 'Overview',
        SiteDashboardSection.water => 'Water',
        SiteDashboardSection.electricity => 'Electricity',
        SiteDashboardSection.btuCooling => 'BTU / Cooling',
        SiteDashboardSection.fuel => 'Fuel / Diesel',
        SiteDashboardSection.network => 'Network',
        SiteDashboardSection.alerts => 'Alerts',
        SiteDashboardSection.reports => 'Reports',
      };

  IconData get icon => switch (this) {
        SiteDashboardSection.overview => Icons.dashboard_outlined,
        SiteDashboardSection.water => Icons.water_drop_outlined,
        SiteDashboardSection.electricity => Icons.bolt_outlined,
        SiteDashboardSection.btuCooling => Icons.ac_unit_outlined,
        SiteDashboardSection.fuel => Icons.local_gas_station_outlined,
        SiteDashboardSection.network => Icons.hub_outlined,
        SiteDashboardSection.alerts => Icons.notifications_outlined,
        SiteDashboardSection.reports => Icons.summarize_outlined,
      };

  UtilitySystemKey? get utilityKey => switch (this) {
        SiteDashboardSection.water => UtilitySystemKey.water,
        SiteDashboardSection.electricity => UtilitySystemKey.electricity,
        SiteDashboardSection.btuCooling => UtilitySystemKey.btu,
        SiteDashboardSection.fuel => UtilitySystemKey.fuel,
        _ => null,
      };

  bool get isUtilitySection => utilityKey != null;
}

/// Active site navigation — Network excluded from visible dashboard flow.
const mainSiteDashboardSections = [
  SiteDashboardSection.overview,
  SiteDashboardSection.water,
  SiteDashboardSection.electricity,
  SiteDashboardSection.btuCooling,
  SiteDashboardSection.fuel,
  SiteDashboardSection.alerts,
  SiteDashboardSection.reports,
];

/// Desktop sidebar / rail sections.
const desktopSiteDashboardSections = mainSiteDashboardSections;

/// Mobile horizontal utility chips.
const mobileSiteDashboardSections = mainSiteDashboardSections;

/// Network is retained in the enum for legacy code but hidden from navigation.
bool isNetworkSectionVisible(SiteDashboardSection section) =>
    section != SiteDashboardSection.network;

SiteDashboardSection normalizeSiteDashboardSection(SiteDashboardSection section) {
  if (section == SiteDashboardSection.network) {
    return SiteDashboardSection.water;
  }
  return section;
}

SiteDashboardSection? sectionForAlertCategory(String? categoryName) {
  final name = (categoryName ?? '').toLowerCase();
  if (name.contains('water')) return SiteDashboardSection.water;
  if (name.contains('electric')) return SiteDashboardSection.electricity;
  if (name.contains('btu') || name.contains('cool')) {
    return SiteDashboardSection.btuCooling;
  }
  if (name.contains('fuel') || name.contains('diesel')) {
    return SiteDashboardSection.fuel;
  }
  return null;
}

/// Canonical utility systems — one measurement domain per screen.
enum UtilitySystemKey {
  water('water', 'Water System', 'm³', DashboardUtilityColors.water),
  electricity(
    'electricity',
    'Electricity System',
    'kWh',
    DashboardUtilityColors.electricity,
  ),
  btu('btu', 'BTU / Cooling System', 'BTU', DashboardUtilityColors.btu),
  fuel('fuel', 'Fuel / Diesel System', 'L', DashboardUtilityColors.fuel);

  const UtilitySystemKey(
    this.categoryCode,
    this.title,
    this.defaultUnit,
    this.accent,
  );

  final String categoryCode;
  final String title;
  final String defaultUnit;
  final Color accent;

  String get topConsumersTitle => 'Top $label Consumers';

  String get label => switch (this) {
        UtilitySystemKey.water => 'Water',
        UtilitySystemKey.electricity => 'Electricity',
        UtilitySystemKey.btu => 'BTU',
        UtilitySystemKey.fuel => 'Fuel',
      };

  String get metersTableTitle => '$label meters';

  List<String> get sourceHints => switch (this) {
        UtilitySystemKey.water => [
            'Kahramaa',
            'TSE',
            'RO',
            'Irrigation',
            'Flow',
            'Chilled',
            'Storm',
          ],
        UtilitySystemKey.electricity => ['Kahramaa', 'LVP', 'Panel', 'Electrical'],
        UtilitySystemKey.btu => ['CHW', 'Cooling', 'BTU', 'Chiller'],
        UtilitySystemKey.fuel => ['Diesel', 'CAP', 'Tank', 'Generator'],
      };
}

SiteCategorySummary? categorySummaryForUtility(
  List<SiteCategorySummary> summaries,
  UtilitySystemKey system,
) {
  for (final item in summaries) {
    if (item.category.code == system.categoryCode) {
      return item;
    }
  }
  return null;
}

bool alertMatchesUtility(DashboardAlert alert, UtilitySystemKey system) {
  final name = (alert.categoryName ?? '').toLowerCase();
  return switch (system) {
    UtilitySystemKey.water =>
      name.contains('water') || alert.type == AlertType.possibleLeak,
    UtilitySystemKey.electricity =>
      name.contains('electric') || name.contains('kahramaa'),
    UtilitySystemKey.btu => name.contains('btu') || name.contains('cool'),
    UtilitySystemKey.fuel =>
      name.contains('fuel') || name.contains('diesel') || name.contains('gas'),
  };
}

int alertCountForUtility(List<DashboardAlert> alerts, UtilitySystemKey system) =>
    alerts.where((a) => alertMatchesUtility(a, system)).length;

List<DashboardMeterRow> metersForUtility(
  List<DashboardMeterRow> meters,
  UtilitySystemKey system,
) {
  return meters
      .where((m) => _meterMatchesUtility(m, system))
      .toList();
}

bool _meterMatchesUtility(DashboardMeterRow meter, UtilitySystemKey system) {
  final code = meter.categoryName.toLowerCase();
  return switch (system) {
    UtilitySystemKey.water => code.contains('water'),
    UtilitySystemKey.electricity => code.contains('electric'),
    UtilitySystemKey.btu => code.contains('btu'),
    UtilitySystemKey.fuel => code.contains('fuel'),
  };
}

/// Network map overlay layer — default is a single utility, not mixed.
enum NetworkMapLayer {
  water,
  electricity,
  btu,
  fuel,
  allOverlay,
}

extension NetworkMapLayerMeta on NetworkMapLayer {
  String get label => switch (this) {
        NetworkMapLayer.water => 'Water layer',
        NetworkMapLayer.electricity => 'Electricity layer',
        NetworkMapLayer.btu => 'BTU layer',
        NetworkMapLayer.fuel => 'Fuel layer',
        NetworkMapLayer.allOverlay => 'All layers (overlay)',
      };

  UtilitySystemKey? get utilityKey => switch (this) {
        NetworkMapLayer.water => UtilitySystemKey.water,
        NetworkMapLayer.electricity => UtilitySystemKey.electricity,
        NetworkMapLayer.btu => UtilitySystemKey.btu,
        NetworkMapLayer.fuel => UtilitySystemKey.fuel,
        NetworkMapLayer.allOverlay => null,
      };
}
