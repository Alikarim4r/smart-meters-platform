import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('UserRole maps database values', () {
    expect(UserRole.fromDb('technician'), UserRole.technician);
    expect(UserRole.fromDb('technician_request'), UserRole.technicianRequest);
    expect(UserRole.superAdmin.dbValue, 'super_admin');
  });

  test('ApprovalStatus maps database values', () {
    expect(ApprovalStatus.fromDb('pending'), ApprovalStatus.pending);
    expect(ApprovalStatus.fromDb('approved'), ApprovalStatus.approved);
    expect(ApprovalStatus.fromDb('rejected'), ApprovalStatus.rejected);
    expect(ApprovalStatus.fromDb('suspended'), ApprovalStatus.suspended);
  });
}
