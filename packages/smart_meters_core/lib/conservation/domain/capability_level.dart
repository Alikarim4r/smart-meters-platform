/// Capability level for Conservation analytics inputs.
enum ConservationCapabilityLevel {
  /// Manual periodic readings only.
  a('A'),

  /// Manual readings + weather/occupancy metadata.
  b('B'),

  /// Imported / smart interval data.
  c('C');

  const ConservationCapabilityLevel(this.dbValue);
  final String dbValue;

  static ConservationCapabilityLevel fromDb(String value) =>
      ConservationCapabilityLevel.values.firstWhere(
        (e) => e.dbValue == value.toUpperCase(),
        orElse: () => ConservationCapabilityLevel.a,
      );
}
