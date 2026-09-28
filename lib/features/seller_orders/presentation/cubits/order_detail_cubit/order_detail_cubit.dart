import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/order/order.dart';
import '../../../../../core/domain/repositories/order_repository.dart';
import '../../../../../di/injector.dart';

part 'order_detail_state.dart';

/// One order, and the seller's moves on it.
///
/// Every action checks the order's own `can*` flag first and refuses locally
/// rather than letting the server decide. That is not defensive politeness: an
/// out-of-order transition comes back as **HTTP 200 with an HTML exception
/// page**, which no error handler can turn into something a seller would
/// understand.
class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit(this.orderId) : super(const OrderDetailInProgress());

  static OrderDetailCubit get(BuildContext context) => BlocProvider.of(context);

  final int orderId;

  final OrderRepository _orders = injector<OrderRepository>();

  Future<void> load() async {
    if (isClosed) return;
    emit(const OrderDetailInProgress());

    final result = await _orders.getOrder(orderId);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<Order>(:final value):
        emit(OrderDetailLoaded(value));
        await _loadTracking();
      case DataFailed<Order>(:final failure):
        emit(OrderDetailFailure(failure));
      default:
        emit(const OrderDetailFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Pesanan tidak ditemukan.',
          ),
        ));
    }
  }

  /// Only worth asking once the order has actually shipped — before that the
  /// endpoint answers null, and a null tracking row is not news.
  Future<void> _loadTracking() async {
    final current = state;
    if (current is! OrderDetailLoaded) return;
    if (current.order.status != OrderStatus.shipped &&
        current.order.status != OrderStatus.delivered) {
      return;
    }

    final result = await _orders.getTracking(orderId);
    if (isClosed) return;
    if (result is DataSuccess<OrderShipment>) {
      final latest = state;
      if (latest is OrderDetailLoaded) {
        emit(latest.copyWith(shipment: result.value));
      }
    }
  }

  /// "Cetak Resi" — the seller's one commitment on an order.
  ///
  /// The API still has two transitions behind it, `paid` -> `packed` and
  /// `packed` -> `shipped`, so this runs whichever are left. If pack succeeds
  /// and ship fails, the order is left `packed` and the next attempt resumes
  /// at ship; the error is returned so the sheet can stay open with the input.
  ///
  /// Returns the failure, or null; a Secure+ seal code lands in
  /// [OrderDetailLoaded.sealCode].
  Future<DataError?> printWaybill({
    required String courierCode,
    required String awbNumber,
    required String handoverMethod,
    List<ShipmentEvidence> evidence = const <ShipmentEvidence>[],
  }) async {
    final current = state;
    if (current is! OrderDetailLoaded) return null;
    final order = current.order;

    if (!order.canPrintWaybill) {
      return DataError(
        code: 'ORDER_STATE_INVALID',
        message: order.awaitsCustomConfirmation
            ? 'Konfirmasi custom order dulu sebelum mencetak resi.'
            : order.awaitsPartialDecision
                ? 'Menunggu keputusan pembeli atas pemenuhan sebagian.'
                : 'Resi hanya bisa dicetak untuk pesanan yang sedang diproses.',
        details: <String, dynamic>{'status': order.status},
      );
    }

    emit(current.copyWith(isBusy: true));

    if (order.canPack) {
      final packed = await _orders.pack(orderId);
      if (isClosed) return null;
      if (packed is DataFailed<Order>) {
        emit(current.copyWith(isBusy: false));
        return packed.failure;
      }
    }

    final shipped = await _orders.ship(
      orderId,
      courierCode: courierCode,
      awbNumber: awbNumber,
      handoverMethod: handoverMethod,
      evidence: evidence,
    );
    if (isClosed) return null;

    final refreshed = await _orders.getOrder(orderId);
    if (isClosed) return null;
    final latest = refreshed is DataSuccess<Order> ? refreshed.value : order;

    switch (shipped) {
      case DataFailed<ShipOutcome>(:final failure):
        emit(OrderDetailLoaded(latest, shipment: current.shipment));
        return failure;
      case DataSuccess<ShipOutcome>(:final value):
        emit(OrderDetailLoaded(latest, sealCode: value.sealCode));
        await _loadTracking();
        return null;
      default:
        emit(OrderDetailLoaded(latest));
        await _loadTracking();
        return null;
    }
  }

  Future<DataError?> customConfirm(int leadTimeDays) => _act(
        guard: (order) => order.canCustomConfirm,
        refusal: 'Pesanan ini tidak menunggu konfirmasi custom order.',
        action: () =>
            _orders.customConfirm(orderId, leadTimeDays: leadTimeDays),
      );

  Future<DataError?> proposePartial(List<int> unavailableItemIds) => _act(
        guard: (order) => order.canProposePartial,
        refusal: 'Pemenuhan sebagian hanya bisa diajukan sekali, saat '
            'pesanan masih diproses.',
        action: () => _orders.proposePartialFulfillment(
          orderId,
          unavailableItemIds: unavailableItemIds,
        ),
      );

  /// "Tolak Pesanan". Recorded as the seller's fault and counted against the
  /// store's performance score.
  Future<DataError?> cancel(String reason) => _act(
        guard: (order) => order.canCancel,
        refusal: 'Pesanan yang sudah dikemas tidak bisa ditolak lagi.',
        action: () => _orders.cancel(orderId, reason: reason),
      );

  Future<DataError?> resolveRefund({required bool approve}) => _act(
        guard: (order) => order.canResolveRefund,
        refusal: 'Tidak ada pengajuan refund yang menunggu keputusan.',
        action: () {
          final current = state as OrderDetailLoaded;
          final refundId = current.order.refund!.id;
          return approve
              ? _orders.approveRefund(orderId, refundId)
              : _orders.rejectRefund(orderId, refundId);
        },
      );

  Future<DataError?> _act({
    required bool Function(Order order) guard,
    required String refusal,
    required Future<DataState<Order>> Function() action,
  }) async {
    final current = state;
    if (current is! OrderDetailLoaded) return null;

    if (!guard(current.order)) {
      return DataError(
        code: 'ORDER_STATE_INVALID',
        message: refusal,
        details: <String, dynamic>{'status': current.order.status},
      );
    }

    emit(current.copyWith(isBusy: true));
    final result = await action();
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<Order>(:final value):
        emit(OrderDetailLoaded(value, shipment: current.shipment));
        await _loadTracking();
        return null;
      case DataFailed<Order>(:final failure):
        emit(current.copyWith(isBusy: false));
        return failure;
      default:
        emit(current.copyWith(isBusy: false));
        await load();
        return null;
    }
  }
}
