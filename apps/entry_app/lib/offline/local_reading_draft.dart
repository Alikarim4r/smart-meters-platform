import '../photos/reading_photo_models.dart';

enum LocalReadingStatus {
  draft,
  savedLocally,
  syncing,
  synced,
  failed,
  conflict;

  String get label {
    switch (this) {
      case LocalReadingStatus.draft:
        return 'Draft';
      case LocalReadingStatus.savedLocally:
        return 'Saved locally';
      case LocalReadingStatus.syncing:
        return 'Syncing';
      case LocalReadingStatus.synced:
        return 'Synced';
      case LocalReadingStatus.failed:
        return 'Failed sync';
      case LocalReadingStatus.conflict:
        return 'Conflict';
    }
  }

  static LocalReadingStatus fromDb(String value) {
    return LocalReadingStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown local reading status: $value'),
    );
  }
}

class LocalReadingDraft {
  const LocalReadingDraft({
    required this.localId,
    required this.siteId,
    required this.meterId,
    required this.readingDate,
    required this.rawValue,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.organizationId,
    this.categoryCode,
    this.note,
    this.errorMessage,
    this.syncedAt,
    this.localPhotoPath,
    this.watermarkedPhotoPath,
    this.photoSource,
    this.photoUploadStatus = PhotoUploadStatus.none,
    this.photoCapturedAt,
    this.remotePhotoPath,
    this.remotePhotoUrl,
    this.photoErrorMessage,
  });

  final String localId;
  final String siteId;
  final String meterId;
  final String readingDate;
  final double rawValue;
  final String? note;
  final LocalReadingStatus status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? organizationId;
  final String? categoryCode;
  final String? localPhotoPath;
  final String? watermarkedPhotoPath;
  final ReadingPhotoSource? photoSource;
  final PhotoUploadStatus photoUploadStatus;
  final DateTime? photoCapturedAt;
  final String? remotePhotoPath;
  final String? remotePhotoUrl;
  final String? photoErrorMessage;

  bool get hasLocalPhoto =>
      watermarkedPhotoPath != null && watermarkedPhotoPath!.isNotEmpty;

  bool get isEditable =>
      status == LocalReadingStatus.draft ||
      status == LocalReadingStatus.savedLocally ||
      status == LocalReadingStatus.failed;

  bool get isPendingSync =>
      status == LocalReadingStatus.savedLocally ||
      status == LocalReadingStatus.failed ||
      status == LocalReadingStatus.syncing;

  LocalReadingDraft copyWith({
    String? localId,
    String? siteId,
    String? meterId,
    String? readingDate,
    double? rawValue,
    String? note,
    LocalReadingStatus? status,
    String? errorMessage,
    bool clearError = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
    String? organizationId,
    String? categoryCode,
    String? localPhotoPath,
    String? watermarkedPhotoPath,
    bool clearLocalPhotoPath = false,
    bool clearWatermarkedPhotoPath = false,
    ReadingPhotoSource? photoSource,
    bool clearPhotoSource = false,
    PhotoUploadStatus? photoUploadStatus,
    DateTime? photoCapturedAt,
    bool clearPhotoCapturedAt = false,
    String? remotePhotoPath,
    bool clearRemotePhotoPath = false,
    String? remotePhotoUrl,
    bool clearRemotePhotoUrl = false,
    String? photoErrorMessage,
    bool clearPhotoErrorMessage = false,
  }) {
    return LocalReadingDraft(
      localId: localId ?? this.localId,
      siteId: siteId ?? this.siteId,
      meterId: meterId ?? this.meterId,
      readingDate: readingDate ?? this.readingDate,
      rawValue: rawValue ?? this.rawValue,
      note: note ?? this.note,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
      organizationId: organizationId ?? this.organizationId,
      categoryCode: categoryCode ?? this.categoryCode,
      localPhotoPath:
          clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      watermarkedPhotoPath: clearWatermarkedPhotoPath
          ? null
          : (watermarkedPhotoPath ?? this.watermarkedPhotoPath),
      photoSource: clearPhotoSource ? null : (photoSource ?? this.photoSource),
      photoUploadStatus: photoUploadStatus ?? this.photoUploadStatus,
      photoCapturedAt: clearPhotoCapturedAt
          ? null
          : (photoCapturedAt ?? this.photoCapturedAt),
      remotePhotoPath:
          clearRemotePhotoPath ? null : (remotePhotoPath ?? this.remotePhotoPath),
      remotePhotoUrl:
          clearRemotePhotoUrl ? null : (remotePhotoUrl ?? this.remotePhotoUrl),
      photoErrorMessage: clearPhotoErrorMessage
          ? null
          : (photoErrorMessage ?? this.photoErrorMessage),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'siteId': siteId,
      'meterId': meterId,
      'readingDate': readingDate,
      'rawValue': rawValue,
      'note': note,
      'status': status.name,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'organizationId': organizationId,
      'categoryCode': categoryCode,
      'localPhotoPath': localPhotoPath,
      'watermarkedPhotoPath': watermarkedPhotoPath,
      'photoSource': photoSource?.name,
      'photoUploadStatus': photoUploadStatus.name,
      'photoCapturedAt': photoCapturedAt?.toIso8601String(),
      'remotePhotoPath': remotePhotoPath,
      'remotePhotoUrl': remotePhotoUrl,
      'photoErrorMessage': photoErrorMessage,
    };
  }

  factory LocalReadingDraft.fromMap(Map<dynamic, dynamic> map) {
    return LocalReadingDraft(
      localId: map['localId'] as String,
      siteId: map['siteId'] as String,
      meterId: map['meterId'] as String,
      readingDate: map['readingDate'] as String,
      rawValue: (map['rawValue'] as num).toDouble(),
      note: map['note'] as String?,
      status: LocalReadingStatus.fromDb(map['status'] as String),
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      syncedAt: map['syncedAt'] == null
          ? null
          : DateTime.parse(map['syncedAt'] as String),
      organizationId: map['organizationId'] as String?,
      categoryCode: map['categoryCode'] as String?,
      localPhotoPath: map['localPhotoPath'] as String?,
      watermarkedPhotoPath: map['watermarkedPhotoPath'] as String?,
      photoSource: ReadingPhotoSource.fromDb(map['photoSource'] as String?),
      photoUploadStatus: map['photoUploadStatus'] == null
          ? PhotoUploadStatus.none
          : PhotoUploadStatus.fromDb(map['photoUploadStatus'] as String),
      photoCapturedAt: map['photoCapturedAt'] == null
          ? null
          : DateTime.parse(map['photoCapturedAt'] as String),
      remotePhotoPath: map['remotePhotoPath'] as String?,
      remotePhotoUrl: map['remotePhotoUrl'] as String?,
      photoErrorMessage: map['photoErrorMessage'] as String?,
    );
  }
}
