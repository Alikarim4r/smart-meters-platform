import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  late String repositorySource;

  setUpAll(() {
    repositorySource = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
  });

  test('repository source contains Phase D RPC names', () {
    const expectedRpcs = [
      'list_available_tanks_for_network',
      'attach_existing_tank_to_draft',
      'create_tank_in_network_draft',
      'update_asset',
      'add_asset_port',
      'update_asset_port',
      'remove_asset_port',
      'update_connection',
      'remove_asset_from_view',
      'remove_asset_from_revision',
      'create_network_view',
      'update_network_view',
      'delete_network_view',
      'finalize_legacy_network_cutover',
      'get_legacy_write_status',
    ];
    for (final rpc in expectedRpcs) {
      expect(repositorySource.contains(rpc), isTrue, reason: 'missing $rpc');
    }
  });

  test('repository never writes via site_network table .from()', () {
    expect(repositorySource.contains(".from('site_network"), isFalse);
    expect(repositorySource.contains(".from(\"site_network"), isFalse);
    expect(utilityNetworkRepositoryUsesRpcOnly(repositorySource), isTrue);
  });

  test(
    'LegacyImportPlanSummary.fromPlan uses additions/skipped from server',
    () {
      final summary = LegacyImportPlanSummary.fromPlan({
        'additions': 12,
        'skipped': 4,
        'updates': 2,
        'legacy_nodes': 20,
        'legacy_edges': 15,
        'existing_mapped_assets': 3,
        'actions': [
          {'action': 'add_meter_asset'},
          {'action': 'skipped', 'reason': 'already_mapped'},
        ],
      });
      expect(summary.additions, 12);
      expect(summary.skipped, 4);
      expect(summary.updates, 2);
      expect(summary.totalAdds, 12);
      // Action-derived counters remain available for UI breakdowns.
      expect(summary.metersToAdd, 1);
    },
  );

  test('AvailableNetworkTank parses list_available_tanks payload', () {
    final tank = AvailableNetworkTank.fromJson({
      'tank_id': 'tank-1',
      'site_id': 'site-1',
      'name_en': 'Roof tank',
      'name_ar': 'خزان السطح',
      'is_active': true,
      'asset_id': 'asset-1',
      'asset_code': 'tank-abcd1234',
      'service_type': 'potable',
      'facility_area_id': 'area-1',
      'node_id': 'node-1',
      'availability_status': 'not_in_network',
    });
    expect(tank.tankId, 'tank-1');
    expect(tank.assetCode, 'tank-abcd1234');
    expect(tank.state, AvailableMeterState.notInNetwork);
    expect(tank.revisionNodeId, 'node-1');
  });
}
