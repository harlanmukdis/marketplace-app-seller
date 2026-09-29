import '../../data_state.dart';
import '../model/chat/chat_conversation.dart';
import '../model/chat/chat_message.dart';

/// Buyer↔store conversations.
///
/// The store side of chat is only partly reachable: a thread works once its id
/// is known, but nothing lists the threads belonging to a store. See
/// [ChatConversation] for why.
abstract class ChatRepository {
  /// The account's own conversations **as a buyer**. Not the store's inbox —
  /// the backend has no endpoint for that.
  Future<DataState<List<ChatConversation>>> getMyBuyerConversations();

  /// One page of a thread, sorted oldest-first for display.
  Future<DataState<List<ChatMessage>>> getMessages(
    int conversationId, {
    int page = 1,
  });

  /// Sends a message and returns the thread as it stands afterwards — the
  /// `POST` answers only `{ "id": N }`.
  /// Refused with `422 CHAT_CONTENT_BLOCKED` when the text carries a phone
  /// number, email, URL or another platform's name (anti-bypass, v1.18.0).
  Future<DataState<List<ChatMessage>>> sendMessage(
    int conversationId, {
    required String content,
    String type,
    int? sharedProductId,
    int? sharedOrderId,
  });

  Future<DataState<bool>> markRead(int conversationId);

  /// Waits for anything newer than [sinceId]. Comes back empty when the
  /// server's hold expires with nothing new, which is not a failure.
  Future<DataState<List<ChatMessage>>> pollMessages(
    int conversationId, {
    required int sinceId,
  });
}
