import '../models/emission_factor.dart';

/// Optional carbon layer. Never invents emission factors.
class CarbonAccountingService {
  const CarbonAccountingService();

  static const notAvailableLabel = 'Carbon Avoided = Not Available';

  CarbonComputation compute({
    required String siteId,
    required CarbonQuantityBasis basis,
    required double? savingQuantity,
    required EmissionFactor? factor,
    required DateTime asOf,
    String? measurementVerificationId,
  }) {
    if (savingQuantity == null || savingQuantity <= 0) {
      return CarbonComputation(
        siteId: siteId,
        measurementVerificationId: measurementVerificationId,
        quantityBasis: basis,
        savingQuantity: savingQuantity,
        carbonAvoided: null,
        carbonUnit: null,
        status: 'not_available',
        warnings: const ['non_positive_saving'],
        displayLabel: notAvailableLabel,
        lineage: const {},
      );
    }

    if (factor == null || !factor.isActive) {
      return CarbonComputation(
        siteId: siteId,
        measurementVerificationId: measurementVerificationId,
        quantityBasis: basis,
        savingQuantity: savingQuantity,
        emissionFactorId: factor?.id,
        carbonAvoided: null,
        carbonUnit: null,
        status: 'missing_factor',
        warnings: const ['missing_or_inactive_factor'],
        displayLabel: notAvailableLabel,
        lineage: const {},
      );
    }

    if (!factor.isEffectiveOn(asOf)) {
      return CarbonComputation(
        siteId: siteId,
        measurementVerificationId: measurementVerificationId,
        quantityBasis: basis,
        savingQuantity: savingQuantity,
        emissionFactorId: factor.id,
        factorValueSnapshot: factor.factor,
        factorSourceSnapshot: factor.source,
        factorEffectiveFromSnapshot: factor.effectiveFrom,
        carbonAvoided: null,
        carbonUnit: factor.co2eUnit,
        status: 'expired_factor',
        warnings: const ['factor_not_effective_on_date'],
        displayLabel: notAvailableLabel,
        lineage: {
          'emission_factor_id': factor.id,
          'effective_from': factor.effectiveFrom.toIso8601String(),
          'effective_to': factor.effectiveTo?.toIso8601String(),
        },
      );
    }

    final avoided = savingQuantity * factor.factor;
    return CarbonComputation(
      siteId: siteId,
      measurementVerificationId: measurementVerificationId,
      quantityBasis: basis,
      savingQuantity: savingQuantity,
      emissionFactorId: factor.id,
      factorValueSnapshot: factor.factor,
      factorSourceSnapshot: factor.source,
      factorEffectiveFromSnapshot: factor.effectiveFrom,
      carbonAvoided: avoided,
      carbonUnit: factor.co2eUnit,
      status: 'computed',
      warnings: const [],
      displayLabel: basis == CarbonQuantityBasis.verifiedSaving
          ? 'Verified Carbon Avoided'
          : 'Estimated Carbon Avoided',
      lineage: {
        'emission_factor_id': factor.id,
        'factor_value_snapshot': factor.factor,
        'factor_source': factor.source,
        'factor_effective_from':
            factor.effectiveFrom.toIso8601String().substring(0, 10),
        'utility_or_fuel_type': factor.utilityOrFuelType,
        'geography': factor.geography,
        'quantity_basis': basis.dbValue,
      },
    );
  }

  /// Official Verified Carbon Total — verified basis only; ignore estimated & N/A.
  static double verifiedCarbonTotal(Iterable<CarbonComputation> rows) {
    var sum = 0.0;
    for (final r in rows) {
      if (r.quantityBasis != CarbonQuantityBasis.verifiedSaving) continue;
      if (r.status != 'computed') continue;
      if (r.carbonAvoided == null || r.carbonAvoided! <= 0) continue;
      sum += r.carbonAvoided!;
    }
    return sum;
  }
}

class CarbonComputation {
  const CarbonComputation({
    required this.siteId,
    required this.quantityBasis,
    required this.status,
    required this.displayLabel,
    required this.warnings,
    required this.lineage,
    this.measurementVerificationId,
    this.savingQuantity,
    this.emissionFactorId,
    this.factorValueSnapshot,
    this.factorSourceSnapshot,
    this.factorEffectiveFromSnapshot,
    this.carbonAvoided,
    this.carbonUnit,
  });

  final String siteId;
  final String? measurementVerificationId;
  final CarbonQuantityBasis quantityBasis;
  final double? savingQuantity;
  final String? emissionFactorId;
  final double? factorValueSnapshot;
  final String? factorSourceSnapshot;
  final DateTime? factorEffectiveFromSnapshot;
  final double? carbonAvoided;
  final String? carbonUnit;
  final String status;
  final String displayLabel;
  final List<String> warnings;
  final Map<String, dynamic> lineage;

  bool get isNotAvailable =>
      status == 'not_available' ||
      status == 'missing_factor' ||
      status == 'expired_factor';
}
