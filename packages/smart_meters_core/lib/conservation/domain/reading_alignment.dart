import 'period_windows.dart';

/// Mechanical reading-period alignment for Balance Difference analysis.
enum ReadingAlignmentStatus {
  aligned,
  partiallyAligned,
  misaligned,
  insufficientData,
}

/// One meter's observed in-period span (never invented).
class ReadingSpanDiff {
  const ReadingSpanDiff({
    required this.meterId,
    required this.spanStart,
    required this.spanEnd,
    required this.isMissing,
    this.daysFromPeriodStart,
    this.daysFromPeriodEnd,
    this.withinTolerance = false,
  });

  final String meterId;
  final DateTime? spanStart;
  final DateTime? spanEnd;
  final bool isMissing;

  /// Absolute day gap between span start and analysis period start.
  final int? daysFromPeriodStart;

  /// Absolute day gap between span end and analysis period end.
  final int? daysFromPeriodEnd;

  /// True when both edges are within [alignedToleranceDays] of the period.
  final bool withinTolerance;
}

class ReadingAlignmentResult {
  const ReadingAlignmentResult({
    required this.status,
    required this.warnings,
    required this.mainDiff,
    required this.childDiffs,
    required this.alignedToleranceDays,
  });

  final ReadingAlignmentStatus status;
  final List<String> warnings;
  final ReadingSpanDiff mainDiff;
  final List<ReadingSpanDiff> childDiffs;
  final int alignedToleranceDays;

  bool get isAligned => status == ReadingAlignmentStatus.aligned;
  bool get isInsufficient =>
      status == ReadingAlignmentStatus.insufficientData;
}

/// Compares reading spans against each other and the analysis window.
///
/// Never invents missing spans or readings.
class ReadingAlignmentAnalyzer {
  const ReadingAlignmentAnalyzer();

  ReadingAlignmentResult analyze({
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime? mainSpanStart,
    required DateTime? mainSpanEnd,
    required List<
            ({
              String meterId,
              DateTime? spanStart,
              DateTime? spanEnd,
              bool isMissing
            })>
        children,
    int alignedToleranceDays = 3,
  }) {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final warnings = <String>[];
    final tol = alignedToleranceDays < 0 ? 0 : alignedToleranceDays;

    final mainMissing = mainSpanStart == null || mainSpanEnd == null;
    final mainDiff = _diff(
      meterId: 'main',
      spanStart: mainSpanStart,
      spanEnd: mainSpanEnd,
      isMissing: mainMissing,
      periodStart: start,
      periodEnd: end,
      tol: tol,
    );

    final childDiffs = <ReadingSpanDiff>[
      for (final c in children)
        _diff(
          meterId: c.meterId,
          spanStart: c.spanStart,
          spanEnd: c.spanEnd,
          isMissing: c.isMissing || c.spanStart == null || c.spanEnd == null,
          periodStart: start,
          periodEnd: end,
          tol: tol,
        ),
    ];

    final missingChildren =
        childDiffs.where((d) => d.isMissing).map((d) => d.meterId).toList();

    if (mainMissing && (children.isEmpty || missingChildren.length == children.length)) {
      warnings.add(
        'Insufficient Data: main and child reading spans are missing — '
        'alignment cannot be assessed without inventing readings.',
      );
      return ReadingAlignmentResult(
        status: ReadingAlignmentStatus.insufficientData,
        warnings: warnings,
        mainDiff: mainDiff,
        childDiffs: childDiffs,
        alignedToleranceDays: tol,
      );
    }

    if (mainMissing) {
      warnings.add(
        'Main meter reading span missing — alignment degraded; '
        'do not invent boundary readings.',
      );
    }
    if (missingChildren.isNotEmpty) {
      warnings.add(
        'Missing child reading span(s): ${missingChildren.join(', ')} — '
        'not treated as aligned.',
      );
    }

    final comparable = <ReadingSpanDiff>[
      if (!mainDiff.isMissing) mainDiff,
      ...childDiffs.where((d) => !d.isMissing),
    ];

    if (comparable.isEmpty) {
      return ReadingAlignmentResult(
        status: ReadingAlignmentStatus.insufficientData,
        warnings: warnings,
        mainDiff: mainDiff,
        childDiffs: childDiffs,
        alignedToleranceDays: tol,
      );
    }

    final withinPeriod = comparable.where((d) => d.withinTolerance).toList();
    final mutualOk = _mutualSpansWithinTolerance(comparable, tol);

    ReadingAlignmentStatus status;
    if (mainMissing || missingChildren.isNotEmpty) {
      // Any missing span lowers the ceiling — cannot claim full alignment.
      if (withinPeriod.isEmpty || !mutualOk) {
        status = ReadingAlignmentStatus.misaligned;
        warnings.add(
          'Misaligned Reading Periods — spans diverge beyond '
          '$tol-day tolerance or fall outside the analysis window.',
        );
      } else if (withinPeriod.length < comparable.length ||
          missingChildren.isNotEmpty ||
          mainMissing) {
        status = ReadingAlignmentStatus.partiallyAligned;
        warnings.add(
          'Partially Aligned — some meters lack spans or sit near tolerance; '
          'treat Balance Difference with caution.',
        );
      } else {
        status = ReadingAlignmentStatus.partiallyAligned;
        warnings.add(
          'Partially Aligned — incomplete contributor set.',
        );
      }
    } else if (withinPeriod.length == comparable.length && mutualOk) {
      status = ReadingAlignmentStatus.aligned;
    } else if (withinPeriod.isNotEmpty || mutualOk) {
      status = ReadingAlignmentStatus.partiallyAligned;
      warnings.add(
        'Partially Aligned — not all meter spans are within $tol-day '
        'tolerance of the analysis period / each other.',
      );
    } else {
      status = ReadingAlignmentStatus.misaligned;
      warnings.add(
        'Misaligned Reading Periods — contributor spans are not comparable '
        'without caution; do not treat residual as precise Balance Difference.',
      );
    }

    return ReadingAlignmentResult(
      status: status,
      warnings: warnings,
      mainDiff: mainDiff,
      childDiffs: childDiffs,
      alignedToleranceDays: tol,
    );
  }

  ReadingSpanDiff _diff({
    required String meterId,
    required DateTime? spanStart,
    required DateTime? spanEnd,
    required bool isMissing,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int tol,
  }) {
    if (isMissing || spanStart == null || spanEnd == null) {
      return ReadingSpanDiff(
        meterId: meterId,
        spanStart: spanStart == null ? null : dateOnly(spanStart),
        spanEnd: spanEnd == null ? null : dateOnly(spanEnd),
        isMissing: true,
      );
    }
    final s = dateOnly(spanStart);
    final e = dateOnly(spanEnd);
    final fromStart = (s.difference(periodStart).inDays).abs();
    final fromEnd = (e.difference(periodEnd).inDays).abs();
    final within = fromStart <= tol && fromEnd <= tol;
    return ReadingSpanDiff(
      meterId: meterId,
      spanStart: s,
      spanEnd: e,
      isMissing: false,
      daysFromPeriodStart: fromStart,
      daysFromPeriodEnd: fromEnd,
      withinTolerance: within,
    );
  }

  bool _mutualSpansWithinTolerance(List<ReadingSpanDiff> spans, int tol) {
    if (spans.length < 2) return true;
    final starts = spans.map((s) => s.spanStart!).toList()..sort();
    final ends = spans.map((s) => s.spanEnd!).toList()..sort();
    final startGap = starts.last.difference(starts.first).inDays;
    final endGap = ends.last.difference(ends.first).inDays;
    return startGap <= tol && endGap <= tol;
  }
}
