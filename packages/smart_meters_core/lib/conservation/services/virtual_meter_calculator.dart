import '../../domain/chart_period.dart';
import '../../domain/unit_conversion.dart';
import '../../models/enums.dart';
import '../domain/period_windows.dart';
import '../domain/virtual_meter_validation.dart';
import '../models/calculation_meta.dart';
import '../models/virtual_meter_result.dart';
import 'period_comparison_service.dart';

/// Read-only Virtual Meter calculator (P1E).
///
/// Uses existing [periodConsumptionFromEndpoints] semantics — does not invent
/// periodStart-1 readings. Labels residual as Residual / Balance Difference only.
class VirtualMeterCalculator {
  const VirtualMeterCalculator();

  static const method = 'conservation_virtual_meter_v1';

  /// Minimum contributor completeness to trust an aggregate (0–1).
  static const minAggregateCompleteness = 0.5;

  /// Build contributor inputs from leaf reading series (normalized values preferred).
  ///
  /// Pass [meterMultiplier]=1 when readings are already `normalized_value` from DB
  /// to avoid double-applying multipliers.
  List<VirtualMeterContributorInput> contributorsFromSeries({
    required List<PeriodMeterReadingSeries> leaves,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final out = <VirtualMeterContributorInput>[];
    for (final series in leaves) {
      final endpoints = extractEndpoints(
        readings: series.normalizedPoints,
        periodStart: start,
        periodEnd: end,
      );
      if (!endpoints.hasValidConsumptionEndpoints) {
        out.add(VirtualMeterContributorInput(
          meterId: series.meterId,
          consumption: null,
          hasValidEndpoints: false,
          completeness: 0,
          confidence: 40,
          unitCode: series.unitCode,
          isMissing: true,
        ));
        continue;
      }
      final value = periodConsumptionFromEndpoints(
        lastInPeriod: endpoints.lastInPeriod!,
        previousBeforePeriod: endpoints.previousBeforePeriod,
        firstInPeriod: endpoints.firstInPeriod,
      );
      var confidence = 100;
      if (endpoints.previousBeforePeriod == null) confidence -= 15;
      if (endpoints.readingCountInPeriod < 2) confidence -= 10;

      DateTime? spanStart;
      DateTime? spanEnd;
      for (final r in series.normalizedPoints) {
        final d = dateOnly(r.date);
        if (d.isBefore(start) || d.isAfter(end)) continue;
        spanStart ??= d;
        spanEnd = d;
      }

      out.add(VirtualMeterContributorInput(
        meterId: series.meterId,
        consumption: value,
        hasValidEndpoints: true,
        completeness: 1.0,
        confidence: confidence.clamp(0, 100),
        unitCode: series.unitCode,
        readingSpanStart: spanStart,
        readingSpanEnd: spanEnd,
      ));
    }
    return out;
  }

  VirtualMeterResult calculate({
    required CalculationType calculationType,
    required String unitCode,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<VirtualMeterContributorInput> children,
    VirtualMeterContributorInput? parent,
    int hierarchyDepth = 1,
  }) {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final warnings = <String>[];

    if (calculationType != CalculationType.sumChildren &&
        calculationType != CalculationType.parentMinusChildren) {
      return _insufficient(
        calculationType: calculationType,
        unitCode: unitCode,
        start: start,
        end: end,
        reason: 'Unsupported calculation_type ${calculationType.dbValue}.',
        hierarchyDepth: hierarchyDepth,
      );
    }

    if (children.isEmpty) {
      return _insufficient(
        calculationType: calculationType,
        unitCode: unitCode,
        start: start,
        end: end,
        reason: 'No child contributors.',
        hierarchyDepth: hierarchyDepth,
      );
    }

    final incompatibleChildren = <VirtualMeterContributorInput>[];
    final normalizedChildren = <VirtualMeterContributorInput>[];

    for (final c in children) {
      final normalized = _toUnit(c, unitCode);
      if (normalized == null) {
        incompatibleChildren.add(c);
      } else {
        normalizedChildren.add(normalized);
      }
    }

    VirtualMeterContributorInput? normalizedParent = parent;
    if (parent != null) {
      normalizedParent = _toUnit(parent, unitCode);
      if (normalizedParent == null) incompatibleChildren.add(parent);
    }

    if (incompatibleChildren.isNotEmpty) {
      return _insufficient(
        calculationType: calculationType,
        unitCode: unitCode,
        start: start,
        end: end,
        reason: 'Incompatible units/categories among virtual meter contributors.',
        hierarchyDepth: hierarchyDepth,
        missing: incompatibleChildren.map((c) => c.meterId).toList(),
      );
    }

    final missing = normalizedChildren.where((c) => c.isMissing || !c.hasValidEndpoints).toList();
    final present = normalizedChildren.where((c) => c.hasValidEndpoints && c.consumption != null).toList();
    final contributingIds = present.map((c) => c.meterId).toList();
    final missingIds = missing.map((c) => c.meterId).toList();

    final completeness = (present.length / normalizedChildren.length).clamp(0.0, 1.0).toDouble();

    // Conservative confidence = min(contributors) with penalties.
    var confidence = 100;
    for (final c in normalizedChildren) {
      if (c.confidence < confidence) confidence = c.confidence;
    }
    if (missing.isNotEmpty) {
      confidence -= 20 * missing.length;
      warnings.add(
        'Missing contributor(s): ${missingIds.join(', ')} — not treated as 0.',
      );
    }
    if (completeness < 1.0) confidence -= 15;

    // Period alignment: compare reading spans within analysis window.
    final aligned = _alignmentOk(present, start, end);
    if (!aligned) {
      confidence -= 20;
      warnings.add(
        'Misaligned Reading Periods — contributor spans are not comparable '
        'without caution; do not treat residual as precise Balance Difference.',
      );
    }

    if (present.isEmpty || completeness < minAggregateCompleteness) {
      return _insufficient(
        calculationType: calculationType,
        unitCode: unitCode,
        start: start,
        end: end,
        reason:
            'Insufficient Data: missing/incomplete child readings '
            '(completeness ${(completeness * 100).toStringAsFixed(0)}%).',
        hierarchyDepth: hierarchyDepth,
        completeness: completeness,
        confidence: confidence.clamp(0, 100),
        contributing: contributingIds,
        missing: missingIds,
        warnings: warnings,
      );
    }

    final childrenSum = present.fold<double>(0, (a, c) => a + c.consumption!);

    if (calculationType == CalculationType.sumChildren) {
      final meta = _meta(
        calculationType: calculationType,
        start: start,
        end: end,
        completeness: completeness,
        confidence: confidence.clamp(0, 100),
        contributing: contributingIds,
        missing: missingIds,
        hierarchyDepth: hierarchyDepth,
        warnings: warnings,
        expression: 'Σ children = $childrenSum $unitCode',
      );
      return VirtualMeterResult(
        status: VirtualMeterResultStatus.ok,
        calculationType: calculationType,
        value: childrenSum,
        unitCode: unitCode,
        directionLabel: 'Sum of children',
        completeness: completeness,
        confidenceScore: confidence.clamp(0, 100),
        periodStart: start,
        periodEnd: end,
        calculatedAt: meta.calculatedAt,
        meta: meta,
        contributingMeterIds: contributingIds,
        missingMeterIds: missingIds,
        hierarchyDepth: hierarchyDepth,
        childrenContribution: childrenSum,
        expressionSummary: meta.notes.firstWhere(
          (n) => n.startsWith('expression='),
          orElse: () => 'Σ children',
        ),
        warnings: warnings,
      );
    }

    // parent_minus_children
    if (normalizedParent == null || !normalizedParent.hasValidEndpoints || normalizedParent.consumption == null) {
      return _insufficient(
        calculationType: calculationType,
        unitCode: unitCode,
        start: start,
        end: end,
        reason:
            'Insufficient Data: parent meter lacks valid boundary readings '
            'for the analysis period.',
        hierarchyDepth: hierarchyDepth,
        completeness: completeness * 0.5,
        confidence: (confidence - 30).clamp(0, 100),
        contributing: contributingIds,
        missing: [...missingIds, if (normalizedParent != null) normalizedParent.meterId else 'parent'],
        warnings: warnings,
      );
    }

    if (normalizedParent.confidence < confidence) confidence = normalizedParent.confidence;

    final residual = normalizedParent.consumption! - childrenSum;
    if (residual < 0) {
      confidence -= 15;
      warnings.add(
        'Negative Residual — Review Meter Hierarchy / Reading Timing / Data Quality. '
        'Not labeled Leak/Leakage/Water Loss/Waste.',
      );
    }

    final label = residual.abs() < 1e-9
        ? 'Residual (Balance Difference) · On balance'
        : residual > 0
            ? 'Residual (Balance Difference)'
            : 'Residual (Balance Difference) · Negative';

    final meta = _meta(
      calculationType: calculationType,
      start: start,
      end: end,
      completeness: completeness,
      confidence: confidence.clamp(0, 100),
      contributing: [...contributingIds, normalizedParent.meterId],
      missing: missingIds,
      hierarchyDepth: hierarchyDepth,
      warnings: warnings,
      expression:
          'parent(${normalizedParent.consumption}) − Σ children($childrenSum) = $residual $unitCode',
    );

    return VirtualMeterResult(
      status: VirtualMeterResultStatus.ok,
      calculationType: calculationType,
      value: residual,
      unitCode: unitCode,
      directionLabel: label,
      completeness: completeness,
      confidenceScore: confidence.clamp(0, 100),
      periodStart: start,
      periodEnd: end,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      contributingMeterIds: [...contributingIds, normalizedParent.meterId],
      missingMeterIds: missingIds,
      hierarchyDepth: hierarchyDepth,
      parentContribution: normalizedParent.consumption,
      childrenContribution: childrenSum,
      expressionSummary: meta.notes.firstWhere(
        (n) => n.startsWith('expression='),
        orElse: () => 'parent − Σ children',
      ),
      message: residual < 0
          ? 'Negative Residual — Review Meter Hierarchy / Reading Timing / Data Quality'
          : null,
      warnings: warnings,
    );
  }

  bool _alignmentOk(
    List<VirtualMeterContributorInput> present,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    if (present.length < 2) return true;
    final periodDays = inclusiveDayCount(periodStart, periodEnd);
    if (periodDays <= 0) return true;
    for (final c in present) {
      if (c.readingSpanStart == null || c.readingSpanEnd == null) continue;
      final span = inclusiveDayCount(c.readingSpanStart!, c.readingSpanEnd!);
      // If a contributor's in-period span covers < 50% of analysis window → misaligned.
      if (span / periodDays < 0.5) return false;
    }
    // Also flag if earliest starts diverge by > 25% of period.
    final starts = present
        .where((c) => c.readingSpanStart != null)
        .map((c) => c.readingSpanStart!)
        .toList();
    if (starts.length >= 2) {
      starts.sort();
      final gap = starts.last.difference(starts.first).inDays;
      if (gap > (periodDays * 0.25).ceil()) return false;
    }
    return true;
  }

  CalculationMeta _meta({
    required CalculationType calculationType,
    required DateTime start,
    required DateTime end,
    required double completeness,
    required int confidence,
    required List<String> contributing,
    required List<String> missing,
    required int hierarchyDepth,
    required List<String> warnings,
    required String expression,
  }) {
    return CalculationMeta(
      calculationMethod: '${method}:${calculationType.dbValue}',
      periodStart: start,
      periodEnd: end,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      calculatedAt: DateTime.now().toUtc(),
      notes: [
        'expression=$expression',
        'contributing_meter_ids=${contributing.join(',')}',
        'contributing_meter_count=${contributing.length}',
        'missing_meter_ids=${missing.join(',')}',
        'hierarchy_depth=$hierarchyDepth',
        'max_depth_cap=$kVirtualMeterMaxDepth',
        'note=Residual / Balance Difference only — never Leak.',
        'note=Do not invent periodStart-1 readings.',
        'note=Physical meters remain enterable; virtual is derived only.',
        ...warnings.map((w) => 'warning=$w'),
      ],
    );
  }

  VirtualMeterResult _insufficient({
    required CalculationType calculationType,
    required String unitCode,
    required DateTime start,
    required DateTime end,
    required String reason,
    required int hierarchyDepth,
    double completeness = 0,
    int confidence = 0,
    List<String> contributing = const [],
    List<String> missing = const [],
    List<String> warnings = const [],
  }) {
    final meta = CalculationMeta(
      calculationMethod: '${method}:${calculationType.dbValue}',
      periodStart: start,
      periodEnd: end,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      calculatedAt: DateTime.now().toUtc(),
      notes: [reason, ...warnings],
    );
    return VirtualMeterResult(
      status: VirtualMeterResultStatus.insufficientData,
      calculationType: calculationType,
      value: null,
      unitCode: unitCode,
      directionLabel: 'Insufficient Data',
      completeness: completeness,
      confidenceScore: confidence,
      periodStart: start,
      periodEnd: end,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      contributingMeterIds: contributing,
      missingMeterIds: missing,
      hierarchyDepth: hierarchyDepth,
      message: reason,
      warnings: warnings,
    );
  }

  /// [c] expressed in [unitCode], or `null` when the units are incompatible
  /// (different category, unknown, or apparent vs real energy).
  VirtualMeterContributorInput? _toUnit(
    VirtualMeterContributorInput c,
    String unitCode,
  ) {
    if (c.unitCode == unitCode) return c;
    final factor = UnitConversion.factor(c.unitCode, unitCode);
    if (factor == null) return null;
    return VirtualMeterContributorInput(
      meterId: c.meterId,
      consumption: c.consumption == null ? null : c.consumption! * factor,
      hasValidEndpoints: c.hasValidEndpoints,
      completeness: c.completeness,
      confidence: c.confidence,
      unitCode: unitCode,
      readingSpanStart: c.readingSpanStart,
      readingSpanEnd: c.readingSpanEnd,
      isMissing: c.isMissing,
    );
  }
}
