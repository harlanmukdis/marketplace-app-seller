import '../../../utils/json_parse.dart';

/// One row of `GET /chat/conversations/{id}/messages`.
///
/// The server returns them **newest first**, thirty to a page, ordered by
/// `created_at` — which is only second-resolution, so two messages sent in the
/// same second come back in an arbitrary order. Sort by [id] before rendering:
/// it is the only strictly increasing field, and it is what `poll` pages
/// against too.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    this.type = ChatMessageType.text,
    this.content,
    this.sharedProductId,
    this.sharedOrderId,
    this.createdAt,
    this.readAt,
    this.deliveredAt,
    this.status = ChatMessageStatus.sent,
  });

  final int id;
  final int conversationId;

  /// The only identity a message carries — no name, no role, no side. Which
  /// bubble is the store's own is decided by comparing this against the signed
  /// in user, so a store answered by two staff accounts shows both as "ours".
  final int senderUserId;

  final String type;

  /// Nullable in the schema and never validated: the server accepts a message
  /// with no content at all and stores it.
  final String? content;

  final int? sharedProductId;
  final int? sharedOrderId;

  final DateTime? createdAt;

  /// Stamped by `POST /read` for every message the *other* side sent. A message
  /// the store sent is only marked when the buyer opens the thread.
  final DateTime? readAt;

  /// Stamped when the other side fetches the thread (API v1.18.0).
  final DateTime? deliveredAt;

  /// `sent` | `delivered` | `read` from the server, or `pending` for a
  /// message this device is still sending — the fourth state of design rule
  /// 7 exists only on the client.
  final String status;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: asInt(json['id']),
        conversationId: asInt(json['conversation_id']),
        senderUserId: asInt(json['sender_user_id']),
        type: asString(json['message_type'], fallback: ChatMessageType.text),
        content: asStringOrNull(json['content']),
        sharedProductId: asIntOrNull(json['shared_product_id']),
        sharedOrderId: asIntOrNull(json['shared_order_id']),
        createdAt: asCreatedDate(json),
        readAt: asDateTime(json['read_at']),
        deliveredAt: asDateTime(json['delivered_at']),
        status: asStringOrNull(json['status']) ??
            (json['read_at'] != null
                ? ChatMessageStatus.read
                : json['delivered_at'] != null
                    ? ChatMessageStatus.delivered
                    : ChatMessageStatus.sent),
      );

  /// A placeholder shown while a send is in flight. A negative id cannot
  /// collide with the server's.
  factory ChatMessage.pending({
    required int localId,
    required int conversationId,
    required int senderUserId,
    required String type,
    String? content,
    int? sharedProductId,
    int? sharedOrderId,
  }) =>
      ChatMessage(
        id: -localId,
        conversationId: conversationId,
        senderUserId: senderUserId,
        type: type,
        content: content,
        sharedProductId: sharedProductId,
        sharedOrderId: sharedOrderId,
        createdAt: DateTime.now(),
        status: ChatMessageStatus.pending,
      );

  bool get isPending => status == ChatMessageStatus.pending;

  bool get isRead => readAt != null;

  /// An `image` message has nowhere to put a file: the `chat_attachments`
  /// table exists but **no route writes to it**, so the uploaded URL travels
  /// in [content].
  bool get isMedia => type == ChatMessageType.image;

  bool get isShare =>
      type == ChatMessageType.productShare || type == ChatMessageType.orderShare;
}

/// The only four types the server accepts since v1.6.0 — video is refused
/// with a 422, and so are files (design rule 7).
abstract class ChatMessageType {
  static const String text = 'text';
  static const String image = 'image';
  static const String productShare = 'product_share';
  static const String orderShare = 'order_share';

  static String label(String? type) => switch (type) {
        text => 'Pesan',
        image => 'Gambar',
        productShare => 'Produk dibagikan',
        orderShare => 'Pesanan dibagikan',
        _ => type ?? '-',
      };
}

abstract class ChatMessageStatus {
  static const String pending = 'pending';
  static const String sent = 'sent';
  static const String delivered = 'delivered';
  static const String read = 'read';
}
