import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:entry_app/offline/local_reading_draft.dart';
import 'package:entry_app/offline/offline_storage_service.dart';

LocalReadingDraft _draft({
  required String localId,
  required String? ownerUserId,
}) {
  return LocalReadingDraft(
    ownerUserId: ownerUserId,
    environment: ownerUserId == null
        ? null
        : OfflineStorageService.instance.currentEnvironment,
    localId: localId,
    siteId: 'site-1',
    meterId: 'meter-1',
    readingDate: '2026-08-04',
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
    ]) {
      await Hive.box<dynamic>(name).clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('draft queries and deletion are isolated by owner', () async {
    await storage.saveDraft(_draft(localId: 'a', ownerUserId: 'user-a'));
    await storage.saveDraft(_draft(localId: 'b', ownerUserId: 'user-b'));

    expect(storage.getAllDrafts(ownerUserId: 'user-a'), hasLength(1));
    expect(storage.getPendingSyncDrafts(ownerUserId: 'user-b'), hasLength(1));
    expect(
      await storage.deleteDraft(localId: 'a', ownerUserId: 'user-b'),
      isFalse,
    );
    expect(storage.getAllDrafts(ownerUserId: 'user-a'), hasLength(1));
    expect(
      await storage.deleteDraft(localId: 'a', ownerUserId: 'user-a'),
      isTrue,
    );
    expect(storage.getAllDrafts(ownerUserId: 'user-a'), isEmpty);
  });

  test(
    'legacy unowned drafts are retained and never enter a user queue',
    () async {
      final legacy = _draft(localId: 'legacy', ownerUserId: null).toMap()
        ..remove('ownerUserId');
      await Hive.box<dynamic>('reading_drafts').put('legacy', legacy);

      expect(storage.getAllDrafts(ownerUserId: 'user-a'), isEmpty);
      expect(storage.getQuarantinedLegacyDrafts(), hasLength(1));
      expect(
        () => storage.saveDraft(_draft(localId: 'new', ownerUserId: null)),
        throwsStateError,
      );
    },
  );

  test('drafts from another environment cannot be persisted', () async {
    final draft = _draft(localId: 'foreign', ownerUserId: 'user-a');
    final foreign = LocalReadingDraft.fromMap(
      draft.toMap()..['environment'] = 'different-environment',
    );

    expect(() => storage.saveDraft(foreign), throwsStateError);
  });

  test('last sync metadata is isolated by owner', () async {
    final first = DateTime(2026, 8, 4, 10);
    final second = DateTime(2026, 8, 4, 11);
    await storage.setLastSyncTime(ownerUserId: 'user-a', time: first);
    await storage.setLastSyncTime(ownerUserId: 'user-b', time: second);

    expect(storage.getLastSyncTime(ownerUserId: 'user-a'), first);
    expect(storage.getLastSyncTime(ownerUserId: 'user-b'), second);
  });
}
