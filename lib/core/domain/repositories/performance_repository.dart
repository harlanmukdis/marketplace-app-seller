import '../../data_state.dart';
import '../model/performance/store_performance.dart';

/// Everything the Performance (S-35) and Analytics (S-33) screens read. Each
/// call is independent: a failure in one tile must not blank the others.
abstract class PerformanceRepository {
  Future<DataState<PartnersPerformance>> getPartnersPerformance(int storeId);

  /// [DataEmpty] until a tier is assigned.
  Future<DataState<SellerTier>> getTier(int storeId);

  Future<DataState<(HealthScore?, List<HealthScore>)>> getHealthScore(
    int storeId,
  );

  Future<DataState<CustomerSegmentation>> getCustomerSegmentation(int storeId);

  Future<DataState<List<StockMismatchEvent>>> getStockMismatchEvents(
    int storeId,
  );
}
