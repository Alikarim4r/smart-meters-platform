import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meter_entry_status.dart';
import '../offline/cached_meter.dart';
import '../offline/local_reading_draft.dart';
import '../offline/offline_storage_service.dart';
import '../photos/reading_photo_models.dart';
import '../photos/reading_photo_service.dart';
import '../photos/reading_sync_helpers.dart';
import 'connectivity_provider.dart';

final _random = Random();

String _newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

final offlineStorageProvider = Provider<OfflineStorageService>((ref) {
  return OfflineStorageService.instance;
});

/// Entry business date. Defaults to today (Asia/Qatar). Users with the
/// per-user backdating permission may select a past date from the header.
final businessDateProvider = StateProvider<DateTime>((ref) {
  return qatarBusinessDate();
});

final sitePolicyProvider =
    FutureProvider.autoDispose.family<PolicySettings, String>((ref, siteId) async {
  return ref
      .read(policySettingsRepositoryProvider)
      .getEffectivePolicyForSite(siteId);
});

final accessibleSitesProvider = FutureProvider<List<Site>>((ref) async {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) {
    return [];
  }

  final isOnline = ref.watch(isOnlineProvider);
  final storage = ref.read(offlineStorageProvider);
  final siteRepo = ref.read(siteRepositoryProvider);

  if (isOnline) {
    try {
      final sites = await siteRepo
          .getAccessibleSites(profile)
          .timeout(const Duration(seconds: 15));
      await storage.cacheSites(sites.map(CachedSite.fromSite).toList());
      return sites;
    } catch (_) {
      // Fall through to cache.
    }
  }

  return storage.getCachedSites().map((site) => site.toSite()).toList();
});

final selectedSiteProvider = StateProvider<Site?>((ref) => null);

final selectedCategoryProvider = StateProvider<MeterCategoryConfig?>((ref) => null);

final meterListSearchProvider = StateProvider<String>((ref) => '');

final meterListFilterProvider =
    StateProvider<MeterListFilter>((ref) => MeterListFilter.all);

final availableCategoriesProvider =
    FutureProvider.family<List<MeterCategoryConfig>, String>((ref, siteId) {
  return ref.read(meterCatalogRepositoryProvider).getCategoriesForSite(siteId);
});

class EntryMeterQuery {
  const EntryMeterQuery({
    required this.siteId,
    required this.category,
    required this.businessDate,
    this.siteLocation,
  });

  final String siteId;
  final MeterCategoryConfig category;
  final DateTime businessDate;
  final String? siteLocation;

  String get categoryId => category.id;
  String get categoryCode => category.code;

  String get readingDateIso => formatBusinessDate(businessDate);

  @override
  bool operator ==(Object other) {
    return other is EntryMeterQuery &&
        other.siteId == siteId &&
        other.category == category &&
        other.businessDate == businessDate;
  }

  @override
  int get hashCode => Object.hash(siteId, category.id, businessDate);
}

