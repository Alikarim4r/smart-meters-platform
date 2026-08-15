/// Standard ≥12 unit definitions per meter category code.
/// Used to seed `meter_units` when Staging still has the default 4-unit set.
class ExpandedUnitSpec {
  const ExpandedUnitSpec({
    required this.code,
    required this.nameEn,
    this.nameAr,
    required this.unitToBaseFactor,
    this.isBase = false,
    required this.sortOrder,
  });

  final String code;
  final String nameEn;
  final String? nameAr;
  final double unitToBaseFactor;
  final bool isBase;
  final int sortOrder;
}

class ExpandedUnitCatalog {
  static List<ExpandedUnitSpec> forCategoryCode(String code) {
    switch (code.trim().toLowerCase()) {
      case 'water':
        return _water;
      case 'electricity':
        return _electricity;
      case 'btu':
        return _btu;
      case 'fuel':
        return _fuel;
      default:
        return const [];
    }
  }

  static const _water = <ExpandedUnitSpec>[
    ExpandedUnitSpec(
      code: 'm3',
      nameEn: 'Cubic metre (m³)',
      nameAr: 'متر مكعب',
      unitToBaseFactor: 1,
      isBase: true,
      sortOrder: 1,
    ),
    ExpandedUnitSpec(
      code: 'liter',
      nameEn: 'Litre',
      nameAr: 'لتر',
      unitToBaseFactor: 0.001,
      sortOrder: 2,
    ),
    ExpandedUnitSpec(
      code: 'dm3',
      nameEn: 'Cubic decimetre (dm³)',
      nameAr: 'دسيمتر مكعب',
      unitToBaseFactor: 0.001,
      sortOrder: 3,
    ),
    ExpandedUnitSpec(
      code: 'gallon',
      nameEn: 'US gallon',
      nameAr: 'غالون أمريكي',
      unitToBaseFactor: 0.00378541,
      sortOrder: 4,
    ),
    ExpandedUnitSpec(
      code: 'ml',
      nameEn: 'Millilitre',
      nameAr: 'مليلتر',
      unitToBaseFactor: 0.000001,
      sortOrder: 10,
    ),
    ExpandedUnitSpec(
      code: 'cm3',
      nameEn: 'Cubic centimetre (cm³)',
      nameAr: 'سنتيمتر مكعب',
      unitToBaseFactor: 0.000001,
      sortOrder: 11,
    ),
    ExpandedUnitSpec(
      code: 'gal_imp',
      nameEn: 'Imperial gallon',
      nameAr: 'غالون إمبراطوري',
      unitToBaseFactor: 0.00454609,
      sortOrder: 12,
    ),
    ExpandedUnitSpec(
      code: 'ft3',
      nameEn: 'Cubic foot (ft³)',
      nameAr: 'قدم مكعب',
      unitToBaseFactor: 0.0283168466,
      sortOrder: 13,
    ),
    ExpandedUnitSpec(
      code: 'yd3',
      nameEn: 'Cubic yard (yd³)',
      nameAr: 'ياردة مكعبة',
      unitToBaseFactor: 0.764554858,
      sortOrder: 14,
    ),
    ExpandedUnitSpec(
      code: 'bbl',
      nameEn: 'Oil barrel (bbl)',
      nameAr: 'برميل نفطي',
      unitToBaseFactor: 0.1589872949,
      sortOrder: 15,
    ),
    ExpandedUnitSpec(
      code: 'acre_ft',
      nameEn: 'Acre-foot',
      nameAr: 'قدم فدان',
      unitToBaseFactor: 1233.4818375,
      sortOrder: 16,
    ),
    ExpandedUnitSpec(
      code: 'megalitre',
      nameEn: 'Megalitre (ML)',
      nameAr: 'ميغا لتر',
      unitToBaseFactor: 1000,
      sortOrder: 17,
    ),
  ];

