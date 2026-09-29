import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/chat/chat_message.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  Map<String, dynamic> row(String? status, {bool delivered = false, bool read = false}) =>
      <String, dynamic>{
        'id': '3',
        'conversation_id': '1',
        'sender_user_id': '40',
        'message_type': 'product_share',
        'content': 'Kaos',
        'shared_product_id': '1',
        'shared_order_id': null,
        'created_at': '2026-09-29 08:00:00',
        'delivered_at': delivered ? '2026-09-29 08:01:00' : null,
        'read_at': read ? '2026-09-29 08:02:00' : null,
        'status': status,
      };

  test('reads the server status', () {
    expect(ChatMessage.fromJson(row('read', delivered: true, read: true)).status,
        ChatMessageStatus.read);
    expect(ChatMessage.fromJson(row('delivered', delivered: true)).status,
        ChatMessageStatus.delivered);
  });

  test('derives status from timestamps on an older server', () {
    expect(ChatMessage.fromJson(row(null)).status, ChatMessageStatus.sent);
    expect(ChatMessage.fromJson(row(null, delivered: true)).status,
        ChatMessageStatus.delivered);
    expect(ChatMessage.fromJson(row(null, delivered: true, read: true)).status,
        ChatMessageStatus.read);
  });

  test('a pending message is client-side, with an id that cannot collide', () {
    final p = ChatMessage.pending(
      localId: 1,
      conversationId: 1,
      senderUserId: 40,
      type: ChatMessageType.text,
      content: 'Halo',
    );
    expect(p.isPending, isTrue);
    expect(p.id, lessThan(0));
  });

  test('a product share keeps its product id', () {
    final m = ChatMessage.fromJson(row('sent'));
    expect(m.isShare, isTrue);
    expect(m.sharedProductId, 1);
  });
}
