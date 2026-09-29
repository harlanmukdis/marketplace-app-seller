/// A parcel on its way, with the courier's scans (S-23).
///
/// ⏳ The API tracks one row per shipment and never writes `in_transit`:
/// there is no courier integration and no scan history. This is the shape
/// S-23 needs once there is.
class TrackedShipment {
  const TrackedShipment({
    required this.awb,
    required this.courier,
    required this.orderNumber,
    required this.state,
    required this.checkpoints,
    this.orderId,
    this.destinationCity,
    this.buyerName,
    this.receivedBy,
    this.isSample = false,
  });

  final String awb;

  /// Display name with service, e.g. "JNE Regular".
  final String courier;
  final int? orderId;
  final String orderNumber;

  /// [ShipmentState].
  final String state;
  final String? destinationCity;
  final String? buyerName;
  final String? receivedBy;

  /// Newest first.
  final List<ShipmentCheckpoint> checkpoints;
  final bool isSample;

  ShipmentCheckpoint? get last =>
      checkpoints.isEmpty ? null : checkpoints.first;

  /// The courier company, for the filter chips.
  String get courierCompany => courier.split(' ').first;
}

class ShipmentCheckpoint {
  const ShipmentCheckpoint({
    required this.location,
    required this.description,
    this.at,
  });

  final String location;
  final String description;
  final DateTime? at;
}

abstract class ShipmentState {
  static const String inTransit = 'in_transit';
  static const String problem = 'problem';
  static const String delivered = 'delivered';

  static String label(String s) => switch (s) {
        inTransit => 'Dalam Pengiriman',
        problem => 'Kendala Pengantaran',
        delivered => 'Diterima',
        _ => s,
      };
}
