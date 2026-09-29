import '../../data_state.dart';
import '../model/chat/chat_message.dart';
import '../model/chat/store_conversation.dart';

/// The store's chat inbox (S-29) — the one piece of chat the backend lacks.
///
/// Implemented by `DemoStoreInboxRepository` until an endpoint such as
/// `GET /stores/{id}/chat/conversations` exists.
abstract class StoreInboxRepository {
  Future<DataState<List<StoreConversation>>> getConversations(int storeId);

  /// Messages of a sample conversation. Real conversations go through
  /// `ChatRepository`, which already works.
  Future<DataState<List<ChatMessage>>> getSampleThread(int conversationId);
}
