import '../domain/data_quality_rules.dart';
import '../models/data_quality_result.dart';

/// Builds an explainable, deterministic confidence score from findings.
ConfidenceBreakdown buildConfidenceBreakdown(
  List<DataQualityFinding> findings, {
  int base = ConfidenceDeltas.base,
}) {
  final adjustments = <ConfidenceAdjustment>[];
  var score = base;

  // Deduplicate photo findings per reading for scoring.
  final seenPhotoKeys = <String>{};
  final seenCorrectionMeters = <String>{};
  var incompleteReadingsApplied = false;
  var incompleteGroupApplied = false;

  for (final f in findings) {
    switch (f.code) {
      case DataQualityFindingCode.missingRequiredPhoto:
        final key = '${f.meterId}:${f.readingId}';
        if (!seenPhotoKeys.add(key)) continue;
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Missing required photo',
            delta: ConfidenceDeltas.missingRequiredPhoto,
          ),
        );
        score += ConfidenceDeltas.missingRequiredPhoto;
      case DataQualityFindingCode.correctionInAnalysisPeriod:
        final key = f.meterId ?? f.detail;
        if (!seenCorrectionMeters.add(key)) continue;
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Correction in analysis period',
            delta: ConfidenceDeltas.correctionInAnalysisPeriod,
          ),
        );
        score += ConfidenceDeltas.correctionInAnalysisPeriod;
      case DataQualityFindingCode.incompleteExpectedReadings:
      case DataQualityFindingCode.missingExpectedReading:
        if (incompleteReadingsApplied) continue;
        incompleteReadingsApplied = true;
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Incomplete expected readings',
            delta: ConfidenceDeltas.incompleteExpectedReadings,
          ),
        );
        score += ConfidenceDeltas.incompleteExpectedReadings;
      case DataQualityFindingCode.unusualConsumptionChange:
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Unusual consumption change',
            delta: ConfidenceDeltas.unusualConsumptionChange,
          ),
        );
        score += ConfidenceDeltas.unusualConsumptionChange;
      case DataQualityFindingCode.readingRequiresReview:
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Reading requires review',
            delta: ConfidenceDeltas.readingRequiresReview,
          ),
        );
        score += ConfidenceDeltas.readingRequiresReview;
      case DataQualityFindingCode.possibleRolloverOrReset:
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Possible rollover or reset',
            delta: ConfidenceDeltas.possibleRolloverOrReset,
          ),
        );
        score += ConfidenceDeltas.possibleRolloverOrReset;
      case DataQualityFindingCode.incompleteMeterGroup:
        if (incompleteGroupApplied) continue;
        incompleteGroupApplied = true;
        adjustments.add(
          const ConfidenceAdjustment(
            reason: 'Incomplete meter group',
            delta: ConfidenceDeltas.incompleteMeterGroup,
          ),
        );
        score += ConfidenceDeltas.incompleteMeterGroup;
    }
  }

  final finalScore = score.clamp(0, 100);
  return ConfidenceBreakdown(
    base: base,
    adjustments: adjustments,
    finalScore: finalScore,
  );
}
