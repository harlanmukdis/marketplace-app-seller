import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/performance/store_performance.dart';
import 'base_service.dart';

/// Read-only store metrics: Partners Performance, tier, health score, and the
/// analytics the API actually computes.
class PerformanceService extends BaseService {
  const PerformanceService(super.dio);

  Map<String, dynamic> _store(int storeId) =>
      <String, dynamic>{'X-Store-Id': '$storeId'};

  Future<PartnersPerformance> getPartnersPerformance(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.storePartnersPerformance(storeId),
      headers: _store(storeId),
    );
    return PartnersPerformance.fromJson(envelope.map);
  }

  /// Null until the nightly `seller_tier_evaluation_worker` assigns one.
  Future<SellerTier?> getTier(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.storeTier(storeId),
      headers: _store(storeId),
    );
    return envelope.isNull ? null : SellerTier.fromJson(envelope.map);
  }

  /// `{latest, history}`; both empty until the worker has run.
  Future<(HealthScore?, List<HealthScore>)> getHealthScore(
    int storeId, {
    int days = 30,
  }) async {
    final envelope = await getRequest(
      ApiEndpoints.storeHealthScore(storeId),
      query: <String, dynamic>{'days': days},
      headers: _store(storeId),
    );
    final map = envelope.map;
    final latest = map['latest'];
    return (
      latest is Map<String, dynamic> ? HealthScore.fromJson(latest) : null,
      asHistory(map['history']),
    );
  }

  static List<HealthScore> asHistory(dynamic raw) => raw is List
      ? raw
          .whereType<Map<String, dynamic>>()
          .map(HealthScore.fromJson)
          .toList(growable: false)
      : const <HealthScore>[];

  Future<CustomerSegmentation> getCustomerSegmentation(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.storeCustomerSegmentation(storeId),
      headers: _store(storeId),
    );
    return CustomerSegmentation.fromJson(envelope.map);
  }

  Future<List<StockMismatchEvent>> getStockMismatchEvents(
    int storeId, {
    int page = 1,
  }) async {
    final envelope = await getRequest(
      ApiEndpoints.storeStockMismatchEvents(storeId),
      query: <String, dynamic>{'page': page},
      headers: _store(storeId),
    );
    return envelope.list
        .map(StockMismatchEvent.fromJson)
        .toList(growable: false);
  }
}
