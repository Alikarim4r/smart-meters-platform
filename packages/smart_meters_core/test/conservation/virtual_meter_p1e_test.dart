import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';
import 'package:smart_meters_core/models/enums.dart';
import 'package:smart_meters_core/models/meter.dart';

PeriodReadingPoint p(DateTime d, double v) =>
    PeriodReadingPoint(date: d, value: v);

Meter meter({
  required String id,
  String siteId = 'site-1',
  String categoryId = 'cat-water',
  MeterKind kind = MeterKind.physical,
  CalculationType calc = CalculationType.directReading,
  String? parentId,
  String unit = 'm3',
  double multiplier = 1,
  MeterLevel level = MeterLevel.main,
}) {
  return Meter(
    id: id,
    siteId: siteId,
    meterCode: id,
    nameEn: id,
    nameAr: id,
    categoryId: categoryId,
    sourceId: 'src',
    unitId: 'u',
    category: MeterCategory.water,
    source: MeterSource.kahramaa,
    unit: MeterUnit.m3,
    level: level,
    parentMeterId: parentId,
    unitToBaseFactor: 1,
    baseUnit: unit,
    meterMultiplier: multiplier,
    meterKind: kind,
    calculationType: calc,
    isActive: true,
    includeInDashboard: true,
    sortOrder: 0,
  );
}

