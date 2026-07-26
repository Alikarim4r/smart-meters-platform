import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../catalog/catalog_helpers.dart';
import '../domain/business_date.dart';
import '../domain/chart_aggregation.dart';
import '../domain/chart_meter_selection.dart';
import '../domain/meter_reading_card_logic.dart';
import '../domain/chart_period.dart';
import '../models/chart_models.dart';
import '../models/dashboard_models.dart';
import '../models/enums.dart';
import '../models/meter.dart';
import '../models/meter_category_config.dart';
import '../models/meter_reading.dart';
import '../models/meter_reading_card_data.dart';
import '../models/profile.dart';
import '../models/report_export_models.dart';
import '../models/site.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  /// In-memory meters cache — cleared on [invalidateSiteCaches].
  final Map<String, List<Meter>> _metersBySite = {};

  void invalidateSiteCaches([String? siteId]) {
    if (siteId == null) {
      _metersBySite.clear();
    } else {
      _metersBySite.remove(siteId);
    }
  }

  static const _siteSelect =
      '*, zones(*), organizations(id, name_en, name_ar, is_active), meters(count)';
  static const _meterSelect = '''
*,
meter_categories(*),
meter_sources(*),
meter_units(*),
parent_meter:parent_meter_id(name_en, meter_code)
''';
  static const _readingSelect = '''
*,
meters(
  name_en,
  meter_code,
  category_id,
  category,
  source,
  unit,
  meter_categories(code, name_en),
  meter_sources(code, name_en),
  meter_units(code, name_en)
),
profiles:entered_by(full_name, email)
''';

  Future<List<Site>> getAccessibleSitesForDashboard() async {
    // Prefer scoped ID RPC + filtered select (same path as SiteAccessGate).
    // A bare `from('sites')` scan forces RLS has_site_access per row and can hang.
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', _client.auth.currentUser!.id)
        .single()
        .timeout(const Duration(seconds: 12));
    final parsed = Profile.fromJson(Map<String, dynamic>.from(profile));
    // Reuse SiteRepository path via RPC list — keep logic local to avoid circular deps.
    if (parsed.isPlatformOwner) {
      final rows = await _client
          .from('sites')
          .select(_siteSelect)
          .eq('is_active', true)
          .order('name_en')
          .timeout(const Duration(seconds: 15));
      return (rows as List)
          .map((row) => Site.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    }
    final ids = await _client
        .rpc('list_readable_site_ids')
        .timeout(const Duration(seconds: 15));
    final idList = <String>[];
    if (ids is List) {
      for (final e in ids) {
        if (e is String) {
          idList.add(e);
        } else if (e is Map && e.values.isNotEmpty && e.values.first is String) {
          idList.add(e.values.first as String);
        }
      }
    }
    if (idList.isEmpty) return [];
    final rows = await _client
        .from('sites')
        .select(_siteSelect)
        .inFilter('id', idList)
        .order('name_en')
        .timeout(const Duration(seconds: 15));
    return (rows as List)
        .map((row) => Site.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<DashboardSiteOverview>> getSitesOverview({
    required DateTime businessDate,
  }) async {
    final sites = await getAccessibleSitesForDashboard();
    if (sites.isEmpty) {
      return [];
    }

    final siteIds = sites.map((site) => site.id).toList();
    final todayIso = formatBusinessDate(businessDate);

    final meterRows = await _client
        .from('meters')
        .select(
          'site_id, category_id, is_active, meter_kind, calculation_type, include_in_dashboard, meter_categories(*)',
        )
        .inFilter('site_id', siteIds)
        .timeout(const Duration(seconds: 15));

    // Today-only readings query — never scan historical rows on the Sites list.
    List todayReadingRows = const [];
    try {
      todayReadingRows =
          await _client
                  .from('meter_readings')
                  .select('site_id, meter_id')
                  .inFilter('site_id', siteIds)
                  .eq('reading_date', todayIso)
                  .timeout(const Duration(seconds: 15))
              as List;
    } catch (_) {
      todayReadingRows = const [];
    }

    final metersBySite = <String, List<Map<String, dynamic>>>{};
    for (final row in meterRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final siteId = map['site_id'] as String;
      metersBySite.putIfAbsent(siteId, () => []).add(map);
    }

    final todayCountBySite = <String, int>{};
    for (final row in todayReadingRows) {
      final siteId = (row as Map)['site_id'] as String;
      todayCountBySite[siteId] = (todayCountBySite[siteId] ?? 0) + 1;
    }

    final today = DateTime.parse(todayIso);
    return [
      for (final site in sites)
        _buildSiteOverview(
          site: site,
          meterRows: metersBySite[site.id] ?? const [],
          readingsSubmittedToday: todayCountBySite[site.id] ?? 0,
          // Prefer today's activity; skip full-history max(reading_date).
          lastReadingDate: (todayCountBySite[site.id] ?? 0) > 0 ? today : null,
        ),
    ];
  }

  DashboardSiteOverview _buildSiteOverview({
    required Site site,
    required List<Map<String, dynamic>> meterRows,
    required int readingsSubmittedToday,
    DateTime? lastReadingDate,
  }) {
    final categoriesById = <String, MeterCategoryConfig>{};
    var activeMeterCount = 0;
    var entryEligibleCount = 0;

    for (final row in meterRows) {
      if (row['is_active'] as bool? ?? false) {
        activeMeterCount++;
      }
      final isEntryEligible =
          (row['is_active'] as bool? ?? false) &&
          row['meter_kind'] == MeterKind.physical.dbValue &&
          row['calculation_type'] == CalculationType.directReading.dbValue &&
          (row['include_in_dashboard'] as bool? ?? true);
      if (isEntryEligible) {
        entryEligibleCount++;
      }

      final categoryJson = row['meter_categories'];
      if (categoryJson is Map) {
        final config = MeterCategoryConfig.fromJson(
          Map<String, dynamic>.from(categoryJson),
        );
        if (config.isActive) {
          categoriesById[config.id] = config;
        }
      }
    }

    final categories = categoriesById.values.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.nameEn.compareTo(b.nameEn);
      });

    return DashboardSiteOverview(
      site: site,
      meterCount: meterRows.length,
      activeMeterCount: activeMeterCount,
      categories: categories,
      readingsSubmittedToday: readingsSubmittedToday,
      entryEligibleMeterCount: entryEligibleCount,
      lastReadingDate: lastReadingDate,
    );
  }

  Future<SiteDashboardSummary> getSiteDashboardSummary({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final todayIso = formatBusinessDate(businessDate);
    final lookbackIso = formatBusinessDate(
      businessDate.subtract(const Duration(days: 45)),
    );

    final siteFuture = _client
        .from('sites')
        .select(_siteSelect)
        .eq('id', siteId)
        .single();
    final metersFuture = _fetchMetersForSite(siteId);
    final todayFuture = _client
        .from('meter_readings')
        .select('id')
        .eq('site_id', siteId)
        .eq('reading_date', todayIso);
    final lastFuture = _client
        .from('meter_readings')
        .select('reading_date')
        .eq('site_id', siteId)
        .gte('reading_date', lookbackIso)
        .order('reading_date', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 3));
    final copFuture = _client
        .from('cop_groups')
        .select('id')
        .eq('site_id', siteId);

    final siteRow = await siteFuture;
    final site = Site.fromJson(Map<String, dynamic>.from(siteRow));
    final meters = await metersFuture;
    final todayReadings = await todayFuture as List;

    DateTime? lastReadingDate;
    if (todayReadings.isNotEmpty) {
      lastReadingDate = businessDate;
    } else {
      try {
        final lastReading = await lastFuture;
        if (lastReading != null) {
          lastReadingDate = DateTime.parse(
            lastReading['reading_date'] as String,
          );
        }
      } catch (_) {}
    }

    final copRows = await copFuture;

    final entryEligible = meters.where((m) => m.isEntryEligible).length;
    final submittedToday = todayReadings.length;
    final categoryIds = meters
        .map((m) => m.categoryId)
        .where((id) => id.isNotEmpty)
        .toSet();

    return SiteDashboardSummary(
      site: site,
      totalMeters: meters.length,
      activeMeters: meters.where((m) => m.isActive).length,
      readingsSubmittedToday: submittedToday,
      pendingReadingsToday: (entryEligible - submittedToday).clamp(
        0,
        entryEligible,
      ),
      categoriesCount: categoryIds.length,
      copGroupsCount: (copRows as List).length,
      lastReadingDate: lastReadingDate,
    );
  }

  Future<List<SiteCategorySummary>> getSiteCategoriesSummary({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final meters = await _fetchMetersForSite(siteId);
    final todayIso = formatBusinessDate(businessDate);

    final todayReadings = await _client
        .from('meter_readings')
        .select('meter_id, entered_at, meters(category_id)')
        .eq('site_id', siteId)
        .eq('reading_date', todayIso);

    // Avoid meter_daily_consumption view (full-history window = timeout).
    final consumptionRows = await _fetchConsumptionRows(
      siteId: siteId,
      from: businessDate,
      to: businessDate,
    );

    // Latest activity from today's readings only (no full-history per-category scans).
    final latestAtByCategory = <String, DateTime>{};
    for (final row in todayReadings as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final meterJson = map['meters'];
      if (meterJson is! Map) continue;
      final categoryId = meterJson['category_id'] as String?;
      final enteredAt = map['entered_at'] as String?;
      if (categoryId == null || enteredAt == null) continue;
      final at = DateTime.parse(enteredAt);
      final prev = latestAtByCategory[categoryId];
      if (prev == null || at.isAfter(prev)) {
        latestAtByCategory[categoryId] = at;
      }
    }

    final grouped = <String, List<Meter>>{};
    final categories = <String, MeterCategoryConfig>{};
    for (final meter in meters.where((m) => m.isEntryEligible)) {
      grouped.putIfAbsent(meter.categoryId, () => []).add(meter);
      if (meter.categoryConfig != null) {
        categories[meter.categoryId] = meter.categoryConfig!;
      }
    }

    final submittedByCategory = <String, int>{};
    for (final row in todayReadings as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final meterJson = map['meters'];
      if (meterJson is! Map) continue;
      final categoryId = meterJson['category_id'] as String?;
      if (categoryId == null) continue;
      submittedByCategory[categoryId] =
          (submittedByCategory[categoryId] ?? 0) + 1;
    }

    final consumptionByCategory = <String, double>{};
    for (final row in consumptionRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final meterJson = map['meters'];
      if (meterJson is! Map) continue;
      final categoryId = meterJson['category_id'] as String?;
      if (categoryId == null) continue;
      final value = nonNegativeConsumption(map['daily_consumption']);
      consumptionByCategory[categoryId] =
          (consumptionByCategory[categoryId] ?? 0) + value;
    }

    final summaries = <SiteCategorySummary>[];
    for (final entry in grouped.entries) {
      final category = categories[entry.key];
      if (category == null) continue;
      summaries.add(
        SiteCategorySummary(
          category: category,
          meterCount: entry.value.length,
          readingsSubmittedToday: submittedByCategory[entry.key] ?? 0,
          latestReadingAt: latestAtByCategory[entry.key],
          totalDailyConsumption: consumptionByCategory[entry.key],
        ),
      );
    }

    summaries.sort((a, b) {
      final order = a.category.sortOrder.compareTo(b.category.sortOrder);
      return order != 0
          ? order
          : a.category.nameEn.compareTo(b.category.nameEn);
    });
    return summaries;
  }

  Future<List<DashboardMeterRow>> getSiteMetersWithLatestReadings({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final meters = await _fetchMetersForSite(siteId);
    if (meters.isEmpty) {
      return [];
    }

    final meterIds = meters.map((m) => m.id).toList();
    final todayIso = formatBusinessDate(businessDate);

    final todayRows = await _client
        .from('meter_readings')
        .select('meter_id')
        .eq('site_id', siteId)
        .eq('reading_date', todayIso)
        .inFilter('meter_id', meterIds);
    final todayMeterIds = (todayRows as List)
        .map((row) => (row as Map)['meter_id'] as String)
        .toSet();

    // Paginated lookback (newest first); stop once every meter has a latest.
    final lookbackFrom = formatBusinessDate(
      businessDate.subtract(const Duration(days: 180)),
    );
    final latestByMeter = <String, Map<String, dynamic>>{};
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final page = await _client
          .from('meter_readings')
          .select('meter_id, raw_value, reading_date')
          .eq('site_id', siteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', lookbackFrom)
          .lte('reading_date', todayIso)
          .order('reading_date', ascending: false)
          .range(offset, offset + pageSize - 1);
      final rows = page as List;
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        latestByMeter.putIfAbsent(map['meter_id'] as String, () => map);
      }
      if (rows.length < pageSize || latestByMeter.length >= meterIds.length) {
        break;
      }
      offset += pageSize;
    }

    return [
      for (final meter in meters)
        DashboardMeterRow(
          meterId: meter.id,
          meterCode: meter.meterCode,
          nameEn: meter.nameEn,
          categoryName: meter.categoryConfig?.nameEn ?? meter.category.label,
          categoryId: meter.categoryId,
          sourceName: meter.sourceDisplayName,
          unitLabel: meter.unitDisplayLabel,
          level: meter.level,
          isActive: meter.isActive,
          includeInDashboard: meter.includeInDashboard,
          parentMeterName: meter.parentMeterNameEn,
          parentMeterCode: meter.parentMeterCode,
          latestRawValue: latestByMeter[meter.id] == null
              ? null
              : _toDouble(latestByMeter[meter.id]!['raw_value']),
          latestReadingDate: latestByMeter[meter.id] == null
              ? null
              : DateTime.parse(
                  latestByMeter[meter.id]!['reading_date'] as String,
                ),
          hasSubmittedToday: todayMeterIds.contains(meter.id),
        ),
    ];
  }

  Future<List<MeterReadingCardData>> getMeterReadingCardsForSite({
    required String siteId,
    required String utilityKey,
    required DateTime businessDate,
    DateTime? previousBusinessDate,
    DateTime? rangeStart,
    String? search,
    String? sourceCode,
    String? statusFilter,
  }) async {
    final allMeters = await _fetchMetersForSite(siteId);
    var meters = allMeters.where((meter) {
      if (!meter.isActive) {
        return false;
      }
      final code = meter.categoryConfig?.code ?? meter.category.dbValue;
      return code == utilityKey;
    }).toList();

    if (sourceCode != null && sourceCode.trim().isNotEmpty) {
      final normalized = sourceCode.trim().toLowerCase();
      meters = meters
          .where(
            (meter) =>
                (meter.sourceConfig?.code ?? meter.source.dbValue)
                    .toLowerCase() ==
                normalized,
          )
          .toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      meters = meters
          .where(
            (meter) =>
                meter.nameEn.toLowerCase().contains(q) ||
                meter.meterCode.toLowerCase().contains(q),
          )
          .toList();
    }

    if (meters.isEmpty) {
      return [];
    }

    final meterIds = meters.map((meter) => meter.id).toList();
    final dateIso = formatBusinessDate(businessDate);
    final useRange =
        rangeStart != null && formatBusinessDate(rangeStart) != dateIso;
    final startIso = useRange ? formatBusinessDate(rangeStart) : dateIso;

    final latestByMeter = <String, MeterReading>{};
    final previousByMeter = <String, MeterReading>{};

    if (!useRange) {
      final latestRows = await _client
          .from('meter_readings')
          .select(
            'id, site_id, meter_id, reading_date, raw_value, normalized_value, entered_at, image_url, note',
          )
          .eq('site_id', siteId)
          .eq('reading_date', dateIso)
          .inFilter('meter_id', meterIds);

      for (final row in latestRows as List) {
        final reading = MeterReading.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        latestByMeter[reading.meterId] = reading;
      }

      final previousIso = previousBusinessDate != null
          ? formatBusinessDate(previousBusinessDate)
          : null;

      if (previousIso != null) {
        final previousRows = await _client
            .from('meter_readings')
            .select(
              'id, site_id, meter_id, reading_date, raw_value, normalized_value, entered_at, image_url, note',
            )
            .eq('site_id', siteId)
            .eq('reading_date', previousIso)
            .inFilter('meter_id', meterIds);

        for (final row in previousRows as List) {
          final reading = MeterReading.fromJson(
            Map<String, dynamic>.from(row as Map),
          );
          previousByMeter[reading.meterId] = reading;
        }
      } else {
        final previousRows = await _batchPreviousReadings(
          siteId: siteId,
          meterIds: meterIds,
          beforeIso: dateIso,
        );
        previousByMeter.addAll(previousRows);
      }
    } else {
      // Paginated range fetch (newest first) — never scan unbounded history.
      const pageSize = 1000;
      const readingCols =
          'id, site_id, meter_id, reading_date, raw_value, normalized_value, '
          'entered_at, image_url, note';
      var offset = 0;
      while (true) {
        final page = await _client
            .from('meter_readings')
            .select(readingCols)
            .eq('site_id', siteId)
            .inFilter('meter_id', meterIds)
            .gte('reading_date', startIso)
            .lte('reading_date', dateIso)
            .order('reading_date', ascending: false)
            .range(offset, offset + pageSize - 1);
        final rows = (page as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        for (final row in rows) {
          final reading = MeterReading.fromJson(row);
          latestByMeter.putIfAbsent(reading.meterId, () => reading);
        }
        if (rows.length < pageSize) break;
        offset += pageSize;
        // Once every meter has a latest, stop paging.
        if (latestByMeter.length >= meterIds.length) break;
      }

      // Previous = last reading strictly before range start (batched).
      final previousRows = await _batchPreviousReadings(
        siteId: siteId,
        meterIds: meterIds,
        beforeIso: startIso,
      );
      for (final entry in previousRows.entries) {
        final latest = latestByMeter[entry.key];
        if (latest == null || entry.value.id == latest.id) continue;
        if (!entry.value.readingDate.isAfter(latest.readingDate)) {
          previousByMeter[entry.key] = entry.value;
        }
      }
    }

    final cards = <MeterReadingCardData>[
      for (final meter in meters)
        buildMeterReadingCardData(
          meter: meter,
          businessDate: businessDate,
          latestOnDate: latestByMeter[meter.id],
          previousReading: previousByMeter[meter.id],
        ),
    ];

    return cards
        .where((card) => matchesMeterReadingStatusFilter(card, statusFilter))
        .toList();
  }

  Future<List<DashboardReadingRow>> getRecentSiteReadings({
    required String siteId,
    required DashboardReadingFilters filters,
  }) async {
    var query = _client
        .from('meter_readings')
        .select(_readingSelect)
        .eq('site_id', siteId);

    if (filters.fromDate != null) {
      query = query.gte('reading_date', formatBusinessDate(filters.fromDate!));
    }
    if (filters.toDate != null) {
      query = query.lte('reading_date', formatBusinessDate(filters.toDate!));
    }
    if (filters.meterId != null) {
      query = query.eq('meter_id', filters.meterId!);
    }

    final rows = await query
        .order('reading_date', ascending: false)
        .order('entered_at', ascending: false)
        .limit(filters.limit);

    final results = <DashboardReadingRow>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final reading = MeterReading.fromJson(map);
      final meterJson = map['meters'];
      if (meterJson is! Map<String, dynamic>) {
        continue;
      }

      final categoryId = meterJson['category_id'] as String?;
      if (filters.categoryId != null && categoryId != filters.categoryId) {
        continue;
      }

      if (filters.hasPhoto == true && !reading.hasPhoto) {
        continue;
      }
      if (filters.hasPhoto == false && reading.hasPhoto) {
        continue;
      }

      final categoryJson = meterJson['meter_categories'];
      final unitJson = meterJson['meter_units'];
      final profileJson = map['profiles'];

      results.add(
        DashboardReadingRow(
          reading: reading,
          meterName: meterJson['name_en'] as String? ?? 'Unknown',
          meterCode: meterJson['meter_code'] as String? ?? '',
          categoryName: joinedCatalogDisplayName(
            categoryJson is Map
                ? Map<String, dynamic>.from(categoryJson)
                : null,
            legacyFallback: legacyMeterCategoryLabel(meterJson['category']),
          ),
          unitLabel: joinedCatalogDisplayName(
            unitJson is Map ? Map<String, dynamic>.from(unitJson) : null,
            legacyFallback: legacyMeterUnitLabel(meterJson['unit']),
          ),
          enteredByName: profileJson is Map
              ? profileJson['full_name'] as String?
              : null,
          enteredByEmail: profileJson is Map
              ? profileJson['email'] as String?
              : null,
        ),
      );
    }
    return results;
  }

  Future<List<DashboardCopGroupSummary>> getCopGroupsForSite(
    String siteId,
  ) async {
    final rows = await _client
        .from('cop_groups')
        .select(
          'id, name_en, is_active, cop_group_btu_meters(count), cop_group_electricity_meters(count)',
        )
        .eq('site_id', siteId)
        .order('name_en');

    return (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return DashboardCopGroupSummary(
        id: map['id'] as String,
        nameEn: map['name_en'] as String,
        isActive: map['is_active'] as bool? ?? true,
        btuMeterCount: _parseCount(map['cop_group_btu_meters']),
        electricityMeterCount: _parseCount(map['cop_group_electricity_meters']),
      );
    }).toList();
  }

  Future<TodayReadingProgress> getTodayReadingProgress({
    required String siteId,
    required DateTime businessDate,
  }) async {
    final meters = await _fetchMetersForSite(siteId);
    final entryEligible = meters.where((m) => m.isEntryEligible).length;
    final todayIso = formatBusinessDate(businessDate);
    final rows = await _client
        .from('meter_readings')
        .select('id')
        .eq('site_id', siteId)
        .eq('reading_date', todayIso);
    final submitted = (rows as List).length;
    return TodayReadingProgress(
      submitted: submitted,
      total: entryEligible,
      pending: (entryEligible - submitted).clamp(0, entryEligible),
    );
  }

  /// Alias for chart completion donut.
  Future<TodayReadingProgress> getTodayCompletion({
    required String siteId,
    required DateTime businessDate,
  }) => getTodayReadingProgress(siteId: siteId, businessDate: businessDate);

  Future<SiteConsumptionTrend> getSiteConsumptionTrend({
    required String siteId,
    required ChartPeriod period,
    required DateTime businessDate,
  }) async {
    final range = chartPeriodRange(period: period, businessDate: businessDate);
    final rows = await _fetchConsumptionRows(
      siteId: siteId,
      from: range.from,
      to: range.to,
      bucket: range.bucket,
    );
    final series = aggregateCategoryConsumption(rows: rows, range: range);
    if (series.isEmpty) {
      return const SiteConsumptionTrend(
        series: [],
        emptyMessage: 'No readings for this period',
      );
    }
    return SiteConsumptionTrend(series: series);
  }

  Future<CategoryConsumptionSeries> getCategoryConsumptionTrend({
    required String siteId,
    required String categoryId,
    required ChartPeriod period,
    required DateTime businessDate,
    ChartPeriodRange? rangeOverride,
  }) async {
    final range =
        rangeOverride ??
        chartPeriodRange(period: period, businessDate: businessDate);
    final rows = await _fetchConsumptionRows(
      siteId: siteId,
      from: range.from,
      to: range.to,
      categoryId: categoryId,
      bucket: range.bucket,
    );
    final series = aggregateCategoryConsumption(rows: rows, range: range);
    if (series.isEmpty) {
      return CategoryConsumptionSeries(
        categoryId: categoryId,
        categoryName: 'Category',
        unitCode: '',
        points: chartBucketTimeline(range: range)
            .map(
              (date) => TimeSeriesPoint(
                date: date,
                value: 0,
                label: chartBucketLabel(date: date, bucket: range.bucket),
              ),
            )
            .toList(),
      );
    }
    return series.first;
  }

  Future<List<CategoryRankingItem>> getCategoryRanking({
    required String siteId,
    required String categoryId,
    required ChartPeriod period,
    required DateTime businessDate,
    ChartPeriodRange? rangeOverride,
  }) async {
    final range =
        rangeOverride ??
        chartPeriodRange(period: period, businessDate: businessDate);
    final rows = await _fetchConsumptionRows(
      siteId: siteId,
      from: range.from,
      to: range.to,
      categoryId: categoryId,
      bucket: range.bucket,
    );
    return aggregateMeterRanking(rows: rows, categoryId: categoryId);
  }

  Future<MeterComparisonResult> getMeterComparisonTrend({
    required String siteId,
    required String categoryId,
    required List<String> meterIds,
    required ChartPeriod period,
    required DateTime businessDate,
    ChartPeriodRange? rangeOverride,
  }) async {
    final meters = await _fetchMetersForSite(siteId);
    final range =
        rangeOverride ??
        chartPeriodRange(period: period, businessDate: businessDate);
    final rows = await _fetchConsumptionRows(
      siteId: siteId,
      from: range.from,
      to: range.to,
      categoryId: categoryId,
      meterIds: meterIds,
      bucket: range.bucket,
    );
    return buildMeterComparison(
      meters: meters,
      meterIds: meterIds,
      consumptionRows: rows,
      range: range,
    );
  }

  Future<CategoryChartBundle> getCategoryChartBundle({
    required String siteId,
    required String categoryId,
    required ChartPeriod period,
    required DateTime businessDate,
    ChartPeriodRange? rangeOverride,
  }) async {
    final range =
        rangeOverride ??
        chartPeriodRange(period: period, businessDate: businessDate);

    final meters = await _fetchMetersForSite(siteId);
    final inCategory =
        meters.where((m) => m.categoryId == categoryId).toList();
    // Never sum potable + TSE (+ other water kinds) into one trend line.
    final compatibleIds = meterIdsForCompatibleWaterTrend(inCategory);

    // Chart series only — never block on another full site summary round-trip.
    final rows = await _fetchConsumptionRows(
      siteId: siteId,
      from: range.from,
      to: range.to,
      categoryId: categoryId,
      meterIds: compatibleIds,
      bucket: range.bucket,
    );

    final seriesList = aggregateCategoryConsumption(rows: rows, range: range);
    final trend = seriesList.isEmpty
        ? CategoryConsumptionSeries(
            categoryId: categoryId,
            categoryName: 'Category',
            unitCode: '',
            points: chartBucketTimeline(range: range)
                .map(
                  (date) => TimeSeriesPoint(
                    date: date,
                    value: 0,
                    label: chartBucketLabel(date: date, bucket: range.bucket),
                  ),
                )
                .toList(),
          )
        : seriesList.first;
    final ranking = aggregateMeterRanking(rows: rows, categoryId: categoryId);

    return CategoryChartBundle(
      categoryId: categoryId,
      categoryName: trend.categoryName,
      unitCode: trend.unitCode,
      trend: trend,
      ranking: ranking,
      submittedToday: 0,
      pendingToday: 0,
      meterCount: ranking.length,
    );
  }

  Future<CopTrendResult> getCopTrend({
    required String copGroupId,
    required ChartPeriod period,
    required DateTime businessDate,
    ChartPeriodRange? rangeOverride,
  }) async {
    final groupRow = await _client
        .from('cop_groups')
        .select('id, name_en, site_id')
        .eq('id', copGroupId)
        .single();

    final btuLinks = await _client
        .from('cop_group_btu_meters')
        .select('meter_id, weight')
        .eq('cop_group_id', copGroupId);
    final elecLinks = await _client
        .from('cop_group_electricity_meters')
        .select('meter_id, weight')
        .eq('cop_group_id', copGroupId);

    final btuWeights = <String, double>{};
    for (final row in btuLinks as List) {
      final map = Map<String, dynamic>.from(row as Map);
      btuWeights[map['meter_id'] as String] = _toDouble(map['weight']);
    }
    final elecWeights = <String, double>{};
    for (final row in elecLinks as List) {
      final map = Map<String, dynamic>.from(row as Map);
      elecWeights[map['meter_id'] as String] = _toDouble(map['weight']);
    }

    if (btuWeights.isEmpty || elecWeights.isEmpty) {
      return CopTrendResult(
        copGroupId: copGroupId,
        copGroupName: groupRow['name_en'] as String,
        points: const [],
        btuMeterCount: btuWeights.length,
        electricityMeterCount: elecWeights.length,
        emptyMessage: 'COP requires both BTU and electricity readings',
      );
    }

    final range =
        rangeOverride ??
        chartPeriodRange(period: period, businessDate: businessDate);
    final meterIds = [...btuWeights.keys, ...elecWeights.keys];
    final rows = await _fetchConsumptionRows(
      siteId: groupRow['site_id'] as String,
      from: range.from,
      to: range.to,
      meterIds: meterIds,
      bucket: range.bucket,
    );

    final points = aggregateCopTrend(
      range: range,
      btuWeights: btuWeights,
      electricityWeights: elecWeights,
      consumptionRows: rows,
    );

    if (!points.any((p) => p.cop != null)) {
      return CopTrendResult(
        copGroupId: copGroupId,
        copGroupName: groupRow['name_en'] as String,
        points: points,
        btuMeterCount: btuWeights.length,
        electricityMeterCount: elecWeights.length,
        emptyMessage: 'Not enough readings to calculate COP for this period',
      );
    }

    return CopTrendResult(
      copGroupId: copGroupId,
      copGroupName: groupRow['name_en'] as String,
      points: points,
      btuMeterCount: btuWeights.length,
      electricityMeterCount: elecWeights.length,
      averageCop: averageCopValues(points),
      minCop: minCopValues(points),
      maxCop: maxCopValues(points),
    );
  }

  Future<List<DashboardExportReadingRow>> getExportReadings({
    required String siteId,
    required DateTime fromDate,
    required DateTime toDate,
    String? categoryId,
    int limit = 5000,
  }) async {
    assert(() {
      // ignore: avoid_print
      print('[ReportExport][D] getExportReadings start site=$siteId');
      return true;
    }());
    final siteRow = await _client
        .from('sites')
        .select('name_en, zones(name_en)')
        .eq('id', siteId)
        .single();
    final siteName = siteRow['name_en'] as String? ?? 'Site';
    final zoneJson = siteRow['zones'];
    final zoneName = zoneJson is Map
        ? zoneJson['name_en'] as String? ?? 'No Zone'
        : 'No Zone';

    final consumptionRows = await _fetchConsumptionRows(
      siteId: siteId,
      from: fromDate,
      to: toDate,
      categoryId: categoryId,
    );
    final consumptionByKey = <String, double>{};
    for (final row in consumptionRows) {
      final meterId = row['meter_id'] as String;
      final date = row['reading_date'] as String;
      consumptionByKey['$meterId|$date'] = _toDouble(row['daily_consumption']);
    }

    final detailedRows = await _client
        .from('meter_readings')
        .select('''
*,
meters(
  name_en,
  meter_code,
  category_id,
  category,
  source,
  unit,
  meter_categories(code, name_en),
  meter_sources(code, name_en),
  meter_units(code, name_en)
),
profiles:entered_by(full_name, email)
''')
        .eq('site_id', siteId)
        .gte('reading_date', formatBusinessDate(fromDate))
        .lte('reading_date', formatBusinessDate(toDate))
        .order('reading_date', ascending: false)
        .order('entered_at', ascending: false)
        .limit(limit);

    final results = <DashboardExportReadingRow>[];
    for (final row in detailedRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final reading = MeterReading.fromJson(map);
      final meterJson = map['meters'];
      if (meterJson is! Map<String, dynamic>) continue;

      final rowCategoryId = meterJson['category_id'] as String?;
      if (categoryId != null && rowCategoryId != categoryId) continue;

      final categoryJson = meterJson['meter_categories'];
      final unitJson = meterJson['meter_units'];
      final sourceJson = meterJson['meter_sources'];
      final profileJson = map['profiles'];
      final dateKey = formatBusinessDate(reading.readingDate);

      results.add(
        DashboardExportReadingRow(
          reading: reading,
          siteName: siteName,
          zoneName: zoneName,
          meterName: meterJson['name_en'] as String? ?? 'Unknown',
          meterCode: meterJson['meter_code'] as String? ?? '',
          categoryName: joinedCatalogDisplayName(
            categoryJson is Map
                ? Map<String, dynamic>.from(categoryJson)
                : null,
            legacyFallback: legacyMeterCategoryLabel(meterJson['category']),
          ),
          unitLabel: joinedCatalogDisplayName(
            unitJson is Map ? Map<String, dynamic>.from(unitJson) : null,
            legacyFallback: legacyMeterUnitLabel(meterJson['unit']),
          ),
          sourceName: joinedCatalogDisplayName(
            sourceJson is Map ? Map<String, dynamic>.from(sourceJson) : null,
            legacyFallback: legacyMeterSourceLabel(meterJson['source']),
          ),
          enteredByName: profileJson is Map
              ? profileJson['full_name'] as String?
              : null,
          enteredByEmail: profileJson is Map
              ? profileJson['email'] as String?
              : null,
          dailyConsumption: consumptionByKey['${reading.meterId}|$dateKey'],
        ),
      );
    }
    assert(() {
      // ignore: avoid_print
      print('[ReportExport][D] getExportReadings ok rows=${results.length}');
      return true;
    }());
    return results;
  }

  Future<List<Map<String, dynamic>>> getConsumptionRowsForAlerts({
    required String siteId,
    required DateTime from,
    required DateTime to,
  }) => _fetchConsumptionRows(siteId: siteId, from: from, to: to);

  /// Slim readings for alert detection — no export joins / consumption view.
  Future<List<MeterReading>> getAlertWindowReadings({
    required String siteId,
    required DateTime fromDate,
    required DateTime toDate,
    int pageSize = 1000,
  }) async {
    final fromIso = formatBusinessDate(fromDate);
    final toIso = formatBusinessDate(toDate);
    final results = <MeterReading>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('meter_readings')
          .select(
            'id, meter_id, site_id, reading_date, raw_value, normalized_value, '
            'image_url, note, entered_at',
          )
          .eq('site_id', siteId)
          .gte('reading_date', fromIso)
          .lte('reading_date', toIso)
          .order('reading_date', ascending: false)
          .order('entered_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      final page = (rows as List)
          .map(
            (row) =>
                MeterReading.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
      results.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return results;
  }

  /// Builds daily consumption for [from]–[to] from `meter_readings` only.
  ///
  /// Does **not** use `meter_daily_consumption` — that view runs LAG over the
  /// full reading history and times out on large imported sites (e.g. MOEHE HQ).
  ///
  /// Monthly/yearly buckets fetch only the latest reading per meter per period
  /// (not every daily row). Large daily ranges use per-meter indexed pages.
  Future<List<Map<String, dynamic>>> _fetchConsumptionRows({
    required String siteId,
    required DateTime from,
    required DateTime to,
    String? categoryId,
    List<String>? meterIds,
    ChartBucket? bucket,
  }) async {
    final meters = await _fetchMetersForSite(siteId);
    var targetMeters = meters;
    if (meterIds != null && meterIds.isNotEmpty) {
      final allowed = meterIds.toSet();
      targetMeters = targetMeters.where((m) => allowed.contains(m.id)).toList();
    }
    if (categoryId != null) {
      targetMeters = targetMeters
          .where((m) => m.categoryId == categoryId)
          .toList();
    }
    if (targetMeters.isEmpty) return const [];

    final meterMetaById = {
      for (final meter in targetMeters) meter.id: _meterEmbedMap(meter),
    };
    final ids = targetMeters.map((m) => m.id).toList();
    final fromIso = formatBusinessDate(from);
    final toIso = formatBusinessDate(to);
    final spanDays = to.difference(from).inDays;

    if (bucket == ChartBucket.monthly || bucket == ChartBucket.yearly) {
      // Per-window last/first (+ previous before window) so a lone year/month
      // still yields non-zero totals when older history was pruned.
      return _fetchBucketPeriodConsumptionRows(
        siteId: siteId,
        meterIds: ids,
        meterMetaById: meterMetaById,
        from: from,
        to: to,
        bucket: bucket!,
      );
    }

    final List<Map<String, dynamic>> rawRows;
    if (preferSiteScopedChartScan(
      meterCount: ids.length,
      spanDays: spanDays,
      bucket: bucket,
    )) {
      rawRows = await _fetchReadingPagesForMeters(
        meterIds: ids,
        fromIso: fromIso,
        toIso: toIso,
        siteScopedSiteId: siteId,
      );
    } else {
      rawRows = await _fetchReadingPagesPerMeterParallel(
        meterIds: ids,
        fromIso: fromIso,
        toIso: toIso,
      );
    }

    if (rawRows.isEmpty) return const [];

    // One batched lookback for previous values (not N×limit(1)).
    final prevByMeter = await _batchPreviousNormalized(
      siteId: siteId,
      meterIds: ids,
      beforeIso: fromIso,
    );

    final byMeter = <String, List<Map<String, dynamic>>>{};
    for (final row in rawRows) {
      byMeter.putIfAbsent(row['meter_id'] as String, () => []).add(row);
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in byMeter.entries) {
      final meterId = entry.key;
      final meta = meterMetaById[meterId];
      if (meta == null) continue;
      final sorted = List<Map<String, dynamic>>.from(entry.value)
        ..sort(
          (a, b) => (a['reading_date'] as String).compareTo(
            b['reading_date'] as String,
          ),
        );
      double? prev = prevByMeter[meterId];
      for (final row in sorted) {
        final value = _toDouble(row['normalized_value']);
        final daily = prev == null
            ? 0.0
            : (value - prev < 0 ? 0.0 : value - prev);
        prev = value;
        results.add({
          'meter_id': meterId,
          'site_id': row['site_id'] ?? siteId,
          'reading_date': row['reading_date'],
          'daily_consumption': daily,
          'meters': meta,
        });
      }
    }

    results.sort(
      (a, b) =>
          (a['reading_date'] as String).compareTo(b['reading_date'] as String),
    );
    return results;
  }

  /// Monthly/yearly: one consumption point per meter per period window.
  Future<List<Map<String, dynamic>>> _fetchBucketPeriodConsumptionRows({
    required String siteId,
    required List<String> meterIds,
    required Map<String, Map<String, dynamic>> meterMetaById,
    required DateTime from,
    required DateTime to,
    required ChartBucket bucket,
  }) async {
    final windows = chartBucketWindows(from: from, to: to, bucket: bucket);
    if (windows.isEmpty) return const [];

    // Bound concurrency: windows in parallel chunks; earliest+prev in parallel.
    const chunkSize = 4;
    final results = <Map<String, dynamic>>[];

    for (var i = 0; i < windows.length; i += chunkSize) {
      final chunk = windows.skip(i).take(chunkSize).toList();
      final chunkRows = await Future.wait(
        chunk.map((window) async {
          final windowFromIso = formatBusinessDate(window.from);
          final windowToIso = formatBusinessDate(window.to);
          final latest = await _fetchEdgeReadingPerMeterInWindow(
            siteId: siteId,
            meterIds: meterIds,
            fromIso: windowFromIso,
            toIso: windowToIso,
            ascending: false,
          );
          if (latest.isEmpty) return <Map<String, dynamic>>[];

          final activeIds = latest.keys.toList();
          final earliestFuture = _fetchEdgeReadingPerMeterInWindow(
            siteId: siteId,
            meterIds: activeIds,
            fromIso: windowFromIso,
            toIso: windowToIso,
            ascending: true,
          );
          final prevFuture = _batchPreviousNormalized(
            siteId: siteId,
            meterIds: activeIds,
            beforeIso: windowFromIso,
          );
          final earliest = await earliestFuture;
          final prevByMeter = await prevFuture;

          final out = <Map<String, dynamic>>[];
          for (final entry in latest.entries) {
            final meterId = entry.key;
            final meta = meterMetaById[meterId];
            if (meta == null) continue;
            final lastRow = entry.value;
            final lastValue = _toDouble(lastRow['normalized_value']);
            final firstValue = earliest[meterId] == null
                ? null
                : _toDouble(earliest[meterId]!['normalized_value']);
            final consumption = periodConsumptionFromEndpoints(
              lastInPeriod: lastValue,
              previousBeforePeriod: prevByMeter[meterId],
              firstInPeriod: firstValue,
            );
            out.add({
              'meter_id': meterId,
              'site_id': lastRow['site_id'] ?? siteId,
              'reading_date': lastRow['reading_date'],
              'daily_consumption': consumption,
              'meters': meta,
            });
          }
          return out;
        }),
      );
      for (final rows in chunkRows) {
        results.addAll(rows);
      }
    }

    results.sort(
      (a, b) =>
          (a['reading_date'] as String).compareTo(b['reading_date'] as String),
    );
    return results;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchEdgeReadingPerMeterInWindow({
    required String siteId,
    required List<String> meterIds,
    required String fromIso,
    required String toIso,
    required bool ascending,
  }) async {
    final found = <String, Map<String, dynamic>>{};
    if (meterIds.isEmpty) return found;
    const pageSize = 1000;
    var offset = 0;
    while (found.length < meterIds.length) {
      final rows = await _client
          .from('meter_readings')
          .select('meter_id, site_id, reading_date, normalized_value')
          .eq('site_id', siteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', fromIso)
          .lte('reading_date', toIso)
          .order('reading_date', ascending: ascending)
          .range(offset, offset + pageSize - 1);
      final page = rows as List;
      for (final row in page) {
        final map = Map<String, dynamic>.from(row as Map);
        found.putIfAbsent(map['meter_id'] as String, () => map);
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return found;
  }

  /// Newest full reading before [beforeIso] for each meter — few paginated calls.
  Future<Map<String, MeterReading>> _batchPreviousReadings({
    required String siteId,
    required List<String> meterIds,
    required String beforeIso,
  }) async {
    if (meterIds.isEmpty) return {};
    final lookbackIso = formatBusinessDate(
      DateTime.parse(beforeIso).subtract(const Duration(days: 400)),
    );
    final prevByMeter = <String, MeterReading>{};
    const pageSize = 1000;
    const readingCols =
        'id, site_id, meter_id, reading_date, raw_value, normalized_value, '
        'entered_at, image_url, note';
    var offset = 0;
    while (prevByMeter.length < meterIds.length) {
      final page = await _client
          .from('meter_readings')
          .select(readingCols)
          .eq('site_id', siteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', lookbackIso)
          .lt('reading_date', beforeIso)
          .order('reading_date', ascending: false)
          .range(offset, offset + pageSize - 1);
      final rows = page as List;
      for (final row in rows) {
        final reading = MeterReading.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        prevByMeter.putIfAbsent(reading.meterId, () => reading);
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return prevByMeter;
  }

  /// Newest reading before [beforeIso] for each meter — few paginated calls.
  Future<Map<String, double>> _batchPreviousNormalized({
    required String siteId,
    required List<String> meterIds,
    required String beforeIso,
  }) async {
    if (meterIds.isEmpty) return {};
    final lookbackIso = formatBusinessDate(
      DateTime.parse(beforeIso).subtract(const Duration(days: 400)),
    );
    final prevByMeter = <String, double>{};
    const pageSize = 1000;
    var offset = 0;
    while (prevByMeter.length < meterIds.length) {
      final page = await _client
          .from('meter_readings')
          .select('meter_id, normalized_value')
          .eq('site_id', siteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', lookbackIso)
          .lt('reading_date', beforeIso)
          .order('reading_date', ascending: false)
          .range(offset, offset + pageSize - 1);
      final rows = page as List;
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        prevByMeter.putIfAbsent(
          map['meter_id'] as String,
          () => _toDouble(map['normalized_value']),
        );
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return prevByMeter;
  }

  Map<String, dynamic> _meterEmbedMap(Meter meter) {
    final category = meter.categoryConfig;
    return {
      'name_en': meter.nameEn,
      'name_ar': meter.nameAr,
      'meter_code': meter.meterCode,
      'category_id': meter.categoryId,
      'base_unit': meter.baseUnit,
      'meter_categories': category == null
          ? {
              'name_en': meter.category.label,
              'code': meter.category.dbValue,
              'base_unit_code': meter.baseUnit,
            }
          : {
              'name_en': category.nameEn,
              'code': category.code,
              'base_unit_code': category.baseUnitCode,
            },
    };
  }

  /// Short ranges: one site-scoped query filtered by meter ids (paginated).
  Future<List<Map<String, dynamic>>> _fetchReadingPagesForMeters({
    required List<String> meterIds,
    required String fromIso,
    required String toIso,
    required String siteScopedSiteId,
  }) async {
    const pageSize = 1000;
    final rawRows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from('meter_readings')
          .select('meter_id, site_id, reading_date, normalized_value')
          .eq('site_id', siteScopedSiteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', fromIso)
          .lte('reading_date', toIso)
          .order('reading_date')
          .range(offset, offset + pageSize - 1);
      final page = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      rawRows.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return rawRows;
  }

  /// Multi-year ranges: fetch each meter via its primary index (parallel).
  Future<List<Map<String, dynamic>>> _fetchReadingPagesPerMeterParallel({
    required List<String> meterIds,
    required String fromIso,
    required String toIso,
  }) async {
    const pageSize = 1000;
    const concurrency = 12;
    final rawRows = <Map<String, dynamic>>[];

    Future<List<Map<String, dynamic>>> fetchOne(String meterId) async {
      final out = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final rows = await _client
            .from('meter_readings')
            .select('meter_id, site_id, reading_date, normalized_value')
            .eq('meter_id', meterId)
            .gte('reading_date', fromIso)
            .lte('reading_date', toIso)
            .order('reading_date')
            .range(offset, offset + pageSize - 1);
        final page = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        out.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }
      return out;
    }

    for (var i = 0; i < meterIds.length; i += concurrency) {
      final chunk = meterIds.sublist(
        i,
        i + concurrency > meterIds.length ? meterIds.length : i + concurrency,
      );
      final pages = await Future.wait(chunk.map(fetchOne));
      for (final page in pages) {
        rawRows.addAll(page);
      }
    }
    return rawRows;
  }

  Future<List<Meter>> _fetchMetersForSite(String siteId) async {
    final cached = _metersBySite[siteId];
    if (cached != null) return cached;

    final rows = await _client
        .from('meters')
        .select(_meterSelect)
        .eq('site_id', siteId)
        .order('sort_order')
        .order('name_en');
    final meters = (rows as List)
        .map((row) => Meter.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    _metersBySite[siteId] = meters;
    return meters;
  }

  static int _parseCount(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map && first['count'] != null) {
        return first['count'] as int;
      }
    }
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return 0;
    }
    return double.parse(value as String);
  }
}

class TodayReadingProgress {
  const TodayReadingProgress({
    required this.submitted,
    required this.total,
    required this.pending,
  });

  final int submitted;
  final int total;
  final int pending;
}
