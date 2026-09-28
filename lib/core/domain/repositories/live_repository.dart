import '../../data_state.dart';
import '../model/live/live_session.dart';

abstract class LiveRepository {
  /// The API cannot list a store's sessions, so these are the ones created
  /// from this device, remembered locally per store.
  List<int> rememberedSessionIds(int storeId);

  Future<DataState<LiveSession>> create(
    int storeId, {
    required String title,
    DateTime? scheduledAt,
  });

  Future<DataState<LiveSession>> get(int id);

  Future<DataState<LiveIngest>> start(int id);

  Future<DataState<LiveSession>> end(int id);

  Future<DataState<LiveSession>> addProduct(
    int id, {
    required int productId,
    int? livePrice,
  });

  Future<DataState<LiveSession>> pin(int id, int productId);

  Future<DataState<List<LiveVoucher>>> getVouchers(int id);

  Future<DataState<List<LiveVoucher>>> addVoucher(
    int id, {
    required int voucherId,
    required int quota,
  });
}
