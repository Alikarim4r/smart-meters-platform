import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('Profile.fromJson parses approval fields', () {
    final profile = Profile.fromJson({
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
      'full_name': 'Test Technician',
      'email': 'test-technician@validation.local',
      'role': 'technician',
      'is_active': true,
      'approval_status': 'approved',
      'approval_note': 'welcome',
      'approved_at': '2026-07-04T00:00:00.000Z',
      'approved_by': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
      'rejected_at': null,
      'rejected_by': null,
      'created_at': '2026-07-03T00:00:00.000Z',
      'updated_at': '2026-07-04T00:00:00.000Z',
    });

    expect(profile.approvalStatus, ApprovalStatus.approved);
    expect(profile.approvalNote, 'welcome');
    expect(profile.approvedBy, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1');
    expect(profile.isApprovedForAccess, isTrue);
  });

  test('Profile defaults approval_status to approved when absent', () {
    final profile = Profile.fromJson({
      'id': 'x',
      'full_name': 'Legacy',
      'email': 'legacy@example.com',
      'role': 'viewer',
      'is_active': true,
      'created_at': '2026-07-03T00:00:00.000Z',
      'updated_at': '2026-07-03T00:00:00.000Z',
    });

    expect(profile.approvalStatus, ApprovalStatus.approved);
  });

  test('pending profile is not approved for access', () {
    final profile = Profile.fromJson({
      'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
      'full_name': 'Pending',
      'email': 'pending@validation.local',
      'role': 'viewer',
      'is_active': false,
      'approval_status': 'pending',
      'created_at': '2026-07-03T00:00:00.000Z',
      'updated_at': '2026-07-03T00:00:00.000Z',
    });

    expect(profile.isApprovedForAccess, isFalse);
  });
}
