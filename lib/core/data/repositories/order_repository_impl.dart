import '../../data_state.dart';
import '../../domain/model/order/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/remote/service/order_service.dart';
import 'repository_guard.dart';

class OrderRepositoryImpl with RepositoryGuard implements OrderRepository {
  const OrderRepositoryImpl(this._service);

  final OrderService _service;

  @override
  Future<DataState<List<Order>>> getStoreOrders(
    int storeId, {
    String? status,
    int page = 1,
  }) =>
      guard(() => _service.getStoreOrders(storeId, status: status, page: page));

  @override
  Future<DataState<Order>> getOrder(int orderId) =>
      guard(() => _service.getOrder(orderId));

  @override
  Future<DataState<Order>> pack(int orderId) =>
      guard(() => _service.pack(orderId));

  @override
  Future<DataState<ShipOutcome>> ship(
    int orderId, {
    required String courierCode,
    required String awbNumber,
    String handoverMethod = HandoverMethod.dropOff,
    List<ShipmentEvidence> evidence = const <ShipmentEvidence>[],
  }) =>
      guard(() async => ShipOutcome(
            sealCode: await _service.ship(
              orderId,
              courierCode: courierCode,
              awbNumber: awbNumber,
              handoverMethod: handoverMethod,
              evidence: evidence,
            ),
          ));

  @override
  Future<DataState<Order>> customConfirm(
    int orderId, {
    required int leadTimeDays,
  }) =>
      guard(() => _service.customConfirm(orderId, leadTimeDays: leadTimeDays));

  @override
  Future<DataState<Order>> proposePartialFulfillment(
    int orderId, {
    required List<int> unavailableItemIds,
  }) =>
      guard(() => _service.proposePartialFulfillment(
            orderId,
            unavailableItemIds: unavailableItemIds,
          ));

  @override
  Future<DataState<OrderInvoice>> getInvoice(int orderId) =>
      guard(() => _service.getInvoice(orderId));

  @override
  Future<DataState<Order>> cancel(int orderId, {required String reason}) =>
      guard(() => _service.cancel(orderId, reason: reason));

  @override
  Future<DataState<OrderShipment>> getTracking(int orderId) async {
    final result = await guard(() => _service.getTracking(orderId));

    // Null means "not shipped yet", which is an empty state rather than a
    // success carrying nothing.
    return switch (result) {
      DataSuccess<OrderShipment?>(:final value) when value != null =>
        DataSuccess<OrderShipment>(value),
      DataFailed<OrderShipment?>(:final failure) =>
        DataFailed<OrderShipment>(failure),
      _ => const DataEmpty<OrderShipment>(),
    };
  }

  @override
  Future<DataState<Order>> approveRefund(int orderId, int refundId) =>
      guard(() => _service.approveRefund(orderId, refundId));

  @override
  Future<DataState<Order>> rejectRefund(int orderId, int refundId) =>
      guard(() => _service.rejectRefund(orderId, refundId));
}
