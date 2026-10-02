enum SubscriptionPlan { trial, starter, professional, business, enterprise }

enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  gracePeriod,
  canceled,
  expired,
}

class OrganizationSubscription {
  const OrganizationSubscription({
    required this.organizationId,
    required this.plan,
    required this.status,
    required this.hasAccess,
    required this.maxUsers,
    required this.maxSites,
    required this.maxMeters,
    this.currentPeriodEnd,
    this.gracePeriodEnd,
    this.features = const {},
  });
  final String organizationId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final bool hasAccess;
  final int maxUsers;
  final int maxSites;
  final int maxMeters;
  final DateTime? currentPeriodEnd;
  final DateTime? gracePeriodEnd;
  final Map<String, dynamic> features;
  bool hasFeature(String key) => features[key] == true;
  factory OrganizationSubscription.fromRpc(
    String organizationId,
    Map<String, dynamic> json,
  ) => OrganizationSubscription(
    organizationId: organizationId,
    plan: SubscriptionPlan.values.firstWhere(
      (v) => v.name == json['plan'],
      orElse: () => SubscriptionPlan.trial,
    ),
    status: _status(json['status'] as String?),
    hasAccess: json['has_access'] == true,
    maxUsers: (json['max_users'] as num?)?.toInt() ?? 0,
    maxSites: (json['max_sites'] as num?)?.toInt() ?? 0,
    maxMeters: (json['max_meters'] as num?)?.toInt() ?? 0,
    currentPeriodEnd: DateTime.tryParse('${json['current_period_end'] ?? ''}'),
    gracePeriodEnd: DateTime.tryParse('${json['grace_period_end'] ?? ''}'),
    features: Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
  );
  static SubscriptionStatus _status(String? v) => switch (v) {
    'active' => SubscriptionStatus.active,
    'past_due' => SubscriptionStatus.pastDue,
    'grace_period' => SubscriptionStatus.gracePeriod,
    'canceled' => SubscriptionStatus.canceled,
    'expired' => SubscriptionStatus.expired,
    _ => SubscriptionStatus.trialing,
  };
}
