import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:entry_app/offline/local_reading_draft.dart';
import 'package:entry_app/offline/offline_storage_service.dart';
import 'package:entry_app/photos/meter_photo_watermark.dart';

LocalReadingDraft _draft({
  required String localId,
  String meterId = 'meter-1',
  String readingDate = '2026-08-04',
}) {
  return LocalReadingDraft(
    localId: localId,
    siteId: 'site-1',
    meterId: meterId,
    readingDate: readingDate,
    rawValue: 42,
    status: LocalReadingStatus.savedLocally,
    createdAt: DateTime(2026, 8, 4),
    updatedAt: DateTime(2026, 8, 4),
  );
}

void main() {
  late Directory hiveDirectory;
  final storage = OfflineStorageService.instance;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'entry-offline-storage-test-',
    );
    Hive.init(hiveDirectory.path);
    for (final name in [
      'reading_drafts',
      'cached_meters',
      'cached_sites',
      'offline_meta',
      readingPhotoBytesBoxName,
    ]) {
      await Hive.openBox<dynamic>(name);
    }
  });

  setUp(() async {
    for (final name in [
      'reading_drafts',
      'cached_meters',
      'cached_sites',
      'offline_meta',
      readingPhotoBytesBoxName,
    ]) {
      await Hive.box<dynamic>(name).clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('saves and lists drafts for sync', () async {
    await storage.saveDraft(_draft(localId: 'a'));
    await storage.saveDraft(_draft(localId: 'b', meterId: 'meter-2'));

    expect(storage.getAllDrafts(), hasLength(2));
    expect(storage.getPendingSyncDrafts(), hasLength(2));
    await storage.deleteDraft('a');
    expect(storage.getAllDrafts(), hasLength(1));
    expect(storage.getAllDrafts().single.localId, 'b');
  });

  test('finds draft for meter and date', () async {
    await storage.saveDraft(_draft(localId: 'd1'));
    final found = storage.getDraftForMeterAndDate(
      meterId: 'meter-1',
      readingDate: '2026-08-04',
    );
    expect(found?.localId, 'd1');
    expect(
      storage.getDraftForMeterAndDate(
        meterId: 'missing',
        readingDate: '2026-08-04',
      ),
      isNull,
    );
  });

  test('caches site policy and categories for offline reuse', () async {
    await storage.cacheSitePolicy(
      siteId: 'site-1',
      policy: {'organization_id': 'org-1', 'photo_required': true},
    );
    expect(storage.getCachedSitePolicy('site-1')?['photo_required'], isTrue);

    await storage.cacheCategories(
      siteId: 'site-1',
      categories: [
        {'id': 'c1', 'code': 'electric', 'name_en': 'Electric'},
      ],
    );
    expect(storage.getCachedCategories('site-1'), hasLength(1));
  });

  test('photo store deletion removes cached logical bytes', () async {
    final box = Hive.box<dynamic>(readingPhotoBytesBoxName);
    const logicalKey = 'draft-1-watermarked.jpg';
    await box.put(logicalKey, <int>[1, 2, 3]);
    final fileStore = ReadingPhotoFileStore();

    expect(await fileStore.readBytes(logicalKey), isNotNull);
    await fileStore.deletePhoto(logicalKey);
    expect(box.containsKey(logicalKey), isFalse);
    expect(await fileStore.readBytes(logicalKey), isNull);
  });

  test('last sync metadata is persisted', () async {
    final time = DateTime(2026, 8, 4, 10);
    await storage.setLastSyncTime(time);
    expect(storage.lastSyncTime, time);
  });
}
