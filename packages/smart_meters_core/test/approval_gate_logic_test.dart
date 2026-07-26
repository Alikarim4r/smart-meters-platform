import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

Profile _profile({
  required ApprovalStatus approvalStatus,
  required bool isActive,
  required UserRole role,
}) {
  return Profile.fromJson({
    'id': 'test-id',
    'full_name': 'Test User',
    'email': 'test@validation.local',
    'role': role.dbValue,
    'is_active': isActive,
    'approval_status': approvalStatus.dbValue,
    'created_at': '2026-07-03T00:00:00.000Z',
    'updated_at': '2026-07-03T00:00:00.000Z',
  });
}

void main() {
  group('entry_app role gate', () {
    bool allowed(Profile profile) =>
        profile.isTechnician || profile.isSiteAdmin;

    test('approved technician allowed', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.approved,
            isActive: true,
            role: UserRole.technician,
          ),
        ),
        isTrue,
      );
    });

    test('approved viewer blocked', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.approved,
            isActive: true,
            role: UserRole.viewer,
          ),
        ),
        isFalse,
      );
    });
  });

  group('approval status blocks app entry', () {
    test('pending not approved for access', () {
      final profile = _profile(
        approvalStatus: ApprovalStatus.pending,
        isActive: false,
        role: UserRole.viewer,
      );
      expect(profile.isApprovedForAccess, isFalse);
    });

    test('rejected not approved for access', () {
      final profile = _profile(
        approvalStatus: ApprovalStatus.rejected,
        isActive: false,
        role: UserRole.viewer,
      );
      expect(profile.isApprovedForAccess, isFalse);
    });

    test('suspended not approved for access', () {
      final profile = _profile(
        approvalStatus: ApprovalStatus.suspended,
        isActive: false,
        role: UserRole.technician,
      );
      expect(profile.isApprovedForAccess, isFalse);
    });
  });

  group('admin_app role gate', () {
    bool allowed(Profile profile) =>
        profile.isSuperAdmin || profile.isSiteAdmin;

    test('approved site_admin allowed', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.approved,
            isActive: true,
            role: UserRole.siteAdmin,
          ),
        ),
        isTrue,
      );
    });

    test('approved technician blocked', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.approved,
            isActive: true,
            role: UserRole.technician,
          ),
        ),
        isFalse,
      );
    });
  });

  group('dashboard_app role gate', () {
    bool allowed(Profile profile) =>
        profile.isSuperAdmin ||
        profile.isSiteAdmin ||
        profile.isTechnician ||
        profile.isViewer;

    test('approved viewer allowed', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.approved,
            isActive: true,
            role: UserRole.viewer,
          ),
        ),
        isTrue,
      );
    });

    test('technician_request blocked', () {
      expect(
        allowed(
          _profile(
            approvalStatus: ApprovalStatus.pending,
            isActive: false,
            role: UserRole.technicianRequest,
          ),
        ),
        isFalse,
      );
    });
  });
}
