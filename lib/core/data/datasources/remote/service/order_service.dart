import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/order/order.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// The store's orders, and the actions that move them along.
///
/// Two things shape everything here.
///
/// **Transitions are strict and their failure is unreadable.** `pack` and
/// `ship` each demand an exact starting status, and the backend throws an
/// uncaught exception when that is not met — which reaches the app as **HTTP
/// 200 carrying an HTML error page**, not a 422. So the caller must check
/// [Order.canPack] and friends *before* calling; these methods cannot
/// recover from being invoked at the wrong moment, only report the mess.
///
/// **Nothing here returns the updated order**, so every action re-reads it.
class OrderService extends BaseService {
  const OrderService(super.dio);

  /// One page of the store's orders, newest first. Capped at 20 with no `meta`,
  /// like every other list on this backend — a short page is the end.
  ///
  /// [status] filters server-side on an exact value; there is no "needs
  /// attention" filter, so a queue view has to ask for each status it wants.
  Future<List<Order>> getStoreOrders(
    int storeId, {
    String? status,
    int page = 1,
  }) async {
    final envelope = await getRequest(
      ApiEndpoints.storeOrders(storeId),
      query: <String, dynamic>{'status': status, 'page': page},
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return envelope.list.map(Order.fromJson).toList(growable: false);
  }

  /// The full order: items, status history, and the latest refund request —
  /// the only place the refund id needed by approve/reject can be found.
  Future<Order> getOrder(int orderId) async {
    final envelope = await getRequest(ApiEndpoints.order(orderId));
    return Order.fromJson(envelope.map);
  }

  /// `paid` -> `packed`. There is no accept step since API v1.6.0.
  ///
  /// Refused with `422 CUSTOM_CONFIRMATION_REQUIRED` while a custom order is
  /// unconfirmed, and `422 PARTIAL_FULFILLMENT_PENDING` while the buyer has
  /// not answered a partial-fulfilment proposal — [Order.canPack] gates both.
  Future<Order> pack(int orderId) async {
    await postRequest(ApiEndpoints.orderPack(orderId));
    return getOrder(orderId);
  }

  /// `packed` -> `shipped`, recording the courier, the airway bill and how the
  /// parcel is handed over. Returns the Secure+ seal code, or null for an
  /// ordinary order.
  ///
  /// Sent **form-encoded**: this endpoint reads its fields with the REST
  /// library's `post()`, which only ever looks at `$_POST` — a JSON body is
  /// parsed by nobody and the AWB would be stored as null while the order
  /// still moved to `shipped`, which is worse than an outright failure.
  ///
  /// [evidence] matters only on a Secure+ order, where the server demands at
  /// least one photo and one video (`422 SECURE_PLUS_EVIDENCE_REQUIRED`). The
  /// seller cannot tell in advance whether an order is Secure+ — nothing in
  /// the order payload says so — so the error is the signal.
  Future<String?> ship(
    int orderId, {
    required String courierCode,
    required String awbNumber,
    String handoverMethod = HandoverMethod.dropOff,
    List<ShipmentEvidence> evidence = const <ShipmentEvidence>[],
  }) async {
    final envelope = await postFormRequest(
      ApiEndpoints.orderShip(orderId),
      fields: <String, String>{
        'courier_code': courierCode,
        'awb_number': awbNumber,
        'handover_method': handoverMethod,
        for (var i = 0; i < evidence.length; i++) ...<String, String>{
          'evidence[$i][media_type]': evidence[i].mediaType,
          'evidence[$i][url]': evidence[i].url,
        },
      },
    );
    if (envelope.isNull) return null;
    return asStringOrNull(envelope.map['seal_code']);
  }

  /// Confirms a custom order can be made, and how long it will take.
  Future<Order> customConfirm(int orderId, {required int leadTimeDays}) async {
    await postFormRequest(
      ApiEndpoints.orderCustomConfirm(orderId),
      fields: <String, String>{'lead_time_days': '$leadTimeDays'},
    );
    return getOrder(orderId);
  }

  /// Proposes that some items cannot be fulfilled. Only from `paid`; packing
  /// is then blocked until the buyer continues or cancels.
  Future<Order> proposePartialFulfillment(
    int orderId, {
    required List<int> unavailableItemIds,
  }) async {
    await postFormRequest(
      ApiEndpoints.orderPartialPropose(orderId),
      fields: <String, String>{
        for (var i = 0; i < unavailableItemIds.length; i++)
          'unavailable_item_ids[$i]': '${unavailableItemIds[i]}',
      },
    );
    return getOrder(orderId);
  }

  /// `422 INVOICE_NOT_AVAILABLE` unless the order is completed.
  Future<OrderInvoice> getInvoice(int orderId) async {
    final envelope = await getRequest(ApiEndpoints.orderInvoice(orderId));
    return OrderInvoice.fromJson(envelope.map);
  }

  /// Only from `pending` or `paid` — once packed, an order cannot be cancelled
  /// this way. A paid order refunds the buyer's wallet automatically, and the
  /// cancellation is recorded as the seller's fault ("Tolak Pesanan").
  ///
  /// Form-encoded for the same reason as [ship]: `reason` is read with `post()`
  /// and would otherwise be lost, leaving a cancellation with no explanation in
  /// the status history.
  Future<Order> cancel(int orderId, {required String reason}) async {
    await postFormRequest(
      ApiEndpoints.orderCancel(orderId),
      fields: <String, String>{'reason': reason},
    );
    return getOrder(orderId);
  }

  /// Null until the order ships.
  Future<OrderShipment?> getTracking(int orderId) async {
    final envelope = await getRequest(ApiEndpoints.orderTracking(orderId));
    if (envelope.isNull) return null;
    return OrderShipment.fromJson(envelope.map);
  }

  /// Approving credits the buyer's wallet and moves the order to
  /// `refund_approved`.
  Future<Order> approveRefund(int orderId, int refundId) async {
    await postRequest(ApiEndpoints.refundApprove(orderId, refundId));
    return getOrder(orderId);
  }

  Future<Order> rejectRefund(int orderId, int refundId) async {
    await postRequest(ApiEndpoints.refundReject(orderId, refundId));
    return getOrder(orderId);
  }
}
