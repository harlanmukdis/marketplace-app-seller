import '../../data_state.dart';
import '../../domain/model/live/live_session.dart';
import '../../domain/repositories/live_repository.dart';
import '../../utils/format_helper.dart';
import '../../utils/local_network.dart';
import '../datasources/remote/service/live_service.dart';
import 'repository_guard.dart';

class LiveRepositoryImpl with RepositoryGuard implements LiveRepository {
  const LiveRepositoryImpl(this._service);

  final LiveService _service;

  static String _key(int storeId) => 'liveSessionIds_$storeId';

  @override
  List<int> rememberedSessionIds(int storeId) {
    final raw = CachedHelper.getData(_key(storeId));
    if (raw is! List) return const <int>[];
    return raw
        .map((e) => int.tryParse('$e'))
        .whereType<int>()
        .toList(growable: false);
  }

  Future<void> _remember(int storeId, int id) async {
    final ids = <int>{id, ...rememberedSessionIds(storeId)};
    await CachedHelper.saveData(
      _key(storeId),
      ids.take(50).map((e) => '$e').toList(),
    );
  }

  @override
  Future<DataState<LiveSession>> create(
    int storeId, {
    required String title,
    DateTime? scheduledAt,
  }) =>
      guard(() async {
        final id = await _service.create(
          storeId,
          title: title,
          scheduledAt:
              scheduledAt == null ? null : formatApiDateTime(scheduledAt),
        );
        await _remember(storeId, id);
        return _service.get(id);
      });

  @override
  Future<DataState<LiveSession>> get(int id) => guard(() => _service.get(id));

  @override
  Future<DataState<LiveIngest>> start(int id) =>
      guard(() => _service.start(id));

  @override
  Future<DataState<LiveSession>> end(int id) => guard(() async {
        await _service.end(id);
        return _service.get(id);
      });

  @override
  Future<DataState<LiveSession>> addProduct(
    int id, {
    required int productId,
    int? livePrice,
  }) =>
      guard(() async {
        await _service.addProduct(id, productId: productId, livePrice: livePrice);
        return _service.get(id);
      });

  @override
  Future<DataState<LiveSession>> pin(int id, int productId) =>
      guard(() async {
        await _service.pin(id, productId);
        return _service.get(id);
      });

  @override
  Future<DataState<List<LiveVoucher>>> getVouchers(int id) =>
      guard(() => _service.getVouchers(id));

  @override
  Future<DataState<List<LiveVoucher>>> addVoucher(
    int id, {
    required int voucherId,
    required int quota,
  }) =>
      guard(() async {
        await _service.addVoucher(id, voucherId: voucherId, quota: quota);
        return _service.getVouchers(id);
      });
}
