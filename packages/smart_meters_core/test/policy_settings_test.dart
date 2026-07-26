import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('PolicySettings defaults', () {
    test('matches platform operational defaults', () {
      final policy = PolicySettings.defaults('org-1');
      expect(policy.photoRequired, isFalse);
      expect(policy.missingPhotoSeverity, MissingPhotoSeverity.info);
      expect(policy.highConsumptionMultiplier, 3.0);
      expect(policy.highConsumptionCriticalMultiplier, 5.0);
      expect(policy.lowCompletionWarningPercent, 80);
      expect(policy.lowCompletionCriticalPercent, 50);
      expect(policy.lowCopWarningThreshold, 2.5);
      expect(policy.lowCopCriticalThreshold, 2.0);
      expect(policy.zeroConsumptionAlertEnabled, isTrue);
      expect(policy.possibleLeakDaysWarning, 2);
      expect(policy.possibleLeakDaysCritical, 3);
    });
  });

  group('readingViolatesPhotoPolicy', () {
    test('blocks when photo required and missing', () {
      expect(
        readingViolatesPhotoPolicy(
          policy: PolicySettings.defaults('org').copyWith(photoRequired: true),
          hasPhoto: false,
        ),
        isTrue,
      );
    });

    test('allows when photo optional', () {
      expect(
        readingViolatesPhotoPolicy(
          policy: PolicySettings.defaults('org'),
          hasPhoto: false,
        ),
        isFalse,
      );
    });
  });

  group('detectSiteAlerts policy integration', () {
    final businessDate = DateTime(2026, 7, 4);

    SiteAlertContext context({
      required PolicySettings policy,
      List<MeterAlertContext> meters = const [],
      List<CopAlertContext> copGroups = const [],
      int submitted = 10,
      int total = 10,
    }) {
      return SiteAlertContext(
        siteId: 'site-1',
        siteName: 'Site',
        zoneName: 'Zone',
        submittedToday: submitted,
        totalEntryMeters: total,
        meters: meters,
        copGroups: copGroups,
        businessDate: businessDate,
        policy: policy,
      );
    }

    MeterAlertContext meter({
      bool hasPhoto = false,
      List<double> recent = const [10, 10, 10],
      double? todayConsumption = 40,
    }) {
      return MeterAlertContext(
        meterId: 'm1',
        meterCode: 'm1',
        meterName: 'Meter 1',
        categoryName: 'Electricity',
        categoryCode: 'electricity',
        isActive: true,
        includeInDashboard: true,
        hasReadingToday: true,
        todayReadingHasPhoto: hasPhoto,
        recentDailyConsumptions: recent,
        todayConsumption: todayConsumption,
      );
    }

    test('missing photo severity follows policy', () {
      final alerts = detectSiteAlerts(
        context(
          policy: PolicySettings.defaults(
            'org',
          ).copyWith(missingPhotoSeverity: MissingPhotoSeverity.warning),
          meters: [meter(hasPhoto: false)],
        ),
      );
      final photoAlert = alerts.firstWhere(
        (a) => a.type == AlertType.missingPhoto,
      );
      expect(photoAlert.severity, AlertSeverity.warning);
    });

    test('high consumption uses policy multiplier', () {
      final alerts = detectSiteAlerts(
        context(
          policy: PolicySettings.defaults('org').copyWith(
            highConsumptionMultiplier: 2.0,
            highConsumptionCriticalMultiplier: 4.0,
          ),
          meters: [meter(todayConsumption: 25)],
        ),
      );
      expect(alerts.any((a) => a.type == AlertType.highConsumption), isTrue);
      final alert = alerts.firstWhere(
        (a) => a.type == AlertType.highConsumption,
      );
      expect(alert.severity, AlertSeverity.warning);
    });

    test('low completion uses policy percentages', () {
      final alerts = detectSiteAlerts(
        context(
          policy: PolicySettings.defaults('org').copyWith(
            lowCompletionWarningPercent: 90,
            lowCompletionCriticalPercent: 40,
          ),
          submitted: 5,
          total: 10,
        ),
      );
      expect(alerts.any((a) => a.type == AlertType.lowCompletion), isTrue);
      expect(
        alerts.firstWhere((a) => a.type == AlertType.lowCompletion).severity,
        AlertSeverity.warning,
      );
    });

    test('low COP uses policy thresholds', () {
      final alerts = detectSiteAlerts(
        context(
          policy: PolicySettings.defaults(
            'org',
          ).copyWith(lowCopWarningThreshold: 3.0, lowCopCriticalThreshold: 2.2),
          copGroups: const [
            CopAlertContext(
              copGroupId: 'cop-1',
              copGroupName: 'Main',
              btuMeterCount: 1,
              electricityMeterCount: 1,
              averageCop: 2.1,
            ),
          ],
        ),
      );
      expect(alerts.any((a) => a.type == AlertType.lowCop), isTrue);
      expect(
        alerts.firstWhere((a) => a.type == AlertType.lowCop).severity,
        AlertSeverity.critical,
      );
    });
  });

  group('validatePolicySettings', () {
    test('rejects critical completion above warning', () {
      final result = validatePolicySettings(
        PolicySettings.defaults('org').copyWith(
          lowCompletionWarningPercent: 50,
          lowCompletionCriticalPercent: 60,
        ),
      );
      expect(result.isValid, isFalse);
    });

    test('accepts valid reset defaults shape', () {
      final result = validatePolicySettings(PolicySettings.defaults('org'));
      expect(result.isValid, isTrue);
    });
  });
}
