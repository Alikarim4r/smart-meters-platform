/// Selected efficiency metric on the BTU / energy tab (not a chart type).
enum EfficiencyMetric {
  cop,
  eer,
}

extension EfficiencyMetricMeta on EfficiencyMetric {
  String get labelEn => switch (this) {
        EfficiencyMetric.cop => 'COP',
        EfficiencyMetric.eer => 'EER',
      };

  String get labelAr => switch (this) {
        EfficiencyMetric.cop => 'COP',
        EfficiencyMetric.eer => 'EER',
      };

  String get unitLabel => switch (this) {
        EfficiencyMetric.cop => 'COP',
        EfficiencyMetric.eer => 'EER',
      };

  String get subtitleEn => switch (this) {
        EfficiencyMetric.cop =>
          'Cooling capacity ÷ electric power (same units)',
        EfficiencyMetric.eer => 'Cooling BTU/hr ÷ electric Watts',
      };

  String get subtitleAr => switch (this) {
        EfficiencyMetric.cop =>
          'سعة التبريد ÷ القدرة الكهربائية (نفس الوحدات)',
        EfficiencyMetric.eer => 'التبريد BTU/hr ÷ القدرة الكهربائية بالواط',
      };
}
