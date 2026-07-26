import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'site_system_navigation.dart';

enum MeterCardStatusFilter {
  all,
  submitted,
  pending,
  hasAlert,
  hasPhoto,
  missingPhoto,
  negativeConsumption,
}

extension MeterCardStatusFilterMeta on MeterCardStatusFilter {
  String get label => switch (this) {
    MeterCardStatusFilter.all => 'All',
    MeterCardStatusFilter.submitted => 'Submitted',
    MeterCardStatusFilter.pending => 'Pending',
    MeterCardStatusFilter.hasAlert => 'Has alert',
    MeterCardStatusFilter.hasPhoto => 'Has photo',
    MeterCardStatusFilter.missingPhoto => 'Missing photo',
    MeterCardStatusFilter.negativeConsumption => 'Negative consumption',
  };

  String get repositoryValue => switch (this) {
    MeterCardStatusFilter.all => 'all',
    MeterCardStatusFilter.submitted => 'submitted',
    MeterCardStatusFilter.pending => 'pending',
    MeterCardStatusFilter.hasAlert => 'has_alert',
    MeterCardStatusFilter.hasPhoto => 'has_photo',
    MeterCardStatusFilter.missingPhoto => 'missing_photo',
    MeterCardStatusFilter.negativeConsumption => 'negative_consumption',
  };
}

enum MeterCardSort {
  meterName,
  meterCode,
  highestConsumption,
  pendingFirst,
  alertsFirst,
  latestReadingDate,
  missingPhotoFirst,
  sourceThenCode,
}

extension MeterCardSortMeta on MeterCardSort {
  String get label => switch (this) {
    MeterCardSort.meterName => 'Name',
    MeterCardSort.meterCode => 'Code',
    MeterCardSort.highestConsumption => 'Highest consumption',
    MeterCardSort.pendingFirst => 'Pending first',
    MeterCardSort.alertsFirst => 'Alerts first',
    MeterCardSort.latestReadingDate => 'Latest reading date',
    MeterCardSort.missingPhotoFirst => 'Missing photo first',
    MeterCardSort.sourceThenCode => 'Source, then code',
  };

  String get repositoryValue => switch (this) {
    MeterCardSort.meterName => 'meter_name',
    MeterCardSort.meterCode => 'meter_code',
    MeterCardSort.highestConsumption => 'highest_consumption',
    MeterCardSort.pendingFirst => 'pending_first',
    MeterCardSort.alertsFirst => 'alerts_first',
    MeterCardSort.latestReadingDate => 'latest_reading_date',
    MeterCardSort.missingPhotoFirst => 'missing_photo_first',
    MeterCardSort.sourceThenCode => 'source_then_code',
  };
}

List<MeterReadingCardData> applyMeterCardClientFilters({
  required List<MeterReadingCardData> cards,
  required MeterCardStatusFilter statusFilter,
  required MeterCardSort sort,
  bool ascending = true,
}) {
  final filtered = List<MeterReadingCardData>.from(
    cards.where(
      (card) =>
          matchesMeterReadingStatusFilter(card, statusFilter.repositoryValue),
    ),
  );
  filtered.sort((a, b) {
    final cmp = compareMeterReadingCards(a, b, sort.repositoryValue);
    return ascending ? cmp : -cmp;
  });
  return filtered;
}

List<MeterReadingCardData> enrichMeterCardsWithAlerts({
  required List<MeterReadingCardData> cards,
  required List<DashboardAlert> alerts,
}) {
  final alertsByMeter = <String, DashboardAlert>{};
  for (final alert in alerts) {
    final meterId = alert.meterId;
    if (meterId == null) {
      continue;
    }
    final existing = alertsByMeter[meterId];
    if (existing == null ||
        _severityRank(alert.severity) < _severityRank(existing.severity)) {
      alertsByMeter[meterId] = alert;
    }
  }

  return [
    for (final card in cards)
      card.copyWithAlert(
        hasAlert: alertsByMeter.containsKey(card.meterId),
        alertSeverity: alertsByMeter[card.meterId]?.severity,
      ),
  ];
}

