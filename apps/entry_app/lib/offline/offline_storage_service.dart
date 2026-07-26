import 'package:hive_flutter/hive_flutter.dart';

import 'cached_meter.dart';
import 'local_reading_draft.dart';

class OfflineStorageService {
  OfflineStorageService._();

  static final OfflineStorageService instance = OfflineStorageService._();

  static const _draftsBoxName = 'reading_drafts';
  static const _metersBoxName = 'cached_meters';
  static const _sitesBoxName = 'cached_sites';
  static const _metaBoxName = 'offline_meta';

  static Future<void> init() async {
    await Hive.initFlutter();
    await _openBox(_draftsBoxName);
    await _openBox(_metersBoxName);
    await _openBox(_sitesBoxName);
    await _openBox(_metaBoxName);
  }

  /// Reuse an already-open box (hot restart) and retry once on lock contention
  /// when another Entry instance briefly holds the Hive file lock on macOS.
  static Future<Box<dynamic>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }
    try {
      return await Hive.openBox<dynamic>(name);
    } catch (error) {
      final message = error.toString();
      final isLock = message.contains('lock failed') ||
          message.contains('Resource temporarily unavailable');
      if (!isLock) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (Hive.isBoxOpen(name)) {
        return Hive.box<dynamic>(name);
      }
      return Hive.openBox<dynamic>(name);
    }
  }

  Box<dynamic> get _draftsBox => Hive.box<dynamic>(_draftsBoxName);
  Box<dynamic> get _metersBox => Hive.box<dynamic>(_metersBoxName);
  Box<dynamic> get _sitesBox => Hive.box<dynamic>(_sitesBoxName);
  Box<dynamic> get _metaBox => Hive.box<dynamic>(_metaBoxName);

  String _meterCacheKey(String siteId, String category) => '$siteId::$category';

  Future<void> saveDraft(LocalReadingDraft draft) async {
    await _draftsBox.put(draft.localId, draft.toMap());
  }

  Future<void> deleteDraft(String localId) async {
    await _draftsBox.delete(localId);
  }

  List<LocalReadingDraft> getAllDrafts() {
    return _draftsBox.values
        .map((value) => LocalReadingDraft.fromMap(Map<dynamic, dynamic>.from(value as Map)))
        .toList();
  }

  LocalReadingDraft? getDraftForMeterAndDate({
    required String meterId,
    required String readingDate,
  }) {
    for (final draft in getAllDrafts()) {
      if (draft.meterId == meterId && draft.readingDate == readingDate) {
        return draft;
      }
    }
    return null;
  }

  List<LocalReadingDraft> getDraftsForSiteAndDate({
    required String siteId,
    required String readingDate,
  }) {
    return getAllDrafts()
        .where((draft) => draft.siteId == siteId && draft.readingDate == readingDate)
        .toList();
  }

  List<LocalReadingDraft> getPendingSyncDrafts() {
    return getAllDrafts().where((draft) => draft.isPendingSync).toList();
  }

  Future<void> cacheSites(List<CachedSite> sites) async {
    final maps = sites.map((site) => site.toMap()).toList();
    await _sitesBox.put('all', maps);
  }

  List<CachedSite> getCachedSites() {
    final raw = _sitesBox.get('all');
    if (raw is! List) {
      return [];
    }
    return raw
        .map((item) => CachedSite.fromMap(Map<dynamic, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> cacheMeters({
    required String siteId,
    required String category,
    required List<CachedMeter> meters,
  }) async {
    final maps = meters.map((meter) => meter.toMap()).toList();
    await _metersBox.put(_meterCacheKey(siteId, category), maps);
  }

  List<CachedMeter> getCachedMeters({
    required String siteId,
    required String category,
  }) {
    final raw = _metersBox.get(_meterCacheKey(siteId, category));
    if (raw is! List) {
      return [];
    }
    return raw
        .map((item) => CachedMeter.fromMap(Map<dynamic, dynamic>.from(item as Map)))
        .toList();
  }

  DateTime? get lastSyncTime {
    final raw = _metaBox.get('lastSyncTime');
    return raw == null ? null : DateTime.parse(raw as String);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _metaBox.put('lastSyncTime', time.toIso8601String());
  }
}
