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
  static const _appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

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

  String get currentEnvironment => _appEnvironment;

  String _userPrefix(String ownerUserId) => '$_appEnvironment::$ownerUserId';

  String _siteCacheKey(String ownerUserId) =>
      '${_userPrefix(ownerUserId)}::all';

  String _meterCacheKey(String ownerUserId, String siteId, String category) =>
      '${_userPrefix(ownerUserId)}::$siteId::$category';

  String _lastSyncKey(String ownerUserId) =>
      '${_userPrefix(ownerUserId)}::lastSyncTime';

  String _draftKey(String ownerUserId, String localId) =>
      '${_userPrefix(ownerUserId)}::draft::$localId';

  Future<void> saveDraft(LocalReadingDraft draft) async {
    if (draft.isLegacyUnscoped || draft.environment != _appEnvironment) {
      throw StateError(
        'Offline drafts must match the current user and environment.',
      );
    }
    await _draftsBox.put(
      _draftKey(draft.ownerUserId!, draft.localId),
      draft.toMap(),
    );
  }

  Future<bool> deleteDraft({
    required String localId,
    required String ownerUserId,
  }) async {
    final draftKey = _draftKey(ownerUserId, localId);
    final raw = _draftsBox.get(draftKey);
    if (raw is! Map) {
      return false;
    }
    final draft = LocalReadingDraft.fromMap(Map<dynamic, dynamic>.from(raw));
    if (!draft.belongsTo(
      userId: ownerUserId,
      appEnvironment: _appEnvironment,
    )) {
      return false;
    }
    await _draftsBox.delete(draftKey);
    return true;
  }

  List<LocalReadingDraft> _getAllDraftsRaw() {
    return _draftsBox.values
        .map(
          (value) => LocalReadingDraft.fromMap(
            Map<dynamic, dynamic>.from(value as Map),
          ),
        )
        .toList();
  }

  List<LocalReadingDraft> getAllDrafts({required String ownerUserId}) {
    return _getAllDraftsRaw()
        .where(
          (draft) => draft.belongsTo(
            userId: ownerUserId,
            appEnvironment: _appEnvironment,
          ),
        )
        .toList();
  }

  /// Pre-isolation records are deliberately retained but cannot be displayed,
  /// edited, deleted, or synced until an explicit ownership recovery flow is
  /// performed.
  List<LocalReadingDraft> getQuarantinedLegacyDrafts() {
    return _getAllDraftsRaw().where((draft) => draft.isLegacyUnscoped).toList();
  }

  LocalReadingDraft? getDraftForMeterAndDate({
    required String ownerUserId,
    required String meterId,
    required String readingDate,
  }) {
    for (final draft in getAllDrafts(ownerUserId: ownerUserId)) {
      if (draft.meterId == meterId && draft.readingDate == readingDate) {
        return draft;
      }
    }
    return null;
  }

  List<LocalReadingDraft> getDraftsForSiteAndDate({
    required String ownerUserId,
    required String siteId,
    required String readingDate,
  }) {
    return getAllDrafts(ownerUserId: ownerUserId)
        .where(
          (draft) => draft.siteId == siteId && draft.readingDate == readingDate,
        )
        .toList();
  }

  List<LocalReadingDraft> getPendingSyncDrafts({required String ownerUserId}) {
    return getAllDrafts(
      ownerUserId: ownerUserId,
    ).where((draft) => draft.isPendingSync).toList();
  }

  Future<void> cacheSites({
    required String ownerUserId,
    required List<CachedSite> sites,
  }) async {
    final maps = sites.map((site) => site.toMap()).toList();
    await _sitesBox.put(_siteCacheKey(ownerUserId), maps);
  }

  List<CachedSite> getCachedSites({required String ownerUserId}) {
    final raw = _sitesBox.get(_siteCacheKey(ownerUserId));
    if (raw is! List) {
      return [];
    }
    return raw
        .map(
          (item) => CachedSite.fromMap(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> cacheMeters({
    required String ownerUserId,
    required String siteId,
    required String category,
    required List<CachedMeter> meters,
  }) async {
    final maps = meters.map((meter) => meter.toMap()).toList();
    await _metersBox.put(_meterCacheKey(ownerUserId, siteId, category), maps);
  }

  List<CachedMeter> getCachedMeters({
    required String ownerUserId,
    required String siteId,
    required String category,
  }) {
    final raw = _metersBox.get(_meterCacheKey(ownerUserId, siteId, category));
    if (raw is! List) {
      return [];
    }
    return raw
        .map(
          (item) =>
              CachedMeter.fromMap(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList();
  }

  DateTime? getLastSyncTime({required String ownerUserId}) {
    final raw = _metaBox.get(_lastSyncKey(ownerUserId));
    return raw == null ? null : DateTime.parse(raw as String);
  }

  Future<void> setLastSyncTime({
    required String ownerUserId,
    required DateTime time,
  }) async {
    await _metaBox.put(_lastSyncKey(ownerUserId), time.toIso8601String());
  }

  /// Clears user-specific reference caches on sign-out while preserving their
  /// owned reading drafts for the next authenticated session.
  Future<void> clearCachesForUser({required String ownerUserId}) async {
    final prefix = '${_userPrefix(ownerUserId)}::';
    await _sitesBox.delete(_siteCacheKey(ownerUserId));
    await _metersBox.deleteAll(
      _metersBox.keys.where((key) => key is String && key.startsWith(prefix)),
    );
    await _metaBox.delete(_lastSyncKey(ownerUserId));
  }
}
