import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/site_network.dart';

class SiteNetworkRepository {
  SiteNetworkRepository(this._client);

  final SupabaseClient _client;

  static const _nodeSelect = '''
*,
meters(meter_code, name_en, name_ar, level, parent_meter_id),
site_tanks(name_en, name_ar)
''';

  Future<SiteNetworkGraph> getGraph({
    required String siteId,
    required String categoryId,
  }) async {
    final nodeRows = await _client
        .from('site_network_nodes')
        .select(_nodeSelect)
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .eq('is_active', true);
    final edgeRows = await _client
        .from('site_network_edges')
        .select()
        .eq('site_id', siteId)
        .eq('category_id', categoryId);
    final viewportRows = await _client
        .from('site_network_viewport')
        .select()
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .maybeSingle();

    final nodes = (nodeRows as List)
        .map(
          (r) => SiteNetworkNode.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    final edges = (edgeRows as List)
        .map(
          (r) => SiteNetworkEdge.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
    SiteNetworkViewport? viewport;
    if (viewportRows != null) {
      viewport = SiteNetworkViewport.fromJson(
        Map<String, dynamic>.from(viewportRows),
      );
    }
    return SiteNetworkGraph(nodes: nodes, edges: edges, viewport: viewport);
  }

  Future<Map<String, dynamic>> importFromMeters({
    required String siteId,
    required String categoryId,
  }) async {
    final result = await _client.rpc(
      'import_site_utility_network',
      params: {'p_site_id': siteId, 'p_category_id': categoryId},
    );
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {'nodes': 0, 'edges': 0};
  }

  Future<SiteNetworkNode> upsertMeterNode({
    required String siteId,
    required String categoryId,
    required String meterId,
    required double posX,
    required double posY,
  }) async {
    final existing = await _client
        .from('site_network_nodes')
        .select(_nodeSelect)
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .eq('ref_meter_id', meterId)
        .eq('is_active', true)
        .maybeSingle();
    if (existing != null) {
      final row = await _client
          .from('site_network_nodes')
          .update({'pos_x': posX, 'pos_y': posY})
          .eq('id', existing['id'] as String)
          .select(_nodeSelect)
          .single();
      return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
    }
    final row = await _client
        .from('site_network_nodes')
        .insert({
          'site_id': siteId,
          'category_id': categoryId,
          'kind': NetworkNodeKind.meter.dbValue,
          'ref_meter_id': meterId,
          'pos_x': posX,
          'pos_y': posY,
        })
        .select(_nodeSelect)
        .single();
    return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SiteNetworkNode> upsertTankNode({
    required String siteId,
    required String categoryId,
    required String tankId,
    required double posX,
    required double posY,
  }) async {
    final existing = await _client
        .from('site_network_nodes')
        .select(_nodeSelect)
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .eq('ref_tank_id', tankId)
        .eq('is_active', true)
        .maybeSingle();
    if (existing != null) {
      final row = await _client
          .from('site_network_nodes')
          .update({'pos_x': posX, 'pos_y': posY})
          .eq('id', existing['id'] as String)
          .select(_nodeSelect)
          .single();
      return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
    }
    final row = await _client
        .from('site_network_nodes')
        .insert({
          'site_id': siteId,
          'category_id': categoryId,
          'kind': NetworkNodeKind.tank.dbValue,
          'ref_tank_id': tankId,
          'pos_x': posX,
          'pos_y': posY,
        })
        .select(_nodeSelect)
        .single();
    return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SiteNetworkNode> createDischargeNode({
    required String siteId,
    required String categoryId,
    required NetworkNodeKind kind,
    required String labelEn,
    String? labelAr,
    required double posX,
    required double posY,
  }) async {
    assert(
      kind == NetworkNodeKind.tankerDischarge ||
          kind == NetworkNodeKind.groundDrain,
    );
    final row = await _client
        .from('site_network_nodes')
        .insert({
          'site_id': siteId,
          'category_id': categoryId,
          'kind': kind.dbValue,
          'label_en': labelEn.trim(),
          'label_ar': (labelAr == null || labelAr.trim().isEmpty)
              ? labelEn.trim()
              : labelAr.trim(),
          'pos_x': posX,
          'pos_y': posY,
        })
        .select(_nodeSelect)
        .single();
    return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SiteNetworkNode> updateNodePosition({
    required String nodeId,
    required double posX,
    required double posY,
  }) async {
    final row = await _client
        .from('site_network_nodes')
        .update({'pos_x': posX, 'pos_y': posY})
        .eq('id', nodeId)
        .select(_nodeSelect)
        .single();
    return SiteNetworkNode.fromJson(Map<String, dynamic>.from(row));
  }

  Future<SiteNetworkEdge> createEdge({
    required String siteId,
    required String categoryId,
    required String fromNodeId,
    required String toNodeId,
    required NetworkEdgeKind edgeKind,
    SiteNetworkNode? fromNode,
    SiteNetworkNode? toNode,
  }) async {
    final row = await _client
        .from('site_network_edges')
        .insert({
          'site_id': siteId,
          'category_id': categoryId,
          'from_node_id': fromNodeId,
          'to_node_id': toNodeId,
          'edge_kind': edgeKind.dbValue,
        })
        .select()
        .single();
    final edge = SiteNetworkEdge.fromJson(Map<String, dynamic>.from(row));
    await _syncLegacyLinks(edge: edge, fromNode: fromNode, toNode: toNode);
    return edge;
  }

  Future<void> deleteEdge(String edgeId) async {
    await _client.from('site_network_edges').delete().eq('id', edgeId);
  }

  /// Soft-remove discharge nodes; meter/tank nodes stay (unlink edges instead).
  Future<void> deleteNode(String nodeId) async {
    final node = await _client
        .from('site_network_nodes')
        .select()
        .eq('id', nodeId)
        .maybeSingle();
    if (node == null) return;
    final kind = node['kind'] as String?;
    if (kind == NetworkNodeKind.tankerDischarge.dbValue ||
        kind == NetworkNodeKind.groundDrain.dbValue) {
      await _client.from('site_network_nodes').delete().eq('id', nodeId);
      return;
    }
    await _client
        .from('site_network_edges')
        .delete()
        .eq('from_node_id', nodeId);
    await _client.from('site_network_edges').delete().eq('to_node_id', nodeId);
    await _client
        .from('site_network_nodes')
        .update({'is_active': false})
        .eq('id', nodeId);
  }

  Future<void> saveViewport(SiteNetworkViewport viewport) async {
    await _client.from('site_network_viewport').upsert({
      'site_id': viewport.siteId,
      'category_id': viewport.categoryId,
      'scale': viewport.scale,
      'offset_x': viewport.offsetX,
      'offset_y': viewport.offsetY,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Deprecated: v2 utility network is the sole source of meter relationships.
  /// Intentionally a no-op — do not dual-write parent_meter_id / pours_into_tank.
  Future<void> _syncLegacyLinks({
    required SiteNetworkEdge edge,
    SiteNetworkNode? fromNode,
    SiteNetworkNode? toNode,
  }) async {
    return;
  }
}
