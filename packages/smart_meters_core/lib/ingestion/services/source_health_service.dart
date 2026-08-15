import '../domain/data_frequency.dart';

enum SourceHealthStatus {
  healthy,
  delayed,
  failed,
  neverSynced,
  disabled,
  authenticationRequired;

  String get wireValue => switch (this) {
        SourceHealthStatus.healthy => 'healthy',
        SourceHealthStatus.delayed => 'delayed',
        SourceHealthStatus.failed => 'failed',
        SourceHealthStatus.neverSynced => 'never_synced',
        SourceHealthStatus.disabled => 'disabled',
        SourceHealthStatus.authenticationRequired => 'authentication_required',
      };
}

class SourceHealthInput {
  const SourceHealthInput({
    required this.enabled,
    this.lastSuccessfulSyncAt,
    this.lastDataTimestamp,
    this.lastError,
    this.expectedFrequency,
    this.authenticationRequired = false,
    this.now,
  });

  final bool enabled;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastDataTimestamp;
  final String? lastError;
  final DataFrequency? expectedFrequency;
  final bool authenticationRequired;
  final DateTime? now;
}

class SourceHealthResult {
  const SourceHealthResult({
    required this.status,
    this.delay,
    this.message,
  });

  final SourceHealthStatus status;
  final Duration? delay;
  final String? message;
}

class SourceHealthService {
  const SourceHealthService();

  /// Expected max delay before marking Delayed (not Equipment Fault).
  Duration expectedMaxDelay(DataFrequency frequency) => switch (frequency) {
        DataFrequency.interval15m => const Duration(minutes: 45),
        DataFrequency.hourly => const Duration(hours: 3),
        DataFrequency.daily => const Duration(hours: 36),
        DataFrequency.weekly => const Duration(days: 8),
        DataFrequency.monthly => const Duration(days: 35),
        DataFrequency.periodicManual => const Duration(days: 40),
        DataFrequency.eventBased => const Duration(days: 7),
      };

  SourceHealthResult evaluate(SourceHealthInput input) {
    if (!input.enabled) {
      return const SourceHealthResult(
        status: SourceHealthStatus.disabled,
        message: 'Source disabled',
      );
    }
    if (input.authenticationRequired) {
      return const SourceHealthResult(
        status: SourceHealthStatus.authenticationRequired,
        message: 'Authentication required',
      );
    }
    if (input.lastError != null &&
        input.lastError!.trim().isNotEmpty &&
        input.lastSuccessfulSyncAt == null) {
      return SourceHealthResult(
        status: SourceHealthStatus.failed,
        message: input.lastError,
      );
    }
    final lastTs = input.lastDataTimestamp ?? input.lastSuccessfulSyncAt;
    if (lastTs == null) {
      return const SourceHealthResult(
        status: SourceHealthStatus.neverSynced,
        message: 'Never synced',
      );
    }
    final now = input.now ?? DateTime.now().toUtc();
    final delay = now.difference(lastTs.toUtc());
    final freq = input.expectedFrequency ?? DataFrequency.daily;
    final maxDelay = expectedMaxDelay(freq);
    if (delay > maxDelay) {
      return SourceHealthResult(
        status: SourceHealthStatus.delayed,
        delay: delay,
        message:
            'Data Availability — expected reading not received within ${maxDelay.inHours}h window',
      );
    }
    if (input.lastError != null && input.lastError!.trim().isNotEmpty) {
      return SourceHealthResult(
        status: SourceHealthStatus.failed,
        delay: delay,
        message: input.lastError,
      );
    }
    return SourceHealthResult(
      status: SourceHealthStatus.healthy,
      delay: delay,
      message: 'Healthy',
    );
  }
}
