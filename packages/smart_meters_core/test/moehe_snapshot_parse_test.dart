import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('parses MOEHE draft snapshot without throwing', () {
    final file = File(
      '/Users/ali-laptop/Downloads/smart-meters-platform/docs/phase_c/moehe_draft_snapshot.json',
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
