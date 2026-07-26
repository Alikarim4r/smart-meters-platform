import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

Map<String, dynamic> _draftSnapshotJson() => {
  'network': {
    'id': 'net-1',
    'code': 'campus-water',
    'name_en': 'Campus',
    'name_ar': 'مجمع',
    'category_id': 'cat-water',
    'draft_revision_id': 'rev-draft',
    'published_revision_id': 'rev-pub',
  },
  'revision': {
    'id': 'rev-draft',
    'network_id': 'net-1',
    'status': 'draft',
    'lock_version': 4,
  },
  'members': [
    {'site_id': 'site-1'},
  ],
  'views': [
    {
      'id': 'view-1',
      'code': 'campus_overview',
      'name_en': 'Campus',
      'name_ar': 'مجمع',
      'is_default': true,
    },
  ],
  'nodes': [
    {
      'node_id': 'node-ro',
      'asset_id': 'asset-ro',
      'site_id': 'site-1',
      'asset_type': 'treatment_unit',
      'service_type': 'ro_product',
      'code': 'RO-1',
      'name_en': 'RO',
      'name_ar': 'تناضح',
      'ports': [
        {'id': 'p1', 'code': 'inlet', 'direction': 'in', 'port_role': 'inlet'},
        {
          'id': 'p2',
          'code': 'product',
          'direction': 'out',
          'port_role': 'product',
        },
        {
          'id': 'p3',
          'code': 'reject',
          'direction': 'out',
          'port_role': 'reject',
        },
      ],
    },
    {
      'node_id': 'node-tank',
      'asset_id': 'asset-tank',
      'site_id': 'site-1',
      'asset_type': 'tank',
      'code': 'T-1',
      'name_en': 'Tank',
      'name_ar': 'خزان',
      'ports': [
        {'id': 't1', 'code': 'inlet', 'direction': 'in', 'port_role': 'inlet'},
        {
          'id': 't2',
          'code': 'outlet',
          'direction': 'out',
          'port_role': 'outlet',
        },
        {
          'id': 't3',
          'code': 'overflow',
          'direction': 'out',
          'port_role': 'overflow',
        },
        {
          'id': 't4',
          'code': 'washout',
          'direction': 'out',
          'port_role': 'washout',
        },
        {'id': 't5', 'code': 'drain', 'direction': 'out', 'port_role': 'drain'},
      ],
    },
  ],
  'connections': [
    {
      'id': 'c1',
      'from_node_id': 'node-ro',
      'from_port_id': 'p2',
      'to_node_id': 'node-tank',
      'to_port_id': 't1',
      'connection_kind': 'transfer',
      'transport_mode': 'pipe',
      'operating_mode': 'normal',
      'legacy_sync_status': 'graph_only',
      'is_consumptive': true,
    },
  ],
  'placements': [
    {'view_id': 'view-1', 'node_id': 'node-ro', 'pos_x': 10, 'pos_y': 20},
  ],
};

Map<String, dynamic> _publishedSnapshotJson() {
  final j = _draftSnapshotJson();
  j['revision'] = {
    'id': 'rev-pub',
    'network_id': 'net-1',
    'status': 'published',
    'lock_version': 1,
    'published_at': '2026-07-01T00:00:00Z',
  };
  return j;
}

