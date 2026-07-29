import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

void main() {
  const analyzer = ReadingAlignmentAnalyzer();
  final periodStart = DateTime(2026, 7, 1);
  final periodEnd = DateTime(2026, 7, 31);

  group('ReadingAlignmentAnalyzer', () {
    test('aligned when main and children spans match period within tolerance', () {
      final r = analyzer.analyze(
        periodStart: periodStart,
        periodEnd: periodEnd,
        mainSpanStart: DateTime(2026, 7, 1),
        mainSpanEnd: DateTime(2026, 7, 31),
        children: [
          (
            meterId: 'c1',
            spanStart: DateTime(2026, 7, 2),
            spanEnd: DateTime(2026, 7, 30),
            isMissing: false,
          ),
          (
            meterId: 'c2',
            spanStart: DateTime(2026, 7, 1),
            spanEnd: DateTime(2026, 7, 31),
            isMissing: false,
          ),
        ],
        alignedToleranceDays: 3,
      );
      expect(r.status, ReadingAlignmentStatus.aligned);
      expect(r.mainDiff.withinTolerance, isTrue);
    });

    test('partiallyAligned when some spans within tolerance', () {
      final r = analyzer.analyze(
        periodStart: periodStart,
        periodEnd: periodEnd,
        mainSpanStart: DateTime(2026, 7, 1),
        mainSpanEnd: DateTime(2026, 7, 31),
        children: [
          (
            meterId: 'c1',
            spanStart: DateTime(2026, 7, 1),
            spanEnd: DateTime(2026, 7, 31),
            isMissing: false,
          ),
          (
            meterId: 'c2',
            spanStart: DateTime(2026, 7, 10),
            spanEnd: DateTime(2026, 7, 20),
            isMissing: false,
          ),
        ],
        alignedToleranceDays: 3,
      );
      expect(r.status, ReadingAlignmentStatus.partiallyAligned);
      expect(r.warnings, isNotEmpty);
    });

    test('misaligned when spans diverge beyond tolerance', () {
      final r = analyzer.analyze(
        periodStart: periodStart,
        periodEnd: periodEnd,
        mainSpanStart: DateTime(2026, 7, 1),
        mainSpanEnd: DateTime(2026, 7, 5),
        children: [
          (
            meterId: 'c1',
            spanStart: DateTime(2026, 7, 25),
            spanEnd: DateTime(2026, 7, 31),
            isMissing: false,
          ),
        ],
        alignedToleranceDays: 3,
      );
      expect(r.status, ReadingAlignmentStatus.misaligned);
    });

    test('insufficientData when main and all children missing spans', () {
      final r = analyzer.analyze(
        periodStart: periodStart,
        periodEnd: periodEnd,
        mainSpanStart: null,
        mainSpanEnd: null,
        children: [
          (
            meterId: 'c1',
            spanStart: null,
            spanEnd: null,
            isMissing: true,
          ),
        ],
      );
      expect(r.status, ReadingAlignmentStatus.insufficientData);
      expect(r.warnings.any((w) => w.contains('Insufficient Data')), isTrue);
    });

    test('never invents spans — missing child lowers to partial/misaligned', () {
      final r = analyzer.analyze(
        periodStart: periodStart,
        periodEnd: periodEnd,
        mainSpanStart: DateTime(2026, 7, 1),
        mainSpanEnd: DateTime(2026, 7, 31),
        children: [
          (
            meterId: 'c1',
            spanStart: DateTime(2026, 7, 1),
            spanEnd: DateTime(2026, 7, 31),
            isMissing: false,
          ),
          (
            meterId: 'c2',
            spanStart: null,
            spanEnd: null,
            isMissing: true,
          ),
        ],
      );
      expect(r.status, isNot(ReadingAlignmentStatus.aligned));
      expect(r.childDiffs.any((d) => d.meterId == 'c2' && d.isMissing), isTrue);
    });
  });
}
