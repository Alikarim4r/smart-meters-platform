/// Interpretive bands for plant efficiency metrics.
enum EfficiencyBand {
  excellent,
  good,
  fair,
  poor,
  critical,
}

extension EfficiencyBandMeta on EfficiencyBand {
  String labelEn(EfficiencyMetricKind kind) => switch (this) {
        EfficiencyBand.excellent =>
          kind == EfficiencyMetricKind.cop ? 'Excellent COP' : 'Excellent EER',
        EfficiencyBand.good =>
          kind == EfficiencyMetricKind.cop ? 'Good COP' : 'Good EER',
        EfficiencyBand.fair =>
          kind == EfficiencyMetricKind.cop ? 'Fair COP' : 'Fair EER',
        EfficiencyBand.poor =>
          kind == EfficiencyMetricKind.cop ? 'Low COP' : 'Low EER',
        EfficiencyBand.critical => kind == EfficiencyMetricKind.cop
            ? 'Critical COP'
            : 'Critical EER',
      };

  String labelAr(EfficiencyMetricKind kind) => switch (this) {
        EfficiencyBand.excellent =>
          kind == EfficiencyMetricKind.cop ? 'COP ممتاز' : 'EER ممتاز',
        EfficiencyBand.good =>
          kind == EfficiencyMetricKind.cop ? 'COP جيد' : 'EER جيد',
        EfficiencyBand.fair =>
          kind == EfficiencyMetricKind.cop ? 'COP مقبول' : 'EER مقبول',
        EfficiencyBand.poor =>
          kind == EfficiencyMetricKind.cop ? 'COP منخفض' : 'EER منخفض',
        EfficiencyBand.critical => kind == EfficiencyMetricKind.cop
            ? 'COP حرج'
            : 'EER حرج',
      };

  String meaningEn(EfficiencyMetricKind kind) => switch (this) {
        EfficiencyBand.excellent =>
          'High efficiency — cooling output is strong relative to electric input.',
        EfficiencyBand.good =>
          'Healthy plant efficiency for typical chiller operation.',
        EfficiencyBand.fair =>
          'Acceptable but watch trends; rising electric use may lower efficiency.',
        EfficiencyBand.poor =>
          'Below target — inspect chillers, pumps, and meter wiring.',
        EfficiencyBand.critical =>
          'Severely inefficient — urgent review of plant load and equipment.',
      };

  String meaningAr(EfficiencyMetricKind kind) => switch (this) {
        EfficiencyBand.excellent =>
          'كفاءة عالية — ناتج التبريد قوي مقارنة باستهلاك الكهرباء.',
        EfficiencyBand.good =>
          'كفاءة جيدة لمحطة التبريد في التشغيل الاعتيادي.',
        EfficiencyBand.fair =>
          'مقبول مع مراقبة الاتجاه؛ ارتفاع الكهرباء يضعف الكفاءة.',
        EfficiencyBand.poor =>
          'أقل من المستهدف — راجع الشيلرز والمضخات وربط العدادات.',
        EfficiencyBand.critical =>
          'كفاءة ضعيفة جداً — مراجعة عاجلة للحمل والمعدات.',
      };
}

enum EfficiencyMetricKind { cop, eer }

/// Classify COP (dimensionless). Defaults align with common chiller plants.
EfficiencyBand classifyCop(
  double value, {
  double warningThreshold = 2.5,
  double criticalThreshold = 2.0,
}) {
  if (value >= 4.5) return EfficiencyBand.excellent;
  if (value >= 3.5) return EfficiencyBand.good;
  if (value >= warningThreshold) return EfficiencyBand.fair;
  if (value >= criticalThreshold) return EfficiencyBand.poor;
  return EfficiencyBand.critical;
}

/// Classify EER (BTU/h per Watt). EER ≈ COP × 3.412.
EfficiencyBand classifyEer(
  double value, {
  double warningThreshold = 2.5,
  double criticalThreshold = 2.0,
}) {
  return classifyCop(
    value / 3.412,
    warningThreshold: warningThreshold,
    criticalThreshold: criticalThreshold,
  );
}
