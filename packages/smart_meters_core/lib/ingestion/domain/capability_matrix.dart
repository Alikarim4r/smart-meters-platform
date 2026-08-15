import 'data_frequency.dart';

/// Analytics capabilities gated by data frequency (Phase 6 matrix only).
abstract final class DataCapabilities {
  static const periodComparisons = 'period_comparisons';
  static const targets = 'targets';
  static const baselines = 'baselines';
  static const balance = 'balance';
  static const mv = 'mv';
  static const forecast = 'forecast';
  static const loadProfile = 'load_profile';
  static const nightFlow = 'night_flow';
  static const peakDemand = 'peak_demand';
  static const timeOfUse = 'time_of_use';
}

/// Static capability matrix mirroring migration 093 seed.
class CapabilityMatrix {
  const CapabilityMatrix();

  static const Map<DataFrequency, Set<String>> _supported = {
    DataFrequency.periodicManual: {
      DataCapabilities.periodComparisons,
      DataCapabilities.targets,
      DataCapabilities.baselines,
      DataCapabilities.balance,
      DataCapabilities.mv,
      DataCapabilities.forecast,
    },
    DataFrequency.monthly: {
      DataCapabilities.periodComparisons,
      DataCapabilities.targets,
      DataCapabilities.baselines,
      DataCapabilities.balance,
      DataCapabilities.mv,
      DataCapabilities.forecast,
    },
    DataFrequency.weekly: {
      DataCapabilities.periodComparisons,
      DataCapabilities.targets,
      DataCapabilities.baselines,
      DataCapabilities.balance,
      DataCapabilities.mv,
      DataCapabilities.forecast,
    },
    DataFrequency.daily: {
      DataCapabilities.periodComparisons,
      DataCapabilities.targets,
      DataCapabilities.baselines,
      DataCapabilities.balance,
      DataCapabilities.mv,
      DataCapabilities.forecast,
    },
    DataFrequency.hourly: {
      DataCapabilities.loadProfile,
      DataCapabilities.peakDemand,
    },
    DataFrequency.interval15m: {
      DataCapabilities.loadProfile,
      DataCapabilities.nightFlow,
      DataCapabilities.peakDemand,
      DataCapabilities.timeOfUse,
    },
    DataFrequency.eventBased: {},
  };

  bool isSupported(DataFrequency frequency, String capabilityKey) {
    return _supported[frequency]?.contains(capabilityKey) ?? false;
  }

  Set<String> supportedFor(DataFrequency frequency) =>
      Set.unmodifiable(_supported[frequency] ?? const {});
}
