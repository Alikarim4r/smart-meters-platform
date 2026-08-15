enum PersistenceStatus {
  verified('verified'),
  sustained('sustained'),
  partiallySustained('partially_sustained'),
  notSustained('not_sustained'),
  insufficientFollowUp('insufficient_follow_up'),
  declining('declining'),
  stale('stale');

  const PersistenceStatus(this.dbValue);
  final String dbValue;

  static PersistenceStatus fromDb(String value) =>
      PersistenceStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => PersistenceStatus.insufficientFollowUp,
      );

  static const decliningLabel = 'Saving Persistence Declining';
  static const notSustainedLabel = 'Saving Not Sustained';
}

enum PersistenceWindow {
  oneMonth('1m', 30),
  threeMonths('3m', 90),
  sixMonths('6m', 180),
  twelveMonths('12m', 365);

  const PersistenceWindow(this.dbValue, this.approxDays);
  final String dbValue;
  final int approxDays;

  static PersistenceWindow fromDb(String value) =>
      PersistenceWindow.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => PersistenceWindow.oneMonth,
      );
}
