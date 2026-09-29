import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/chat/chat_conversation.dart';
import 'package:navy_wear/core/domain/model/chat/chat_message.dart';
import 'package:navy_wear/features/seller_chat/presentation/cubits/chat_thread_cubit/chat_thread_cubit.dart';

/// Payloads captured from the running marketplace API.
void main() {
  Map<String, dynamic> message({
    String id = '14',
    String type = 'text',
    String? content = 'Halo, stok masih ada?',
    String sender = '11',
    String? readAt,
    dynamic sharedProduct,
    dynamic sharedOrder,
  }) =>
      <String, dynamic>{
        'id': id,
        'conversation_id': '8',
        'sender_user_id': sender,
        'message_type': type,
        'content': content,
        'shared_product_id': sharedProduct,
        'shared_order_id': sharedOrder,
        'created_at': '2026-09-20 16:57:12',
        'read_at': readAt,
      };

  group('ChatMessage.fromJson', () {
    test('reads a message the way the server returns one', () {
      final parsed = ChatMessage.fromJson(message());

      expect(parsed.id, 14);
      expect(parsed.conversationId, 8);
      expect(parsed.senderUserId, 11);
      expect(parsed.type, ChatMessageType.text);
      expect(parsed.content, 'Halo, stok masih ada?');
      expect(parsed.isRead, isFalse);
    });

    test('read_at is what makes a message read', () {
      final parsed =
          ChatMessage.fromJson(message(readAt: '2026-09-20 16:57:12'));

      expect(parsed.isRead, isTrue);
      expect(parsed.readAt, isNotNull);
    });

    test('an empty message is a real possibility', () {
      // `content` is nullable in the schema and the controller never checks
      // it, so the server stores a message with nothing in it. The model has
      // to carry that rather than assume a string.
      final parsed = ChatMessage.fromJson(message(content: null));

      expect(parsed.content, isNull);
    });

    test('media and share types are told apart from text', () {
      expect(ChatMessage.fromJson(message(type: 'image')).isMedia, isTrue);
      // Video was removed in API v1.6.0 (the server refuses it), so a stray
      // legacy row is no longer treated as displayable media.
      expect(ChatMessage.fromJson(message(type: 'video')).isMedia, isFalse);
      expect(ChatMessage.fromJson(message(type: 'text')).isMedia, isFalse);

      final share = ChatMessage.fromJson(
        message(type: 'product_share', sharedProduct: '20'),
      );
      expect(share.isShare, isTrue);
      expect(share.sharedProductId, 20);
      expect(share.sharedOrderId, isNull);
    });
  });

  group('ChatConversation.fromJson', () {
    // Verbatim from GET /chat/conversations.
    Map<String, dynamic> row({String? lastMessageAt = '2026-09-20 16:57:12'}) =>
        <String, dynamic>{
          'id': '8',
          'buyer_id': '11',
          'store_id': '1',
          'last_message_at': lastMessageAt,
          'buyer_unread_count': '0',
          'store_unread_count': '0',
          'created_at': '2026-09-20 16:57:12',
          'store_name': 'Kedai Kopi Nusantara',
        };

    test('reads a row, including the joined store name', () {
      final parsed = ChatConversation.fromJson(row());

      expect(parsed.id, 8);
      expect(parsed.buyerId, 11);
      expect(parsed.storeId, 1);
      expect(parsed.storeName, 'Kedai Kopi Nusantara');
      expect(parsed.hasMessages, isTrue);
    });

    test('a conversation opened but never used has no last message', () {
      final parsed = ChatConversation.fromJson(row(lastMessageAt: null));

      expect(parsed.lastMessageAt, isNull);
      expect(parsed.hasMessages, isFalse);
    });

    test('a row pointing at the account own store is recognised', () {
      // The endpoint is buyer-scoped, so a seller sees this only when the
      // account opened a conversation with its own shop — which the server
      // permits. It is not a customer enquiry and must not read as one.
      final parsed = ChatConversation.fromJson(row());

      expect(parsed.isWithOwnStore(1), isTrue);
      expect(parsed.isWithOwnStore(2), isFalse);
      expect(parsed.isWithOwnStore(null), isFalse);
    });
  });

  group('ChatThreadLoaded', () {
    ChatThreadLoaded loaded(List<String> ids, {int? me}) => ChatThreadLoaded(
          messages: <ChatMessage>[
            for (final id in ids) ChatMessage.fromJson(message(id: id)),
          ],
          myUserId: me,
        );

    test('an empty thread polls from zero, which means "everything"', () {
      expect(loaded(const <String>[]).newestId, 0);
    });

    test('the poll cursor is the highest id, not the last element', () {
      // The list endpoint sorts by a second-resolution `created_at`, so two
      // messages written in the same second can arrive in either order.
      // Taking the last element as the cursor would then re-request messages
      // already shown, or skip one.
      expect(loaded(const <String>['14', '17', '15']).newestId, 17);
    });

    test('ownership is decided against the signed-in account', () {
      final state = loaded(const <String>['14'], me: 11);
      expect(state.isMine(state.messages.first), isTrue);

      final other = loaded(const <String>['14'], me: 10);
      expect(other.isMine(other.messages.first), isFalse);
    });

    test('with no cached identity nothing is claimed as ours', () {
      // Better that every bubble sits on the buyer's side than that every
      // bubble claims to be the store's.
      final state = loaded(const <String>['14']);
      expect(state.myUserId, isNull);
      expect(state.isMine(state.messages.first), isFalse);
    });
  });
}
