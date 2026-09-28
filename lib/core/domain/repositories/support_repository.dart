import '../../data_state.dart';
import '../model/support/support_ticket.dart';

abstract class SupportRepository {
  Future<DataState<List<SupportTicket>>> getTickets();

  Future<DataState<SupportTicket>> getTicket(int id);

  Future<DataState<List<SupportTicketMessage>>> getMessages(int id);

  /// Returns the new ticket's id.
  Future<DataState<int>> createTicket({
    required String category,
    required String subject,
    required String description,
    int? storeId,
    int? relatedOrderId,
  });

  /// Returns the thread as it stands afterwards.
  Future<DataState<List<SupportTicketMessage>>> reply(
    int id, {
    required String message,
  });
}
