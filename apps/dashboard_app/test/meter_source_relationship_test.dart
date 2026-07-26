import 'package:dashboard_app/utils/meter_reading_filters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

MeterReadingCardData _card({
  required String id,
  required String code,
  required String sourceCode,
  required String sourceName,
  String? parentMeterId,
  bool isMain = false,
}) {
  return MeterReadingCardData(
    meterId: id,
    meterCode: code,
    meterName: 'Meter $code',
    categoryName: 'Water',
    sourceName: sourceName,
    sourceCode: sourceCode,
    unitLabel: 'm³',
    status: MeterReadingCardStatus.submittedOnDate,
    isActive: true,
    isMain: isMain,
    parentMeterId: parentMeterId,
    latestValue: 100,
    previousValue: 90,
    consumptionValue: 10,
  );
}

void main() {
  group('water source grouping', () {
    final cards = [
      _card(id: '1', code: 'K1', sourceCode: 'kahramaa', sourceName: 'Kahramaa'),
      _card(id: '2', code: 'T1', sourceCode: 'tse', sourceName: 'TSE'),
      _card(id: '3', code: 'R1', sourceCode: 'ro', sourceName: 'RO'),
    ];

    test('Kahramaa and TSE separated by group key', () {
      expect(waterSourceGroupKey(cards[0]), 'kahramaa');
      expect(waterSourceGroupKey(cards[1]), 'tse');
      expect(waterSourceGroupKey(cards[0]), isNot(waterSourceGroupKey(cards[1])));
    });

    test('filter by Kahramaa chip', () {
      final filtered = filterCardsByWaterSourceChip(
        cards: cards,
        chip: WaterSourceChip.kahramaa,
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.meterCode, 'K1');
    });

    test('grouped sections when all sources', () {
      final grouped = groupCardsByWaterSource(cards);
      expect(grouped.keys, containsAll(['kahramaa', 'tse', 'ro']));
      expect(grouped['kahramaa']!.first.meterCode, 'K1');
    });
  });

  group('relationship view', () {
    test('does not nest by deprecated parent_meter_id (flat v2-era list)', () {
      final main = _card(
        id: 'main',
        code: '1219053',
        sourceCode: 'kahramaa',
        sourceName: 'Kahramaa',
        isMain: true,
      );
      final sub = _card(
        id: 'sub',
        code: '1219054',
        sourceCode: 'kahramaa',
        sourceName: 'Kahramaa',
        parentMeterId: 'main',
      );
      final groups = buildMeterRelationshipGroups([main, sub]);
      expect(groups, hasLength(2));
      expect(groups.every((g) => g.children.isEmpty), isTrue);
      expect(groups.map((g) => g.parent.meterCode), containsAll(['1219053', '1219054']));
    });

    test('orphan meters still render as roots', () {
      final orphan = _card(
        id: 'o1',
        code: 'O1',
        sourceCode: 'tse',
        sourceName: 'TSE',
      );
      final groups = buildMeterRelationshipGroups([orphan]);
      expect(groups, hasLength(1));
      expect(groups.first.parent.meterCode, 'O1');
      expect(groups.first.children, isEmpty);
    });
  });

  group('photo button state', () {
    test('enabled only when photo path exists', () {
      expect(
        photoButtonEnabled(hasPhoto: true, storagePath: 'path.jpg'),
        isTrue,
      );
      expect(
        photoButtonEnabled(hasPhoto: true, storagePath: null),
        isFalse,
      );
      expect(
        photoButtonEnabled(hasPhoto: false, storagePath: 'path.jpg'),
        isFalse,
      );
    });
  });
}
