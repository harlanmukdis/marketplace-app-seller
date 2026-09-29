/// Analytics the API cannot produce yet (S-33): visitor funnel, traffic
/// sources, best sellers. `store_analytics_daily` is never filled and
/// `sold_count` never incremented, so all three wait on the backend.
class FunnelStep {
  const FunnelStep({required this.label, required this.count});

  final String label;
  final int count;
}

class ConversionFunnel {
  const ConversionFunnel({required this.steps, this.bestCategory});

  /// Visit → product viewed → cart → checkout → paid, in order.
  final List<FunnelStep> steps;
  final String? bestCategory;

  int get visitors => steps.isEmpty ? 0 : steps.first.count;

  double percentOf(FunnelStep step) =>
      visitors == 0 ? 0 : step.count * 100 / visitors;

  /// Paid orders over visitors.
  double get conversion => steps.isEmpty ? 0 : percentOf(steps.last);
}

class TrafficSource {
  const TrafficSource({required this.label, required this.percent});

  final String label;
  final double percent;
}

class TopProduct {
  const TopProduct({
    required this.name,
    required this.unitsSold,
    required this.revenue,
    this.productId,
  });

  final int? productId;
  final String name;
  final int unitsSold;
  final int revenue;
}

/// Natural Performance — the ≥60 gate on Xpedia Growth (S-32). The API
/// enforces it (`NATURAL_PERFORMANCE_TOO_LOW`) but never reports the score.
class NaturalPerformanceScore {
  const NaturalPerformanceScore({
    required this.score,
    this.threshold = 60,
    this.components = const <(String, int)>[],
  });

  final int score;
  final int threshold;

  /// (label, points) that add up to [score].
  final List<(String, int)> components;

  bool get isEligible => score >= threshold;
}

/// A product's place in the curation queue (S-28).
class ProductModeration {
  const ProductModeration({
    required this.sku,
    required this.productName,
    required this.category,
    required this.state,
    this.productId,
    this.issueTitle,
    this.issueDetail,
    this.submittedAt,
    this.decidedAt,
    this.estimatedDoneAt,
  });

  final int? productId;
  final String sku;
  final String productName;
  final String category;

  /// [ModerationState].
  final String state;
  final String? issueTitle;
  final String? issueDetail;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final DateTime? estimatedDoneAt;
}

abstract class ModerationState {
  static const String needsFix = 'needs_fix';
  static const String rejected = 'rejected';
  static const String inReview = 'in_review';
  static const String approved = 'approved';

  static String label(String s) => switch (s) {
        needsFix => 'Perlu Perbaikan',
        rejected => 'Ditolak',
        inReview => 'Sedang Ditinjau',
        approved => 'Disetujui',
        _ => s,
      };
}

/// "Aktif 7 Hari" vs "Aktif Terus" on a Growth setting (S-32).
enum GrowthDuration {
  sevenDays('Aktif 7 Hari'),
  alwaysOn('Aktif Terus');

  const GrowthDuration(this.label);

  final String label;
}

/// S-32's projection table: the next 7 days without and with Growth.
class GrowthProjection {
  const GrowthProjection({required this.rows});

  /// (metric, sublabel, without, with). Values already formatted.
  final List<(String, String, String, String, String)> rows;
}
