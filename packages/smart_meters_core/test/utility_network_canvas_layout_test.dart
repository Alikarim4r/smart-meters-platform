import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

UtilityNetworkSnapshot _snap({
  required List<Map<String, dynamic>> nodes,
  required List<Map<String, dynamic>> connections,
  required List<Map<String, dynamic>> placements,
  List<Map<String, dynamic>>? views,
}) {
  return UtilityNetworkSnapshot.fromJson({
    'network': {
      'id': 'n',
      'category_id': 'c',
      'code': 'water',
      'name_en': 'Water',
      'name_ar': 'ماء',
    },
    'revision': {
      'id': 'r',
      'network_id': 'n',
      'status': 'draft',
      'lock_version': 1,
    },
    'views':
        views ??
        [
          {
            'id': 'campus',
            'network_id': 'n',
            'code': 'campus',
            'name_en': 'Campus',
            'name_ar': 'المجمع',
            'is_default': true,
          },
        ],
    'nodes': nodes,
    'connections': connections,
    'placements': placements,
  });
}

Map<String, dynamic> _node(
  String id,
  String type, {
  List<Map<String, dynamic>> ports = const [],
}) => {
  'id': id,
  'revision_id': 'r',
  'asset_id': 'a-$id',
  'asset': {
    'id': 'a-$id',
    'site_id': 's',
    'asset_type': type,
    'code': type.toUpperCase(),
    'name_en': type,
    'name_ar': type,
    'ports': ports,
  },
};

Map<String, dynamic> _conn(
  String id,
  String from,
  String to, {
  String kind = 'supply',
  String? waterType,
  String transport = 'piped',
}) => {
  'id': id,
  'revision_id': 'r',
  'from_node_id': from,
  'from_port_id': 'p1',
  'to_node_id': to,
  'to_port_id': 'p2',
  'connection_kind': kind,
  'transport_mode': transport,
  'operating_mode': 'normal',
  'legacy_sync_status': 'graph_only',
  'water_type': waterType,
};

Map<String, dynamic> _place(
  String nodeId,
  double x,
  double y, {
  String view = 'campus',
}) => {
  'revision_id': 'r',
  'view_id': view,
  'node_id': nodeId,
  'pos_x': x,
  'pos_y': y,
};

void main() {
  test('fit bounds includes placed node dimensions and padding', () {
    final snapshot = _snap(
      nodes: [_node('a', 'meter'), _node('b', 'meter')],
      connections: const [],
      placements: [_place('a', 100, 200), _place('b', 400, 500)],
    );
    final bounds = utilityNetworkFitBounds(snapshot, 'campus', padding: 20);
    expect(bounds.left, 80);
    expect(bounds.top, 180);
    expect(bounds.right, 590);
    expect(bounds.bottom, 606);
  });

  test('fit matrix keeps readable min scale', () {
    final m = utilityNetworkFitMatrix(
      contentBounds: const Rect.fromLTWH(0, 0, 4000, 3000),
      viewport: const Size(800, 600),
      minScale: 0.55,
    );
    expect(m.getMaxScaleOnAxis(), greaterThanOrEqualTo(0.55));
  });

  test('sequential meters draw as one connection', () {
    final snap = _snap(
      nodes: [_node('m1', 'meter'), _node('m2', 'meter')],
      connections: [_conn('c1', 'm1', 'm2')],
      placements: [_place('m1', 0, 0), _place('m2', 200, 0)],
    );
    expect(utilityNetworkNodesForView(snap, 'campus'), hasLength(2));
    expect(utilityNetworkConnectionsForView(snap, 'campus'), hasLength(1));
  });

  test('parallel branches keep two edges to same parent', () {
    final snap = _snap(
      nodes: [_node('p', 'meter'), _node('a', 'meter'), _node('b', 'meter')],
      connections: [_conn('c1', 'p', 'a'), _conn('c2', 'p', 'b')],
      placements: [
        _place('p', 0, 100),
        _place('a', 200, 0),
        _place('b', 200, 200),
      ],
    );
    expect(utilityNetworkConnectionsForView(snap, 'campus'), hasLength(2));
  });

  test('tank overflow and washout to same drain are dashed', () {
    final snap = _snap(
      nodes: [
        _node(
          't',
          'tank',
          ports: [
            {
              'id': 'in',
              'asset_id': 'a-t',
              'code': 'in',
              'direction': 'in',
              'port_role': 'inlet',
            },
            {
              'id': 'ov',
              'asset_id': 'a-t',
              'code': 'overflow',
              'direction': 'out',
              'port_role': 'overflow',
            },
            {
              'id': 'wo',
              'asset_id': 'a-t',
              'code': 'washout',
              'direction': 'out',
              'port_role': 'washout',
            },
          ],
        ),
        _node('d', 'discharge_point'),
      ],
      connections: [
        _conn('c1', 't', 'd', kind: 'overflow'),
        _conn('c2', 't', 'd', kind: 'washout'),
      ],
      placements: [_place('t', 0, 0), _place('d', 300, 0)],
    );
    final edges = utilityNetworkConnectionsForView(snap, 'campus');
    expect(edges, hasLength(2));
    expect(edges.every(utilityNetworkConnectionIsDashed), isTrue);
  });

  test('RO product and reject outlets', () {
    final snap = _snap(
      nodes: [
        _node('ro', 'treatment_unit'),
        _node('prod', 'meter'),
        _node('rej', 'discharge_point'),
      ],
      connections: [
        _conn('c1', 'ro', 'prod', waterType: 'product'),
        _conn('c2', 'ro', 'rej', waterType: 'reject'),
      ],
      placements: [
        _place('ro', 0, 0),
        _place('prod', 200, -40),
        _place('rej', 200, 40),
      ],
    );
    final edges = utilityNetworkConnectionsForView(snap, 'campus');
    expect(edges.map((e) => e.waterType).toSet(), {'product', 'reject'});
  });

  test('tanker transport is dashed', () {
    final snap = _snap(
      nodes: [_node('a', 'tanker_loading'), _node('b', 'tank')],
      connections: [
        _conn(
          'c1',
          'a',
          'b',
          kind: 'tanker_transport',
          transport: 'tanker_transport',
        ),
      ],
      placements: [_place('a', 0, 0), _place('b', 250, 0)],
    );
    expect(
      utilityNetworkConnectionIsDashed(
        utilityNetworkConnectionsForView(snap, 'campus').single,
      ),
      isTrue,
    );
  });

  test('same asset can appear in two views without duplicating nodes', () {
    final snap = _snap(
      nodes: [_node('m1', 'meter')],
      connections: const [],
      placements: [
        _place('m1', 10, 10, view: 'campus'),
        _place('m1', 50, 50, view: 'building-a'),
      ],
      views: [
        {
          'id': 'campus',
          'network_id': 'n',
          'code': 'campus',
          'name_en': 'Campus',
          'name_ar': 'المجمع',
          'is_default': true,
        },
        {
          'id': 'building-a',
          'network_id': 'n',
          'code': 'b1',
          'name_en': 'Building A',
          'name_ar': 'مبنى أ',
        },
      ],
    );
    expect(snap.nodes, hasLength(1));
    expect(utilityNetworkNodesForView(snap, 'campus'), hasLength(1));
    expect(utilityNetworkNodesForView(snap, 'building-a'), hasLength(1));
    expect(
      utilityNetworkFitBounds(snap, 'campus').left,
      isNot(utilityNetworkFitBounds(snap, 'building-a').left),
    );
  });
}
