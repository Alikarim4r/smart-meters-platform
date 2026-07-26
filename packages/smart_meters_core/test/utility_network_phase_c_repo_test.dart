import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('parses phase C list summary', () {
    final summary = UtilityNetworkSummary.fromJson({
      'network_id': 'net-1',
      'category_id': 'water',
      'code': 'water-campus',
      'name_en': 'Campus water',
      'name_ar': 'مياه المجمع',
      'status': 'draft',
      'member_count': 1,
      'default_view_id': 'campus',
    });
    expect(summary.id, 'net-1');
    expect(summary.memberCount, 1);
    expect(summary.defaultViewId, 'campus');
  });

  test('not published response maps to typed error contract', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    expect(source.contains("raw['status'] == 'not_published'"), isTrue);
    expect(source.contains('NetworkNotPublishedError'), isTrue);
    expect(source.contains('NetworkNoDraftError'), isTrue);
  });

  test('legacy apply sends revision lock and site only', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    final apply = RegExp(
      r'Future<Map<String, dynamic>> importLegacyApply[\s\S]*?Future<Map<String, dynamic>> reconcileLegacy',
    ).firstMatch(source)!.group(0)!;
    expect(apply.contains('p_revision_id'), isTrue);
    expect(apply.contains('p_expected_lock_version'), isTrue);
    expect(apply.contains('p_site_id'), isTrue);
    expect(apply.contains('p_category_id'), isFalse);
  });

  test('repository never dual-writes legacy 031 tables', () {
    final source = File(
      'lib/repositories/utility_network_repository.dart',
    ).readAsStringSync();
    expect(source.contains('site_network_nodes'), isFalse);
    expect(source.contains('site_network_edges'), isFalse);
    expect(source.contains(".from('"), isFalse);
  });

  test('dry-run plan summary counts actions without mutation side effects', () {
    final summary = LegacyImportPlanSummary.fromPlan({
      'legacy_nodes': 10,
      'legacy_edges': 8,
      'existing_mapped_assets': 2,
      'actions': [
        {'action': 'add_meter_asset'},
        {'action': 'add_meter_asset'},
        {'action': 'add_tank_asset'},
        {'action': 'add_discharge_point'},
        {'action': 'add_tanker_loading'},
        {'action': 'add_connection'},
        {'action': 'add_connection'},
        {'action': 'skipped', 'reason': 'meter_asset_exists'},
        {'action': 'conflict'},
      ],
    });
    expect(summary.metersToAdd, 2);
    expect(summary.tanksToAdd, 1);
    expect(summary.drainsToAdd, 1);
    expect(summary.tankersToAdd, 1);
    expect(summary.connectionsToAdd, 2);
    expect(summary.skipped, 1);
    expect(summary.conflicts, 1);
    expect(summary.totalAdds, 7);
  });
}
