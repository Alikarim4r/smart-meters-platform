import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/utility_network_errors.dart';
import '../models/utility_network_models.dart';

/// Utility network v2 repository (Asset → Port → Connection).
///
/// All mutations go through SECURITY DEFINER RPCs with [expectedLockVersion].
/// Does not dual-write to legacy 031 tables.
class UtilityNetworkRepository {
  UtilityNetworkRepository(this._client);

  final SupabaseClient _client;

  /// Loads the active **draft** revision snapshot (requires manage ACL).
  ///
  /// This is intentionally read-only: it never creates a draft as a side effect.
  Future<UtilityNetworkSnapshot> getDraftSnapshot(String networkId) async {
    final raw = await _rpcMap('get_draft_network_snapshot', {
      'p_network_id': networkId,
    });
    if (raw['status'] == 'no_draft') {
      throw const NetworkNoDraftError();
    }
    try {
      final snap = UtilityNetworkSnapshot.fromJson(raw);
      // Validation warnings/cycles must never block opening the editor.
      return snap;
    } catch (e) {
      throw NetworkRpcError(
        'Failed to parse network draft snapshot: $e',
        cause: e,
      );
    }
  }

  /// Picks the primary water network for a site (one-network UX).
  /// Prefers the draft with the most nodes; creates nothing.
  Future<UtilityNetworkSummary?> resolvePrimaryNetworkForSite({
    required String siteId,
    required String categoryId,
  }) async {
    final networks = (await listNetworksForSite(
      siteId,
    )).where((n) => n.categoryId == categoryId).toList();
    if (networks.isEmpty) return null;
    if (networks.length == 1) return networks.single;

    UtilityNetworkSummary? best;
    var bestScore = -1;
    for (final n in networks) {
      var score = 0;
      if (n.publishedRevisionId != null) score += 1000;
      if (n.draftRevisionId != null) {
        try {
          final snap = await getDraftSnapshot(n.id);
          score += snap.nodes.length;
        } catch (_) {}
      }
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return best ?? networks.first;
  }

  /// Loads a specific draft revision by id (manage ACL).
  Future<UtilityNetworkSnapshot> getDraftSnapshotByRevision(
    String networkId,
    String draftRevisionId,
  ) async {
    final raw = await _rpcMap('get_network_snapshot', {
      'p_network_id': networkId,
      'p_revision_id': draftRevisionId,
    });
    final snap = UtilityNetworkSnapshot.fromJson(raw);
    if (!snap.revision.isDraft) {
      throw NetworkRpcError(
        'Expected draft revision, got ${snap.revision.status.dbValue}',
      );
    }
    return snap;
  }

  /// Loads the **published** revision only (never ensure/create draft).
  Future<UtilityNetworkSnapshot> getPublishedSnapshot(String networkId) async {
    final raw = await _rpcMap('get_published_network_snapshot', {
      'p_network_id': networkId,
    });
    if (raw['status'] == 'not_published') {
      throw const NetworkNotPublishedError();
    }
    final snap = UtilityNetworkSnapshot.fromJson(raw);
    if (!snap.revision.isPublished) {
      throw const NetworkNotPublishedError();
    }
    return snap;
  }

  Future<List<UtilityNetworkSummary>> listNetworksForSite(String siteId) async {
    final raw = await _rpcMap('list_utility_networks_for_site', {
      'p_site_id': siteId,
    });
    final networks = raw['networks'];
    if (networks is! List) return const [];
    return [
      for (final e in networks)
        if (e is Map)
          UtilityNetworkSummary.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<Map<String, dynamic>> createUtilityNetwork({
    required String categoryId,
    required String code,
    required String nameEn,
    required String nameAr,
    required List<String> memberSiteIds,
  }) {
    return _rpcMap('create_utility_network', {
      'p_category_id': categoryId,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_member_site_ids': memberSiteIds,
    });
  }

  Future<List<AvailableNetworkMeter>> listAvailableMeters({
    required String networkId,
    String? revisionId,
    String? viewId,
    String? siteId,
    String? search,
    int limit = 200,
  }) async {
    final raw = await _rpcMap('list_available_meters_for_network', {
      'p_network_id': networkId,
      'p_revision_id': revisionId,
      'p_view_id': viewId,
      'p_site_id': siteId,
      'p_search': search,
      'p_limit': limit,
    });
    final meters = raw['meters'];
    if (meters is! List) return const [];
    return [
      for (final e in meters)
        if (e is Map)
          AvailableNetworkMeter.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<List<AvailableNetworkTank>> listAvailableTanks({
    required String networkId,
    String? revisionId,
    String? viewId,
    String? siteId,
    String? search,
    int limit = 200,
  }) async {
    final raw = await _rpcMap('list_available_tanks_for_network', {
      'p_network_id': networkId,
      'p_revision_id': revisionId,
      'p_view_id': viewId,
      'p_site_id': siteId,
      'p_search': search,
      'p_limit': limit,
    });
    final tanks = raw['tanks'];
    if (tanks is! List) return const [];
    return [
      for (final e in tanks)
        if (e is Map)
          AvailableNetworkTank.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<NetworkMutationResult> attachExistingMeter({
    required String revisionId,
    required int expectedLockVersion,
    required String meterId,
    String? viewId,
    double posX = 0,
    double posY = 0,
    String meterRole = 'process',
    String? facilityAreaId,
    String? upstreamNodeId,
    List<String>? downstreamNodeIds,
    String connectionKind = 'supply',
    String? waterType,
    String? legacySyncStatus,
    bool replaceExistingParent = false,
  }) {
    return _mutate('attach_existing_meter_to_draft', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_meter_id': meterId,
      'p_view_id': viewId,
      'p_pos_x': posX,
      'p_pos_y': posY,
      'p_meter_role': meterRole,
      'p_facility_area_id': facilityAreaId,
      'p_upstream_node_id': upstreamNodeId,
      'p_downstream_node_ids': downstreamNodeIds,
      'p_connection_kind': connectionKind,
      'p_water_type': waterType,
      'p_legacy_sync_status': legacySyncStatus,
      'p_replace_existing_parent': replaceExistingParent,
    });
  }

  Future<NetworkMutationResult> attachExistingTank({
    required String revisionId,
    required int expectedLockVersion,
    required String tankId,
    String? viewId,
    double posX = 0,
    double posY = 0,
    String? facilityAreaId,
    bool includeAuxPorts = true,
  }) {
    return _mutate('attach_existing_tank_to_draft', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_tank_id': tankId,
      'p_view_id': viewId,
      'p_pos_x': posX,
      'p_pos_y': posY,
      'p_facility_area_id': facilityAreaId,
      'p_include_aux_ports': includeAuxPorts,
    });
  }

  Future<NetworkMutationResult> createMeterInDraft({
    required String revisionId,
    required int expectedLockVersion,
    required String siteId,
    required String meterCode,
    required String nameEn,
    required String nameAr,
    required String categoryId,
    required String sourceId,
    required String unitId,
    String meterRole = 'main',
    String? facilityAreaId,
    String? viewId,
    double posX = 0,
    double posY = 0,
    String? upstreamNodeId,
    List<String>? downstreamNodeIds,
    String connectionKind = 'supply',
    String? waterType,
    String? legacySyncStatus,
    bool replaceExistingParent = false,
  }) {
    return _mutate('create_meter_in_network_draft', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_site_id': siteId,
      'p_meter_code': meterCode,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_category_id': categoryId,
      'p_source_id': sourceId,
      'p_unit_id': unitId,
      'p_meter_role': meterRole,
      'p_facility_area_id': facilityAreaId,
      'p_view_id': viewId,
      'p_pos_x': posX,
      'p_pos_y': posY,
      'p_upstream_node_id': upstreamNodeId,
      'p_downstream_node_ids': downstreamNodeIds,
      'p_connection_kind': connectionKind,
      'p_water_type': waterType,
      'p_legacy_sync_status': legacySyncStatus,
      'p_replace_existing_parent': replaceExistingParent,
    });
  }

  Future<NetworkMutationResult> createTankInDraft({
    required String revisionId,
    required int expectedLockVersion,
    required String siteId,
    required String nameEn,
    required String nameAr,
    String? code,
    String? serviceType,
    String? facilityAreaId,
    bool includeAuxPorts = true,
    String? viewId,
    double posX = 0,
    double posY = 0,
  }) {
    return _mutate('create_tank_in_network_draft', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_site_id': siteId,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_code': code,
      'p_service_type': serviceType,
      'p_facility_area_id': facilityAreaId,
      'p_include_aux_ports': includeAuxPorts,
      'p_view_id': viewId,
      'p_pos_x': posX,
      'p_pos_y': posY,
    });
  }

  Future<NetworkMutationResult> createGenericAsset({
    required String revisionId,
    required int expectedLockVersion,
    required String siteId,
    required String assetType,
    required String code,
    required String nameEn,
    required String nameAr,
    String? serviceType,
    String? facilityAreaId,
    String? meterRole,
    Map<String, dynamic>? properties,
    bool includeTankAuxPorts = false,
    String? viewId,
    double posX = 0,
    double posY = 0,
  }) {
    return _mutate('create_asset_with_ports', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_site_id': siteId,
      'p_asset_type': assetType,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_service_type': serviceType,
      'p_facility_area_id': facilityAreaId,
      'p_meter_role': meterRole,
      'p_properties': properties ?? const <String, dynamic>{},
      'p_include_tank_aux_ports': includeTankAuxPorts,
      'p_view_id': viewId,
      'p_pos_x': posX,
      'p_pos_y': posY,
    });
  }

  Future<NetworkMutationResult> updateAsset({
    required String revisionId,
    required int expectedLockVersion,
    required String assetId,
    String? code,
    String? nameEn,
    String? nameAr,
    String? serviceType,
    String? facilityAreaId,
    Map<String, dynamic>? properties,
  }) {
    return _mutate('update_asset', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_asset_id': assetId,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_service_type': serviceType,
      'p_facility_area_id': facilityAreaId,
      'p_properties': properties,
    });
  }

  Future<NetworkMutationResult> addAssetPort({
    required String revisionId,
    required int expectedLockVersion,
    required String assetId,
    required String code,
    required String nameEn,
    required String nameAr,
    required String direction,
    required String portRole,
    Map<String, dynamic>? properties,
  }) {
    return _mutate('add_asset_port', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_asset_id': assetId,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_direction': direction,
      'p_port_role': portRole,
      'p_properties': properties ?? const <String, dynamic>{},
    });
  }