int _severityRank(AlertSeverity severity) => switch (severity) {
  AlertSeverity.critical => 0,
  AlertSeverity.warning => 1,
  AlertSeverity.info => 2,
};

NetworkMapLayer networkLayerForSection(SiteDashboardSection section) {
  return switch (section) {
    SiteDashboardSection.water => NetworkMapLayer.water,
    SiteDashboardSection.electricity => NetworkMapLayer.electricity,
    SiteDashboardSection.btuCooling => NetworkMapLayer.btu,
    SiteDashboardSection.fuel => NetworkMapLayer.fuel,
    SiteDashboardSection.overview => NetworkMapLayer.allOverlay,
    _ => NetworkMapLayer.allOverlay,
  };
}

NetworkMapLayer previewNetworkLayer({
  required SiteDashboardSection section,
  required NetworkMapLayer selectedLayer,
}) {
  if (section == SiteDashboardSection.network) {
    return selectedLayer;
  }
  if (section.isUtilitySection) {
    return networkLayerForSection(section);
  }
  if (section == SiteDashboardSection.overview) {
    return selectedLayer == NetworkMapLayer.water
        ? NetworkMapLayer.allOverlay
        : selectedLayer;
  }
  return NetworkMapLayer.allOverlay;
}

List<MeterReadingCardData> meterCardsForNetworkLayer({
  required List<MeterReadingCardData> cards,
  required NetworkMapLayer layer,
}) {
  if (layer == NetworkMapLayer.allOverlay) {
    return cards;
  }
  final utility = layer.utilityKey;
  if (utility == null) {
    return cards;
  }
  return cards.where((card) {
    final category = card.categoryName.toLowerCase();
    return switch (utility) {
      UtilitySystemKey.water => category.contains('water'),
      UtilitySystemKey.electricity => category.contains('electric'),
      UtilitySystemKey.btu =>
        category.contains('btu') || category.contains('cool'),
      UtilitySystemKey.fuel =>
        category.contains('fuel') || category.contains('diesel'),
    };
  }).toList();
}

String meterCardFilterKey(String siteId, String utilityKey) =>
    '$siteId::$utilityKey';

enum MeterCardViewMode { cards, relationship, network }

extension MeterCardViewModeMeta on MeterCardViewMode {
  String get label => switch (this) {
    MeterCardViewMode.cards => 'Cards',
    MeterCardViewMode.relationship => 'Relationship',
    MeterCardViewMode.network => 'Network',
  };
}

/// Water source chip filter for grouped meter card display.
enum WaterSourceChip { all, kahramaa, tse, ro, irrigation, chilledWater, other }

extension WaterSourceChipMeta on WaterSourceChip {
  String get label => switch (this) {
    WaterSourceChip.all => 'All',
    WaterSourceChip.kahramaa => 'Kahramaa',
    WaterSourceChip.tse => 'TSE',
    WaterSourceChip.ro => 'RO',
    WaterSourceChip.irrigation => 'Irrigation',
    WaterSourceChip.chilledWater => 'Chilled Water',
    WaterSourceChip.other => 'Other',
  };
}

String waterSourceGroupKey(MeterReadingCardData card) =>
    meterWaterSourceGroupKey(
      sourceCode: card.sourceCode,
      sourceName: card.sourceName,
    );

String waterSourceGroupLabel(String groupKey) => switch (groupKey) {
  'kahramaa' => 'Kahramaa Water',
  'tse' => 'TSE Water',
  'ro' => 'RO',
  'irrigation' => 'Irrigation',
  'chilled_water' => 'Chilled Water / Flow',
  'storm' => 'Storm Water',
  'other' => 'Other',
  _ => groupKey.isEmpty ? 'Other' : groupKey,
};

WaterSourceChip? waterSourceChipForGroupKey(String groupKey) =>
    switch (groupKey) {
      'kahramaa' => WaterSourceChip.kahramaa,
      'tse' => WaterSourceChip.tse,
      'ro' => WaterSourceChip.ro,
      'irrigation' => WaterSourceChip.irrigation,
      'chilled_water' => WaterSourceChip.chilledWater,
      _ => WaterSourceChip.other,
    };

