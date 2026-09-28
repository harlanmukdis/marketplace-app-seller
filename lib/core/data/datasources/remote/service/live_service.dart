import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/live/live_session.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// Live selling. JSON bodies throughout (this controller reads php://input),
/// except pin, which is a bodiless PATCH.
///
/// The server validates almost nothing: no transition checks on start/end,
/// no ownership check when adding a product or voucher, duplicates accepted,
/// and a missing `title` or `quota` is a PHP warning rather than a 422. The
/// caller validates.
class LiveService extends BaseService {
  const LiveService(super.dio);

  Future<int> create(
    int storeId, {
    required String title,
    String? scheduledAt,
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.storeLiveSessions(storeId),
      body: <String, dynamic>{'title': title, 'scheduled_at': scheduledAt},
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return asInt(envelope.map['id']);
  }

  Future<LiveSession> get(int id) async {
    final envelope = await getRequest(ApiEndpoints.liveSession(id));
    return LiveSession.fromJson(envelope.map);
  }

  Future<LiveIngest> start(int id) async {
    final envelope = await postRequest(ApiEndpoints.liveSessionStart(id));
    return LiveIngest.fromJson(envelope.map);
  }

  Future<void> end(int id) async {
    await postRequest(ApiEndpoints.liveSessionEnd(id));
  }

  Future<void> addProduct(int id, {required int productId, int? livePrice}) =>
      postRequest(
        ApiEndpoints.liveSessionProducts(id),
        body: <String, dynamic>{
          'product_id': productId,
          'live_price': livePrice,
        },
      );

  Future<void> pin(int id, int productId) =>
      patchRequest(ApiEndpoints.liveSessionPin(id, productId));

  Future<List<LiveVoucher>> getVouchers(int id) async {
    final envelope = await getRequest(ApiEndpoints.liveSessionVouchers(id));
    return envelope.list.map(LiveVoucher.fromJson).toList(growable: false);
  }

  Future<void> addVoucher(
    int id, {
    required int voucherId,
    required int quota,
  }) =>
      postRequest(
        ApiEndpoints.liveSessionVouchers(id),
        body: <String, dynamic>{'voucher_id': voucherId, 'quota': quota},
      );
}
