import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:admin_app/utils/user_validation.dart';

void main() {
  AdminUser makeUser({
    required String email,
    required UserRole role,
    required ApprovalStatus status,
    bool isActive = true,
  }) {
    return AdminUser(
      profile: Profile(
        id: email,
        fullName: 'Test User',
        email: email,
        role: role,
        isActive: isActive,
        approvalStatus: status,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      siteAssignmentCount: 0,
    );
  }

  test('searchUsers matches name and email', () {
    final users = [
      makeUser(
        email: 'alice@example.com',
        role: UserRole.technician,
        status: ApprovalStatus.approved,
      ),
      makeUser(
        email: 'bob@example.com',
        role: UserRole.viewer,
        status: ApprovalStatus.pending,
      ),
    ];

    expect(searchUsers(users, 'alice'), hasLength(1));
    expect(searchUsers(users, 'bob@'), hasLength(1));
    expect(searchUsers(users, 'charlie'), isEmpty);
  });

  test('filterUsersByApproval respects status filters', () {
    final users = [
      makeUser(
        email: 'a@test.com',
        role: UserRole.technician,
        status: ApprovalStatus.pending,
      ),
      makeUser(
        email: 'b@test.com',
        role: UserRole.technician,
        status: ApprovalStatus.approved,
      ),
      makeUser(
        email: 'c@test.com',
        role: UserRole.viewer,
        status: ApprovalStatus.suspended,
        isActive: false,
      ),
    ];

    expect(
      filterUsersByApproval(users: users, filter: UserApprovalFilter.pending),
      hasLength(1),
    );
    expect(
      filterUsersByApproval(users: users, filter: UserApprovalFilter.suspended),
      hasLength(1),
    );
    expect(
      filterUsersByApproval(users: users, filter: UserApprovalFilter.inactive),
      hasLength(1),
    );
  });

  test('validateApprovalSites requires sites for technician and viewer', () {
    expect(
      validateApprovalSites(role: UserRole.technician, selectedSiteIds: {}),
      isNotNull,
    );
    expect(
      validateApprovalSites(role: UserRole.viewer, selectedSiteIds: {}),
      isNotNull,
    );
    expect(
      validateApprovalSites(
        role: UserRole.viewer,
        selectedSiteIds: {'site-1'},
      ),
      isNull,
    );
    expect(
      validateApprovalSites(role: UserRole.superAdmin, selectedSiteIds: {}),
      isNull,
    );
  });

  test('validateUserScope requires entity for kind', () {
    expect(
      validateUserScope(kind: ScopeKind.organization, organizationId: null),
      isNotNull,
    );
    expect(
      validateUserScope(kind: ScopeKind.organization, organizationId: 'org-1'),
      isNull,
    );
    expect(
      validateUserScope(
        kind: ScopeKind.zone,
        organizationId: 'org-1',
        zoneId: null,
      ),
      isNotNull,
    );
    expect(
      validateUserScope(
        kind: ScopeKind.site,
        organizationId: 'org-1',
        siteId: 'site-1',
      ),
      isNull,
    );
  });

  test('canEditSiteAssignments only for approved active users', () {
    final approved = makeUser(
      email: 'a@test.com',
      role: UserRole.technician,
      status: ApprovalStatus.approved,
    );
    final pending = makeUser(
      email: 'b@test.com',
      role: UserRole.technicianRequest,
      status: ApprovalStatus.pending,
    );

    expect(canEditSiteAssignments(approved), isTrue);
    expect(canEditSiteAssignments(pending), isFalse);
  });
}
