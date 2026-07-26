import 'package:smart_meters_core/smart_meters_core.dart';

import '../offline/cached_meter.dart';
import '../offline/local_reading_draft.dart';

enum MeterWorkStatus {
  pending,
  savedLocally,
  syncing,
  submitted,
  failedSync,
  conflict;

  String get label {
    switch (this) {
      case MeterWorkStatus.pending:
        return 'Pending';
      case MeterWorkStatus.savedLocally:
        return 'Saved locally';
      case MeterWorkStatus.syncing:
        return 'Syncing';
      case MeterWorkStatus.submitted:
        return 'Submitted';
      case MeterWorkStatus.failedSync:
        return 'Failed sync';
      case MeterWorkStatus.conflict:
        return 'Conflict';
    }
  }

  String localizedLabel(bool isAr) {
    if (!isAr) return label;
    return switch (this) {
      MeterWorkStatus.pending => 'معلّق',
      MeterWorkStatus.savedLocally => 'محفوظ محلياً',
      MeterWorkStatus.syncing => 'جارٍ المزامنة',
      MeterWorkStatus.submitted => 'مُرسَل',
      MeterWorkStatus.failedSync => 'فشل المزامنة',
      MeterWorkStatus.conflict => 'تعارض',
    };
  }
}

enum MeterListFilter {
  all,
  pending,
  submitted,
  savedLocally,
  failedSync;

  String get label {
    switch (this) {
      case MeterListFilter.all:
        return 'All';
      case MeterListFilter.pending:
        return 'Pending';
      case MeterListFilter.submitted:
        return 'Submitted';
      case MeterListFilter.savedLocally:
        return 'Saved locally';
      case MeterListFilter.failedSync:
        return 'Failed sync';
    }
  }

  String localizedLabel(bool isAr) {
    if (!isAr) return label;
    return switch (this) {
      MeterListFilter.all => 'الكل',
      MeterListFilter.pending => 'معلّق',
      MeterListFilter.submitted => 'مُرسَل',
      MeterListFilter.savedLocally => 'محفوظ محلياً',
      MeterListFilter.failedSync => 'فشل المزامنة',
    };
  }
}

class MeterEntryStatus {
  const MeterEntryStatus({
    required this.meter,
    required this.workStatus,
    this.todayReading,
    this.localDraft,
    this.lastReading,
    this.location,
  });

  final Meter meter;
  final MeterWorkStatus workStatus;
  final MeterReading? todayReading;
  final LocalReadingDraft? localDraft;
  final MeterReading? lastReading;
  final String? location;

  bool get isSubmitted => workStatus == MeterWorkStatus.submitted;

  bool get isReadOnly =>
      workStatus == MeterWorkStatus.submitted ||
      workStatus == MeterWorkStatus.syncing ||
      workStatus == MeterWorkStatus.conflict;

  bool get canEnterReading =>
      workStatus == MeterWorkStatus.pending ||
      workStatus == MeterWorkStatus.savedLocally ||
      workStatus == MeterWorkStatus.failedSync;

  static MeterWorkStatus resolveWorkStatus({
    MeterReading? todayReading,
    LocalReadingDraft? localDraft,
  }) {
    if (todayReading != null) {
      return MeterWorkStatus.submitted;
    }
    if (localDraft == null) {
      return MeterWorkStatus.pending;
    }
    switch (localDraft.status) {
      case LocalReadingStatus.synced:
        return MeterWorkStatus.submitted;
      case LocalReadingStatus.syncing:
        return MeterWorkStatus.syncing;
      case LocalReadingStatus.conflict:
        return MeterWorkStatus.conflict;
      case LocalReadingStatus.failed:
        return MeterWorkStatus.failedSync;
      case LocalReadingStatus.savedLocally:
      case LocalReadingStatus.draft:
        return MeterWorkStatus.savedLocally;
    }
  }
}

class MeterWorkSummary {
  const MeterWorkSummary({
    required this.total,
    required this.pending,
    required this.savedLocally,
    required this.submitted,
    required this.failedSync,
  });

  final int total;
  final int pending;
  final int savedLocally;
  final int submitted;
  final int failedSync;

  /// Field-complete: value saved locally or already submitted.
  int get completed => submitted + savedLocally;

  double get completionRatio => total == 0 ? 0 : completed / total;

  factory MeterWorkSummary.fromStatuses(List<MeterEntryStatus> statuses) {
    var pending = 0;
    var savedLocally = 0;
    var submitted = 0;
    var failedSync = 0;

    for (final status in statuses) {
      switch (status.workStatus) {
        case MeterWorkStatus.pending:
          pending++;
        case MeterWorkStatus.savedLocally:
          savedLocally++;
        case MeterWorkStatus.submitted:
          submitted++;
        case MeterWorkStatus.failedSync:
        case MeterWorkStatus.conflict:
          failedSync++;
        case MeterWorkStatus.syncing:
          savedLocally++;
      }
    }

    return MeterWorkSummary(
      total: statuses.length,
      pending: pending,
      savedLocally: savedLocally,
      submitted: submitted,
      failedSync: failedSync,
    );
  }
}

MeterReading? lastReadingFromCached(CachedMeter cached) {
  if (cached.lastReadingValue == null || cached.lastReadingDate == null) {
    return null;
  }
  return MeterReading(
    id: 'cached-${cached.meterId}',
    siteId: cached.siteId,
    meterId: cached.meterId,
    readingDate: DateTime.parse(cached.lastReadingDate!),
    rawValue: cached.lastReadingValue!,
    normalizedValue: cached.lastReadingValue!,
    enteredAt: DateTime.parse(cached.lastReadingDate!),
  );
}

bool matchesMeterSearch(MeterEntryStatus status, String query) {
  if (query.isEmpty) {
    return true;
  }
  final haystack = [
    status.meter.nameEn,
    status.meter.meterCode,
    status.location ?? '',
  ].join(' ').toLowerCase();
  return haystack.contains(query.toLowerCase());
}

bool matchesMeterFilter(MeterEntryStatus status, MeterListFilter filter) {
  switch (filter) {
    case MeterListFilter.all:
      return true;
    case MeterListFilter.pending:
      return status.workStatus == MeterWorkStatus.pending;
    case MeterListFilter.submitted:
      return status.workStatus == MeterWorkStatus.submitted;
    case MeterListFilter.savedLocally:
      return status.workStatus == MeterWorkStatus.savedLocally ||
          status.workStatus == MeterWorkStatus.syncing;
    case MeterListFilter.failedSync:
      return status.workStatus == MeterWorkStatus.failedSync ||
          status.workStatus == MeterWorkStatus.conflict;
  }
}
