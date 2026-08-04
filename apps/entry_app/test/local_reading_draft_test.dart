import 'package:flutter_test/flutter_test.dart';

import 'package:entry_app/offline/local_reading_draft.dart';
import 'package:entry_app/photos/reading_photo_models.dart';

void main() {
  test('LocalReadingDraft round-trips through map', () {
    final draft = LocalReadingDraft(
      ownerUserId: 'user-1',
      environment: 'production',
      localId: 'abc',
      siteId: 'site',
      meterId: 'meter',
      readingDate: '2026-07-04',
      rawValue: 123.5,
      note: 'test',
      status: LocalReadingStatus.savedLocally,
      errorMessage: null,
      createdAt: DateTime(2026, 7, 4, 8),
      updatedAt: DateTime(2026, 7, 4, 9),
      organizationId: 'org-1',
      categoryCode: 'water',
      watermarkedPhotoPath: '/tmp/photo.jpg',
      photoSource: ReadingPhotoSource.camera,
      photoUploadStatus: PhotoUploadStatus.attachedLocally,
      photoCapturedAt: DateTime(2026, 7, 4, 9),
    );

    final restored = LocalReadingDraft.fromMap(draft.toMap());
    expect(restored.localId, 'abc');
    expect(restored.ownerUserId, 'user-1');
    expect(
      restored.belongsTo(userId: 'user-1', appEnvironment: 'production'),
      isTrue,
    );
    expect(restored.rawValue, 123.5);
    expect(restored.status, LocalReadingStatus.savedLocally);
    expect(restored.note, 'test');
    expect(restored.organizationId, 'org-1');
    expect(restored.categoryCode, 'water');
    expect(restored.watermarkedPhotoPath, '/tmp/photo.jpg');
    expect(restored.photoSource, ReadingPhotoSource.camera);
    expect(restored.photoUploadStatus, PhotoUploadStatus.attachedLocally);
  });

  test('legacy draft remains decodable but is quarantined', () {
    final legacyMap = <dynamic, dynamic>{
      'localId': 'legacy',
      'siteId': 'site',
      'meterId': 'meter',
      'readingDate': '2026-07-04',
      'rawValue': 12.0,
      'status': LocalReadingStatus.savedLocally.name,
      'createdAt': DateTime(2026, 7, 4, 8).toIso8601String(),
      'updatedAt': DateTime(2026, 7, 4, 9).toIso8601String(),
    };

    final restored = LocalReadingDraft.fromMap(legacyMap);
    expect(restored.isLegacyUnscoped, isTrue);
    expect(
      restored.belongsTo(userId: 'user-1', appEnvironment: 'production'),
      isFalse,
    );
  });
}
