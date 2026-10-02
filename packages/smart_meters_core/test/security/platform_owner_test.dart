import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/models/profile.dart';

Map<String, dynamic> _row({
  String email = 'someone@example.test',
  Object? isPlatformOwner,
  bool includeFlag = true,
}) =>
    {
      'id': '11111111-1111-4111-8111-111111111111',
      'full_name': 'Test User',
      'email': email,
      'role': 'super_admin',
      'is_active': true,
      'approval_status': 'approved',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      if (includeFlag) 'is_platform_owner': isPlatformOwner,
    };

void main() {
  group('Profile.isPlatformOwner (server-authoritative)', () {
    test('true only when the server flag is true', () {
      expect(Profile.fromJson(_row(isPlatformOwner: true)).isPlatformOwner,
          isTrue);
      expect(Profile.fromJson(_row(isPlatformOwner: false)).isPlatformOwner,
          isFalse);
    });

    test('fails closed when the flag is missing, null or not a bool', () {
      expect(Profile.fromJson(_row(includeFlag: false)).isPlatformOwner,
          isFalse);
      expect(Profile.fromJson(_row(isPlatformOwner: null)).isPlatformOwner,
          isFalse);
      expect(Profile.fromJson(_row(isPlatformOwner: 'true')).isPlatformOwner,
          isFalse);
    });

    test('email alone never grants ownership on the client', () {
      // The legacy owner address no longer implies ownership client-side;
      // only the server-maintained flag does (migration 120).
      final p = Profile.fromJson(
        _row(email: 'alikarim4r@gmail.com', isPlatformOwner: false),
      );
      expect(p.isPlatformOwner, isFalse);
    });

    test('flag survives toJson/fromJson (offline cache) and copyWith', () {
      final owner = Profile.fromJson(_row(isPlatformOwner: true));
      expect(Profile.fromJson(owner.toJson()).isPlatformOwner, isTrue);
      expect(owner.copyWith(fullName: 'Renamed').isPlatformOwner, isTrue);
    });
  });
}
