/// Client-side validation for cumulative meter readings (RLS remains source of truth).
String? validateCumulativeReading(
  String? value, {
  double? lastRawValue,
}) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter the cumulative meter reading.';
  }

  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return 'Reading must be a valid number.';
  }

  if (parsed < 0) {
    return 'Reading cannot be negative.';
  }

  if (lastRawValue != null && parsed < lastRawValue) {
    return 'This reading is lower than the previous reading.';
  }

  return null;
}

/// Returns true when the increase looks unusually high and should prompt confirmation.
bool shouldWarnHighReading({
  required double newReading,
  double? lastRawValue,
  double? averageDailyConsumption,
}) {
  if (lastRawValue == null) {
    return false;
  }

  final increase = newReading - lastRawValue;
  if (increase <= 0) {
    return false;
  }

  if (averageDailyConsumption != null && averageDailyConsumption > 0) {
    return increase > 3 * averageDailyConsumption;
  }

  return newReading > lastRawValue * 2;
}

const highReadingWarningMessage =
    'This reading is much higher than the previous reading. Please confirm before saving.';
