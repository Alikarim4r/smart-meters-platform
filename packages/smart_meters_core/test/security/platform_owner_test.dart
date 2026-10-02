import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/security/platform_owner.dart';

void main() {
  group('isPlatformOwnerEmail', () {
    test('fails closed when configuration is empty', () {
      expect(isPlatformOwnerEmail('alikarim4r@gmail.com', configOverride: ''), isFalse);
      expect(isPlatformOwnerEmail('support@alimind.com', configOverride: ''), isFalse);
      expect(isPlatformOwnerEmail('admin@company.com', configOverride: ''), isFalse);
    });

    test('fails closed for null or empty email', () {
      expect(isPlatformOwnerEmail(null, configOverride: 'admin@company.com'), isFalse);
      expect(isPlatformOwnerEmail('', configOverride: 'admin@company.com'), isFalse);
      expect(isPlatformOwnerEmail('   ', configOverride: 'admin@company.com'), isFalse);
    });

    test('returns true for configured owner email', () {
      expect(
        isPlatformOwnerEmail('admin@company.com', configOverride: 'admin@company.com'),
        isTrue,
      );
      
      // Case insensitivity
      expect(
        isPlatformOwnerEmail('ADMIN@company.com', configOverride: 'admin@company.com'),
        isTrue,
      );
      expect(
        isPlatformOwnerEmail('admin@company.com', configOverride: 'ADMIN@COMPANY.COM'),
        isTrue,
      );
    });

    test('returns false for non-owner emails when config is present', () {
      expect(
        isPlatformOwnerEmail('user@company.com', configOverride: 'admin@company.com'),
        isFalse,
      );
    });

    test('supports comma-separated multiple owner emails', () {
      const config = 'owner1@company.com, owner2@company.com,owner3@test.com ';
      
      expect(isPlatformOwnerEmail('owner1@company.com', configOverride: config), isTrue);
      expect(isPlatformOwnerEmail('owner2@company.com', configOverride: config), isTrue);
      expect(isPlatformOwnerEmail('owner3@test.com', configOverride: config), isTrue);
      expect(isPlatformOwnerEmail('user@company.com', configOverride: config), isFalse);
    });

    test('hardcoded personal emails no longer grant privilege without config', () {
      // By default (without testing override), String.fromEnvironment will be empty 
      // unless passed during the flutter test command. So it should default to false.
      expect(isPlatformOwnerEmail('alikarim4r@gmail.com'), isFalse);
      expect(isPlatformOwnerEmail('support@alimind.com'), isFalse);
    });
  });
}
