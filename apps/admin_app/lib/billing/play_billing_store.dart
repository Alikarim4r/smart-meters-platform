import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'billing_logic.dart';

/// Thin Google Play adapter over in_app_purchase. Holds no entitlement logic:
/// it lists offers, launches purchases and reports store updates. Android
/// only; other platforms report the store as unavailable.
class PlayBillingStore {
  PlayBillingStore({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<List<PurchaseDetails>> get purchaseUpdates => _iap.purchaseStream;

  Future<bool> isAvailable() async =>
      isSupportedPlatform && await _iap.isAvailable();

  /// Queries Play for the given subscription products and flattens every base
  /// plan / offer into a [StoreOffer]. Unknown IDs are simply absent.
  Future<List<StoreOffer>> queryOffers(Set<String> productIds) async {
    if (productIds.isEmpty) return const [];
    final response = await _iap.queryProductDetails(productIds);
    final offers = <StoreOffer>[];
    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;
      final index = details.subscriptionIndex;
      final subOffers = details.productDetails.subscriptionOfferDetails;
      if (index == null || subOffers == null || index >= subOffers.length) {
        continue;
      }
      final offer = subOffers[index];
      final phases = offer.pricingPhases;
      if (phases.isEmpty) continue;
      final recurring = phases.last;
      if (recurring.recurrenceMode != RecurrenceMode.infiniteRecurring) {
        continue; // prepaid / installment plans are not sold in v1
      }
      final intro = phases.length > 1 ? phases.first : null;
      offers.add(
        StoreOffer(
          productId: details.id,
          basePlanId: offer.basePlanId,
          offerId: offer.offerId,
          recurringPrice: recurring.formattedPrice,
          recurringPeriodIso: recurring.billingPeriod,
          introPrice: intro?.formattedPrice,
          introPeriodIso: intro?.billingPeriod,
          introCycles: intro?.billingCycleCount ?? 0,
          handle: details,
        ),
      );
    }
    return offers;
  }

  /// Launches the Play purchase sheet bound to the organization's opaque
  /// account binding. Completion arrives on [purchaseUpdates].
  Future<bool> buy(BillingOption option) {
    final details = option.offer.handle;
    if (details is! GooglePlayProductDetails) return Future.value(false);
    return _iap.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: details,
        applicationUserName: option.entry.accountBinding,
        offerToken: details.offerToken,
      ),
    );
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  static StorePurchaseStatus statusOf(PurchaseDetails p) => switch (p.status) {
    PurchaseStatus.pending => StorePurchaseStatus.pending,
    PurchaseStatus.purchased => StorePurchaseStatus.purchased,
    PurchaseStatus.restored => StorePurchaseStatus.restored,
    PurchaseStatus.error => StorePurchaseStatus.error,
    PurchaseStatus.canceled => StorePurchaseStatus.canceled,
  };

  static String? accountIdOf(PurchaseDetails p) =>
      p is GooglePlayPurchaseDetails
      ? p.billingClientPurchase.obfuscatedAccountId
      : null;

  /// Play purchase token (the server verifies this, never the client).
  static String purchaseTokenOf(PurchaseDetails p) =>
      p.verificationData.serverVerificationData;
}