final metersWithStatusProvider =
    FutureProvider.family<List<MeterEntryStatus>, EntryMeterQuery>((ref, query) async {
  final storage = ref.read(offlineStorageProvider);
  final isOnline = ref.watch(isOnlineProvider);
  final localDrafts = storage.getDraftsForSiteAndDate(
    siteId: query.siteId,
    readingDate: query.readingDateIso,
  );
  final draftsByMeter = {
    for (final draft in localDrafts) draft.meterId: draft,
  };

  if (isOnline) {
    try {
      final meterRepo = ref.read(meterRepositoryProvider);
      final readingRepo = ref.read(meterReadingRepositoryProvider);

      final meters = await meterRepo.getMetersForSiteAndCategoryId(
        query.siteId,
        query.categoryId,
      );
      final meterIds = meters.map((meter) => meter.id).toList();

      // Parallel: today + last readings (last uses a single bulk query).
      final bundled = await Future.wait([
        readingRepo.getReadingsForSiteAndDate(
          siteId: query.siteId,
          date: query.businessDate,
          meterIds: meterIds,
        ),
        readingRepo.getLatestReadingsBeforeDate(
          meterIds: meterIds,
          date: query.businessDate,
        ),
      ]);
      final todayReadings = bundled[0];
      final lastReadings = bundled[1];

      // Cache in background — don't block the UI on Hive writes.
      unawaited(
        storage.cacheMeters(
          siteId: query.siteId,
          category: query.categoryCode,
          meters: meters
              .map(
                (meter) => CachedMeter.fromMeter(
                  meter: meter,
                  lastReading: lastReadings[meter.id],
                ),
              )
              .toList(),
        ),
      );

      return meters
          .map(
            (meter) => MeterEntryStatus(
              meter: meter,
              todayReading: todayReadings[meter.id],
              localDraft: draftsByMeter[meter.id],
              lastReading: lastReadings[meter.id],
              workStatus: MeterEntryStatus.resolveWorkStatus(
                todayReading: todayReadings[meter.id],
                localDraft: draftsByMeter[meter.id],
              ),
            ),
          )
          .toList();
    } catch (_) {
      // Fall through to cache.
    }
  }

  final cachedMeters = storage.getCachedMeters(
    siteId: query.siteId,
    category: query.categoryCode,
  );

  return cachedMeters
      .map(
        (cached) => MeterEntryStatus(
          meter: cached.toMeter(),
          todayReading: null,
          localDraft: draftsByMeter[cached.meterId],
          lastReading: lastReadingFromCached(cached),
          workStatus: MeterEntryStatus.resolveWorkStatus(
            todayReading: null,
            localDraft: draftsByMeter[cached.meterId],
          ),
        ),
      )
      .toList();
});

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastError,
  });

  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? lastError;

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this._ref) : super(const SyncState()) {
    _loadLastSyncTime();
    _ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next) {
        unawaited(syncNow());
      }
    });
  }

  final Ref _ref;

  void _loadLastSyncTime() {
    final stored = _ref.read(offlineStorageProvider).lastSyncTime;
    if (stored != null) {
      state = state.copyWith(lastSyncTime: stored);
    }
  }

  Future<int> syncNow() async {
    if (state.isSyncing) {
      return 0;
    }

    if (!_ref.read(isOnlineProvider)) {
      state = state.copyWith(lastError: 'لا يوجد اتصال بالإنترنت. / No internet connection.');
      return 0;
    }

    final userId = _ref.read(authProvider).profile?.id;
    if (userId == null) {
      return 0;
    }

    state = state.copyWith(isSyncing: true, clearError: true);
    final storage = _ref.read(offlineStorageProvider);
    final pending = storage.getPendingSyncDrafts();
    var syncedCount = 0;

    for (final draft in pending) {
      if (draft.status == LocalReadingStatus.conflict) {
        continue;
      }

      try {
        final syncedDraft = await syncSingleDraft(
          ref: _ref,
          draft: draft,
          userId: userId,
          persistDraft: storage.saveDraft,
        );
        await storage.saveDraft(syncedDraft);
        if (syncedDraft.status == LocalReadingStatus.synced) {
          syncedCount++;
        }
      } catch (error) {
        await storage.saveDraft(
          draft.copyWith(
            status: LocalReadingStatus.failed,
            errorMessage: isNetworkError(error)
                ? 'Network error while syncing.'
                : 'تعذّر مزامنة القراءة. حاول لاحقاً.',
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    final now = DateTime.now();
    await storage.setLastSyncTime(now);
    state = state.copyWith(isSyncing: false, lastSyncTime: now);
    _ref.invalidate(metersWithStatusProvider);
    return syncedCount;
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

final meterReadingPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, storagePath) async {
  if (storagePath.isEmpty) {
    return null;
  }
  return ref.read(meterImageStorageRepositoryProvider).createSignedUrl(storagePath);
});

class ReadingEntryState {
  const ReadingEntryState({
    this.lastReading,
    this.todayReading,
    this.localDraft,
    this.isLoading = false,
    this.isSaving = false,
    this.isAttachingPhoto = false,
    this.errorMessage,
    this.saveSucceeded = false,
    this.savedLocally = false,
  });

  final MeterReading? lastReading;
  final MeterReading? todayReading;
  final LocalReadingDraft? localDraft;
  final bool isLoading;
  final bool isSaving;
  final bool isAttachingPhoto;
  final String? errorMessage;
  final bool saveSucceeded;
  final bool savedLocally;

  bool get isSubmitted =>
      todayReading != null ||
      localDraft?.status == LocalReadingStatus.synced;

  bool get isReadOnly =>
      todayReading != null ||
      localDraft?.status == LocalReadingStatus.syncing ||
      localDraft?.status == LocalReadingStatus.conflict ||
      localDraft?.status == LocalReadingStatus.synced;

  bool get canEdit =>
      !isReadOnly &&
      (localDraft == null || localDraft!.isEditable);

  ReadingEntryState copyWith({
    MeterReading? lastReading,
    MeterReading? todayReading,
    LocalReadingDraft? localDraft,
    bool? isLoading,
    bool? isSaving,
    bool? isAttachingPhoto,
    String? errorMessage,
    bool clearError = false,
    bool? saveSucceeded,
    bool? savedLocally,
    bool clearLocalDraft = false,
  }) {
    return ReadingEntryState(
      lastReading: lastReading ?? this.lastReading,
      todayReading: todayReading ?? this.todayReading,
      localDraft: clearLocalDraft ? null : (localDraft ?? this.localDraft),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isAttachingPhoto: isAttachingPhoto ?? this.isAttachingPhoto,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveSucceeded: saveSucceeded ?? this.saveSucceeded,
      savedLocally: savedLocally ?? this.savedLocally,
    );
  }
}

class ReadingEntryQuery {
  const ReadingEntryQuery({
    required this.siteId,
    required this.organizationId,
    required this.meterId,
    required this.category,
    required this.businessDate,
    this.initialTodayReading,
    this.initialLastReading,
    this.initialLocalDraft,
  });

  final String siteId;
  final String organizationId;
  final String meterId;
  final MeterCategoryConfig category;
  final DateTime businessDate;
  final MeterReading? initialTodayReading;
  final MeterReading? initialLastReading;
  final LocalReadingDraft? initialLocalDraft;

  String get readingDateIso => formatBusinessDate(businessDate);

  @override
  bool operator ==(Object other) {
    return other is ReadingEntryQuery &&
        other.siteId == siteId &&
        other.organizationId == organizationId &&
        other.meterId == meterId &&
        other.category == category &&
        other.businessDate == businessDate;
  }

  @override
  int get hashCode =>
      Object.hash(siteId, organizationId, meterId, category.id, businessDate);
}

class ReadingEntryNotifier extends StateNotifier<ReadingEntryState> {
  ReadingEntryNotifier(this._ref, this._query) : super(const ReadingEntryState()) {
    _load();
  }

  final Ref _ref;
  final ReadingEntryQuery _query;

  OfflineStorageService get _storage => _ref.read(offlineStorageProvider);

  Future<void> _load() async {
    final storageDraft = _storage.getDraftForMeterAndDate(
      meterId: _query.meterId,
      readingDate: _query.readingDateIso,
    );
    final localDraft = _query.initialLocalDraft ?? storageDraft;

    // Batch UI always seeds initials — skip per-meter network round-trips.
    if (_query.initialTodayReading != null ||
        _query.initialLastReading != null ||
        localDraft != null) {
      state = state.copyWith(
        isLoading: false,
        todayReading: _query.initialTodayReading,
        lastReading: _query.initialLastReading ?? _query.initialTodayReading,
        localDraft: localDraft,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final isOnline = _ref.read(isOnlineProvider);
      MeterReading? today = _query.initialTodayReading;
      MeterReading? last = _query.initialLastReading;

      if (isOnline) {
        try {
          final repo = _ref.read(meterReadingRepositoryProvider);
          today ??= await repo.getReadingForMeterAndDate(
            _query.meterId,
            _query.businessDate,
          );
          last ??= today ??
              await repo.getLastReadingBeforeDate(
                _query.meterId,
                _query.businessDate,
              );
        } catch (_) {
          // Use cache/draft only below.
        }
      }

      if (last == null) {
        final cached = _storage.getCachedMeters(
          siteId: _query.siteId,
          category: _query.category.code,
        );
        final match =
            cached.where((meter) => meter.meterId == _query.meterId).toList();
        if (match.isNotEmpty) {
          last = lastReadingFromCached(match.first);
        }
      }

      state = state.copyWith(
        isLoading: false,
        todayReading: today,
        lastReading: last ?? today,
        localDraft: localDraft,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load reading data. Please try again.',
      );
    }
  }

  Future<bool> attachPhoto({
    required Site site,
    required Meter meter,
    required ReadingPhotoSource source,
  }) async {
    if (state.isReadOnly || state.isAttachingPhoto) {
      return false;
    }

    final profile = _ref.read(authProvider).profile;
    if (profile == null) {
      state = state.copyWith(errorMessage: 'Session expired. Please sign in again.');
      return false;
    }

    state = state.copyWith(isAttachingPhoto: true, clearError: true);
    try {
      final photoService = _ref.read(readingPhotoServiceProvider);
      final localId = state.localDraft?.localId ?? _newLocalId();
      final context = await photoService.buildContext(
        site: site,
        meter: meter,
        category: _query.category,
        businessDate: _query.businessDate,
        profile: profile,
        source: source,
      );
      final result = await photoService.captureAndWatermark(
        source: source,
        localId: localId,
        context: context,
      );
      if (result == null) {
        state = state.copyWith(isAttachingPhoto: false);
        return false;
      }

      final now = DateTime.now();
      final existingDraft = state.localDraft;
      final draft = (existingDraft ??
              LocalReadingDraft(
                localId: localId,
                siteId: _query.siteId,
                meterId: _query.meterId,
                readingDate: _query.readingDateIso,
                rawValue: 0,
                status: LocalReadingStatus.draft,
                createdAt: now,
                updatedAt: now,
                organizationId: _query.organizationId,
                categoryCode: _query.category.code,
              ))
          .copyWith(
            localPhotoPath: result.localPhotoPath,
            watermarkedPhotoPath: result.watermarkedPhotoPath,
            photoSource: result.source,
            photoUploadStatus: PhotoUploadStatus.attachedLocally,
            photoCapturedAt: now,
            updatedAt: now,
            organizationId: _query.organizationId,
            categoryCode: _query.category.code,
            clearRemotePhotoPath: true,
            clearRemotePhotoUrl: true,
            clearPhotoErrorMessage: true,
          );

      state = state.copyWith(
        isAttachingPhoto: false,
        localDraft: draft,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isAttachingPhoto: false,
        errorMessage: 'Could not process photo. Try again.',
      );
      return false;
    }
  }

  void removePhoto() {
    if (state.isReadOnly) {
      return;
    }
    final draft = state.localDraft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(
      localDraft: draft.copyWith(
        clearLocalPhotoPath: true,
        clearWatermarkedPhotoPath: true,
        clearPhotoSource: true,
        clearPhotoCapturedAt: true,
        photoUploadStatus: PhotoUploadStatus.none,
        clearRemotePhotoPath: true,
        clearRemotePhotoUrl: true,
        clearPhotoErrorMessage: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Clears local draft + photo for this meter (technician "delete" on a card).
  Future<bool> clearEntry() async {
    if (state.isReadOnly) {
      return false;
    }
    final draft = state.localDraft;
    if (draft != null) {
      await _storage.deleteDraft(draft.localId);
    }
    state = state.copyWith(
      clearLocalDraft: true,
      clearError: true,
      saveSucceeded: false,
      savedLocally: false,
    );
    _ref.invalidate(metersWithStatusProvider);
    return true;
  }

  Future<bool> saveReading({
    required double rawValue,
    String? note,
  }) async {
    if (state.isReadOnly || state.isSaving) {
      return false;
    }

    final userId = _ref.read(authProvider).profile?.id;
    if (userId == null) {
      state = state.copyWith(errorMessage: 'Session expired. Please sign in again.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, saveSucceeded: false);

    final trimmedNote = note?.trim();
    final now = DateTime.now();
    final existingDraft = state.localDraft ??
        _storage.getDraftForMeterAndDate(
          meterId: _query.meterId,
          readingDate: _query.readingDateIso,
        );
    final draft = (existingDraft ??
            LocalReadingDraft(
              localId: _newLocalId(),
              siteId: _query.siteId,
              meterId: _query.meterId,
              readingDate: _query.readingDateIso,
              rawValue: rawValue,
              status: LocalReadingStatus.savedLocally,
              createdAt: now,
              updatedAt: now,
              organizationId: _query.organizationId,
              categoryCode: _query.category.code,
            ))
        .copyWith(
          rawValue: rawValue,
          note: trimmedNote?.isEmpty == true ? null : trimmedNote,
          updatedAt: now,
          organizationId: _query.organizationId,
          categoryCode: _query.category.code,
        );

    final isOnline = _ref.read(isOnlineProvider);
    final localDraft = draft.copyWith(
      status: LocalReadingStatus.savedLocally,
      updatedAt: now,
      clearError: true,
      photoUploadStatus: draft.hasLocalPhoto
          ? PhotoUploadStatus.attachedLocally
          : draft.photoUploadStatus,
    );

    final policy = await _ref
        .read(policySettingsRepositoryProvider)
        .getEffectivePolicyForSite(_query.siteId);
    final hasPhoto = localDraft.hasLocalPhoto ||
        (localDraft.remotePhotoPath != null &&
            localDraft.remotePhotoPath!.trim().isNotEmpty) ||
        (state.todayReading?.hasPhoto ?? false);
    if (readingViolatesPhotoPolicy(policy: policy, hasPhoto: hasPhoto)) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: photoRequiredPolicyMessage,
      );
      return false;
    }

    await _storage.saveDraft(localDraft);

    if (isOnline) {
      try {
        final syncedDraft = await syncSingleDraft(
          ref: _ref,
          draft: localDraft,
          userId: userId,
          persistDraft: _storage.saveDraft,
        );
        await _storage.saveDraft(syncedDraft);

        if (syncedDraft.status == LocalReadingStatus.synced) {
          final reading = await _ref
              .read(meterReadingRepositoryProvider)
              .getReadingForMeterAndDate(_query.meterId, _query.businessDate);

          state = state.copyWith(
            isSaving: false,
            todayReading: reading,
            localDraft: syncedDraft,
            saveSucceeded: true,
          );
          _ref.invalidate(metersWithStatusProvider);
          return true;
        }

        if (syncedDraft.status == LocalReadingStatus.conflict) {
          await _load();
          state = state.copyWith(
            isSaving: false,
            errorMessage: syncedDraft.errorMessage,
          );
          return false;
        }

        if (syncedDraft.status == LocalReadingStatus.failed) {
          state = state.copyWith(
            isSaving: false,
            localDraft: syncedDraft,
            savedLocally: true,
            saveSucceeded: false,
            errorMessage:
                syncedDraft.errorMessage ??
                syncedDraft.photoErrorMessage ??
                'تعذّر مزامنة القراءة. تحقق من صلاحية التاريخ وحاول مجدداً.',
          );
          _ref.invalidate(metersWithStatusProvider);
          return false;
        }

        state = state.copyWith(
          isSaving: false,
          localDraft: syncedDraft,
          savedLocally: true,
          saveSucceeded: true,
          errorMessage: syncedDraft.errorMessage ?? syncedDraft.photoErrorMessage,
        );
        _ref.invalidate(metersWithStatusProvider);
        return true;
      } on PostgrestException catch (error) {
        if (!isNetworkError(error)) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: readablePostgrestError(error),
          );
          return false;
        }
      } catch (error) {
        if (!isNetworkError(error)) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: 'Could not save reading. Check value and try again.',
          );
          return false;
        }
      }
    }

    state = state.copyWith(
      isSaving: false,
      localDraft: localDraft,
      saveSucceeded: true,
      savedLocally: true,
    );
    _ref.invalidate(metersWithStatusProvider);

    if (_ref.read(isOnlineProvider)) {
      unawaited(_ref.read(syncProvider.notifier).syncNow());
    }

    return true;
  }

  Future<void> refresh() => _load();
}

final readingEntryProvider = StateNotifierProvider.autoDispose
    .family<ReadingEntryNotifier, ReadingEntryState, ReadingEntryQuery>(
  (ref, query) => ReadingEntryNotifier(ref, query),
);
