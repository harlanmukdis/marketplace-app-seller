import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/order/order.dart';

/// Payloads captured from the running marketplace API.
void main() {
  Map<String, dynamic> row({String status = 'pending'}) => <String, dynamic>{
        'id': '135',
        'order_number': 'ORD-20260915-0001',
        'checkout_session_id': 'ca9128bd-dd10-4c45-bf01-b95e0c31eddc',
        'buyer_id': '9',
        'store_id': '1',
        'warehouse_id': '1',
        'status': status,
        'subtotal': '75000.00',
        'shipping_cost': '17000.00',
        'discount_total': '0.00',
        'grand_total': '92000.00',
        'courier_code': null,
        'courier_service': null,
        'tracking_number': null,
        // Since API v1.6.0 a seller receives only the destination city and
        // province, already decoded — never the buyer's name or street.
        'shipping_address': <String, dynamic>{
          'city': 'Jakarta Selatan',
          'province': 'DKI Jakarta',
        },
        'requires_custom_confirmation': '0',
        'custom_confirmed_at': null,
        'estimated_lead_time_days': null,
        'partial_fulfillment_proposed_at': null,
        'partial_fulfillment_decision': null,
        'payment_deadline': '2026-09-16 22:38:21',
        'created_at': '2026-09-15 22:38:21',
      };

  group('Order.fromJson', () {
    test('reads a list row', () {
      final order = Order.fromJson(row());

      expect(order.id, 135);
      expect(order.orderNumber, 'ORD-20260915-0001');
      expect(order.grandTotal, 92000);
      expect(order.shippingCost, 17000);
      expect(order.trackingNumber, isNull);
      // The list payload carries no items — that is not "an order with nothing
      // in it".
      expect(order.items, isEmpty);
    });

    test('reads the masked destination, and nothing that identifies the buyer',
        () {
      final order = Order.fromJson(row());

      expect(order.shippingCity, 'Jakarta Selatan');
      expect(order.shippingProvince, 'DKI Jakarta');
      expect(order.shippingAddress.keys, <String>['city', 'province']);
    });

    test('still reads the pre-v1.6.0 JSON-string snapshot', () {
      final json = row()
        ..remove('shipping_address')
        ..['shipping_address_snapshot'] = '{"city":"Bandung"}';

      expect(Order.fromJson(json).shippingCity, 'Bandung');
    });

    test('a null masked address reads as empty, not as a crash', () {
      final json = row()..['shipping_address'] = null;

      expect(Order.fromJson(json).shippingCity, isEmpty);
    });

    test('reads items, history and the refund from the detail payload', () {
      final order = Order.fromJson(row(status: 'refund_requested')
        ..addAll(<String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'id': '135',
              'product_variant_id': '1',
              'product_name_snapshot': 'Kopi Arabika Gayo 250g',
              'variant_options_snapshot': '{"ukuran":"250g"}',
              'price_snapshot': '75000.00',
              'quantity': '2',
              'subtotal': '150000.00',
            },
          ],
          'status_history': <dynamic>[
            <String, dynamic>{
              'id': '149',
              'from_status': null,
              'to_status': 'pending',
              'notes': null,
              'created_at': '2026-09-15 22:38:21',
            },
          ],
          'refund': <String, dynamic>{
            'id': '7',
            'amount': '92000.00',
            'reason': 'Barang tidak sesuai',
            'status': 'requested',
          },
        }));

      expect(order.items.single.productName, 'Kopi Arabika Gayo 250g');
      expect(order.items.single.optionsLabel, '250g');
      expect(order.itemCount, 2);
      expect(order.statusHistory.single.fromStatus, isNull);
      // The refund id lives here and nowhere else the seller can reach.
      expect(order.refund!.id, 7);
      expect(order.refund!.amount, 92000);
      expect(order.canResolveRefund, isTrue);
    });
  });

  group('Order action gating', () {
    // The server answers an out-of-order transition with HTTP 200 and an HTML
    // exception page, so these flags are the only thing standing between a
    // seller and an unreadable failure.
    test('a pending order can only be cancelled', () {
      final order = Order.fromJson(row(status: 'pending'));

      expect(order.isAwaitingPayment, isTrue);
      expect(order.canPack, isFalse);
      expect(order.canShip, isFalse);
      expect(order.canPrintWaybill, isFalse);
      expect(order.canCancel, isTrue);
      expect(order.needsAction, isFalse);
    });

    test('a paid order goes straight to Cetak Resi — there is no accept step',
        () {
      final order = Order.fromJson(row(status: 'paid'));

      expect(order.canPack, isTrue);
      expect(order.canPrintWaybill, isTrue);
      expect(order.canShip, isFalse);
      // "Tolak Pesanan" is still open while the order is only paid.
      expect(order.canCancel, isTrue);
      expect(order.needsAction, isTrue);
    });

    test('packed resumes Cetak Resi at ship, and can no longer be rejected',
        () {
      final packed = Order.fromJson(row(status: 'packed'));

      expect(packed.canShip, isTrue);
      expect(packed.canPack, isFalse);
      expect(packed.canPrintWaybill, isTrue);
      expect(packed.canCancel, isFalse);
    });

    test('an order left processed by the old accept flow is stuck', () {
      // The server's only transition out of `processed` was the removed one.
      final order = Order.fromJson(row(status: 'processed'));

      expect(order.canPack, isFalse);
      expect(order.canPrintWaybill, isFalse);
      expect(order.canCancel, isFalse);
    });

    test('an unconfirmed custom order must be confirmed before packing', () {
      final order = Order.fromJson(
          row(status: 'paid')..['requires_custom_confirmation'] = '1');

      expect(order.canCustomConfirm, isTrue);
      expect(order.canPack, isFalse);
      expect(order.needsAction, isTrue);

      final confirmed = Order.fromJson(row(status: 'paid')
        ..['requires_custom_confirmation'] = '1'
        ..['custom_confirmed_at'] = '2026-09-26 10:00:00');
      expect(confirmed.canCustomConfirm, isFalse);
      expect(confirmed.canPack, isTrue);
    });

    test('a pending partial-fulfilment proposal holds packing', () {
      final order = Order.fromJson(row(status: 'paid')
        ..['partial_fulfillment_proposed_at'] = '2026-09-26 10:00:00');

      expect(order.awaitsPartialDecision, isTrue);
      expect(order.canPack, isFalse);
    });

    test('a shipped order leaves nothing for the seller to do', () {
      final order = Order.fromJson(row(status: 'shipped'));

      expect(order.needsAction, isFalse);
      expect(order.canPrintWaybill, isFalse);
      expect(order.canCancel, isFalse);
    });

    test('only a completed order has a Final Invoice', () {
      expect(Order.fromJson(row(status: 'delivered')).hasInvoice, isFalse);
      expect(Order.fromJson(row(status: 'completed')).hasInvoice, isTrue);
    });

    test('a refund with no refund row cannot be resolved', () {
      // refund_requested but the payload carried no refund object — approve and
      // reject both need an id that is not there.
      final order = Order.fromJson(row(status: 'refund_requested'));

      expect(order.refund, isNull);
      expect(order.canResolveRefund, isFalse);
    });
  });

  group('Settlement', () {
    test('estimates 5% commission on the grand total before completion', () {
      final order = Order.fromJson(row(status: 'paid'));
      final s = order.effectiveSettlement;

      expect(s.isEstimate, isTrue);
      expect(s.grossMerchandiseValue, 75000);
      expect(s.platformCommission, 4600);
      expect(s.netSellerRevenue, 92000 - 4600);
      expect(s.growthCommission, 0);
    });

    test("uses the server's row once the order completes", () {
      final order = Order.fromJson(row(status: 'completed')
        ..['settlement'] = <String, dynamic>{
          'gross_merchandise_value': '75000.00',
          'shipping_support_seller': '5000.00',
          'platform_commission': '4600.00',
          'growth_commission': '750.00',
          'service_adjustment': '0.00',
          'net_seller_revenue': '86650.00',
        });
      final s = order.effectiveSettlement;

      expect(s.isEstimate, isFalse);
      expect(s.shippingSupportSeller, 5000);
      expect(s.growthCommission, 750);
      expect(s.netSellerRevenue, 86650);
    });
  });

  group('OrderSla', () {
    Order paidAt(DateTime at) => Order.fromJson(row(status: 'paid')
      ..['status_history'] = <dynamic>[
        <String, dynamic>{
          'id': '1',
          'from_status': 'pending',
          'to_status': 'paid',
          'created_at': formatForTest(at),
        },
      ]);

    test('counts 48 plain hours from payment', () {
      final paid = DateTime(2026, 9, 26, 10);
      final order = paidAt(paid);

      expect(OrderSla.deadlineFor(order), DateTime(2026, 9, 28, 10));
      expect(
        OrderSla.remaining(order, now: DateTime(2026, 9, 28, 3)),
        const Duration(hours: 7),
      );
    });

    test('has no deadline once shipped, or without a payment record', () {
      expect(OrderSla.deadlineFor(Order.fromJson(row(status: 'shipped'))),
          isNull);
      expect(OrderSla.deadlineFor(Order.fromJson(row(status: 'paid'))), isNull);
    });

    test('formats the countdown the way the chip reads', () {
      expect(OrderSla.format(const Duration(hours: 6, minutes: 45)),
          '6 jam 45 mnt');
      expect(OrderSla.format(const Duration(hours: 30)), '1 hari 6 jam');
      expect(OrderSla.format(const Duration(minutes: -1)), 'lewat batas');
    });
  });

  group('OrderShipment.fromJson', () {
    test('reads the shipment row', () {
      final shipment = OrderShipment.fromJson(<String, dynamic>{
        'id': '3',
        'order_id': '135',
        'courier_code': 'jne',
        'service_type': 'reguler',
        'awb_number': 'JNE1234567890',
        'status': 'picked_up',
        'shipped_at': '2026-09-15 23:10:00',
      });

      expect(shipment.awbNumber, 'JNE1234567890');
      expect(shipment.serviceType, 'reguler');
      expect(shipment.shippedAt, DateTime(2026, 9, 15, 23, 10));
    });
  });
}

String formatForTest(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
