import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/data_state.dart';
import 'package:navy_wear/core/domain/model/catalog/product.dart';
import 'package:navy_wear/core/domain/model/catalog/product_growth.dart';
import 'package:navy_wear/features/seller_catalog/presentation/product_errors.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  Map<String, dynamic> listRow() => <String, dynamic>{
        'id': '20',
        'store_id': '13',
        'name': 'Probe PO',
        'base_price': '50000.00',
        'status': 'draft',
        'fulfillment_mode': 'pre_order',
        'fulfillment_lead_time_days': '7',
        'growth_commission_percent': '0.00',
        'growth_locked_until': null,
      };

  group('Product — Xpedia fields', () {
    test('a list row carries the mode but no availability', () {
      final p = Product.fromJson(listRow());

      expect(p.fulfillmentMode, FulfillmentMode.preOrder);
      expect(p.fulfillmentLeadTimeDays, 7);
      expect(p.availability, isNull);
      expect(p.stockMode, FulfillmentMode.preOrder);
      expect(p.isGrowthActive, isFalse);
    });

    test('the detail availability overrides the mode for the chip', () {
      final p = Product.fromJson(listRow()
        ..['fulfillment_mode'] = 'ready_stock'
        ..['availability'] = 'low_stock'
        ..['stock'] = 4);

      expect(p.fulfillmentMode, FulfillmentMode.readyStock);
      expect(p.stockMode, StockMode.lowStock);
    });

    test('a pre-v1.7.0 row with no mode reads as ready stock', () {
      final p = Product.fromJson(listRow()..remove('fulfillment_mode'));

      expect(p.fulfillmentMode, FulfillmentMode.readyStock);
    });

    test('growth lock is judged against the given clock', () {
      final p = Product.fromJson(listRow()
        ..['growth_commission_percent'] = '5.00'
        ..['growth_locked_until'] = '2026-10-05 22:27:21');

      expect(p.isGrowthActive, isTrue);
      expect(p.isGrowthLockedAt(DateTime(2026, 10, 1)), isTrue);
      expect(p.isGrowthLockedAt(DateTime(2026, 10, 6)), isFalse);
    });

    test('only pre-order and custom order need a lead time', () {
      expect(FulfillmentMode.needsLeadTime(FulfillmentMode.preOrder), isTrue);
      expect(
          FulfillmentMode.needsLeadTime(FulfillmentMode.customOrder), isTrue);
      expect(
          FulfillmentMode.needsLeadTime(FulfillmentMode.readyStock), isFalse);
      expect(FulfillmentMode.needsLeadTime(FulfillmentMode.infinite), isFalse);
    });

    test('there are seven distinct stock chips', () {
      final labels = <String>{
        for (final m in <String>[
          ...FulfillmentMode.settable,
          StockMode.lowStock,
          StockMode.outOfStock,
        ])
          StockMode.label(m),
      };
      expect(labels, hasLength(7));
      expect(StockMode.label(FulfillmentMode.preOrder, leadTimeDays: 7),
          'Pre-Order (7 hari)');
    });
  });

  group('GrowthPerformance', () {
    test('reads the 7-day report', () {
      final g = GrowthPerformance.fromJson(<String, dynamic>{
        'growth_commission_percent': 0,
        'growth_locked_until': '2026-10-05 22:27:21',
        'is_growth_active': false,
        'current_window': <String, dynamic>{
          'label': '7 hari terakhir',
          'units_sold': 3,
          'revenue': 150000,
          'growth_commission_charged': 7500,
        },
        'previous_window': <String, dynamic>{
          'label': '7 hari sebelumnya',
          'units_sold': 0,
          'revenue': 0,
          'growth_commission_charged': 0,
        },
      });

      expect(g.isActive, isFalse);
      expect(g.lockedUntil, DateTime(2026, 10, 5, 22, 27, 21));
      expect(g.current.unitsSold, 3);
      expect(g.current.commissionCharged, 7500);
      expect(g.previous.revenue, 0);
    });

    test('the ranking boost follows 50 × (p/15)^1.5', () {
      expect(GrowthRules.boostPoints(0), 0);
      expect(GrowthRules.boostPoints(15), closeTo(50, 0.001));
      expect(GrowthRules.boostPoints(10), closeTo(27.2166, 0.001));
    });
  });

  group('ShippingCoverage', () {
    test('rebuilds mode and locations from the stored rows', () {
      final c = ShippingCoverage.fromRows(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': '1',
          'product_id': '20',
          'coverage_type': 'exclude',
          'city': 'Jayapura',
          'province': null,
        },
        <String, dynamic>{
          'id': '2',
          'product_id': '20',
          'coverage_type': 'exclude',
          'city': null,
          'province': 'Maluku',
        },
      ]);

      expect(c.mode, CoverageMode.exclude);
      expect(c.isRestricted, isTrue);
      expect(c.locations.map((l) => l.label), <String>['Jayapura', 'Prov. Maluku']);
      expect(c.locations.last.toJson(), <String, dynamic>{'province': 'Maluku'});
    });

    test('no rows means unrestricted', () {
      final c = ShippingCoverage.fromRows(const <Map<String, dynamic>>[]);

      expect(c.mode, CoverageMode.none);
      expect(c.isRestricted, isFalse);
    });
  });

  group('explainProductError', () {
    test('fills in codes the server sends without a message', () {
      final e = explainProductError(const DataError(
        code: 'RESTRICTION_REVIEW_PENDING',
        message: 'RESTRICTION_REVIEW_PENDING',
      ));

      expect(e.message, contains('moderasi'));
      expect(e.code, 'RESTRICTION_REVIEW_PENDING');
    });

    test("keeps the server's unlock time on GROWTH_LOCKED", () {
      const server = 'Setting Growth produk ini masih terkunci sampai '
          '2026-10-05 22:27:21';
      final e = explainProductError(
          const DataError(code: 'GROWTH_LOCKED', message: server));

      expect(e.message, server);
    });

    test('leaves other errors alone', () {
      const original = DataError(code: 'VALIDATION_ERROR', message: 'x');

      expect(identical(explainProductError(original), original), isTrue);
    });
  });
}
