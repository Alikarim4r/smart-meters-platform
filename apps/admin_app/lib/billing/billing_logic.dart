import 'package:smart_meters_core/smart_meters_core.dart';

/// Pure, plugin-free billing rules for the admin app's Google Play flow.
///
/// Invariants (see docs/regression/GOOGLE_PLAY_BILLING_V1.md):
/// * Entitlement is only ever read back from the server; a store
///   PurchaseStatus never unlocks anything.
/// * Only products present in the server catalog AND the Play store are
///   offered; anything ambiguous is hidden (fail closed).
/// * The server acknowledges purchases; the client acknowledges
///   (completePurchase) only when the server applied the purchase but its own
///   acknowledgement failed, so a purchase is never acknowledged twice.

/// Android package this app sells under. Server mapping rows for other
/// packages are ignored.
const String kAdminAppPackageName = 'com.smartmeters.admin_app';

enum BillingPeriod { monthly, annual }

/// One server-configured Play product/base plan with server-derived limits.
class GooglePlayCatalogEntry {
  const GooglePlayCatalogEntry({
    required this.packageName,
    required this.productId,
    required this.basePlanId,
    required this.plan,
    required this.billingPeriod,
    required this.displayOrder,
    required this.maxUsers,
    required this.maxSites,
    required this.maxMeters,
    required this.features,
    required this.accountBinding,
  });

  final String packageName;
  final String productId;
  final String basePlanId;
  final SubscriptionPlan plan;
  final BillingPeriod billingPeriod;
  final int displayOrder;
  final int maxUsers;
  final int maxSites;
  final int maxMeters;
  final Map<String, dynamic> features;

  /// Opaque per-org binding passed to Play as applicationUserName.
  final String accountBinding;

  /// Returns null for any malformed row so it is never offered.
  static GooglePlayCatalogEntry? tryParse(Map<String, dynamic> j) {
    final plan = SubscriptionPlan.values
        .where((p) => p.name == j['plan'] && p != SubscriptionPlan.trial)
        .firstOrNull;
    final period = switch (j['billing_period']) {
      'monthly' => BillingPeriod.monthly,
      'annual' => BillingPeriod.annual,
      _ => null,
    };
    final packageName = j['package_name'];
    final productId = j['product_id'];
    final basePlanId = j['base_plan_id'];
    final binding = j['account_binding'];
    final maxUsers = j['max_users'];
    final maxSites = j['max_sites'];
    final maxMeters = j['max_meters'];
    if (plan == null ||
        period == null ||
        packageName is! String ||
        productId is! String ||
        productId.isEmpty ||
        basePlanId is! String ||
        basePlanId.isEmpty ||
        binding is! String ||
        binding.isEmpty ||
        maxUsers is! num ||
        maxSites is! num ||
        maxMeters is! num) {
      return null;
    }
    return GooglePlayCatalogEntry(
      packageName: packageName,
      productId: productId,
      basePlanId: basePlanId,
      plan: plan,
      billingPeriod: period,
      displayOrder: (j['display_order'] as num?)?.toInt() ?? 0,
      maxUsers: maxUsers.toInt(),
      maxSites: maxSites.toInt(),
      maxMeters: maxMeters.toInt(),
      features: Map<String, dynamic>.from(j['features'] as Map? ?? const {}),
      accountBinding: binding,
    );
  }
}

/// A Play store offer (base plan or promotional offer), decoupled from the
/// plugin type so the rules are testable. [handle] is the plugin object.
class StoreOffer {
  const StoreOffer({
    required this.productId,
    required this.basePlanId,
    required this.offerId,
    required this.recurringPrice,
    required this.recurringPeriodIso,
    this.introPrice,
    this.introPeriodIso,
    this.introCycles = 0,
    this.handle,
  });

  final String productId;
  final String basePlanId;

  /// null for the base plan itself.
  final String? offerId;

  /// Localized price string from Play, e.g. "QAR 99.00".
  final String recurringPrice;

  /// ISO 8601 billing period of the recurring phase, e.g. P1M / P1Y.
  final String recurringPeriodIso;

  /// First phase price when an intro/free-trial phase precedes recurrence.
  final String? introPrice;
  final String? introPeriodIso;
  final int introCycles;
  final Object? handle;

  bool get hasIntro => introPrice != null;
}

/// A purchasable option: the server mapping matched with a store offer.
class BillingOption {
  const BillingOption({required this.entry, required this.offer});
  final GooglePlayCatalogEntry entry;
  final StoreOffer offer;

  String get key =>
      '${entry.productId}/${entry.basePlanId}/${offer.offerId ?? '-'}';
}

bool _periodMatches(BillingPeriod period, String iso) => switch (period) {
  BillingPeriod.monthly => iso == 'P1M' || iso == 'P4W',
  BillingPeriod.annual => iso == 'P1Y' || iso == 'P12M',
};