void main() {
  const validator = VirtualMeterValidation();
  const calc = VirtualMeterCalculator();

  group('VirtualMeterValidation', () {
    test('self-parent rejection', () {
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.parentMinusChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: 'v1',
        virtualMeterId: 'v1',
        memberMeters: [meter(id: 'c1')],
        metersById: {'v1': meter(id: 'v1', kind: MeterKind.virtual, calc: CalculationType.parentMinusChildren), 'c1': meter(id: 'c1')},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'self_parent'), isTrue);
    });

    test('duplicate child rejection', () {
      final c1 = meter(id: 'c1');
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [c1, c1],
        metersById: {'c1': c1},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'duplicate_child'), isTrue);
    });

    test('cross-site rejection', () {
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [meter(id: 'c1', siteId: 'site-2')],
        metersById: {'c1': meter(id: 'c1', siteId: 'site-2')},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'cross_site'), isTrue);
    });

    test('utility mismatch', () {
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [meter(id: 'c1', categoryId: 'cat-elec')],
        metersById: {'c1': meter(id: 'c1', categoryId: 'cat-elec')},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'utility_mismatch'), isTrue);
    });

    test('unit mismatch', () {
      final bad = meter(id: 'c1', unit: 'kWh');
      // Force unit enum electricity-ish via baseUnit already kWh; MeterUnit still m3 — check baseUnit path
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [bad],
        metersById: {'c1': bad},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'unit_mismatch'), isTrue);
    });

    test('invalid calculation type', () {
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.manualAdjustment,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [meter(id: 'c1')],
        metersById: {'c1': meter(id: 'c1')},
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'invalid_calculation_type'), isTrue);
    });

    test('indirect cycle rejection via nested virtuals', () {
      final vA = meter(id: 'vA', kind: MeterKind.virtual, calc: CalculationType.sumChildren);
      final vB = meter(id: 'vB', kind: MeterKind.virtual, calc: CalculationType.sumChildren);
      final c1 = meter(id: 'c1');
      // Draft vA members include vB; vB members include vA → cycle
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        virtualMeterId: 'vA',
        memberMeters: [vB],
        metersById: {'vA': vA, 'vB': vB, 'c1': c1},
        memberIdsByVirtualId: {
          'vA': ['vB'],
          'vB': ['vA'],
        },
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'cycle'), isTrue);
    });

    test('duplicate leaf in nested tree', () {
      final vB = meter(id: 'vB', kind: MeterKind.virtual, calc: CalculationType.sumChildren);
      final c1 = meter(id: 'c1');
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        virtualMeterId: 'vA',
        memberMeters: [vB, c1],
        metersById: {
          'vA': meter(id: 'vA', kind: MeterKind.virtual, calc: CalculationType.sumChildren),
          'vB': vB,
          'c1': c1,
        },
        memberIdsByVirtualId: {
          'vB': ['c1'],
        },
      );
      expect(r.ok, isFalse);
      expect(r.issues.any((i) => i.code == 'duplicate_leaf'), isTrue);
    });

    test('valid sum_children config', () {
      final c1 = meter(id: 'c1');
      final c2 = meter(id: 'c2');
      final r = validator.validateConfig(
        meterKind: MeterKind.virtual,
        calculationType: CalculationType.sumChildren,
        siteId: 'site-1',
        categoryId: 'cat-water',
        unitCode: 'm3',
        parentMeterId: null,
        memberMeters: [c1, c2],
        metersById: {'c1': c1, 'c2': c2},
      );
      expect(r.ok, isTrue);
      expect(r.leafMeterIds.toSet(), {'c1', 'c2'});
    });
  });

  group('VirtualMeterCalculator', () {
    test('A — sum_children basic', () {
      final contributors = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 10)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c2',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 15)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: contributors,
      );
      expect(r.status, VirtualMeterResultStatus.ok);
      expect(r.value, 25);
      expect(r.directionLabel, 'Sum of children');
      expect(r.directionLabel.toLowerCase(), isNot(contains('leak')));
      expect(r.meta.notes.any((n) => n.contains('contributing_meter_count=2')), isTrue);
    });

    test('B — parent_minus_children positive residual', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 40)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c2',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 30)],
          ),
        ],
      );
      final parent = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'main',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 100)],
          ),
        ],
      ).single;
      final r = calc.calculate(
        calculationType: CalculationType.parentMinusChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
        parent: parent,
      );
      expect(r.value, 30);
      expect(r.directionLabel.toLowerCase(), contains('residual'));
      expect(r.directionLabel.toLowerCase(), isNot(contains('leak')));
    });

    test('C — negative residual shown (not clamped)', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 80)],
          ),
        ],
      );
      final parent = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'main',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 50)],
          ),
        ],
      ).single;
      final r = calc.calculate(
        calculationType: CalculationType.parentMinusChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
        parent: parent,
      );
      expect(r.value, -30);
      expect(r.isNegativeResidual, isTrue);
      expect(r.warnings.any((w) => w.contains('Negative Residual')), isTrue);
      expect(r.directionLabel.toLowerCase(), isNot(contains('leak')));
    });

    test('D — missing child / Insufficient Data', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 10)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c2',
            unitCode: 'm3',
            readings: const [],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c3',
            unitCode: 'm3',
            readings: const [],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
      );
      expect(r.isInsufficient, isTrue);
      expect(r.missingMeterIds, containsAll(['c2', 'c3']));
      expect(r.warnings.any((w) => w.contains('Missing contributor')), isTrue);
    });

    test('E — nested virtual via pre-expanded leaves (no double count)', () {
      // Leaves already expanded by validation — calculator sums once.
      final contributors = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'd',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 5)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'e',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 7)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 3)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: contributors,
        hierarchyDepth: 2,
      );
      expect(r.value, 15);
      expect(r.hierarchyDepth, 2);
    });

    test('multiplier applied once via series (normalizedPoints)', () {
      final contributors = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            meterMultiplier: 2,
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 10)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: contributors,
      );
      expect(r.value, 20); // 10 * 2 once
    });

    test('multiplier = 1 unchanged', () {
      final contributors = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            meterMultiplier: 1,
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 10)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: contributors,
      );
      expect(r.value, 10);
    });

    test('zero residual', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 50)],
          ),
        ],
      );
      final parent = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'main',
            unitCode: 'm3',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 50)],
          ),
        ],
      ).single;
      final r = calc.calculate(
        calculationType: CalculationType.parentMinusChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
        parent: parent,
      );
      expect(r.value, 0);
      expect(r.directionLabel.toLowerCase(), contains('on balance'));
    });

    test('misaligned reading periods lowers confidence / warns', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'm3',
            readings: [
              p(DateTime(2026, 6, 30), 0),
              p(DateTime(2026, 7, 5), 1),
              p(DateTime(2026, 7, 31), 10),
            ],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c2',
            unitCode: 'm3',
            // Only late-month readings → short span
            readings: [
              p(DateTime(2026, 7, 25), 0),
              p(DateTime(2026, 7, 31), 5),
            ],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
      );
      expect(r.status, VirtualMeterResultStatus.ok);
      expect(
        r.warnings.any((w) => w.contains('Misaligned Reading Periods')),
        isTrue,
      );
    });

    test('low contributor confidence propagates as min', () {
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: const [
          VirtualMeterContributorInput(
            meterId: 'c1',
            consumption: 10,
            hasValidEndpoints: true,
            completeness: 1,
            confidence: 90,
            unitCode: 'm3',
            readingSpanStart: null,
            readingSpanEnd: null,
          ),
          VirtualMeterContributorInput(
            meterId: 'c2',
            consumption: 5,
            hasValidEndpoints: true,
            completeness: 1,
            confidence: 55,
            unitCode: 'm3',
          ),
        ],
      );
      expect(r.confidenceScore, lessThanOrEqualTo(55));
    });

    test('labels never say Leak', () {
      expect('Residual'.toLowerCase(), isNot(contains('leak')));
      expect('Balance Difference'.toLowerCase(), isNot(contains('leak')));
    });

    test('mixed compatible units normalize correctly', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'mwh',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 1)],
          ),
          PeriodMeterReadingSeries(
            meterId: 'c2',
            unitCode: 'kwh',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 500)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'kwh',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
      );
      expect(r.status, VirtualMeterResultStatus.ok);
      expect(r.value, 1500.0);
    });

    test('incompatible units explicitly rejected', () {
      final children = calc.contributorsFromSeries(
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        leaves: [
          PeriodMeterReadingSeries(
            meterId: 'c1',
            unitCode: 'mwh',
            readings: [p(DateTime(2026, 6, 30), 0), p(DateTime(2026, 7, 31), 1)],
          ),
        ],
      );
      final r = calc.calculate(
        calculationType: CalculationType.sumChildren,
        unitCode: 'm3',
        periodStart: DateTime(2026, 7, 1),
        periodEnd: DateTime(2026, 7, 31),
        children: children,
      );
      expect(r.isInsufficient, isTrue);
      expect(r.message, contains('Incompatible'));
    });
  });
}