  static const _electricity = <ExpandedUnitSpec>[
    ExpandedUnitSpec(
      code: 'kwh',
      nameEn: 'Kilowatt-hour (kWh)',
      nameAr: 'كيلوواط ساعة',
      unitToBaseFactor: 1,
      isBase: true,
      sortOrder: 1,
    ),
    ExpandedUnitSpec(
      code: 'mwh',
      nameEn: 'Megawatt-hour (MWh)',
      nameAr: 'ميجاواط ساعة',
      unitToBaseFactor: 1000,
      sortOrder: 2,
    ),
    ExpandedUnitSpec(
      code: 'wh',
      nameEn: 'Watt-hour (Wh)',
      nameAr: 'واط ساعة',
      unitToBaseFactor: 0.001,
      sortOrder: 3,
    ),
    ExpandedUnitSpec(
      code: 'kvah',
      nameEn: 'Kilovolt-ampere-hour (kVAh)',
      nameAr: 'كيلوفولت أمبير ساعة',
      unitToBaseFactor: 1,
      sortOrder: 4,
    ),
    ExpandedUnitSpec(
      code: 'gwh',
      nameEn: 'Gigawatt-hour (GWh)',
      nameAr: 'غيغاواط ساعة',
      unitToBaseFactor: 1000000,
      sortOrder: 10,
    ),
    ExpandedUnitSpec(
      code: 'j',
      nameEn: 'Joule',
      nameAr: 'جول',
      unitToBaseFactor: 0.0000000002777777778,
      sortOrder: 11,
    ),
    ExpandedUnitSpec(
      code: 'kj',
      nameEn: 'Kilojoule',
      nameAr: 'كيلوجول',
      unitToBaseFactor: 0.000277777778,
      sortOrder: 12,
    ),
    ExpandedUnitSpec(
      code: 'mj',
      nameEn: 'Megajoule',
      nameAr: 'ميغاجول',
      unitToBaseFactor: 0.277777778,
      sortOrder: 13,
    ),
    ExpandedUnitSpec(
      code: 'gj',
      nameEn: 'Gigajoule',
      nameAr: 'غيغاجول',
      unitToBaseFactor: 277.777778,
      sortOrder: 14,
    ),
    ExpandedUnitSpec(
      code: 'kcal',
      nameEn: 'Kilocalorie',
      nameAr: 'كيلوكالوري',
      unitToBaseFactor: 0.001163,
      sortOrder: 15,
    ),
    ExpandedUnitSpec(
      code: 'mvah',
      nameEn: 'Megavolt-ampere-hour (MVAh)',
      nameAr: 'ميغافولت أمبير ساعة',
      unitToBaseFactor: 1000,
      sortOrder: 16,
    ),
    ExpandedUnitSpec(
      code: 'therm',
      nameEn: 'Therm',
      nameAr: 'ثرم',
      unitToBaseFactor: 29.307107,
      sortOrder: 17,
    ),
  ];

  static const _btu = <ExpandedUnitSpec>[
    ExpandedUnitSpec(
      code: 'kwh_thermal',
      nameEn: 'Kilowatt-hour thermal',
      nameAr: 'كيلوواط حراري',
      unitToBaseFactor: 1,
      isBase: true,
      sortOrder: 1,
    ),
    ExpandedUnitSpec(
      code: 'btu',
      nameEn: 'BTU',
      nameAr: 'وحدة حرارية',
      unitToBaseFactor: 0.000293071,
      sortOrder: 2,
    ),
    ExpandedUnitSpec(
      code: 'ton_hour',
      nameEn: 'Ton-hour',
      nameAr: 'طن ساعة',
      unitToBaseFactor: 3.51685,
      sortOrder: 3,
    ),
    ExpandedUnitSpec(
      code: 'rt_hour',
      nameEn: 'RT-hour',
      nameAr: 'طن تبريد ساعة',
      unitToBaseFactor: 3.51685,
      sortOrder: 4,
    ),
    ExpandedUnitSpec(
      code: 'gj',
      nameEn: 'Gigajoule',
      nameAr: 'غيغاجول',
      unitToBaseFactor: 277.777778,
      sortOrder: 5,
    ),
    ExpandedUnitSpec(
      code: 'mj',
      nameEn: 'Megajoule',
      nameAr: 'ميغاجول',
      unitToBaseFactor: 0.277777778,
      sortOrder: 10,
    ),
    ExpandedUnitSpec(
      code: 'kbtu',
      nameEn: 'Thousand BTU (kBTU)',
      nameAr: 'ألف وحدة حرارية',
      unitToBaseFactor: 0.29307107,
      sortOrder: 11,
    ),
    ExpandedUnitSpec(
      code: 'mmbtu',
      nameEn: 'Million BTU (MMBtu)',
      nameAr: 'مليون وحدة حرارية',
      unitToBaseFactor: 293.07107,
      sortOrder: 12,
    ),
    ExpandedUnitSpec(
      code: 'therm',
      nameEn: 'Therm',
      nameAr: 'ثرم',
      unitToBaseFactor: 29.307107,
      sortOrder: 13,
    ),
    ExpandedUnitSpec(
      code: 'wh_thermal',
      nameEn: 'Watt-hour thermal',
      nameAr: 'واط ساعة حراري',
      unitToBaseFactor: 0.001,
      sortOrder: 14,
    ),
    ExpandedUnitSpec(
      code: 'kcal',
      nameEn: 'Kilocalorie',
      nameAr: 'كيلوكالوري',
      unitToBaseFactor: 0.001163,
      sortOrder: 15,
    ),
    ExpandedUnitSpec(
      code: 'j',
      nameEn: 'Joule',
      nameAr: 'جول',
      unitToBaseFactor: 0.0000000002777777778,
      sortOrder: 16,
    ),
    ExpandedUnitSpec(
      code: 'kj',
      nameEn: 'Kilojoule',
      nameAr: 'كيلوجول',
      unitToBaseFactor: 0.000277777778,
      sortOrder: 17,
    ),
  ];

