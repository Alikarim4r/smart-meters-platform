/// Summarizes `import_legacy_network_dry_run` / plan payloads for Admin UI.
class LegacyImportPlanSummary {
  const LegacyImportPlanSummary({
    required this.metersToAdd,
    required this.tanksToAdd,
    required this.drainsToAdd,
    required this.tankersToAdd,
    required this.connectionsToAdd,
    required this.skipped,
    required this.conflicts,
    required this.legacyNodes,
    required this.legacyEdges,
    required this.existingMappedAssets,
    required this.actions,
    this.additions = 0,
    this.updates = 0,
  });

  final int metersToAdd;
  final int tanksToAdd;
  final int drainsToAdd;
  final int tankersToAdd;
  final int connectionsToAdd;
  final int skipped;
  final int conflicts;
  final int legacyNodes;
  final int legacyEdges;
  final int existingMappedAssets;
  final List<Map<String, dynamic>> actions;
  final int additions;
  final int updates;

  int get totalAdds => additions > 0
      ? additions
      : metersToAdd +
            tanksToAdd +
            drainsToAdd +
            tankersToAdd +
            connectionsToAdd;

  factory LegacyImportPlanSummary.fromPlan(Map<String, dynamic> plan) {
    final rawActions = plan['actions'];
    final actions = <Map<String, dynamic>>[];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is Map) actions.add(Map<String, dynamic>.from(a));
      }
    }

    var meters = 0;
    var tanks = 0;
    var drains = 0;
    var tankers = 0;
    var connections = 0;
    var skipped = 0;
    var conflicts = 0;

    for (final a in actions) {
      final action = a['action']?.toString() ?? '';
      switch (action) {
        case 'add_meter_asset':
          meters++;
        case 'add_tank_asset':
          tanks++;
        case 'add_discharge_point':
          drains++;
        case 'add_tanker_loading':
          tankers++;
        case 'add_connection':
          connections++;
        case 'skipped':
          skipped++;
        case 'conflict':
          conflicts++;
        default:
          if (action.contains('conflict')) conflicts++;
      }
    }

    final conflictList = plan['conflicts'];
    if (conflictList is List) {
      conflicts += conflictList.length;
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final computedAdds = meters + tanks + drains + tankers + connections;
    final serverSkipped = plan['skipped'] ?? plan['unchanged'];

    return LegacyImportPlanSummary(
      metersToAdd: meters,
      tanksToAdd: tanks,
      drainsToAdd: drains,
      tankersToAdd: tankers,
      connectionsToAdd: connections,
      skipped: serverSkipped != null ? asInt(serverSkipped) : skipped,
      conflicts: conflicts,
      legacyNodes: asInt(plan['legacy_nodes']),
      legacyEdges: asInt(plan['legacy_edges']),
      existingMappedAssets: asInt(plan['existing_mapped_assets']),
      actions: actions,
      additions: plan['additions'] == null
          ? computedAdds
          : asInt(plan['additions']),
      updates: asInt(plan['updates']),
    );
  }
}
