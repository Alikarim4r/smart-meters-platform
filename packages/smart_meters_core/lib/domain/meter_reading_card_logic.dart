import '../models/enums.dart';
import '../models/meter.dart';
import '../models/meter_reading.dart';
import '../models/meter_reading_card_data.dart';

/// Consumption = latest raw value − previous raw value when both exist.
double? calculateMeterReadingConsumption({
  required double? latestValue,
  required double? previousValue,
}) {
  if (latestValue == null || previousValue == null) {
    return null;
  }
  return latestValue - previousValue;
}

bool isNegativeMeterConsumption(double? consumption) {
  if (consumption == null) {
    return false;
  }
  return consumption < 0;
}

bool isReadingCorrected(MeterReading? reading) {
  if (reading == null) {
    return false;
  }
  final note = reading.note?.toLowerCase() ?? '';
  return note.contains('correct');
}

MeterReadingCardStatus resolveMeterReadingCardStatus({
  required bool isActive,
  required MeterReading? latestOnDate,
}) {
  if (latestOnDate != null) {
    return MeterReadingCardStatus.submittedOnDate;
  }
  if (isActive) {
    return MeterReadingCardStatus.pendingOnDate;
  }
  return MeterReadingCardStatus.noReadingOnDate;
}

MeterReadingCardData buildMeterReadingCardData({
  required Meter meter,
  required DateTime businessDate,
  MeterReading? latestOnDate,
  MeterReading? previousReading,
}) {
  final consumption = calculateMeterReadingConsumption(
    latestValue: latestOnDate?.rawValue,
    previousValue: previousReading?.rawValue,
  );
  final negative = isNegativeMeterConsumption(consumption);
  final corrected = isReadingCorrected(latestOnDate);

  return MeterReadingCardData(
    meterId: meter.id,
    meterCode: meter.meterCode,
    meterName: meter.nameEn,
    meterNameAr: meter.nameAr,
    categoryName: meter.categoryConfig?.nameEn ?? meter.category.label,
    sourceName: meter.sourceDisplayName,
    sourceCode: meter.sourceConfig?.code ?? meter.source.dbValue,
    unitLabel: meter.unitDisplayLabel,
    status: resolveMeterReadingCardStatus(
      isActive: meter.isActive,
      latestOnDate: latestOnDate,
    ),
    isActive: meter.isActive,
    isMain: meter.level == MeterLevel.main,
    parentMeterId: meter.parentMeterId,
    parentMeterCode: meter.parentMeterCode,
    parentMeterName: meter.parentMeterNameEn,
    previousValue: previousReading?.rawValue,
    previousDate: previousReading?.readingDate,
    latestValue: latestOnDate?.rawValue,
    latestDate: latestOnDate?.readingDate,
    latestEnteredAt: latestOnDate?.enteredAt,
    consumptionValue: consumption,
    imageStoragePath: latestOnDate?.imageStoragePath,
    hasPhoto: latestOnDate?.hasPhoto ?? false,
    previousImageStoragePath: previousReading?.imageStoragePath,
    previousHasPhoto: previousReading?.hasPhoto ?? false,
    previousReadingId: previousReading?.id,
    isCorrected: corrected,
    hasNegativeConsumption: negative,
    latestReadingId: latestOnDate?.id,
  );
}

bool matchesMeterReadingStatusFilter(
  MeterReadingCardData card,
  String? statusFilter,
) {
  if (statusFilter == null || statusFilter.isEmpty || statusFilter == 'all') {
    return true;
  }
  return switch (statusFilter) {
    'submitted' => card.status == MeterReadingCardStatus.submittedOnDate,
    'pending' => card.status == MeterReadingCardStatus.pendingOnDate,
    'has_alert' => card.hasAlert,
    'has_photo' => card.hasPhoto,
    'missing_photo' =>
      card.status == MeterReadingCardStatus.submittedOnDate && !card.hasPhoto,
    'negative_consumption' => card.hasNegativeConsumption,
    _ => true,
  };
}

int compareMeterReadingCards(
  MeterReadingCardData a,
  MeterReadingCardData b,
  String sortKey,
) {
  return switch (sortKey) {
    'highest_consumption' => _compareNullableDouble(
      b.consumptionValue,
      a.consumptionValue,
    ),
    'pending_first' => _comparePendingFirst(a, b),
    'alerts_first' => _compareAlertsFirst(a, b),
    'latest_reading_date' => _compareLatestReadingDate(a, b),
    'missing_photo_first' => _compareMissingPhotoFirst(a, b),
    'source_then_code' => _compareSourceThenCode(a, b),
    'meter_name' => a.meterName.compareTo(b.meterName),
    'meter_code' => a.meterCode.compareTo(b.meterCode),
    _ => a.meterCode.compareTo(b.meterCode),
  };
}

int _compareNullableDouble(double? a, double? b) {
  final left = a ?? -1;
  final right = b ?? -1;
  return left.compareTo(right);
}

int _comparePendingFirst(MeterReadingCardData a, MeterReadingCardData b) {
  final aPending = a.status == MeterReadingCardStatus.pendingOnDate ? 0 : 1;
  final bPending = b.status == MeterReadingCardStatus.pendingOnDate ? 0 : 1;
  final pendingCmp = aPending.compareTo(bPending);
  if (pendingCmp != 0) {
    return pendingCmp;
  }
  return a.meterCode.compareTo(b.meterCode);
}

int _compareAlertsFirst(MeterReadingCardData a, MeterReadingCardData b) {
  final aAlert = a.hasAlert ? 0 : 1;
  final bAlert = b.hasAlert ? 0 : 1;
  final alertCmp = aAlert.compareTo(bAlert);
  if (alertCmp != 0) {
    return alertCmp;
  }
  return a.meterCode.compareTo(b.meterCode);
}

int _compareLatestReadingDate(MeterReadingCardData a, MeterReadingCardData b) {
  final aDate = a.latestDate ?? a.previousDate;
  final bDate = b.latestDate ?? b.previousDate;
  if (aDate == null && bDate == null) {
    return a.meterCode.compareTo(b.meterCode);
  }
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final dateCmp = bDate.compareTo(aDate);
  if (dateCmp != 0) return dateCmp;
  return a.meterCode.compareTo(b.meterCode);
}

int _compareMissingPhotoFirst(MeterReadingCardData a, MeterReadingCardData b) {
  final aMissing =
      a.status == MeterReadingCardStatus.submittedOnDate && !a.hasPhoto ? 0 : 1;
  final bMissing =
      b.status == MeterReadingCardStatus.submittedOnDate && !b.hasPhoto ? 0 : 1;
  final cmp = aMissing.compareTo(bMissing);
  if (cmp != 0) return cmp;
  return a.meterCode.compareTo(b.meterCode);
}

int _compareSourceThenCode(MeterReadingCardData a, MeterReadingCardData b) {
  final sourceCmp = a.sourceName.compareTo(b.sourceName);
  if (sourceCmp != 0) return sourceCmp;
  return a.meterCode.compareTo(b.meterCode);
}

MeterReadingCardData? findMeterCardByCodes(
  List<MeterReadingCardData> cards,
  List<String> codes,
) {
  for (final code in codes) {
    for (final card in cards) {
      if (card.meterCode == code) {
        return card;
      }
    }
  }
  return null;
}
