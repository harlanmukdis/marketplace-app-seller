import '../../data_state.dart';
import '../../domain/model/support/support_ticket.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/remote/service/support_service.dart';
import 'repository_guard.dart';

class SupportRepositoryImpl with RepositoryGuard implements SupportRepository {
  const SupportRepositoryImpl(this._service);

  final SupportService _service;

  @override
  Future<DataState<List<SupportTicket>>> getTickets() =>
      guard(_service.getTickets);

  @override
  Future<DataState<SupportTicket>> getTicket(int id) =>
      guard(() => _service.getTicket(id));

  @override
  Future<DataState<List<SupportTicketMessage>>> getMessages(int id) =>
      guard(() => _service.getMessages(id));

  @override
  Future<DataState<int>> createTicket({
    required String category,
    required String subject,
    required String description,
    int? storeId,
    int? relatedOrderId,
  }) =>
      guard(() => _service.createTicket(
            category: category,
            subject: subject,
            description: description,
            storeId: storeId,
            relatedOrderId: relatedOrderId,
          ));

  @override
  Future<DataState<List<SupportTicketMessage>>> reply(
    int id, {
    required String message,
    String? attachmentUrl,
  }) =>
      guard(() async {
        await _service.reply(
          id,
          message: message,
          attachmentUrl: attachmentUrl,
        );
        return _service.getMessages(id);
      });
}
