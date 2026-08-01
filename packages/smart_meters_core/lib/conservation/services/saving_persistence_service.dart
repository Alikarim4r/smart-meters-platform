import '../domain/persistence_status.dart';
import '../models/saving_persistence_result.dart';

/// Saving persistence follow-up analysis. Never mutates original verified MV.
class SavingPersistenceService {
  const SavingPersistenceService();

  static const sustainedThreshold = 0.8;
  static const partialThreshold = 0.4;

  /// [originalVerifiedSaving] must be the historical verified quantity (≥ 0).
  SavingPersistenceResult evaluate({
    required String siteId,
    required String measurementVerificationId,
    required double originalVerifiedSaving,
    required PersistenceWindow window,
    required DateTime followUpStart,
    required DateTime followUpEnd,
    double? expectedReferenceConsumption,
    double? actualConsumption,
    double? dataCompleteness,
    int confidenceScore = 0,
    Set<String> existingReopenKeys = const {},
  }) {
    final warnings = <String>[];
    final lineage = <String, dynamic>{
      'original_verified_saving': originalVerifiedSaving,
      'measurement_verification_id': measurementVerificationId,
      'follow_up_window': window.dbValue,
    };

    if (actualConsumption == null || expectedReferenceConsumption == null) {
      return SavingPersistenceResult(
        id: '',
        siteId: siteId,
        measurementVerificationId: measurementVerificationId,
        followUpWindow: window,
        followUpStart: followUpStart,
        followUpEnd: followUpEnd,
        expectedReferenceConsumption: expectedReferenceConsumption,
        actualConsumption: actualConsumption,
        sustainedQuantity: null,
        persistencePct: null,
        dataCompleteness: dataCompleteness,
        confidenceScore: confidenceScore,
        status: PersistenceStatus.insufficientFollowUp,
        warnings: const ['insufficient_follow_up_data'],
        lineage: lineage,
        calculatedAt: DateTime.now().toUtc(),
      );
    }

    if (dataCompleteness != null && dataCompleteness < 0.7) {
      warnings.add('low_completeness');
    }
    if (confidenceScore < 50) {
      warnings.add('low_confidence');
    }

    final sustainedQty = expectedReferenceConsumption - actualConsumption;
    final persistencePct = originalVerifiedSaving == 0
        ? null
        : (sustainedQty / originalVerifiedSaving);

    PersistenceStatus status;
    if (persistencePct == null) {
      status = PersistenceStatus.insufficientFollowUp;
    } else if (persistencePct >= sustainedThreshold) {
      status = PersistenceStatus.sustained;
    } else if (persistencePct >= 0.55) {
      status = PersistenceStatus.partiallySustained;
    } else if (persistencePct >= partialThreshold) {
      status = PersistenceStatus.declining;
      warnings.add(PersistenceStatus.decliningLabel);
    } else {
      status = PersistenceStatus.notSustained;
      warnings.add(PersistenceStatus.notSustainedLabel);
    }

    // Substantial degradation → suggest reopen (never auto-open).
    final suggestReopen = status == PersistenceStatus.notSustained ||
        (persistencePct != null && persistencePct < 0.3);
    final reopenKey = suggestReopen
        ? 'reopen:${measurementVerificationId}:${window.dbValue}'
        : null;
    final deduped = reopenKey != null && existingReopenKeys.contains(reopenKey);

    return SavingPersistenceResult(
      id: '',
      siteId: siteId,
      measurementVerificationId: measurementVerificationId,
      followUpWindow: window,
      followUpStart: followUpStart,
      followUpEnd: followUpEnd,
      expectedReferenceConsumption: expectedReferenceConsumption,
      actualConsumption: actualConsumption,
      sustainedQuantity: sustainedQty,
      persistencePct: persistencePct == null ? null : persistencePct * 100,
      dataCompleteness: dataCompleteness,
      confidenceScore: confidenceScore,
      status: status,
      reopenOpportunitySuggested: suggestReopen && !deduped,
      reopenSuggestionKey: deduped ? null : reopenKey,
      warnings: warnings,
      lineage: lineage,
      calculatedAt: DateTime.now().toUtc(),
    );
  }

  /// Windows allowed given available follow-up days (do not force 12m early).
  static List<PersistenceWindow> availableWindows(int followUpDaysAvailable) {
    return PersistenceWindow.values
        .where((w) => followUpDaysAvailable >= (w.approxDays * 0.8).round())
        .toList();
  }
}
