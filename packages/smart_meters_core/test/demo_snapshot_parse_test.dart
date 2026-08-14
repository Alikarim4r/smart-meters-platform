import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'support/demo_snapshot.dart';

void main() {
  test('parses the demo network snapshot without throwing', () {
    final file = demoSnapshotFile();
    expect(
      file.existsSync(),
      isTrue,
      reason: 'demo snapshot fixture missing at ${file.path}',
    );

    final snap = UtilityNetworkSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
    );

    expect(snap.nodes, hasLength(7));
    expect(snap.connections, hasLength(5));
    expect(snap.revision.isDraft, isTrue);
    for (final n in snap.nodes) {
      expect(n.asset, isNotNull, reason: n.id);
      expect(n.asset!.code, isNotEmpty);
    }
  });
}
