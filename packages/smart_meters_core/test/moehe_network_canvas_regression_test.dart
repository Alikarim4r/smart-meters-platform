import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  late UtilityNetworkSnapshot moehe;

  setUpAll(() {
    final file = File(
      '/Users/ali-laptop/Downloads/smart-meters-platform/docs/phase_c/moehe_draft_snapshot.json',
    );
    moehe = UtilityNetworkSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
    );
  });

  test('MOEHE snapshot parse never throws TypeError', () {
    expect(moehe.nodes, isNotEmpty);
    expect(moehe.placements, isNotEmpty);
    expect(moehe.revision.isDraft, isTrue);
    for (final n in moehe.nodes) {
      expect(n.asset, isNotNull);
    }
  });

  testWidgets('MOEHE canvas paints without FlutterError / TypeError', (
    tester,
  ) async {
    final errors = <Object>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exception);
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    final viewId = moehe.views.where((v) => v.isDefault).firstOrNull?.id ??
        moehe.views.first.id;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: UtilityNetworkCanvas(
              snapshot: moehe,
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
    final viewId = moehe.views.first.id;
    final orphan = UtilityRevisionNode(
      id: 'orphan-node',
      revisionId: moehe.revision.id,
      assetId: 'orphan-asset',
      asset: UtilityAsset(
        id: 'orphan-asset',
        siteId: moehe.network.members.first.siteId,
        assetType: UtilityAssetType.meter,
        code: 'ORPHAN',
        nameEn: 'Orphan',
        nameAr: 'يتيم',
      ),
    );
    final snap = moehe.copyWith(nodes: [...moehe.nodes, orphan]);

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