/// Intersects the server catalog with the store's offers. Store offers that
/// the server does not map, rows for other packages, and offers whose billing
/// period contradicts the server mapping are dropped.
List<BillingOption> matchBillingOptions(
  List<GooglePlayCatalogEntry> catalog,
  List<StoreOffer> offers, {
  String packageName = kAdminAppPackageName,
}) {
  final options = <BillingOption>[];
  for (final entry in catalog) {
    if (entry.packageName != packageName) continue;
    for (final offer in offers) {
      if (offer.productId == entry.productId &&
          offer.basePlanId == entry.basePlanId &&
          _periodMatches(entry.billingPeriod, offer.recurringPeriodIso)) {
        options.add(BillingOption(entry: entry, offer: offer));
      }
    }
  }
  options.sort((a, b) {
    final byOrder = a.entry.displayOrder.compareTo(b.entry.displayOrder);
    if (byOrder != 0) return byOrder;
    final byPlan = a.entry.plan.index.compareTo(b.entry.plan.index);
    if (byPlan != 0) return byPlan;
    final byPeriod = a.entry.billingPeriod.index.compareTo(
      b.entry.billingPeriod.index,
    );
    if (byPeriod != 0) return byPeriod;
    // Base plan before promotional offers.
    return (a.offer.offerId == null ? 0 : 1).compareTo(
      b.offer.offerId == null ? 0 : 1,
    );
  });
  return options;
}

/// Server acknowledgement result reported by the verify Edge Function.
enum ServerAcknowledgement {
  serverAcknowledged,
  alreadyAcknowledged,
  serverAckFailed,
  inProgress,
  notRequired,
  unknown,
}

/// Parsed google-play-verify response. Anything missing or unknown parses to
/// a non-entitled, non-applied result.
class BillingVerificationResult {
  const BillingVerificationResult({
    required this.ok,
    required this.outcome,
    required this.reason,
    required this.status,
    required this.plan,
    required this.hasAccess,
    required this.entitlementApplied,
    required this.acknowledgement,
  });

  final bool ok;

  /// applied | recorded | rejected | conflict | error | unknown
  final String outcome;
  final String? reason;
  final String? status;
  final String? plan;
  final bool hasAccess;
  final bool entitlementApplied;
  final ServerAcknowledgement acknowledgement;

  bool get applied => outcome == 'applied' && entitlementApplied;

  factory BillingVerificationResult.fromJson(Object? raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    const outcomes = {'applied', 'recorded', 'rejected', 'conflict', 'error'};
    final outcome = j['outcome'];
    return BillingVerificationResult(
      ok: j['ok'] == true,
      outcome: outcome is String && outcomes.contains(outcome)
          ? outcome
          : 'unknown',
      reason: j['reason'] is String ? j['reason'] as String : null,
      status: j['status'] is String ? j['status'] as String : null,
      plan: j['plan'] is String ? j['plan'] as String : null,
      hasAccess: j['has_access'] == true,
      entitlementApplied: j['entitlement_applied'] == true,
      acknowledgement: switch (j['acknowledgement']) {
        'server_acknowledged' => ServerAcknowledgement.serverAcknowledged,
        'already_acknowledged' => ServerAcknowledgement.alreadyAcknowledged,
        'server_ack_failed' => ServerAcknowledgement.serverAckFailed,
        'in_progress' => ServerAcknowledgement.inProgress,
        'not_required' => ServerAcknowledgement.notRequired,
        _ => ServerAcknowledgement.unknown,
      },
    );
  }
}

/// Store-side purchase status, decoupled from the plugin enum.
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

enum StoreUpdateAction { showPending, verifyWithServer, ignore, showStoreError }

/// What to do with a purchase update from the store. Purchases bound to a
/// different organization (different obfuscated account id) are ignored;
/// a missing id is still sent so the server can reject it explicitly.
StoreUpdateAction actionForStoreUpdate(
  StorePurchaseStatus status, {
  required String? purchaseAccountId,
  required String? expectedAccountBinding,
}) {
  switch (status) {
    case StorePurchaseStatus.pending:
      return StoreUpdateAction.showPending;
    case StorePurchaseStatus.canceled:
      return StoreUpdateAction.ignore;
    case StorePurchaseStatus.error:
      return StoreUpdateAction.showStoreError;
    case StorePurchaseStatus.purchased:
    case StorePurchaseStatus.restored:
      if (expectedAccountBinding == null) return StoreUpdateAction.ignore;
      if (purchaseAccountId != null &&
          purchaseAccountId != expectedAccountBinding) {
        return StoreUpdateAction.ignore;
      }
      return StoreUpdateAction.verifyWithServer;
  }
}

/// Whether the client must call completePurchase (which acknowledges on
/// Android). Only after the server verified and applied the purchase and its
/// own acknowledgement failed; never on store status alone, never twice.
bool shouldCompletePurchase({
  required bool pendingCompletePurchase,
  required BillingVerificationResult? server,
}) {
  if (!pendingCompletePurchase || server == null) return false;
  return server.applied &&
      server.acknowledgement == ServerAcknowledgement.serverAckFailed;
}

/// Buying is offered only on Android, with a configured catalog, for a caller
/// the server allowed to manage billing, and never while the org already has
/// a live Play subscription or a live external contract (the server would
/// reject the second purchase as a conflict).
bool canStartPurchase({
  required bool storeAvailable,
  required bool canManageBilling,
  required int optionCount,
  required String? provider,
  required bool hasAccess,
}) {
  if (!storeAvailable || !canManageBilling || optionCount == 0) return false;
  if (hasAccess &&
      (provider == 'google_play' || provider == 'external_contract')) {
    return false;
  }
  return true;
}
