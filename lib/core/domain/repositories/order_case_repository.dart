import '../../data_state.dart';
import '../model/order/order_case.dart';

/// Cancellation requests (S-18) and complaints (S-19) raised by buyers.
///
/// Implemented by `DemoOrderCaseRepository` until the backend has them.
abstract class OrderCaseRepository {
  Future<DataState<List<CancellationRequest>>> getCancellationRequests(
      int storeId);

  Future<DataState<List<Complaint>>> getComplaints(int storeId);

  Future<DataState<CancellationRequest>> getCancellationRequest(int id);

  Future<DataState<Complaint>> getComplaint(int id);

  /// [rejectReason] is required when [approve] is false — one of
  /// [CancellationRequest.rejectReasons].
  Future<DataError?> respondCancellation(
    int id, {
    required bool approve,
    String? rejectReason,
  });

  Future<DataError?> resolveComplaint(int id, ComplaintResolution resolution);
}
