import '../../data_state.dart';
import '../../domain/model/chat/chat_message.dart';
import '../../domain/model/chat/store_conversation.dart';
import '../../domain/repositories/store_inbox_repository.dart';
import 'demo_support.dart';

/// Sample inbox for S-29, shaped after the design's own rows.
class DemoStoreInboxRepository implements StoreInboxRepository {
  const DemoStoreInboxRepository();

  static const String _feature = 'Kotak masuk chat toko';

  /// The buyer side of a sample thread.
  static const int buyerId = -100;

  @override
  Future<DataState<List<StoreConversation>>> getConversations(int storeId) {
    final now = DateTime.now();
    return demoOr(
        _feature,
        () => <StoreConversation>[
              StoreConversation(
                id: 9001,
                buyerName: 'D******',
                buyerCity: 'Kota Jakarta Selatan',
                lastMessage: 'Halo kak, stok warna hitam ready kirim hari ini?',
                lastMessageAt: now.subtract(const Duration(minutes: 12)),
                unreadCount: 2,
                topic: ConversationTopic.order,
                topicLabel: 'Order #XP2501182765',
                topicStatus: 'Processing',
                isOnline: true,
                isSample: true,
              ),
              StoreConversation(
                id: 9002,
                buyerName: 'A****** K****',
                buyerCity: 'Kota Surabaya',
                lastMessage:
                    'Kak paket saya sudah sampai tapi kemasannya penyok…',
                lastMessageAt:
                    now.subtract(const Duration(hours: 1, minutes: 30)),
                unreadCount: 1,
                topic: ConversationTopic.complaint,
                topicLabel: 'Komplain #CMP-20250118-88',
                isImportant: true,
                isOnline: true,
                isSample: true,
              ),
              StoreConversation(
                id: 9003,
                buyerName: 'R**** N*****',
                buyerCity: 'Kota Bandung',
                lastMessage:
                    'Baik kak, resi sudah terbit dan siap diserahkan ke '
                    'kurir JNE ya.',
                lastMessageAt: now.subtract(const Duration(days: 1, hours: 2)),
                lastFromStore: true,
                lastStatus: ChatMessageStatus.read,
                topic: ConversationTopic.product,
                topicLabel: 'Kopi Arabika Gayo 250g',
                topicStatus: 'Terkirim',
                isSample: true,
              ),
              StoreConversation(
                id: 9004,
                buyerName: 'B**** W*****',
                buyerCity: 'Kota Medan',
                lastMessage: 'Apakah untuk pesanan 5 unit dapat harga grosir?',
                lastMessageAt: now.subtract(const Duration(days: 3)),
                lastFromStore: true,
                lastStatus: ChatMessageStatus.delivered,
                topic: ConversationTopic.question,
                topicLabel: 'Tanya Grosir',
                topicStatus: 'Dibalas',
                isSample: true,
              ),
              StoreConversation(
                id: 9005,
                buyerName: 'T**** S****',
                buyerCity: 'Kota Semarang',
                lastMessage:
                    'Terima kasih kak, barang sudah sampai dengan aman!',
                lastMessageAt: now.subtract(const Duration(days: 5)),
                lastFromStore: true,
                lastStatus: ChatMessageStatus.read,
                topic: ConversationTopic.completed,
                topicLabel: 'Pesanan Selesai',
                topicStatus: 'Ulasan Diberikan',
                isSample: true,
              ),
            ]);
  }

  @override
  Future<DataState<List<ChatMessage>>> getSampleThread(int conversationId) {
    final now = DateTime.now();
    ChatMessage m(int id, int minutesAgo, String text,
            {bool mine = false, String status = ChatMessageStatus.read}) =>
        ChatMessage(
          id: id,
          conversationId: conversationId,
          senderUserId: mine ? 0 : buyerId,
          content: text,
          createdAt: now.subtract(Duration(minutes: minutesAgo)),
          status: status,
        );
    return demoOr(
        _feature,
        () => <ChatMessage>[
              m(1, 95, 'Halo kak, mau tanya soal pesanan saya.'),
              m(2, 90, 'Halo kak, silakan. Ada yang bisa kami bantu?',
                  mine: true),
              m(3, 20, 'Apakah bisa dikirim hari ini?'),
              m(4, 15, 'Bisa kak, resi kami cetak sebelum jam 15.00.',
                  mine: true, status: ChatMessageStatus.delivered),
              m(5, 12, 'Siap, terima kasih kak!'),
            ]);
  }
}
