import 'subscription.dart';

class SubscriptionPlanCatalogItem {
  const SubscriptionPlanCatalogItem({
    required this.plan,
    required this.maxUsers,
    required this.maxSites,
    required this.maxMeters,
    required this.features,
    this.monthlyPriceQar,
    this.annualPriceQar,
    this.trialDays = 0,
    this.isRecommended = false,
  });
  final SubscriptionPlan plan;
  final int? monthlyPriceQar;
  final int? annualPriceQar;
  final int trialDays;
  final int maxUsers;
  final int maxSites;
  final int maxMeters;
  final bool isRecommended;
  final Map<String, dynamic> features;
  factory SubscriptionPlanCatalogItem.fromJson(Map<String, dynamic> j) =>
      SubscriptionPlanCatalogItem(
        plan: SubscriptionPlan.values.firstWhere((v) => v.name == j['plan']),
        monthlyPriceQar: (j['monthly_price_qar'] as num?)?.toInt(),
        annualPriceQar: (j['annual_price_qar'] as num?)?.toInt(),
        trialDays: (j['trial_days'] as num?)?.toInt() ?? 0,
        maxUsers: (j['max_users'] as num).toInt(),
        maxSites: (j['max_sites'] as num).toInt(),
        maxMeters: (j['max_meters'] as num).toInt(),
        isRecommended: j['is_recommended'] == true,
        features: Map<String, dynamic>.from(j['features'] as Map? ?? const {}),
      );
}

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.activeUsers,
    required this.activeSites,
    required this.activeMeters,
  });
  final int activeUsers;
  final int activeSites;
  final int activeMeters;
}
