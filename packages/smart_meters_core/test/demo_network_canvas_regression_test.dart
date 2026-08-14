import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'support/demo_snapshot.dart';

void main() {
  late UtilityNetworkSnapshot demo;

  setUpAll(() {
    final file = demoSnapshotFile();
    demo = UtilityNetworkSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
    );
  });

  test('demo snapshot parse never throws TypeError', () {
    expect(demo.nodes, isNotEmpty);
    expect(demo.placements, isNotEmpty);
    expect(demo.revision.isDraft, isTrue);
    for (final n in demo.nodes) {
      expect(n.asset, isNotNull);
    }
  });

  testWidgets('demo canvas paints without FlutterError / TypeError', (
    tester,
  ) async {
    final errors = <Object>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    final viewId = demo.views.where((v) => v.isDefault).firstOrNull?.id ??
        demo.views.first.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: UtilityNetworkCanvas(
              snapshot: demo,
              viewId: viewId,
              isArabic: true,
              editMode: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(errors.whereType<TypeError>(), isEmpty, reason: '$errors');
    expect(errors, isEmpty, reason: 'unexpected FlutterError: $errors');
    expect(find.byType(UtilityNetworkCanvas), findsOneWidget);
  });

  testWidgets('missing placement does not throw null-check TypeError', (
    tester,
  ) async {
    final viewId = demo.views.first.id;
    final orphan = UtilityRevisionNode(
      id: 'orphan-node',
      revisionId: demo.revision.id,
      assetId: 'orphan-asset',
      asset: UtilityAsset(
        id: 'orphan-asset',
        siteId: demo.network.members.first.siteId,
        assetType: UtilityAssetType.meter,
        code: 'ORPHAN',
        nameEn: 'Orphan',
        nameAr: 'يتيم',
      ),
    );
    final snap = demo.copyWith(nodes: [...demo.nodes, orphan]);

    final errors = <Object>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: UtilityNetworkCanvas(
              snapshot: snap,
              viewId: viewId,
              isArabic: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(errors.whereType<TypeError>(), isEmpty, reason: '$errors');
  });

  test('MeterCategoryConfig tolerates num sort_order (TypeError regression)', () {
    final c = MeterCategoryConfig.fromJson({
      'id': 'c1',
      'code': 'water',
      'name_en': 'Water',
      'name_ar': 'ماء',
      'base_unit_code': 'm3',
      'sort_order': 3.0, // JSON/num path that used to throw TypeError
      'is_active': true,
    });
    expect(c.sortOrder, 3);
    expect(c.code, 'water');
  });
}
