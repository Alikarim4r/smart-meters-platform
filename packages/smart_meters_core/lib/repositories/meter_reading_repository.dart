import '../domain/business_date.dart';
import '../models/meter_reading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeterReadingRepository {
  MeterReadingRepository(this._client);

  final SupabaseClient _client;

  Future<MeterReading?> getReadingForMeterAndDate(
    String meterId,
    DateTime date,
  ) async {
    final rows = await _client
        .from('meter_readings')
        .select()
        .eq('meter_id', meterId)
        .eq('reading_date', formatBusinessDate(date))
        .maybeSingle();

    if (rows == null) {
      return null;
    }
    return MeterReading.fromJson(Map<String, dynamic>.from(rows));
  }

  Future<MeterReading?> getLastReadingBeforeDate(
    String meterId,
    DateTime date,
  ) async {
    final rows = await _client
        .from('meter_readings')
        .select()
        .eq('meter_id', meterId)
        .lt('reading_date', formatBusinessDate(date))
        .order('reading_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (rows == null) {
      return null;
    }
    return MeterReading.fromJson(Map<String, dynamic>.from(rows));
  }

  Future<Map<String, MeterReading>> getReadingsForSiteAndDate({
    required String siteId,
    required DateTime date,
    List<String>? meterIds,
  }) async {
    var query = _client
        .from('meter_readings')
        .select()
        .eq('site_id', siteId)
        .eq('reading_date', formatBusinessDate(date));

    if (meterIds != null && meterIds.isNotEmpty) {
      query = query.inFilter('meter_id', meterIds);
    }

    final rows = await query;
    final map = <String, MeterReading>{};
    for (final row in rows as List) {
      final reading = MeterReading.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      map[reading.meterId] = reading;
    }
    return map;
  }

  /// Latest reading per meter strictly before [date] (for list display).
  /// Uses one query then picks the newest row per meter (no N+1).
  Future<Map<String, MeterReading>> getLatestReadingsBeforeDate({
    required List<String> meterIds,
    required DateTime date,
  }) async {
    if (meterIds.isEmpty) {
      return {};
    }

    final beforeIso = formatBusinessDate(date);
    final lookbackIso = formatBusinessDate(
      date.subtract(const Duration(days: 90)),
    );

    final rows = await _client
        .from('meter_readings')
        .select()
        .inFilter('meter_id', meterIds)
        .gte('reading_date', lookbackIso)
        .lt('reading_date', beforeIso)
        .order('reading_date', ascending: false);

    final map = <String, MeterReading>{};
    for (final row in rows as List) {
      final reading = MeterReading.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
      map.putIfAbsent(reading.meterId, () => reading);
    }
    return map;
  }

  Future<MeterReading> createReading({
    required String siteId,
    required String meterId,
    required double rawValue,
    required DateTime readingDate,
    String? note,
    String? imageStoragePath,
    required String enteredByUserId,
  }) async {
    try {
      final row = await _client
          .from('meter_readings')
          .insert({
            'site_id': siteId,
            'meter_id': meterId,
            'reading_date': formatBusinessDate(readingDate),
            'raw_value': rawValue,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            if (imageStoragePath != null && imageStoragePath.trim().isNotEmpty)
              'image_url': imageStoragePath.trim(),
            'entered_by': enteredByUserId,
          })
          .select()
          .single();

      return MeterReading.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw DuplicateReadingException();
      }
      rethrow;
    }
  }
}

class DuplicateReadingException implements Exception {
  @override
  String toString() => 'A reading for this meter and date already exists.';
}
