import 'dart:typed_data';

import 'package:dashboard_app/reports/excel_report_service.dart';
import 'package:dashboard_app/reports/pdf_report_service.dart';
import 'package:dashboard_app/reports/report_filename.dart';
import 'package:dashboard_app/reports/report_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('report export smoke', () {
    late SiteReportBundle bundle;
    late AllSitesReportBundle allSitesBundle;

    setUp(() {
      final site = Site(
        id: '22222222-2222-4222-8222-222222222222',
        organizationId: '11111111-1111-4111-8111-111111111111',
        zoneId: 'zone-1',
        nameEn: 'MOEHE HQ — مكتب',
        nameAr: 'مكتب',
        siteType: SiteType.office,
        location: 'Doha',
        isActive: true,
      );
      final category = MeterCategoryConfig(
        id: 'cat-water',
        code: 'water',
        nameEn: 'Water',
        nameAr: 'ماء',
        baseUnitCode: 'm3',
        isSystem: true,
        isActive: true,
        sortOrder: 1,
        supportsCopOutput: false,
        supportsElectricInput: false,
        isConsumptionCategory: true,
      );
      final reading = MeterReading(
        id: 'reading-1',
        meterId: 'meter-1',
        siteId: site.id,
        readingDate: DateTime(2026, 7, 4),
        rawValue: 1234.5,
        normalizedValue: 1234.5,
        enteredAt: DateTime(2026, 7, 4, 10),
        note: 'Test note with — dash and m³ unit',
        imageStoragePath: 'org/site/meter/photo.jpg',
      );
      bundle = SiteReportBundle(
        meta: ReportMeta(
          title: 'Site Summary Report',
          generatedAt: DateTime(2026, 7, 4, 12),
          generatedByEmail: 'test@example.com',
          period: ChartPeriod.weekly,
          siteName: site.nameEn,
          zoneName: 'Central',
          siteType: site.siteType.label,
          location: site.location,
          organizationDisplayName: 'MOEHE — Ministry',
          reportFooterText: 'Confidential — internal use only',
        ),
        summary: SiteDashboardSummary(
          site: site,
          totalMeters: 5,
          activeMeters: 4,
          readingsSubmittedToday: 3,
          pendingReadingsToday: 1,
          categoriesCount: 2,
          copGroupsCount: 1,
          lastReadingDate: DateTime(2026, 7, 4),
        ),
        categories: [
          SiteCategorySummary(
            category: category,
            meterCount: 3,
            readingsSubmittedToday: 2,
            totalDailyConsumption: 45.67,
          ),
        ],
        meters: [
          DashboardMeterRow(
            meterId: 'meter-1',
            meterCode: 'W-01',
            nameEn: 'Main Water',
            categoryId: category.id,
            categoryName: 'Water',
            sourceName: 'Kahramaa',
            unitLabel: 'm³',
            level: MeterLevel.main,
            isActive: true,
            includeInDashboard: true,
            hasSubmittedToday: true,
            latestRawValue: 1234.5,
            latestReadingDate: DateTime(2026, 7, 4),
          ),
        ],
        readings: [
          DashboardExportReadingRow(
            reading: reading,
            siteName: site.nameEn,
            zoneName: 'Central',
            meterName: 'Main Water',
            meterCode: 'W-01',
            categoryName: 'Water',
            unitLabel: 'm³',
            sourceName: 'Kahramaa',
            enteredByName: 'Technician',
            enteredByEmail: 'tech@example.com',
            dailyConsumption: 12.3,
          ),
        ],
        completion: const TodayReadingProgress(submitted: 3, total: 4, pending: 1),
        consumptionTrend: SiteConsumptionTrend(
          series: [
            CategoryConsumptionSeries(
              categoryId: category.id,
              categoryName: category.nameEn,
              unitCode: 'm3',
              points: [
                TimeSeriesPoint(
                  date: DateTime(2026, 7, 3),
                  value: 10.5,
                  label: '2026-07-03',
                ),
              ],
            ),
          ],
        ),
        categoryRankings: {
          category.id: [
            CategoryRankingItem(
              meterId: 'meter-1',
              meterCode: 'W-01',
              meterName: 'Main Water',
              totalConsumption: 10.5,
            ),
          ],
        },
        copResults: [
          CopTrendResult(
            copGroupId: 'cop-1',
            copGroupName: 'HVAC COP',
            points: [
              CopTrendPoint(
                date: DateTime(2026, 7, 3),
                cop: 4.2,
                btuConsumption: 100,
                electricityConsumption: 24,
              ),
            ],
            btuMeterCount: 1,
            electricityMeterCount: 1,
            averageCop: 4.2,
            minCop: 4.2,
            maxCop: 4.2,
          ),
        ],
        alerts: [
          DashboardAlert(
            id: 'alert-1',
            type: AlertType.missingReading,
            severity: AlertSeverity.warning,
            title: 'Missing reading',
            message: 'No reading today for W-02',
            siteId: site.id,
            siteName: site.nameEn,
            zoneName: 'Central',
            meterCode: 'W-02',
            categoryName: 'Water',
            suggestedAction: 'Submit reading',
            createdAt: DateTime(2026, 7, 4),
          ),
        ],
      );

      allSitesBundle = AllSitesReportBundle(
        meta: ReportMeta(
          title: 'All Accessible Sites Summary',
          generatedAt: DateTime(2026, 7, 4, 12),
          generatedByEmail: 'test@example.com',
          period: ChartPeriod.weekly,
        ),
        sites: [
          DashboardSiteOverview(
            site: site,
            meterCount: 5,
            activeMeterCount: 4,
            categories: [category],
            readingsSubmittedToday: 3,
            entryEligibleMeterCount: 4,
            lastReadingDate: DateTime(2026, 7, 4),
          ),
        ],
        alerts: bundle.alerts,
      );
    });

    test('builds site summary PDF bytes', () async {
      final bytes = await PdfReportService().buildSitePdf(
        bundle: bundle,
        type: ReportType.siteSummary,
        includePhotos: true,
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(500));
    });

    test('builds readings Excel bytes', () async {
      final bytes = await ExcelReportService().buildReadingsExcel(bundle);
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(100));
    });

    test('builds all sites PDF bytes', () async {
      final bytes = await PdfReportService().buildAllSitesPdf(allSitesBundle);
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(200));
    });

    test('builds safe filename for unicode site name', () {
      final filename = buildReportFilename(
        siteName: 'MOEHE HQ — مكتب',
        type: ReportType.siteSummary,
        format: ReportFormat.pdf,
        period: ChartPeriod.weekly,
        generatedAt: DateTime(2026, 7, 4),
      );
      expect(filename, contains('.pdf'));
      expect(filename, isNot(contains('—')));
      expect(filename, isNot(contains('مكتب')));
    });
  });
}