  Future<NetworkMutationResult> updateAssetPort({
    required String revisionId,
    required int expectedLockVersion,
    required String portId,
    String? code,
    String? nameEn,
    String? nameAr,
    String? direction,
    String? portRole,
    Map<String, dynamic>? properties,
  }) {
    return _mutate('update_asset_port', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_port_id': portId,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_direction': direction,
      'p_port_role': portRole,
      'p_properties': properties,
    });
  }

  Future<NetworkMutationResult> removeAssetPort({
    required String revisionId,
    required int expectedLockVersion,
    required String portId,
  }) {
    return _mutate('remove_asset_port', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_port_id': portId,
    });
  }

  Future<NetworkMutationResult> connectPorts({
    required String revisionId,
    required int expectedLockVersion,
    required String fromNodeId,
    required String fromPortId,
    required String toNodeId,
    required String toPortId,
    required String connectionKind,
    String? waterType,
    String transportMode = 'pipe',
    String operatingMode = 'normal',
    String? legacySyncStatus,
    Map<String, dynamic>? properties,
    bool replaceExistingParent = false,
  }) {
    return _mutate('connect_ports', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_from_node_id': fromNodeId,
      'p_from_port_id': fromPortId,
      'p_to_node_id': toNodeId,
      'p_to_port_id': toPortId,
      'p_connection_kind': connectionKind,
      'p_water_type': waterType,
      'p_transport_mode': transportMode,
      'p_operating_mode': operatingMode,
      'p_legacy_sync_status': legacySyncStatus,
      'p_properties': properties ?? const <String, dynamic>{},
      'p_replace_existing_parent': replaceExistingParent,
    });
  }

  Future<NetworkMutationResult> updateConnection({
    required String revisionId,
    required int expectedLockVersion,
    required String connectionId,
    String? connectionKind,
    String? waterType,
    String? transportMode,
    String? operatingMode,
    int? priority,
    bool? normallyOpen,
    Map<String, dynamic>? properties,
    String? legacySyncStatus,
    bool allowBreakLegacySync = false,
  }) {
    return _mutate('update_connection', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_connection_id': connectionId,
      'p_connection_kind': connectionKind,
      'p_water_type': waterType,
      'p_transport_mode': transportMode,
      'p_operating_mode': operatingMode,
      'p_priority': priority,
      'p_normally_open': normallyOpen,
      'p_properties': properties,
      'p_legacy_sync_status': legacySyncStatus,
      'p_allow_break_legacy_sync': allowBreakLegacySync,
    });
  }

  Future<NetworkMutationResult> disconnectConnection({
    required String revisionId,
    required int expectedLockVersion,
    required String connectionId,
  }) {
    return _mutate('disconnect_ports', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_connection_id': connectionId,
    });
  }

  Future<NetworkMutationResult> removeAssetFromView({
    required String revisionId,
    required int expectedLockVersion,
    required String viewId,
    required String nodeId,
  }) {
    return _mutate('remove_asset_from_view', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_view_id': viewId,
      'p_node_id': nodeId,
    });
  }

  Future<NetworkMutationResult> removeAssetFromRevision({
    required String revisionId,
    required int expectedLockVersion,
    required String nodeId,
  }) {
    return _mutate('remove_asset_from_revision', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_node_id': nodeId,
    });
  }

  Future<NetworkMutationResult> createNetworkView({
    required String revisionId,
    required int expectedLockVersion,
    required String code,
    required String nameEn,
    required String nameAr,
    required String viewKind,
    String? facilityAreaId,
    int sortOrder = 0,
    bool isDefault = false,
  }) {
    return _mutate('create_network_view', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_view_kind': viewKind,
      'p_facility_area_id': facilityAreaId,
      'p_sort_order': sortOrder,
      'p_is_default': isDefault,
    });
  }

  Future<NetworkMutationResult> updateNetworkView({
    required String revisionId,
    required int expectedLockVersion,
    required String viewId,
    String? code,
    String? nameEn,
    String? nameAr,
    String? viewKind,
    String? facilityAreaId,
    int? sortOrder,
    bool? isDefault,
    bool clearFacilityArea = false,
  }) {
    return _mutate('update_network_view', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_view_id': viewId,
      'p_code': code,
      'p_name_en': nameEn,
      'p_name_ar': nameAr,
      'p_view_kind': viewKind,
      'p_facility_area_id': facilityAreaId,
      'p_sort_order': sortOrder,
      'p_is_default': isDefault,
      'p_clear_facility_area': clearFacilityArea,
    });
  }

  Future<NetworkMutationResult> deleteNetworkView({
    required String revisionId,
    required int expectedLockVersion,
    required String viewId,
    String? replacementDefaultViewId,
  }) {
    return _mutate('delete_network_view', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_view_id': viewId,
      'p_replacement_default_view_id': replacementDefaultViewId,
    });
  }

  Future<NetworkMutationResult> batchMoveViewNodes({
    required String revisionId,
    required int expectedLockVersion,
    required String viewId,
    required List<UtilityViewNode> positions,
  }) {
    return _mutate('batch_update_view_positions', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_view_id': viewId,
      'p_positions': positions.map((e) => e.toRpcPosition()).toList(),
    });
  }

  Future<
    ({
      bool ok,
      List<NetworkValidationIssue> errors,
      List<NetworkValidationIssue> warnings,
    })
  >
  validateDraft(String revisionId) async {
    final raw = await _rpcMap('validate_network_draft', {
      'p_revision_id': revisionId,
    });
    List<NetworkValidationIssue> parseIssues(dynamic v) => (v is List)
        ? v
              .map(
                (e) => NetworkValidationIssue.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
        : const [];
    return (
      ok: raw['ok'] == true,
      errors: parseIssues(raw['errors']),
      warnings: parseIssues(raw['warnings']),
    );
  }

  Future<NetworkMutationResult> publishDraft({
    required String revisionId,
    required int expectedLockVersion,
    bool allowWarnings = true,
  }) {
    return _mutate('publish_network_draft', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_allow_warnings': allowWarnings,
    });
  }

  Future<Map<String, dynamic>> importLegacyDryRun({
    required String siteId,
    required String categoryId,
    String? networkId,
  }) {
    return _rpcMap('import_legacy_network_dry_run', {
      'p_site_id': siteId,
      'p_category_id': categoryId,
      'p_network_id': networkId,
    });
  }

  Future<Map<String, dynamic>> importLegacyApply({
    required String revisionId,
    required int expectedLockVersion,
    required String siteId,
  }) {
    return _rpcMap('import_legacy_network_apply', {
      'p_revision_id': revisionId,
      'p_expected_lock_version': expectedLockVersion,
      'p_site_id': siteId,
    }, expectedLockVersion: expectedLockVersion);
  }

  Future<Map<String, dynamic>> reconcileLegacy({
    required String networkId,
    String? revisionId,
  }) {
    return _rpcMap('reconcile_legacy_network', {
      'p_network_id': networkId,
      'p_revision_id': revisionId,
    });
  }

  Future<Map<String, dynamic>> finalizeLegacyCutover({
    required String networkId,
    required String siteId,
    required bool confirm,
    String? notes,
    bool acknowledgeValidationErrors = false,
  }) {
    return _rpcMap('finalize_legacy_network_cutover', {
      'p_network_id': networkId,
      'p_site_id': siteId,
      'p_confirm': confirm,
      'p_notes': notes,
      'p_acknowledge_validation_errors': acknowledgeValidationErrors,
    });
  }

  Future<Map<String, dynamic>> getLegacyWriteStatus({
    required String siteId,
    required String categoryId,
  }) {
    return _rpcMap('get_legacy_write_status', {
      'p_site_id': siteId,
      'p_category_id': categoryId,
    });
  }

  Future<NetworkMutationResult> _mutate(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final expected = params['p_expected_lock_version'];
    final raw = await _rpcMap(
      fn,
      params,
      expectedLockVersion: expected is int ? expected : null,
    );
    return NetworkMutationResult.fromJson(raw);
  }

  Future<Map<String, dynamic>> _rpcMap(
    String fn,
    Map<String, dynamic> params, {
    int? expectedLockVersion,
  }) async {
    try {
      final result = await _client.rpc(fn, params: params);
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      throw NetworkRpcError('Unexpected RPC payload from $fn');
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e, expectedLockVersion: expectedLockVersion);
    } catch (e) {
      if (e is UtilityNetworkException) rethrow;
      throw NetworkRpcError(e.toString(), cause: e);
    }
  }

  UtilityNetworkException _mapPostgrest(
    PostgrestException e, {
    int? expectedLockVersion,
  }) {
    final msg = e.message;
    final code = e.code;
    if (code == '40001' || msg.contains('version conflict')) {
      return NetworkVersionConflict(
        expectedLockVersion: expectedLockVersion ?? 0,
        message: msg,
        cause: e,
      );
    }
    if (code == '42501' || msg.toLowerCase().contains('not allowed')) {
      return NetworkPermissionError(msg, e);
    }
    if (msg.toLowerCase().contains('parent conflict')) {
      return NetworkParentConflictError(msg, e);
    }
    if (msg.toLowerCase().contains('not found')) {
      return NetworkNotFoundError(msg, e);
    }
    return NetworkRpcError(msg, cause: e);
  }
}

