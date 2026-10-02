import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('subscription access parses fail-closed feature map', () {
    final s = OrganizationSubscription.fromRpc('org', {
      'plan': 'professional',
      'status': 'active',
      'has_access': true,
      'max_users': 50,
      'max_sites': 5,
      'max_meters': 500,
      'features': {'conservation_mv': true},
    });
    expect(s.plan, SubscriptionPlan.professional);
    expect(s.hasAccess, isTrue);
    expect(s.maxMeters, 500);
    expect(s.hasFeature('conservation_mv'), isTrue);
    expect(s.hasFeature('automation'), isFalse);
  });
  test('unknown status fails to trialing but access stays server-owned', () {
    final s = OrganizationSubscription.fromRpc('org', {
      'plan': 'starter',
      'status': 'unknown',
      'has_access': false,
      'max_users': 10,
      'max_sites': 1,
      'max_meters': 50,
    });
    expect(s.status, SubscriptionStatus.trialing);
    expect(s.hasAccess, isFalse);
  });
}
