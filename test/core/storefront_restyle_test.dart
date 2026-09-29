import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/notification/app_notification.dart';
import 'package:navy_wear/core/domain/model/shipping/courier.dart';
import 'package:navy_wear/features/seller_promotions/presentation/views/widgets/margin_protection_card.dart';
import 'package:navy_wear/features/seller_shipping/presentation/cubits/courier_cubit/courier_cubit.dart';

void main() {
  group('MarginSimulation (S-31)', () {
    test('reproduces the design example: 10% off Rp1.399.000, HPP 1.010.000',
        () {
      final sim = MarginSimulation.of(
        normalPrice: 1399000,
        cost: 1010000,
        discountValue: 10,
        discountIsPercent: true,
      );
      expect(sim.discount, 139900);
      expect(sim.buyerPrice, 1259100);
      expect(sim.commission, 62955);
      expect(sim.payout, 1196145);
      expect(sim.marginPercent!.toStringAsFixed(1), '18.4');
      expect(sim.isLoss, isFalse);
    });

    test('flags a loss when payout falls under cost', () {
      final sim = MarginSimulation.of(
        normalPrice: 100000,
        cost: 95000,
        discountValue: 10000,
        discountIsPercent: false,
        shippingSupport: 5000,
      );
      // 90.000 − 5.000 ongkir − 4.500 komisi = 80.500
      expect(sim.payout, 80500);
      expect(sim.isLoss, isTrue);
    });

    test('adds the product Growth rate on top of the platform commission', () {
      final sim = MarginSimulation.of(
        normalPrice: 200000,
        cost: 0,
        discountValue: 0,
        discountIsPercent: true,
        growthPercent: 3,
      );
      expect(sim.commission, 10000);
      expect(sim.growthCommission, 6000);
      expect(sim.payout, 184000);
      expect(sim.marginPercent, isNull, reason: 'no cost entered');
    });

    test('clamps a discount to the price and a percentage to 100', () {
      expect(
        MarginSimulation.of(
          normalPrice: 50000,
          cost: 0,
          discountValue: 250,
          discountIsPercent: true,
        ).buyerPrice,
        0,
      );
      expect(
        MarginSimulation.of(
          normalPrice: 50000,
          cost: 0,
          discountValue: 80000,
          discountIsPercent: false,
        ).discount,
        50000,
      );
    });
  });

  group('NotificationCategory (S-40)', () {
    test('groups the types the API raises today', () {
      expect(NotificationCategory.of('order_new'),
          NotificationCategory.operational);
      expect(NotificationCategory.of('staff_invitation'),
          NotificationCategory.operational);
      expect(NotificationCategory.of('maintenance_notice'),
          NotificationCategory.info);
    });

    test('puts deadlines and disputes first', () {
      expect(NotificationCategory.of('order_sla_warning'),
          NotificationCategory.critical);
      expect(NotificationCategory.of('refund_requested'),
          NotificationCategory.critical);
      expect(NotificationCategory.of('complaint_opened'),
          NotificationCategory.critical);
    });
  });

  group('CourierLoaded switches (S-24)', () {
    const all = <Courier>[
      Courier(code: 'jne', name: 'JNE'),
      Courier(code: 'jnt', name: 'J&T'),
      Courier(code: 'sicepat', name: 'SiCepat'),
    ];

    test('an empty whitelist reads as every courier on', () {
      const state = CourierLoaded(available: all, selectedCodes: <String>{});
      expect(all.every((c) => state.isOn(c.code)), isTrue);
      expect(state.activeCount, 3);
    });

    test('a whitelist turns the rest off', () {
      const state =
          CourierLoaded(available: all, selectedCodes: <String>{'jne'});
      expect(state.isOn('jne'), isTrue);
      expect(state.isOn('jnt'), isFalse);
      expect(state.activeCount, 1);
    });
  });
}
