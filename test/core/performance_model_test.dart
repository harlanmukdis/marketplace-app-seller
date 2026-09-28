import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/order/order.dart';
import 'package:navy_wear/core/domain/model/performance/store_performance.dart';
import 'package:navy_wear/features/seller_performance/presentation/cubits/performance_cubit.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  test('reads partners-performance for a store with no activity', () {
    final p = PartnersPerformance.fromJson(<String, dynamic>{
      'rating': <String, dynamic>{
        'average': 0,
        'total_reviews': 0,
        'distribution': <dynamic>[
          <String, dynamic>{'rating': 5, 'count': 0},
          <String, dynamic>{'rating': 1, 'count': 0},
        ],
      },
      'order_performance': <String, dynamic>{
        'total_orders': 0,
        'completed_orders': 0,
        'cancelled_orders': 0,
        'success_rate_percent': 0,
        'cancellation_rate_percent': 0,
      },
      'service_performance': <String, dynamic>{
        'response_rate_percent': null,
        'avg_reply_minutes': null,
        'operating_hours': null,
        'online_status': null,
      },
      'live_performance': <String, dynamic>{
        'total_sessions': 0,
        'total_live_minutes': 0,
        'average_viewers': 0,
        'checkout_from_live': null,
      },
    });

    expect(p.rating.totalReviews, 0);
    expect(p.rating.countOf(3), 0);
    // Null means "no buyer has written yet", which must not read as 0%.
    expect(p.service.responseRate, isNull);
    expect(p.service.avgReplyMinutes, isNull);
    expect(p.service.operatingHours, isEmpty);
    expect(p.live.minutes, 0);
  });

  test('reads a health score row and a tier row', () {
    final h = HealthScore.fromJson(<String, dynamic>{
      'period_date': '2026-09-28',
      'rating_component': '90.00',
      'delivery_speed_component': '80.00',
      'cancellation_component': '100.00',
      'return_rate_component': '95.00',
      'response_time_component': '70.00',
      'composite_score': '87.50',
    });
    expect(h.composite, 87.5);
    expect(h.date, DateTime(2026, 9, 28));

    final t = SellerTier.fromJson(<String, dynamic>{
      'seller_tier_id': '2',
      'effective_from': '2026-09-01',
      'code': 'silver',
      'name': 'Silver Seller',
    });
    expect(t.name, 'Silver Seller');
  });

  test('reads customer segmentation', () {
    final s = CustomerSegmentation.fromJson(<String, dynamic>{
      'loyal_customer_min_orders': 2,
      'new_customers': 3,
      'loyal_customers': 1,
      'total_customers': 4,
    });
    expect(s.total, 4);
    expect(s.loyalMinOrders, 2);
  });

  group('AnalyticsSnapshot.figures', () {
    Order completedAt(DateTime t, int subtotal) => Order.fromJson(
          <String, dynamic>{
            'id': '${t.millisecondsSinceEpoch}',
            'order_number': 'X',
            'status': 'completed',
            'subtotal': '$subtotal.00',
            'grand_total': '$subtotal.00',
            'created_at': '${t.year}-${t.month.toString().padLeft(2, '0')}-'
                '${t.day.toString().padLeft(2, '0')} 10:00:00',
          },
        );

    test('this month against last month, completed orders only', () {
      final s = AnalyticsSnapshot(
        loading: false,
        period: AnalyticsPeriod.month,
        completed: <Order>[
          completedAt(DateTime(2026, 9, 3), 100000),
          completedAt(DateTime(2026, 9, 20), 50000),
          completedAt(DateTime(2026, 8, 15), 60000),
        ],
      );
      final (now, before) = s.figures(now: DateTime(2026, 9, 29));

      expect(now.gmv, 150000);
      expect(now.orders, 2);
      expect(now.averageOrder, 75000);
      expect(before.gmv, 60000);
    });

    test('the last 7 days include today and exclude the 8th day back', () {
      final s = AnalyticsSnapshot(
        loading: false,
        period: AnalyticsPeriod.week,
        completed: <Order>[
          completedAt(DateTime(2026, 9, 29), 10000),
          completedAt(DateTime(2026, 9, 23), 20000),
          completedAt(DateTime(2026, 9, 22), 40000),
        ],
      );
      final (now, before) = s.figures(now: DateTime(2026, 9, 29, 15));

      expect(now.gmv, 30000);
      expect(before.gmv, 40000);
    });
  });
}
