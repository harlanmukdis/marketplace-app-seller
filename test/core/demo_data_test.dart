import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/config/env/app_config.dart';
import 'package:navy_wear/core/data/demo/demo_account_security_repository.dart';
import 'package:navy_wear/core/data/demo/demo_order_case_repository.dart';
import 'package:navy_wear/core/data/demo/demo_product_extras_repository.dart';
import 'package:navy_wear/core/data/demo/demo_store_inbox_repository.dart';
import 'package:navy_wear/core/data/demo/demo_support.dart';
import 'package:navy_wear/core/data_state.dart';
import 'package:navy_wear/core/domain/model/catalog/product_extras.dart';
import 'package:navy_wear/core/domain/model/chat/store_conversation.dart';
import 'package:navy_wear/core/domain/model/order/order_case.dart';
import 'package:navy_wear/core/domain/model/performance/store_insights.dart';

/// Run twice: `flutter test` checks the default (API pending) behaviour, and
/// `flutter test --dart-define=DEMO_DATA=true` the sample-data flows.
void main() {
  group('demo switch', () {
    test('without DEMO_DATA every sample repository answers API_PENDING',
        () async {
      final result = await demoOr<int>('Fitur X', () => 1);
      if (AppConfig.demoData) {
        expect(result, isA<DataSuccess<int>>());
      } else {
        expect(result, isA<DataFailed<int>>());
        expect((result as DataFailed<int>).failure.isApiPending, isTrue);
        expect(result.failure.message, contains('Fitur X'));
      }
    });

    test('writes are refused without DEMO_DATA', () async {
      final error = await demoWrite('Fitur Y');
      expect(error?.isApiPending ?? false, !AppConfig.demoData);
    });

    test('an empty sample list reads as DataEmpty', () async {
      final result = await demoOr<List<int>>('Z', () => <int>[]);
      expect(
          result,
          AppConfig.demoData
              ? isA<DataEmpty<List<int>>>()
              : isA<DataFailed<List<int>>>());
    });
  });

  group('models', () {
    test('remainingLabel counts down and says when it has passed', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(
        remainingLabel(now.add(const Duration(hours: 18, minutes: 30)),
            now: now),
        'Sisa 18j 30m',
      );
      expect(remainingLabel(now.add(const Duration(minutes: 5)), now: now),
          'Sisa 5m');
      expect(remainingLabel(now.subtract(const Duration(minutes: 1)), now: now),
          'Lewat batas');
    });

    test('funnel percentages are relative to visits', () {
      const f = ConversionFunnel(steps: <FunnelStep>[
        FunnelStep(label: 'Kunjungan', count: 1000),
        FunnelStep(label: 'Dilihat', count: 500),
        FunnelStep(label: 'Dibayar', count: 40),
      ]);
      expect(f.visitors, 1000);
      expect(f.percentOf(f.steps[1]), 50);
      expect(f.conversion, 4);
    });

    test('Natural Performance gate is 60', () {
      expect(const NaturalPerformanceScore(score: 60).isEligible, isTrue);
      expect(const NaturalPerformanceScore(score: 59).isEligible, isFalse);
    });

    test('volumetric weight uses the 6000 divisor', () {
      const e = ProductExtras(lengthCm: 30, widthCm: 20, heightCm: 10);
      expect(e.volumetricGrams, 1000);
      expect(const ProductExtras().volumetricGrams, isNull);
    });

    test('cancellation total adds price × quantity', () {
      const c = CancellationRequest(
        id: 1,
        orderNumber: 'X',
        buyerName: 'D***',
        reason: 'r',
        items: <CaseItem>[
          CaseItem(name: 'a', price: 1000, quantity: 2),
          CaseItem(name: 'b', price: 500),
        ],
      );
      expect(c.total, 2500);
    });

    test('store conversation initials', () {
      const c =
          StoreConversation(id: 1, buyerName: 'A****** K****', lastMessage: '');
      expect(c.initials, 'AK');
    });
  });

  group('sample flows (DEMO_DATA=true)', () {
    test('a cancellation can be decided once', () async {
      final repo = DemoOrderCaseRepository();
      expect(await repo.respondCancellation(7101, approve: true), isNull);
      final again = await repo.respondCancellation(7101,
          approve: false,
          rejectReason: CancellationRequest.rejectReasons.first);
      expect(again?.code, DataErrorCode.invalidState);
      final read = await repo.getCancellationRequest(7101);
      expect((read as DataSuccess<CancellationRequest>).value.status,
          CaseStatus.approved);
    });

    test('refusing a cancellation needs a reason', () async {
      final error = await DemoOrderCaseRepository()
          .respondCancellation(7102, approve: false);
      expect(error?.code, DataErrorCode.validationError);
    });

    test('a complaint resolution maps to a status', () async {
      final repo = DemoOrderCaseRepository();
      await repo.resolveComplaint(8801, ComplaintResolution.escalate);
      final c = await repo.getComplaint(8801);
      expect((c as DataSuccess<Complaint>).value.status, CaseStatus.escalated);
    });

    test('wholesale tiers must get cheaper as quantity grows', () async {
      final error = await DemoProductExtrasRepository().saveExtras(
        1,
        const ProductExtras(wholesale: <WholesaleTier>[
          WholesaleTier(minQuantity: 5, unitPrice: 9000),
          WholesaleTier(minQuantity: 10, unitPrice: 9500),
        ]),
      );
      expect(error?.code, DataErrorCode.validationError);
    });

    test('a weak new password is refused before anything is sent', () async {
      final error = await DemoAccountSecurityRepository()
          .changePassword(current: 'x', next: 'abc');
      expect(error?.code, DataErrorCode.validationError);
    });

    test('the sample inbox carries unread counts', () async {
      final r = await const DemoStoreInboxRepository().getConversations(1);
      final list = (r as DataSuccess<List<StoreConversation>>).value;
      expect(list.where((c) => c.isUnread), isNotEmpty);
      expect(list.every((c) => c.isSample), isTrue);
    });
  },
      skip:
          AppConfig.demoData ? false : 'run with --dart-define=DEMO_DATA=true');
}
