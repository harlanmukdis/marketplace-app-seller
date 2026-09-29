import '../../data_state.dart';
import '../../domain/model/chat/chat_conversation.dart';
import '../../domain/model/chat/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/remote/service/chat_service.dart';
import 'repository_guard.dart';

class ChatRepositoryImpl with RepositoryGuard implements ChatRepository {
  const ChatRepositoryImpl(this._service);

  final ChatService _service;

  @override
  Future<DataState<List<ChatConversation>>> getMyBuyerConversations() =>
      guard(() => _service.getMyBuyerConversations());

  @override
  Future<DataState<List<ChatMessage>>> getMessages(
    int conversationId, {
    int page = 1,
  }) =>
      guard(() async {
        final messages = await _service.getMessages(conversationId, page: page);
        return _oldestFirst(messages);
      });

  @override
  Future<DataState<List<ChatMessage>>> sendMessage(
    int conversationId, {
    required String content,
    String type = ChatMessageType.text,
    int? sharedProductId,
    int? sharedOrderId,
  }) =>
      guard(() async {
        await _service.sendMessage(
          conversationId,
          content: content,
          type: type,
          sharedProductId: sharedProductId,
          sharedOrderId: sharedOrderId,
        );
        // The POST answers with an id and nothing else, so the thread is
        // re-read rather than having the sent message assembled locally.
        return _oldestFirst(await _service.getMessages(conversationId));
      });

  @override
  Future<DataState<bool>> markRead(int conversationId) => guard(() async {
        await _service.markRead(conversationId);
        return true;
      });

  @override
  Future<DataState<List<ChatMessage>>> pollMessages(
    int conversationId, {
    required int sinceId,
  }) =>
      guard(() async {
        final messages =
            await _service.pollMessages(conversationId, sinceId: sinceId);
        return _oldestFirst(messages);
      });

  /// The list endpoint sorts newest-first by a second-resolution `created_at`,
  /// so messages sent in the same second arrive in an arbitrary order. Sorting
  /// by id restores the order they were written in and matches what `poll`
  /// pages against.
  List<ChatMessage> _oldestFirst(List<ChatMessage> messages) {
    final sorted = List<ChatMessage>.of(messages)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted;
  }
}
