import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  final businessDate = DateTime(2026, 7, 4);

  SiteAlertContext baseContext({
    int submitted = 5,
    int total = 10,
    List<MeterAlertContext> meters = const [],
    List<CopAlertContext> copGroups = const [],
  }) {
    return SiteAlertContext(
      siteId: 'site-1',
      siteName: 'Test School A',
      zoneName: 'North Zone',
      submittedToday: submitted,
      totalEntryMeters: total,
      meters: meters,
      copGroups: copGroups,
      businessDate: businessDate,
    );
  }

  MeterAlertContext meter({
    required String id,
    bool hasReadingToday = true,
    double? latest,
    double? previous,
    List<double> recent = const [],
    double? todayConsumption,
    bool hasPhoto = true,
    bool active = true,
    bool includeDashboard = true,
    int consecutiveWater = 0,
    String category = 'Water',
    bool inactiveReading = false,
  }) {
    return MeterAlertContext(
      meterId: id,
      meterCode: '$id-code',
      meterName: 'Meter $id',
      categoryName: category,
      categoryCode: category.toLowerCase(),
      isActive: active,
      includeInDashboard: includeDashboard,
      hasReadingToday: hasReadingToday,
      latestValue: latest,
      previousValue: previous,
      latestReadingDate: businessDate,
      todayReadingHasPhoto: hasPhoto,
      todayConsumption: todayConsumption,
      recentDailyConsumptions: recent,
      consecutiveHighWaterDays: consecutiveWater,
      hasRecentReadingWhileInactive: inactiveReading,
    );
  }

  test('detects missing reading today', () {
    final alerts = detectSiteAlerts(
      baseContext(meters: [meter(id: 'm1', hasReadingToday: false)]),
    );
    expect(alerts.any((a) => a.type == AlertType.missingReading), isTrue);
    expect(
      alerts.firstWhere((a) => a.type == AlertType.missingReading).severity,
      AlertSeverity.warning,
    );
  });

  test('detects lower than previous reading', () {
    final alerts = detectSiteAlerts(
      baseContext(meters: [meter(id: 'm1', latest: 90, previous: 100)]),
    );
    expect(alerts.any((a) => a.type == AlertType.lowerThanPrevious), isTrue);
    expect(
      alerts.firstWhere((a) => a.type == AlertType.lowerThanPrevious).severity,
      AlertSeverity.critical,
    );
  });

  test('detects high consumption with enough history', () {
    final alerts = detectSiteAlerts(
      baseContext(
        meters: [
          meter(id: 'm1', recent: [10, 12, 11, 10], todayConsumption: 40),
        ],
      ),
    );
    expect(alerts.any((a) => a.type == AlertType.highConsumption), isTrue);
  });

  test('detects low completion critical below 50%', () {
    final alerts = detectSiteAlerts(baseContext(submitted: 2, total: 10));
    expect(alerts.any((a) => a.type == AlertType.lowCompletion), isTrue);
    expect(
      alerts.firstWhere((a) => a.type == AlertType.lowCompletion).severity,
      AlertSeverity.critical,
    );
  });

  test('detects low COP', () {
    final alerts = detectSiteAlerts(
      baseContext(
        copGroups: [
          const CopAlertContext(
            copGroupId: 'cop-1',
            copGroupName: 'Main COP',
            btuMeterCount: 1,
            electricityMeterCount: 1,
            averageCop: 2.0,
          ),
        ],
      ),
    );
    expect(alerts.any((a) => a.type == AlertType.lowCop), isTrue);
  });

  test('detects possible water leak', () {
    final alerts = detectSiteAlerts(
      baseContext(
        meters: [meter(id: 'w1', category: 'Water', consecutiveWater: 3)],
      ),
    );
    expect(alerts.any((a) => a.type == AlertType.possibleLeak), isTrue);
    expect(
      alerts.firstWhere((a) => a.type == AlertType.possibleLeak).severity,
      AlertSeverity.critical,
    );
  });

  test('countConsecutiveHighWaterDays stops at normal day', () {
    expect(
      countConsecutiveHighWaterDays(
        dailyConsumptionsNewestFirst: [30, 25, 5, 20],
        average: 10,
      ),
      2,
    );
  });
}
