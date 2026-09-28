import '../../data_state.dart';
import '../model/order/order.dart';

/// The store's orders and the actions that move them along.
///
/// Every action returns the order as it stands afterwards, because none of the
/// endpoints answer with one. Callers must still check the `can*` flags on
/// [Order] first: an out-of-order transition fails in a way the API cannot
/// report properly.
abstract class OrderRepository {
  Future<DataState<List<Order>>> getStoreOrders(
    int storeId, {
    String? status,
    int page,
  });

  Future<DataState<Order>> getOrder(int orderId);

  Future<DataState<Order>> pack(int orderId);

  /// Carries the Secure+ seal code when there is one; re-read the order after.
  Future<DataState<ShipOutcome>> ship(
    int orderId, {
    required String courierCode,
    required String awbNumber,
    String handoverMethod,
    List<ShipmentEvidence> evidence,
  });

  Future<DataState<Order>> customConfirm(
    int orderId, {
    required int leadTimeDays,
  });

  Future<DataState<Order>> proposePartialFulfillment(
    int orderId, {
    required List<int> unavailableItemIds,
  });

  Future<DataState<OrderInvoice>> getInvoice(int orderId);

  Future<DataState<Order>> cancel(int orderId, {required String reason});

  /// [DataEmpty] until the order ships.
  Future<DataState<OrderShipment>> getTracking(int orderId);

  Future<DataState<Order>> approveRefund(int orderId, int refundId);

  Future<DataState<Order>> rejectRefund(int orderId, int refundId);
}

class ShipOutcome {
  const ShipOutcome({this.sealCode});

  /// Generated for a Secure+ order and sent to the buyer, who must enter it to
  /// confirm delivery. Null for an ordinary order.
  final String? sealCode;
}
