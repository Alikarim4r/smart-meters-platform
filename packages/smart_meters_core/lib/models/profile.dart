import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.approvalStatus,
    required this.createdAt,
    required this.updatedAt,
    this.approvalNote,
    this.approvedAt,
    this.approvedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.allowBackdatedReadings = false,
    this.phone,
    this.companyName,
    this.avatarPath,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final bool isActive;
  final ApprovalStatus approvalStatus;

  /// When true, the user may submit Entry-app readings for past dates.
  final bool allowBackdatedReadings;
  final String? approvalNote;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional Entry profile contact fields.
  final String? phone;
  final String? companyName;

  /// Storage path in `profile-avatars` bucket.
  final String? avatarPath;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: UserRole.fromDb(json['role'] as String),
      isActive: json['is_active'] as bool,
      approvalStatus: json['approval_status'] != null
          ? ApprovalStatus.fromDb(json['approval_status'] as String)
          : ApprovalStatus.approved,
      approvalNote: json['approval_note'] as String?,
      approvedAt: _parseOptionalDateTime(json['approved_at']),
      approvedBy: json['approved_by'] as String?,
      rejectedAt: _parseOptionalDateTime(json['rejected_at']),
      rejectedBy: json['rejected_by'] as String?,
      allowBackdatedReadings:
          json['allow_backdated_readings'] as bool? ?? false,
      phone: json['phone'] as String?,
      companyName: json['company_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }

  bool get isSuperAdmin => role == UserRole.superAdmin;

  bool get isSiteAdmin => role == UserRole.siteAdmin;

  bool get isTechnician => role == UserRole.technician;

  bool get isViewer => role == UserRole.viewer;

  bool get isTechnicianRequest => role == UserRole.technicianRequest;

  /// Approved and active — required before role/site gates and data access.
  bool get isApprovedForAccess =>
      approvalStatus == ApprovalStatus.approved && isActive;

  Profile copyWith({
    String? fullName,
    String? phone,
    String? companyName,
    String? avatarPath,
    bool clearPhone = false,
    bool clearCompanyName = false,
    bool clearAvatarPath = false,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      role: role,
      isActive: isActive,
      approvalStatus: approvalStatus,
      approvalNote: approvalNote,
      approvedAt: approvedAt,
      approvedBy: approvedBy,
      rejectedAt: rejectedAt,
      rejectedBy: rejectedBy,
      allowBackdatedReadings: allowBackdatedReadings,
      phone: clearPhone ? null : (phone ?? this.phone),
      companyName: clearCompanyName ? null : (companyName ?? this.companyName),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
