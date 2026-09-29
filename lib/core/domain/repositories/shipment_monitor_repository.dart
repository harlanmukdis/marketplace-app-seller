import '../../data_state.dart';
import '../model/shipping/tracked_shipment.dart';

/// Parcels in transit and their scans (S-23). Implemented by
/// `DemoShipmentMonitorRepository` until couriers report scans to the API.
abstract class ShipmentMonitorRepository {
  Future<DataState<List<TrackedShipment>>> getShipments(int storeId);
}
