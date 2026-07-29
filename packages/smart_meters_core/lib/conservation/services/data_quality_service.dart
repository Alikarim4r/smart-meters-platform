import '../domain/data_quality_rules.dart';
import '../models/calculation_meta.dart';
import '../models/data_quality_result.dart';
import 'confidence_score.dart';

/// Read-only Data Quality / Completeness / Confidence / Photo evaluation.
///
/// Never writes to meter_readings, meters, reading_audit_logs, or policy_settings.
/// Does not persist quality snapshots in P1A.
class DataQualityService {
  const DataQualityService();

  DataQualityResult evaluate(DataQualityRuleContext context) {
    final findings = evaluateDataQualityRules(context);
    final confidence = buildConfidenceBreakdown(findings);
    final completeness = computeCompletenessRatio(context);

    final notes = <String>[];
    if (completeness == null) {
      notes.add(
        'Completeness skipped: no documented or inferable reading frequency '
        'for evaluated meters (daily expectation not invented).',
      );
    }
    if (!context.photoRequired) {
      notes.add(
        'Photo not required by policy: missing photos do not reduce confidence.',
      );
    }

    var knownFreq = 0;
    for (final m in context.meters) {
      if (!m.isActive || !m.includeInDashboard) continue;
      if (resolveExpectedIntervalDays(m) != null) knownFreq++;
    }

    final sourceReadings = <SourceReadingRef>[];
    for (final m in context.meters) {
      for (final r in m.readings) {
        sourceReadings.add(
          SourceReadingRef(
            readingId: r.readingId,
            meterId: r.meterId,
            readingDate: r.readingDate,
            rawValue: r.rawValue,
            normalizedValue: r.normalizedValue,
            imageStoragePath: r.imageStoragePath,
            hasCorrectionInPeriod: m.correctionCountInPeriod > 0,
          ),
        );
      }
    }

    final meta = CalculationMeta(
      calculationMethod: 'conservation_data_quality_v1',
      periodStart: context.periodStart,
      periodEnd: context.periodEnd,
      dataCompleteness: completeness,
      confidenceScore: confidence.finalScore,
      calculatedAt: DateTime.now().toUtc(),
      notes: notes,
    );

    return DataQualityResult(
      siteId: context.siteId,
      findings: findings,
      confidence: confidence,
      meta: meta,
      sourceReadings: sourceReadings,
      metersEvaluated: context.meters
          .where((m) => m.isActive && m.includeInDashboard)
          .length,
      metersWithKnownFrequency: knownFreq,
    );
  }
}