/// Exposed for unit tests: maps Postgrest-like messages without a client.
UtilityNetworkException mapUtilityNetworkErrorMessage(
  String message, {
  String? code,
  int? expectedLockVersion,
}) {
  if (code == '40001' || message.contains('version conflict')) {
    return NetworkVersionConflict(
      expectedLockVersion: expectedLockVersion ?? 0,
      message: message,
    );
  }
  if (code == '42501' || message.toLowerCase().contains('not allowed')) {
    return NetworkPermissionError(message);
  }
  if (message.toLowerCase().contains('parent conflict')) {
    return NetworkParentConflictError(message);
  }
  if (message.toLowerCase().contains('not found')) {
    return NetworkNotFoundError(message);
  }
  return NetworkRpcError(message);
}

/// Ensures repository source does not contain direct multi-table draft writes.
/// Used by tests as a static contract check.
bool utilityNetworkRepositoryUsesRpcOnly(String repositorySource) {
  // Strip this helper so its example strings are not false positives.
  final body = repositorySource.replaceAll(
    RegExp(r'bool utilityNetworkRepositoryUsesRpcOnly[\s\S]*?\n\}'),
    '',
  );
  final forbidden = <String>[
    "from('site_utility_revision_connections')",
    "from('site_utility_revision_nodes')",
    "from('site_utility_assets')",
    "from('site_utility_asset_ports')",
    "from('meters')",
  ];
  final hasDirectTable = forbidden.any(body.contains);
  final usesRpc = body.contains('.rpc(');
  return usesRpc && !hasDirectTable;
}