void main() {
  test('parses draft snapshot', () {
    final snap = UtilityNetworkSnapshot.fromJson(_draftSnapshotJson());
    expect(snap.revision.isDraft, isTrue);
    expect(snap.revision.lockVersion, 4);
    expect(snap.nodes, hasLength(2));
    expect(snap.connections, hasLength(1));
    expect(snap.placements.first.posX, 10);
  });

  test('parses published snapshot', () {
    final snap = UtilityNetworkSnapshot.fromJson(_publishedSnapshotJson());
    expect(snap.revision.isPublished, isTrue);
    expect(snap.revision.id, 'rev-pub');
  });

  test('RO asset has inlet/product/reject ports', () {
    final snap = UtilityNetworkSnapshot.fromJson(_draftSnapshotJson());
    final ro = snap.nodes.firstWhere((n) => n.asset?.code == 'RO-1').asset!;
    expect(ro.assetType, UtilityAssetType.treatmentUnit);
    expect(ro.ports.map((p) => p.portRole.dbValue).toSet(), {
      'inlet',
      'product',
      'reject',
    });
  });

  test('tank asset has overflow/washout/drain ports', () {
    final snap = UtilityNetworkSnapshot.fromJson(_draftSnapshotJson());
    final tank = snap.nodes.firstWhere((n) => n.asset?.code == 'T-1').asset!;
    expect(
      tank.ports.map((p) => p.portRole.dbValue).toSet(),
      containsAll(['overflow', 'washout', 'drain']),
    );
  });

  test('available meter states', () {
    expect(
      AvailableNetworkMeter.fromJson({
        'meter_id': 'm1',
        'site_id': 's1',
        'meter_code': 'A',
        'name_en': 'A',
        'name_ar': 'أ',
        'availability_status': 'not_in_network',
      }).state,
      AvailableMeterState.notInNetwork,
    );
    expect(
      AvailableNetworkMeter.fromJson({
        'meter_id': 'm1',
        'site_id': 's1',
        'meter_code': 'A',
        'name_en': 'A',
        'name_ar': 'أ',
        'availability_status': 'in_network_not_in_current_view',
        'asset_id': 'a1',
        'node_id': 'n1',
      }).state,
      AvailableMeterState.inNetworkNotInCurrentView,
    );
    expect(
      AvailableNetworkMeter.fromJson({
        'meter_id': 'm1',
        'site_id': 's1',
        'meter_code': 'A',
        'name_en': 'A',
        'name_ar': 'أ',
        'availability_status': 'in_current_view',
        'view_node_id': 'vn1',
      }).state,
      AvailableMeterState.inCurrentView,
    );
  });

  test('unknown lookup does not throw', () {
    final t = UtilityAssetType.parse('future_valve');
    expect(t.isKnown, isFalse);
    expect(t.dbValue, 'future_valve');
    final kind = UtilityConnectionKind.parse('hyperloop');
    expect(kind.isKnown, isFalse);
  });

  test('maps stale version to NetworkVersionConflict', () {
    final err = mapUtilityNetworkErrorMessage(
      'Network draft version conflict: expected 3, actual 4',
      code: '40001',
      expectedLockVersion: 3,
    );
    expect(err, isA<NetworkVersionConflict>());
    expect((err as NetworkVersionConflict).expectedLockVersion, 3);
  });

  test('maps permission error', () {
    final err = mapUtilityNetworkErrorMessage(
      'Not allowed to manage this utility network',
      code: '42501',
    );
    expect(err, isA<NetworkPermissionError>());
  });

  test('attach params default replaceExistingParent false', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    expect(source.contains('bool replaceExistingParent = false'), isTrue);
  });

  test('create meter supports optional upstream/downstream', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    expect(source.contains('p_upstream_node_id'), isTrue);
    expect(source.contains('p_downstream_node_ids'), isTrue);
    expect(source.contains('p_expected_lock_version'), isTrue);
    expect(source.contains('p_replace_existing_parent'), isTrue);
  });

  test('batch move builds rpc positions', () {
    final n = UtilityViewNode(
      revisionId: 'r',
      viewId: 'v',
      nodeId: 'n',
      posX: 1.5,
      posY: 2.5,
    );
    expect(n.toRpcPosition()['node_id'], 'n');
    expect(n.toRpcPosition()['pos_x'], 1.5);
  });

  test('validation issues parse errors and warnings', () {
    final err = NetworkValidationIssue.fromJson({
      'severity': 'error',
      'code': 'self_loop',
      'message': 'bad',
    });
    final warn = NetworkValidationIssue.fromJson({
      'severity': 'warning',
      'code': 'eng_review',
      'message': 'check',
    });
    expect(err.severity, UtilityValidationSeverity.error);
    expect(warn.severity, UtilityValidationSeverity.warning);
  });

  test('published loader uses explicit published snapshot RPC', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    final publishedFn = RegExp(
      r'Future<UtilityNetworkSnapshot> getPublishedSnapshot[\s\S]*?Future<',
    ).firstMatch(source)!.group(0)!;
    expect(publishedFn.contains('ensure_network_draft'), isFalse);
    expect(publishedFn.contains('get_published_network_snapshot'), isTrue);
  });

  test('draft loader uses explicit draft snapshot RPC without mutation', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    final draftFn = RegExp(
      r'Future<UtilityNetworkSnapshot> getDraftSnapshot\([\s\S]*?Future<UtilityNetworkSnapshot> getDraftSnapshotByRevision',
    ).firstMatch(source)!.group(0)!;
    expect(draftFn.contains('get_draft_network_snapshot'), isTrue);
    expect(draftFn.contains('ensure_network_draft'), isFalse);
  });

  test('repository has no direct multi-table draft writes', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    expect(utilityNetworkRepositoryUsesRpcOnly(source), isTrue);
  });

  test('mutation result carries lock_version', () {
    final r = NetworkMutationResult.fromJson({
      'lock_version': 9,
      'status': 'already_in_current_view',
      'meter_id': 'm1',
    });
    expect(r.lockVersion, 9);
    expect(r.status, 'already_in_current_view');
  });
}
