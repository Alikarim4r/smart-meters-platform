import '../domain/period_windows.dart';
import '../models/conservation_opportunity.dart';
import '../repositories/opportunity_repository.dart';
import 'opportunity_engine.dart';

/// Result of an explicit opportunity refresh for a site/period.
class GenerationResult {
  const GenerationResult({
    required this.created,
    required this.refreshed,
    required this.skipped,
  });

  final int created;
  final int refreshed;
  final int skipped;

  int get total => created + refreshed + skipped;
}

/// Persists [OpportunityEngine] candidates for a bounded analysis period.
///
/// **Not** called on dashboard open — callers must invoke [refreshForSite]
/// explicitly. No historical backfill beyond the provided period signals.
class OpportunityGenerationService {
  OpportunityGenerationService({
    required OpportunityGenerationStore repository,
    this.engine = const OpportunityEngine(),
  }) : _repository = repository;

  final OpportunityGenerationStore _repository;
  final OpportunityEngine engine;

  /// Upsert-refresh candidates for [siteId] within the analysis period only.
  ///
  /// For each candidate:
  /// - open opp with same fingerprint → refresh snapshot/confidence/metadata
  /// - else → insert
  Future<GenerationResult> refreshForSite({
    required String siteId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<OpportunityCandidate> candidates,
    String? createdBy,
  }) async {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);

    var created = 0;
    var refreshed = 0;
    var skipped = 0;

    for (final c in candidates) {
      if (c.siteId != siteId) {
        skipped++;
        continue;
      }
      // Bound to provided analysis period — skip candidates outside window.
      final cStart = dateOnly(c.detectedPeriodStart);
      final cEnd = dateOnly(c.detectedPeriodEnd);
      if (cStart.isBefore(start) || cEnd.isAfter(end)) {
        skipped++;
        continue;
      }

      final existing = await _repository.findOpenByFingerprint(
        siteId: siteId,
        sourceFingerprint: c.sourceFingerprint,
      );

      if (existing != null) {
        await _repository.refreshOpenSignal(
          id: existing.id,
          confidenceScore: c.confidenceScore,
          priority: c.priority,
          sourceSnapshot: c.sourceSnapshot,
          estimatedWasteQuantity: c.estimatedWasteQuantity,
          possibleCauses: c.possibleCauses,
          suggestedInvestigations: c.suggestedInvestigations,
          title: c.title,
          description: c.description,
        );
        refreshed++;
      } else {
        await _repository.insert(
          ConservationOpportunity(
            id: '', // DB-generated; ignored on insert
            siteId: c.siteId,
            meterId: c.meterId,
            balanceGroupId: c.balanceGroupId,
            utilityType: c.utilityType,
            origin: c.origin,
            sourceType: c.sourceType,
            sourceFingerprint: c.sourceFingerprint,
            title: c.title,
            description: c.description,
            detectedPeriodStart: c.detectedPeriodStart,
            detectedPeriodEnd: c.detectedPeriodEnd,
            unitCode: c.unitCode,
            estimatedWasteQuantity: c.estimatedWasteQuantity,
            confidenceScore: c.confidenceScore,
            priority: c.priority,
            status: c.status,
            possibleCauses: c.possibleCauses,
            suggestedInvestigations: c.suggestedInvestigations,
            sourceSnapshot: c.sourceSnapshot,
            ruleVersion: c.ruleVersion,
            createdBy: createdBy,
            detectedAt: DateTime.now().toUtc(),
          ),
        );
        created++;
      }
    }

    return GenerationResult(
      created: created,
      refreshed: refreshed,
      skipped: skipped,
    );
  }
}
