import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:entry_app/models/meter_entry_status.dart';
import 'package:entry_app/offline/local_reading_draft.dart';

Meter _meter() {
  return Meter(
    id: 'meter-1',
    siteId: 'site-1',
    meterCode: 'M-001',
    nameEn: 'Main Water',
    nameAr: 'Main Water',
    categoryId: 'cat-water',
    sourceId: 'src-kahramaa',
    unitId: 'unit-m3',
    category: MeterCategory.water,
    source: MeterSource.kahramaa,
    unit: MeterUnit.m3,
    unitToBaseFactor: 1,
    baseUnit: 'm3',
    level: MeterLevel.main,
    meterMultiplier: 1,
    meterKind: MeterKind.physical,
    calculationType: CalculationType.directReading,
    isActive: true,
    includeInDashboard: true,
    sortOrder: 0,
  );
}

LocalReadingDraft _draft(LocalReadingStatus status) {
  return LocalReadingDraft(
    localId: 'local-1',
    siteId: 'site-1',
    meterId: 'meter-1',
    readingDate: '2026-07-04',
    rawValue: 100,
    status: status,
    createdAt: DateTime(2026, 7, 4),
    updatedAt: DateTime(2026, 7, 4),
  );
}

void main() {
  test('resolveWorkStatus prefers server reading', () {
    final status = MeterEntryStatus.resolveWorkStatus(
      todayReading: MeterReading(
        id: 'r1',
        siteId: 'site-1',
        meterId: 'meter-1',
        readingDate: DateTime(2026, 7, 4),
        rawValue: 50,
        normalizedValue: 50,
        enteredAt: DateTime(2026, 7, 4),
      ),
      localDraft: _draft(LocalReadingStatus.savedLocally),
    );
    expect(status, MeterWorkStatus.submitted);
  });

  test('resolveWorkStatus maps local draft states', () {
    expect(
      MeterEntryStatus.resolveWorkStatus(
        localDraft: _draft(LocalReadingStatus.savedLocally),
      ),
      MeterWorkStatus.savedLocally,
    );
    expect(
      MeterEntryStatus.resolveWorkStatus(
        localDraft: _draft(LocalReadingStatus.conflict),
      ),
      MeterWorkStatus.conflict,
    );
  });

  test('search matches code and location', () {
    final status = MeterEntryStatus(
      meter: _meter(),
      workStatus: MeterWorkStatus.pending,
      location: 'Pump room',
    );
    expect(matchesMeterSearch(status, 'pump'), isTrue);
    expect(matchesMeterSearch(status, 'm-001'), isTrue);
    expect(matchesMeterSearch(status, 'electric'), isFalse);
  });

  test('filter chips map to work status', () {
    final pending = MeterEntryStatus(
      meter: _meter(),
      workStatus: MeterWorkStatus.pending,
    );
    final failed = MeterEntryStatus(
      meter: _meter(),
      workStatus: MeterWorkStatus.failedSync,
    );

    expect(matchesMeterFilter(pending, MeterListFilter.pending), isTrue);
    expect(matchesMeterFilter(failed, MeterListFilter.failedSync), isTrue);
    expect(matchesMeterFilter(pending, MeterListFilter.submitted), isFalse);
  });

  test('local draft editable only before sync', () {
    expect(_draft(LocalReadingStatus.savedLocally).isEditable, isTrue);
    expect(_draft(LocalReadingStatus.synced).isEditable, isFalse);
    expect(_draft(LocalReadingStatus.conflict).isEditable, isFalse);
  });
}
