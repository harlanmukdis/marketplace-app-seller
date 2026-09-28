part of 'order_detail_cubit.dart';

sealed class OrderDetailState {
  const OrderDetailState();
}

final class OrderDetailInProgress extends OrderDetailState {
  const OrderDetailInProgress();
}

final class OrderDetailFailure extends OrderDetailState {
  const OrderDetailFailure(this.error);

  final DataError error;
}

final class OrderDetailLoaded extends OrderDetailState {
  const OrderDetailLoaded(
    this.order, {
    this.shipment,
    this.isBusy = false,
    this.sealCode,
    this.evidence = const <ShipmentEvidence>[],
  });

  final Order order;

  /// Fetched separately and only once the order has shipped; null otherwise.
  final OrderShipment? shipment;

  final bool isBusy;

  /// Returned once, by the ship call of a Secure+ order. The server keeps it
  /// but never hands it back to the seller, so it is shown when it arrives.
  final String? sealCode;

  /// Secure+ pre-handover proof, read once the order has shipped.
  final List<ShipmentEvidence> evidence;

  OrderDetailLoaded copyWith({
    Order? order,
    OrderShipment? shipment,
    bool? isBusy,
    List<ShipmentEvidence>? evidence,
  }) =>
      OrderDetailLoaded(
        order ?? this.order,
        shipment: shipment ?? this.shipment,
        isBusy: isBusy ?? this.isBusy,
        sealCode: sealCode,
        evidence: evidence ?? this.evidence,
      );
}
