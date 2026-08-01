import '../domain/period_windows.dart';
import '../models/measurement_verification.dart';
import '../models/utility_tariff.dart';

/// Cost Avoided / simple ROI / payback from **Verified Saving** + tariff.
///
/// ## Formulas
///
/// **Cost Avoided** (only when verified saving > 0 **and** tariff present):
/// ```
/// costAvoided = verifiedSavingQuantity × tariff.rate
/// currency    = tariff.currency (typically QAR; no FX conversion)
/// ```
/// Missing tariff or non-positive saving → Cost Avoided = **N/A** (`null`),
/// never fabricated `0`.
///
/// **Annualized value** (for ROI/payback): scale verified-period cost avoided
/// to a year by day count:
/// ```
/// annualizedValue = costAvoided × (365 / postPeriodDays)
/// ```
/// When cost avoided is N/A, annualized is also N/A.
///
/// **Simple ROI** (requires implementation cost > 0 and annualized value):
/// ```
/// simpleRoi = (annualizedValue − implementationCost) / implementationCost
/// ```
/// Missing cost → ROI N/A.
///
/// **Simple payback (months)** (requires annualized > 0 and cost > 0):
/// ```
/// simplePaybackMonths = implementationCost / (annualizedValue / 12)
/// ```
///
/// Never invent tariffs or costs.
class CostRoiService {
  const CostRoiService();

  CostRoiResult compute({
    required double? verifiedSavingQuantity,
    required UtilityTariff? tariff,
    required DateTime postPeriodStart,
    required DateTime postPeriodEnd,
    double? implementationCost,
    String? implementationCostCurrency,
  }) {
    final notes = <String>[];
    final days = inclusiveDayCount(postPeriodStart, postPeriodEnd);

    double? costAvoided;
    String? costCurrency;

    if (verifiedSavingQuantity == null) {
      notes.add('verified_saving_missing→cost_avoided_N/A');
    } else if (verifiedSavingQuantity <= 0) {
      notes.add('verified_saving_non_positive→cost_avoided_N/A');
    } else if (tariff == null) {
      notes.add('tariff_missing→cost_avoided_N/A');
    } else {
      costAvoided = verifiedSavingQuantity * tariff.rate;
      costCurrency = tariff.currency;
      notes.add('cost_avoided=verified_saving×rate');
      notes.add('currency=$costCurrency');
      if (costCurrency.toUpperCase() == 'QAR') {
        notes.add('qar_no_fx');
      }
    }

    double? annualized;
    if (costAvoided != null && days > 0) {
      annualized = costAvoided * (365 / days);
      notes.add('annualized=cost_avoided×(365/post_days)');
    } else if (costAvoided != null && days <= 0) {
      notes.add('invalid_post_period→annualized_N/A');
    }

    double? simpleRoi;
    if (implementationCost == null) {
      notes.add('implementation_cost_missing→roi_N/A');
    } else if (implementationCost <= 0) {
      notes.add('implementation_cost_not_positive→roi_N/A');
    } else if (annualized == null) {
      notes.add('annualized_missing→roi_N/A');
    } else {
      simpleRoi = (annualized - implementationCost) / implementationCost;
      notes.add('simple_roi=(annualized-cost)/cost');
    }

    double? paybackMonths;
    if (implementationCost == null || implementationCost <= 0) {
      notes.add('implementation_cost_missing→payback_N/A');
    } else if (annualized == null || annualized <= 0) {
      notes.add('annualized_not_positive→payback_N/A');
    } else {
      paybackMonths = implementationCost / (annualized / 12);
      notes.add('simple_payback_months=cost/(annualized/12)');
    }

    // Currency mismatch check — still no FX; flag only.
    if (costCurrency != null &&
        implementationCostCurrency != null &&
        costCurrency.toUpperCase() !=
            implementationCostCurrency.toUpperCase()) {
      notes.add(
        'currency_mismatch:$costCurrency≠$implementationCostCurrency'
        '(no_fx;ROI_uses_same_numeric_units_as_inputs)',
      );
    }

    return CostRoiResult(
      costAvoided: costAvoided,
      costCurrency: costCurrency,
      annualizedValue: annualized,
      simpleRoi: simpleRoi,
      simplePaybackMonths: paybackMonths,
      displayCostAvoided: costAvoided == null
          ? ConservationSavingLabels.costAvoidedNa
          : null,
      notes: notes,
    );
  }
}

/// Cost / ROI computation result. Null numeric fields mean **N/A**.
class CostRoiResult {
  const CostRoiResult({
    required this.costAvoided,
    required this.costCurrency,
    required this.annualizedValue,
    required this.simpleRoi,
    required this.simplePaybackMonths,
    required this.displayCostAvoided,
    required this.notes,
  });

  /// Null = N/A (never invent 0 when tariff/saving missing).
  final double? costAvoided;
  final String? costCurrency;
  final double? annualizedValue;
  final double? simpleRoi;
  final double? simplePaybackMonths;

  /// Set to `N/A` when [costAvoided] is null.
  final String? displayCostAvoided;
  final List<String> notes;

  bool get costAvoidedIsNa => costAvoided == null;
  bool get roiIsNa => simpleRoi == null;
  bool get paybackIsNa => simplePaybackMonths == null;

  Map<String, dynamic> toJson() => {
        'cost_avoided': costAvoided,
        'cost_currency': costCurrency,
        'annualized_value': annualizedValue,
        'simple_roi': simpleRoi,
        'simple_payback_months': simplePaybackMonths,
        'display_cost_avoided': displayCostAvoided,
        'notes': notes,
      };
}
