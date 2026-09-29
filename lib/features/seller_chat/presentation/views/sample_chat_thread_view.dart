import 'package:flutter/material.dart';

import '../../../../core/data/demo/demo_store_inbox_repository.dart';
import '../../../../core/domain/model/chat/chat_message.dart';
import '../../../../core/domain/repositories/store_inbox_repository.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import 'widgets/message_bubble.dart';

/// A conversation from the sample inbox. Looks like S-30, sends nothing:
/// replies are added locally so the flow can be shown end to end.
class SampleChatThreadView extends StatefulWidget {
  const SampleChatThreadView({super.key, required this.conversationId});

  final int conversationId;

  @override
  State<SampleChatThreadView> createState() => _SampleChatThreadViewState();
}

class _SampleChatThreadViewState extends State<SampleChatThreadView> {
  final TextEditingController _text = TextEditingController();
  final List<ChatMessage> _local = <ChatMessage>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _local.add(ChatMessage(
        id: 100000 + _local.length,
        conversationId: widget.conversationId,
        senderUserId: 0,
        content: text,
        createdAt: DateTime.now(),
        status: ChatMessageStatus.sent,
      ));
      _text.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(
        title: 'Percakapan contoh',
        subtitle: 'Balasan tidak dikirim ke server',
      ),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
                XSpace.screen, XSpace.s12, XSpace.screen, 0),
            child: XBanner(
              tone: XTone.preOrder,
              icon: Icons.science_outlined,
              title: 'Data contoh',
              message: 'Kotak masuk toko menunggu API. Membuka dan membalas '
                  'percakapan asli sudah berfungsi.',
            ),
          ),
          Expanded(
            child: PendingBuilder<List<ChatMessage>>(
              load: () => injector<StoreInboxRepository>()
                  .getSampleThread(widget.conversationId),
              builder: (context, messages, _) {
                final all = <ChatMessage>[...messages, ..._local];
                return ListView(
                  padding: const EdgeInsets.all(XSpace.screen),
                  children: <Widget>[
                    for (final m in all)
                      MessageBubble(
                        message: m,
                        isMine:
                            m.senderUserId != DemoStoreInboxRepository.buyerId,
                      ),
                  ],
                );
              },
            ),
          ),
          Material(
            color: XColors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(XSpace.s12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _text,
                        onSubmitted: (_) => _send(),
                        decoration:
                            const InputDecoration(hintText: 'Tulis pesan…'),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    IconButton.filled(
                      tooltip: 'Kirim',
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
