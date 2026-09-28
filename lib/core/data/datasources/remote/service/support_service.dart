import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/support/support_ticket.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// Xpedia 911 — tickets between the account and the platform's admins.
///
/// Encoding is split like the orders module: creating a ticket reads a JSON
/// body, replying reads form fields (`$this->post()`), and a JSON reply would
/// arrive with an empty message and be refused.
class SupportService extends BaseService {
  const SupportService(super.dio);

  /// Newest first, 20 a page, no `meta`.
  Future<List<SupportTicket>> getTickets({int page = 1}) async {
    final envelope = await getRequest(
      ApiEndpoints.supportTickets,
      query: <String, dynamic>{'page': page},
    );
    return envelope.list.map(SupportTicket.fromJson).toList(growable: false);
  }

  Future<SupportTicket> getTicket(int id) async {
    final envelope = await getRequest(ApiEndpoints.supportTicket(id));
    return SupportTicket.fromJson(envelope.map);
  }

  /// Oldest first.
  Future<List<SupportTicketMessage>> getMessages(int id) async {
    final envelope = await getRequest(ApiEndpoints.supportTicketMessages(id));
    return envelope.list
        .map(SupportTicketMessage.fromJson)
        .toList(growable: false);
  }

  Future<int> createTicket({
    required String category,
    required String subject,
    required String description,
    int? storeId,
    int? relatedOrderId,
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.supportTickets,
      body: <String, dynamic>{
        'category': category,
        'subject': subject,
        'description': description,
        'store_id': storeId,
        'related_order_id': relatedOrderId,
      },
    );
    return asInt(envelope.map['id']);
  }

  Future<void> reply(int id, {required String message}) async {
    await postFormRequest(
      ApiEndpoints.supportTicketMessages(id),
      fields: <String, String>{'message': message},
    );
  }
}
