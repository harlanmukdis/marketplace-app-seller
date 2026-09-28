import '../../data_state.dart';
import '../../domain/model/performance/store_performance.dart';
import '../../domain/repositories/performance_repository.dart';
import '../datasources/remote/service/performance_service.dart';
import 'repository_guard.dart';

class PerformanceRepositoryImpl
    with RepositoryGuard
    implements PerformanceRepository {
  const PerformanceRepositoryImpl(this._service);

  final PerformanceService _service;

  @override
  Future<DataState<PartnersPerformance>> getPartnersPerformance(int storeId) =>
      guard(() => _service.getPartnersPerformance(storeId));

  @override
  Future<DataState<SellerTier>> getTier(int storeId) async {
    final result = await guard(() => _service.getTier(storeId));
    return switch (result) {
      DataSuccess<SellerTier?>(:final value) when value != null =>
        DataSuccess<SellerTier>(value),
      DataFailed<SellerTier?>(:final failure) => DataFailed<SellerTier>(failure),
      _ => const DataEmpty<SellerTier>(),
    };
  }

  @override
  Future<DataState<(HealthScore?, List<HealthScore>)>> getHealthScore(
    int storeId,
  ) =>
      guard(() => _service.getHealthScore(storeId));

  @override
  Future<DataState<CustomerSegmentation>> getCustomerSegmentation(
    int storeId,
  ) =>
      guard(() => _service.getCustomerSegmentation(storeId));

  @override
  Future<DataState<List<StockMismatchEvent>>> getStockMismatchEvents(
    int storeId,
  ) =>
      guard(() => _service.getStockMismatchEvents(storeId));
}