List<MeterReadingCardData> filterCardsByWaterSourceChip({
  required List<MeterReadingCardData> cards,
  required WaterSourceChip chip,
}) {
  if (chip == WaterSourceChip.all) return cards;
  return cards
      .where(
        (card) => waterSourceChipForGroupKey(waterSourceGroupKey(card)) == chip,
      )
      .toList();
}

Map<String, List<MeterReadingCardData>> groupCardsBySource(
  List<MeterReadingCardData> cards, {
  bool waterUtility = false,
}) {
  final groups = <String, List<MeterReadingCardData>>{};
  for (final card in cards) {
    final key = waterUtility
        ? waterSourceGroupKey(card)
        : _genericSourceGroupKey(card);
    groups.putIfAbsent(key, () => []).add(card);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.meterCode.compareTo(b.meterCode));
  }
  return Map.fromEntries(
    groups.entries.toList()..sort(
      (a, b) => sourceGroupLabel(
        a.key,
        waterUtility: waterUtility,
      ).compareTo(sourceGroupLabel(b.key, waterUtility: waterUtility)),
    ),
  );
}

String _genericSourceGroupKey(MeterReadingCardData card) {
  final code = card.sourceCode.trim();
  if (code.isNotEmpty) return code.toLowerCase();
  final name = card.sourceName.trim();
  return name.isEmpty ? 'other' : name.toLowerCase();
}

String sourceGroupLabel(String groupKey, {bool waterUtility = false}) {
  if (waterUtility) return waterSourceGroupLabel(groupKey);
  if (groupKey == 'other') return 'Other';
  return groupKey
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

IconData sourceGroupIcon(String groupKey, {bool waterUtility = false}) {
  if (waterUtility) {
    return switch (groupKey) {
      'kahramaa' => Icons.water_drop_outlined,
      'tse' => Icons.recycling_outlined,
      'ro' => Icons.filter_alt_outlined,
      'irrigation' => Icons.grass_outlined,
      'chilled_water' => Icons.ac_unit_outlined,
      'storm' => Icons.thunderstorm_outlined,
      _ => Icons.water_outlined,
    };
  }
  return switch (groupKey) {
    'kahramaa' => Icons.bolt_outlined,
    'generator' => Icons.electrical_services_outlined,
    'solar' => Icons.solar_power_outlined,
    'other' => Icons.device_hub_outlined,
    _ => Icons.bolt_outlined,
  };
}

bool shouldGroupCardsBySource(List<MeterReadingCardData> cards) {
  if (cards.length < 2) return false;
  final sources = cards.map(_genericSourceGroupKey).toSet();
  return sources.length > 1;
}

Map<String, List<MeterReadingCardData>> groupCardsByWaterSource(
  List<MeterReadingCardData> cards,
) {
  final groups = <String, List<MeterReadingCardData>>{};
  for (final card in cards) {
    final key = waterSourceGroupKey(card);
    groups.putIfAbsent(key, () => []).add(card);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.meterCode.compareTo(b.meterCode));
  }
  return Map.fromEntries(
    groups.entries.toList()..sort(
      (a, b) =>
          waterSourceGroupLabel(a.key).compareTo(waterSourceGroupLabel(b.key)),
    ),
  );
}

class MeterRelationshipGroup {
  const MeterRelationshipGroup({required this.parent, required this.children});

  final MeterReadingCardData parent;
  final List<MeterReadingCardData> children;

  bool get hasBranches => children.isNotEmpty;
}

/// Flat groups — does **not** use deprecated meters.parent_meter_id.
/// Network relationships belong to utility network v2 (Dashboard network map).
List<MeterRelationshipGroup> buildMeterRelationshipGroups(
  List<MeterReadingCardData> cards,
) {
  if (cards.isEmpty) return const [];
  final sorted = [...cards]..sort((a, b) => a.meterCode.compareTo(b.meterCode));
  return [
    for (final card in sorted)
      MeterRelationshipGroup(parent: card, children: const []),
  ];
}

bool photoButtonEnabled({required bool hasPhoto, String? storagePath}) =>
    hasPhoto && storagePath != null && storagePath.isNotEmpty;
