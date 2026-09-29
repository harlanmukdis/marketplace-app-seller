import '../../data_state.dart';
import '../model/performance/store_insights.dart';

/// Analytics beyond completed-order sales (S-33). Implemented by
/// `DemoStoreInsightsRepository` until the backend aggregates visits.
abstract class StoreInsightsRepository {
  Future<DataState<ConversionFunnel>> getFunnel(int storeId, {int days = 30});

  Future<DataState<List<TrafficSource>>> getTrafficSources(int storeId);

  Future<DataState<List<TopProduct>>> getTopProducts(int storeId);
}

/// Curation and Growth data the seller cannot read yet (S-28, S-32).
abstract class CatalogQualityRepository {
  Future<DataState<List<ProductModeration>>> getModeration(int storeId);

  Future<DataState<NaturalPerformanceScore>> getNaturalPerformance(int storeId);

  Future<DataState<GrowthDuration>> getGrowthDuration(int productId);

  Future<DataError?> setGrowthDuration(int productId, GrowthDuration value);

  Future<DataState<GrowthProjection>> getGrowthProjection(
    int productId, {
    required double percent,
    required int price,
  });
}
