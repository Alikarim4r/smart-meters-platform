import 'package:admin_app/billing/billing_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

Map<String, dynamic> row({
  String plan = 'professional',
  String period = 'monthly',
  String package = kAdminAppPackageName,
}) => {
  'package_name': package,
  'product_id': 'smartmeters_professional',
  'base_plan_id': period == 'annual' ? 'professional-annual' : 'professional-monthly',
  'plan': plan,
  'billing_period': period,
  'display_order': 0,
  'max_users': 50,
  'max_sites': 10,
  'max_meters': 500,
  'features': {'advanced_reports': true},
  'account_binding': 'abc123',
};

StoreOffer offer({String period = 'P1M', String? offerId}) => StoreOffer(
  productId: 'smartmeters_professional',
  basePlanId: period == 'P1Y' ? 'professional-annual' : 'professional-monthly',
  offerId: offerId,
  recurringPrice: 'QAR 99.00',
  recurringPeriodIso: period,
);

BillingVerificationResult verified(String ack, {bool applied = true}) =>
    BillingVerificationResult.fromJson({
      'ok': applied,
      'outcome': applied ? 'applied' : 'rejected',
      'entitlement_applied': applied,
      'has_access': applied,
      'acknowledgement': ack,
    });

void main() {
  test('catalog parsing is fail closed', () {
    final valid = GooglePlayCatalogEntry.tryParse(row());
    expect(valid, isNotNull);
    expect(valid!.plan, SubscriptionPlan.professional);
    expect(GooglePlayCatalogEntry.tryParse(row(plan: 'trial')), isNull);
    expect(GooglePlayCatalogEntry.tryParse(row(period: 'weekly')), isNull);
    expect(GooglePlayCatalogEntry.tryParse({...row(), 'account_binding': null}), isNull);
  });

  test('only server-mapped matching Play offers are purchasable', () {
    final entry = GooglePlayCatalogEntry.tryParse(row())!;
    expect(matchBillingOptions(const [], [offer()]), isEmpty);
    expect(matchBillingOptions([entry], [offer()]), hasLength(1));
    expect(matchBillingOptions([entry], [offer(period: 'P1Y')]), isEmpty);
    final otherPackage = GooglePlayCatalogEntry.tryParse(row(package: 'com.example.other'))!;
    expect(matchBillingOptions([otherPackage], [offer()]), isEmpty);
  });

  test('verification response cannot fail open', () {
    for (final raw in <Object?>[null, 'bad', 42, const <String, dynamic>{}, {'outcome': 'applied'}]) {
      final r = BillingVerificationResult.fromJson(raw);
      expect(r.applied, isFalse, reason: '$raw');
      expect(r.hasAccess, isFalse, reason: '$raw');
    }
  });

  test('store purchase only routes to server verification for matching org binding', () {
    expect(actionForStoreUpdate(StorePurchaseStatus.pending,
      purchaseAccountId: 'abc123', expectedAccountBinding: 'abc123'), StoreUpdateAction.showPending);
    expect(actionForStoreUpdate(StorePurchaseStatus.purchased,
      purchaseAccountId: 'abc123', expectedAccountBinding: 'abc123'), StoreUpdateAction.verifyWithServer);
    expect(actionForStoreUpdate(StorePurchaseStatus.restored,
      purchaseAccountId: 'other', expectedAccountBinding: 'abc123'), StoreUpdateAction.ignore);
  });

  test('client completes purchase only as fallback after server applied and ack failed', () {
    expect(shouldCompletePurchase(pendingCompletePurchase: true,
      server: verified('server_ack_failed')), isTrue);
    for (final ack in ['server_acknowledged', 'already_acknowledged', 'in_progress', 'not_required']) {
      expect(shouldCompletePurchase(pendingCompletePurchase: true, server: verified(ack)), isFalse);
    }
    expect(shouldCompletePurchase(pendingCompletePurchase: true,
      server: verified('server_ack_failed', applied: false)), isFalse);
  });

  test('second live Google Play or external-contract purchase is blocked', () {
    bool can(String? provider, bool access) => canStartPurchase(
      storeAvailable: true, canManageBilling: true, optionCount: 1,
      provider: provider, hasAccess: access);
    expect(can('google_play', true), isFalse);
    expect(can('external_contract', true), isFalse);
    expect(can('google_play', false), isTrue);
    expect(can('manual', true), isTrue);
  });
}
