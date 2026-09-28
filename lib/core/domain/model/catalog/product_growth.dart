import '../../../utils/json_parse.dart';

/// `GET /products/{id}/growth/performance` — Xpedia Growth's 7-day report
/// (API v1.20.0): the last seven days against the seven before, completed
/// orders only.
class GrowthPerformance {
  const GrowthPerformance({
    this.commissionPercent = 0,
    this.lockedUntil,
    this.isActive = false,
    this.current = const GrowthWindow(),
    this.previous = const GrowthWindow(),
  });

  final double commissionPercent;
  final DateTime? lockedUntil;
  final bool isActive;
  final GrowthWindow current;
  final GrowthWindow previous;

  factory GrowthPerformance.fromJson(Map<String, dynamic> json) =>
      GrowthPerformance(
        commissionPercent: asDouble(json['growth_commission_percent']),
        lockedUntil: asDateTime(json['growth_locked_until']),
        isActive: asBool(json['is_growth_active']),
        current: GrowthWindow.fromJson(asMap(json['current_window'])),
        previous: GrowthWindow.fromJson(asMap(json['previous_window'])),
      );
}

class GrowthWindow {
  const GrowthWindow({
    this.label = '',
    this.unitsSold = 0,
    this.revenue = 0,
    this.commissionCharged = 0,
  });

  final String label;
  final int unitsSold;
  final int revenue;
  final int commissionCharged;

  factory GrowthWindow.fromJson(Map<String, dynamic> json) => GrowthWindow(
        label: asString(json['label']),
        unitsSold: asInt(json['units_sold']),
        revenue: asInt(json['revenue']),
        commissionCharged: asInt(json['growth_commission_charged']),
      );
}

/// The Growth rules the server enforces (API v1.10.0).
abstract class GrowthRules {
  static const int maxPercent = 15;

  /// Turning Growth on needs a live Natural Performance score of at least 60.
  static const int minNaturalPerformance = 60;

  /// Every change — including switching off — locks the setting this long.
  static const Duration lock = Duration(days: 7);

  /// The ranking boost the server adds, `50 × (p / 15)^1.5`, max 50 points.
  static double boostPoints(double percent) {
    if (percent <= 0) return 0;
    final r = percent / maxPercent;
    return 50 * r * _sqrt(r);
  }

  static double _sqrt(double x) {
    var g = x;
    for (var i = 0; i < 20; i++) {
      g = 0.5 * (g + x / g);
    }
    return g;
  }
}

/// `product_shipping_coverage` (API v1.17.0): a per-product allow- or
/// deny-list of cities and provinces. `none` means unrestricted.
class ShippingCoverage {
  const ShippingCoverage({
    this.mode = CoverageMode.none,
    this.locations = const <CoverageLocation>[],
  });

  final String mode;
  final List<CoverageLocation> locations;

  /// The server stores one row per location with the mode repeated on each,
  /// and no rows at all for `none`.
  factory ShippingCoverage.fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const ShippingCoverage();
    return ShippingCoverage(
      mode: asString(rows.first['coverage_type'], fallback: CoverageMode.none),
      locations: rows.map(CoverageLocation.fromJson).toList(growable: false),
    );
  }

  bool get isRestricted => mode != CoverageMode.none && locations.isNotEmpty;
}

class CoverageLocation {
  const CoverageLocation({this.city, this.province});

  /// Exactly one of the two is set per row.
  final String? city;
  final String? province;

  factory CoverageLocation.fromJson(Map<String, dynamic> json) =>
      CoverageLocation(
        city: asStringOrNull(json['city']),
        province: asStringOrNull(json['province']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (city != null) 'city': city,
        if (province != null) 'province': province,
      };

  String get label => city ?? 'Prov. ${province ?? '-'}';

  @override
  bool operator ==(Object other) =>
      other is CoverageLocation &&
      other.city == city &&
      other.province == province;

  @override
  int get hashCode => Object.hash(city, province);
}

abstract class CoverageMode {
  static const String none = 'none';
  static const String include = 'include';
  static const String exclude = 'exclude';

  static String label(String mode) => switch (mode) {
        include => 'Hanya ke lokasi terpilih',
        exclude => 'Seluruh Indonesia, kecuali',
        _ => 'Seluruh Indonesia',
      };
}
