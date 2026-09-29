import 'chat_message.dart';

/// One row of the store's inbox (S-29).
///
/// ⏳ No endpoint yet: `GET /chat/conversations` lists the account's
/// conversations as a *buyer*. The shape here is what S-29 needs — masked
/// buyer, city, last message with its tick state, unread count, and what the
/// conversation is about — and what the backend is asked to return.
class StoreConversation {
  const StoreConversation({
    required this.id,
    required this.buyerName,
    required this.lastMessage,
    this.buyerCity,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastFromStore = false,
    this.lastStatus = ChatMessageStatus.sent,
    this.topic,
    this.topicLabel,
    this.topicStatus,
    this.isImportant = false,
    this.isOnline = false,
    this.isSample = false,
  });

  final int id;

  /// Already masked (`D******`) — the seller never sees a buyer's name.
  final String buyerName;
  final String? buyerCity;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool lastFromStore;
  final String lastStatus;

  /// [ConversationTopic] — what the chat is attached to, if anything.
  final String? topic;
  final String? topicLabel;
  final String? topicStatus;
  final bool isImportant;
  final bool isOnline;

  /// From sample data: opens the sample thread, not the real one.
  final bool isSample;

  bool get isUnread => unreadCount > 0;

  String get initials {
    final letters = buyerName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return letters.isEmpty ? '?' : letters;
  }
}

abstract class ConversationTopic {
  static const String order = 'order';
  static const String complaint = 'complaint';
  static const String product = 'product';
  static const String question = 'question';
  static const String completed = 'completed';
}
