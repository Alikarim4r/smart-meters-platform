import 'calculation_meta.dart';

enum DataQualityFindingCode {
  missingExpectedReading,
  unusualConsumptionChange,
  readingRequiresReview,
  possibleRolloverOrReset,
  missingRequiredPhoto,
  correctionInAnalysisPeriod,
  incompleteExpectedReadings,
  incompleteMeterGroup,
}

enum DataQualitySeverity { info, warning, critical }

/// A single quality finding. Labels avoid Leak/Waste/Fault claims.
class DataQualityFinding {
  const DataQualityFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.detail,
    this.meterId,
    this.readingId,
    this.readingDate,
    this.metadata = const {},
  });

  final DataQualityFindingCode code;
  final DataQualitySeverity severity;
  final String title;
  final String detail;
  final String? meterId;
  final String? readingId;
  final DateTime? readingDate;
  final Map<String, Object?> metadata;
}

/// One explainable confidence adjustment step.
class ConfidenceAdjustment {
  const ConfidenceAdjustment({
    required this.reason,
    required this.delta,
  });

  final String reason;
  final int delta;
}

/// Explainable confidence breakdown (deterministic).
class ConfidenceBreakdown {
  const ConfidenceBreakdown({
    required this.base,
    required this.adjustments,
    required this.finalScore,
  });

  final int base;
  final List<ConfidenceAdjustment> adjustments;
  final int finalScore;

  List<String> get explanationLines {
    final lines = <String>['Base confidence: $base'];
    for (final a in adjustments) {
      final sign = a.delta >= 0 ? '+' : '';
      lines.add('${a.reason}: $sign${a.delta}');
    }
    lines.add('Final confidence: $finalScore');
    return lines;
  }
}

/// Snapshot of a source reading kept available even when confidence is low.
class SourceReadingRef {
  const SourceReadingRef({
    required this.readingId,
    required this.meterId,
    required this.readingDate,
    required this.rawValue,
    required this.normalizedValue,
    this.imageStoragePath,
    this.hasCorrectionInPeriod = false,
  });

  final String readingId;
  final String meterId;
  final DateTime readingDate;
  final double rawValue;
  final double normalizedValue;
  final String? imageStoragePath;
  final bool hasCorrectionInPeriod;
}

/// Full Data Quality evaluation result (in-memory only in P1A).
class DataQualityResult {
  const DataQualityResult({
    required this.siteId,
    required this.findings,
    required this.confidence,
    required this.meta,
    required this.sourceReadings,
    this.metersEvaluated = 0,
    this.metersWithKnownFrequency = 0,
  });

  final String siteId;
  final List<DataQualityFinding> findings;
  final ConfidenceBreakdown confidence;
  final CalculationMeta meta;
  final List<SourceReadingRef> sourceReadings;
  final int metersEvaluated;
  final int metersWithKnownFrequency;
}
