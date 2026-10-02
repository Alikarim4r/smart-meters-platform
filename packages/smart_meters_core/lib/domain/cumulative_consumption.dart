/// Consumption between two cumulative (register) readings, with explicit
/// handling of negative deltas.
///
/// Mirrors `public.meter_daily_consumption` (migration 120) so dashboard,
/// COP and the DB view agree:
///
/// - first reading → 0, [ConsumptionTransition.first]
/// - current ≥ previous → current − previous, [ConsumptionTransition.normal]
/// - current < previous **and** a plausible register rollover →
///   (capacity − previous) + current, [ConsumptionTransition.rollover]
/// - any other drop → `null` consumption (never invented, never clamped):
///   [ConsumptionTransition.resetOrReplacement] when the register fell to
///   near zero, else [ConsumptionTransition.correctionOrImplausibleDrop].
///
/// A rollover is only accepted when **all** hold (normalized scale):
/// - capacity is configured and > 0
/// - previous ≤ capacity and previous ≥ capacity × (1 − [kRolloverEdgeFraction])
/// - 0 ≤ current ≤ capacity × [kRolloverEdgeFraction]
library;

/// Fraction of register capacity treated as "near the top / near zero".
const double kRolloverEdgeFraction = 0.10;

/// Tolerance for floating-point comparisons on normalized values.
const double _epsilon = 1e-9;

enum ConsumptionTransition {
  first('first'),
  normal('normal'),
  rollover('rollover'),
  resetOrReplacement('reset_or_replacement'),
  correctionOrImplausibleDrop('correction_or_implausible_drop');

  const ConsumptionTransition(this.dbValue);

  /// Matches `meter_daily_consumption.consumption_status`.
  final String dbValue;

  /// Negative delta that cannot be turned into consumption.
  bool get isUnverifiable =>
      this == resetOrReplacement || this == correctionOrImplausibleDrop;

  static ConsumptionTransition? fromDb(Object? value) {
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }
}

class ConsumptionDelta {
  const ConsumptionDelta(this.consumption, this.transition);

  /// `null` when the transition is unverifiable.
  final double? consumption;
  final ConsumptionTransition transition;

  bool get isUnverifiable => transition.isUnverifiable;
  bool get isRollover => transition == ConsumptionTransition.rollover;
}

/// Register capacity on the normalized scale:
/// raw capacity × unit_to_base_factor × meter_multiplier.
///
/// Returns `null` unless every input is finite and positive.
double? normalizedRolloverCapacity({
  required double? rawCapacity,
  required double unitToBaseFactor,
  required double meterMultiplier,
}) {
  if (rawCapacity == null || !rawCapacity.isFinite || rawCapacity <= 0) {
    return null;
  }
  if (!unitToBaseFactor.isFinite || unitToBaseFactor <= 0) return null;
  if (!meterMultiplier.isFinite || meterMultiplier <= 0) return null;
  return rawCapacity * unitToBaseFactor * meterMultiplier;
}

/// Classify the step from [previous] to [current] (both normalized).
///
/// [normalizedCapacity] should come from [normalizedRolloverCapacity].
ConsumptionDelta classifyCumulativeDelta({
  required double? previous,
  required double current,
  double? normalizedCapacity,
}) {
  if (previous == null) {
    return const ConsumptionDelta(0, ConsumptionTransition.first);
  }
  if (current >= previous) {
    return ConsumptionDelta(current - previous, ConsumptionTransition.normal);
  }

  final cap = normalizedCapacity;
  if (cap != null && cap.isFinite && cap > 0) {
    final edge = cap * kRolloverEdgeFraction;
    final prevNearTop =
        previous <= cap + _epsilon && previous >= cap - edge - _epsilon;
    final currentNearZero = current >= -_epsilon && current <= edge + _epsilon;
    if (prevNearTop && currentNearZero) {
      final rolled = (cap - previous) + current;
      return ConsumptionDelta(
        rolled < 0 ? 0 : rolled,
        ConsumptionTransition.rollover,
      );
    }
  }

  // Register fell to (near) zero without a verifiable rollover → reset or
  // meter replacement. Otherwise a correction / implausible drop.
  final nearZero = current.abs() <= previous.abs() * kRolloverEdgeFraction;
  return ConsumptionDelta(
    null,
    nearZero
        ? ConsumptionTransition.resetOrReplacement
        : ConsumptionTransition.correctionOrImplausibleDrop,
  );
}

/// Consumption across a chronological run of cumulative readings.
class CumulativeRunConsumption {
  const CumulativeRunConsumption({
    required this.consumption,
    this.rolloverCount = 0,
    this.unverifiableTransitions = const [],
  });

  /// Sum of every step; `null` when the run is empty or any step is
  /// unverifiable (a drop is never clamped to zero).
  final double? consumption;
  final int rolloverCount;
  final List<ConsumptionTransition> unverifiableTransitions;

  bool get isVerifiable => consumption != null;
  bool get hasUnverifiableTransition => unverifiableTransitions.isNotEmpty;
}

/// Classify every step of [values] (normalized, chronological; `values.first`
/// is the boundary reading) with [classifyCumulativeDelta] and sum them.
///
/// Classifying each step — not just the endpoints — means a replacement or
/// correction inside the period cannot hide behind a plausible net delta, and
/// a valid rollover inside the period still yields its consumption.
CumulativeRunConsumption cumulativeRunConsumption({
  required List<double> values,
  double? normalizedCapacity,
}) {
  if (values.isEmpty) return const CumulativeRunConsumption(consumption: null);
  var total = 0.0;
  var rollovers = 0;
  final unverifiable = <ConsumptionTransition>[];
  for (var i = 1; i < values.length; i++) {
    final delta = classifyCumulativeDelta(
      previous: values[i - 1],
      current: values[i],
      normalizedCapacity: normalizedCapacity,
    );
    if (delta.isUnverifiable) {
      unverifiable.add(delta.transition);
      continue;
    }
    if (delta.isRollover) rollovers++;
    total += delta.consumption!;
  }
  return CumulativeRunConsumption(
    consumption: unverifiable.isEmpty ? total : null,
    rolloverCount: rollovers,
    unverifiableTransitions: List.unmodifiable(unverifiable),
  );
}