  static const _fuel = <ExpandedUnitSpec>[
    ExpandedUnitSpec(
      code: 'liter',
      nameEn: 'Litre',
      nameAr: 'لتر',
      unitToBaseFactor: 1,
      isBase: true,
      sortOrder: 1,
    ),
    ExpandedUnitSpec(
      code: 'gallon',
      nameEn: 'US gallon',
      nameAr: 'غالون أمريكي',
      unitToBaseFactor: 3.78541,
      sortOrder: 2,
    ),
    ExpandedUnitSpec(
      code: 'm3',
      nameEn: 'Cubic metre (m³)',
      nameAr: 'متر مكعب',
      unitToBaseFactor: 1000,
      sortOrder: 3,
    ),
    ExpandedUnitSpec(
      code: 'ml',
      nameEn: 'Millilitre',
      nameAr: 'مليلتر',
      unitToBaseFactor: 0.001,
      sortOrder: 10,
    ),
    ExpandedUnitSpec(
      code: 'dm3',
      nameEn: 'Cubic decimetre (dm³)',
      nameAr: 'دسيمتر مكعب',
      unitToBaseFactor: 1,
      sortOrder: 11,
    ),
    ExpandedUnitSpec(
      code: 'gal_imp',
      nameEn: 'Imperial gallon',
      nameAr: 'غالون إمبراطوري',
      unitToBaseFactor: 4.54609,
      sortOrder: 12,
    ),
    ExpandedUnitSpec(
      code: 'ft3',
      nameEn: 'Cubic foot (ft³)',
      nameAr: 'قدم مكعب',
      unitToBaseFactor: 28.3168466,
      sortOrder: 13,
    ),
    ExpandedUnitSpec(
      code: 'bbl',
      nameEn: 'Oil barrel (bbl)',
      nameAr: 'برميل نفطي',
      unitToBaseFactor: 158.9872949,
      sortOrder: 14,
    ),
    ExpandedUnitSpec(
      code: 'us_pint',
      nameEn: 'US pint',
      nameAr: 'باينت أمريكي',
      unitToBaseFactor: 0.473176473,
      sortOrder: 15,
    ),
    ExpandedUnitSpec(
      code: 'us_quart',
      nameEn: 'US quart',
      nameAr: 'كوارت أمريكي',
      unitToBaseFactor: 0.946352946,
      sortOrder: 16,
    ),
    ExpandedUnitSpec(
      code: 'hectolitre',
      nameEn: 'Hectolitre',
      nameAr: 'هكتولتر',
      unitToBaseFactor: 100,
      sortOrder: 17,
    ),
    ExpandedUnitSpec(
      code: 'imperial_pint',
      nameEn: 'Imperial pint',
      nameAr: 'باينت إمبراطوري',
      unitToBaseFactor: 0.56826125,
      sortOrder: 18,
    ),
  ];
}
