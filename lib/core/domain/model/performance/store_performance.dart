import '../../../utils/json_parse.dart';

/// `GET /stores/{id}/partners-performance` (API v1.13.0) — four blocks in a
/// fixed order: rating, order, service, live. All **lifetime** totals: the
/// endpoint takes no period, so the design's month picker has nothing to drive.
class PartnersPerformance {
  const PartnersPerformance({
    this.rating = const PerformanceRating(),
    this.orders = const OrderPerformance(),
    this.service = const ServicePerformance(),
    this.live = const LivePerformance(),
  });

  final PerformanceRating rating;
  final OrderPerformance orders;
  final ServicePerformance service;
  final LivePerformance live;

  factory PartnersPerformance.fromJson(Map<String, dynamic> json) =>
      PartnersPerformance(
        rating: PerformanceRating.fromJson(asMap(json['rating'])),
        orders: OrderPerformance.fromJson(asMap(json['order_performance'])),
        service:
            ServicePerformance.fromJson(asMap(json['service_performance'])),
        live: LivePerformance.fromJson(asMap(json['live_performance'])),
      );
}

/// Recomputed from published product reviews — deliberately not
/// `stores.rating_avg`, which comes from a separate store-rating form.
class PerformanceRating {
  const PerformanceRating({
    this.average = 0,
    this.totalReviews = 0,
    this.distribution = const <int, int>{},
  });

  final double average;
  final int totalReviews;

  /// Star (5..1) -> count.
  final Map<int, int> distribution;

  factory PerformanceRating.fromJson(Map<String, dynamic> json) =>
      PerformanceRating(
        average: asDouble(json['average']),
        totalReviews: asInt(json['total_reviews']),
        distribution: <int, int>{
          for (final row in asMapList(json['distribution']))
            asInt(row['rating']): asInt(row['count']),
        },
      );

  int countOf(int star) => distribution[star] ?? 0;
}

class OrderPerformance {
  const OrderPerformance({
    this.total = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.successRate = 0,
    this.cancellationRate = 0,
  });

  final int total;
  final int completed;
  final int cancelled;

  /// Completed / all orders, in percent. Note the server divides by *all*
  /// orders, not by completed + seller-caused failures as the blueprint asks.
  final double successRate;
  final double cancellationRate;

  factory OrderPerformance.fromJson(Map<String, dynamic> json) =>
      OrderPerformance(
        total: asInt(json['total_orders']),
        completed: asInt(json['completed_orders']),
        cancelled: asInt(json['cancelled_orders']),
        successRate: asDouble(json['success_rate_percent']),
        cancellationRate: asDouble(json['cancellation_rate_percent']),
      );
}

class ServicePerformance {
  const ServicePerformance({
    this.responseRate,
    this.avgReplyMinutes,
    this.operatingHours = const <String, dynamic>{},
  });

  /// Null when no buyer has written yet — "no data", not 0%.
  final double? responseRate;
  final double? avgReplyMinutes;
  final Map<String, dynamic> operatingHours;

  factory ServicePerformance.fromJson(Map<String, dynamic> json) =>
      ServicePerformance(
        responseRate: json['response_rate_percent'] == null
            ? null
            : asDouble(json['response_rate_percent']),
        avgReplyMinutes: json['avg_reply_minutes'] == null
            ? null
            : asDouble(json['avg_reply_minutes']),
        operatingHours: asEncodedMap(json['operating_hours']),
      );
}

class LivePerformance {
  const LivePerformance({
    this.sessions = 0,
    this.minutes = 0,
    this.averageViewers = 0,
  });

  final int sessions;
  final int minutes;
  final double averageViewers;

  factory LivePerformance.fromJson(Map<String, dynamic> json) =>
      LivePerformance(
        sessions: asInt(json['total_sessions']),
        minutes: asInt(json['total_live_minutes']),
        averageViewers: asDouble(json['average_viewers']),
      );
}

/// `GET /stores/{id}/tier` — null until the nightly evaluation assigns one.
class SellerTier {
  const SellerTier({required this.code, required this.name, this.since});

  final String code;
  final String name;
  final DateTime? since;

  factory SellerTier.fromJson(Map<String, dynamic> json) => SellerTier(
        code: asString(json['code']),
        name: asString(json['name']),
        since: asDateTime(json['effective_from']),
      );
}

/// One day of `seller_health_scores` — a 0–100 composite and its parts.
class HealthScore {
  const HealthScore({
    required this.date,
    this.composite = 0,
    this.rating = 0,
    this.deliverySpeed = 0,
    this.cancellation = 0,
    this.returnRate = 0,
    this.responseTime = 0,
  });

  final DateTime? date;
  final double composite;
  final double rating;
  final double deliverySpeed;
  final double cancellation;
  final double returnRate;
  final double responseTime;

  factory HealthScore.fromJson(Map<String, dynamic> json) => HealthScore(
        date: asDateTime(json['period_date']),
        composite: asDouble(json['composite_score']),
        rating: asDouble(json['rating_component']),
        deliverySpeed: asDouble(json['delivery_speed_component']),
        cancellation: asDouble(json['cancellation_component']),
        returnRate: asDouble(json['return_rate_component']),
        responseTime: asDouble(json['response_time_component']),
      );
}

/// `GET /stores/{id}/customer-segmentation` (API v1.25.0), from completed
/// orders only.
class CustomerSegmentation {
  const CustomerSegmentation({
    this.newCustomers = 0,
    this.loyalCustomers = 0,
    this.loyalMinOrders = 2,
  });

  final int newCustomers;
  final int loyalCustomers;

  /// Completed orders a buyer needs with this store to count as loyal.
  final int loyalMinOrders;

  int get total => newCustomers + loyalCustomers;

  factory CustomerSegmentation.fromJson(Map<String, dynamic> json) =>
      CustomerSegmentation(
        newCustomers: asInt(json['new_customers']),
        loyalCustomers: asInt(json['loyal_customers']),
        loyalMinOrders:
            asInt(json['loyal_customer_min_orders'], fallback: 2),
      );
}

/// A checkout that failed because the stock shown to the buyer was not there
/// at reservation (API v1.22.0). Informational — no automatic scoring.
class StockMismatchEvent {
  const StockMismatchEvent({
    required this.id,
    required this.productName,
    this.warehouseName,
    this.requested = 0,
    this.available = 0,
    this.createdAt,
  });

  final int id;
  final String productName;

  /// Null means no warehouse held any stock of the variant at all.
  final String? warehouseName;
  final int requested;
  final int available;
  final DateTime? createdAt;

  factory StockMismatchEvent.fromJson(Map<String, dynamic> json) =>
      StockMismatchEvent(
        id: asInt(json['id']),
        productName: asString(json['product_name']),
        warehouseName: asStringOrNull(json['warehouse_name']),
        requested: asInt(json['requested_quantity']),
        available: asInt(json['available_quantity']),
        createdAt: asCreatedDate(json),
      );
}
