import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/chat/chat_conversation.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/chat_inbox_cubit/chat_inbox_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// Chat, and the one thing the backend cannot yet do.
///
/// A seller inbox needs a list of the conversations belonging to a store.
/// `GET /chat/conversations` is not it: the model filters on `buyer_id`, so it
/// answers with the conversations in which this account is the *customer*.
/// Presenting those as the shop's enquiries would be worse than showing
/// nothing, so this screen says what is missing and shows the buyer-side list
/// under its own name.
///
/// Everything downstream of a conversation id already works — see
/// [ChatThreadView] — so the thread is reachable by id in the meantime.
class ChatInboxView extends StatelessWidget {
  const ChatInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatInboxCubit>(
      create: (_) => ChatInboxCubit()..load(),
      child: const _ChatInboxBody(),
    );
  }
}

class _ChatInboxBody extends StatelessWidget {
  const _ChatInboxBody();

  Future<void> _openById(BuildContext context) async {
    final id = await showDialog<int>(
      context: context,
      builder: (_) => const _OpenByIdDialog(),
    );
    if (id == null || !context.mounted) return;
    await context.push(SellerRoutes.chatThreadPath(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Chat'),
      body: SafeArea(
        child: BlocBuilder<ChatInboxCubit, ChatInboxState>(
          builder: (context, state) => switch (state) {
            ChatInboxInProgress() => const LoadingIndicatorView(),
            ChatInboxFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => ChatInboxCubit.get(context).load(),
              ),
            ChatInboxLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChatInboxLoaded state) {
    final asBuyer = state.withOtherStores;
    final withOwn = state.withOwnStore;

    return RefreshIndicator(
      onRefresh: () => ChatInboxCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _MissingEndpointCard(),
                  12.sbh,
                  SectionCard(
                    onTap: () => _openById(context),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.tag, size: 18),
                        12.sbw,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Buka percakapan lewat ID',
                                style: XText.bodyM,
                              ),
                              2.sbh,
                              Text(
                                'Membaca dan membalas sudah berfungsi penuh — '
                                'yang belum ada hanya daftarnya.',
                                style: XText.caption
                                    .copyWith(color: kLightThirdColor),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                  if (withOwn.isNotEmpty) ...<Widget>[
                    24.sbh,
                    Text('Percakapan dengan toko sendiri', style: XText.labelL),
                    4.sbh,
                    Text(
                      'Akun ini pernah membuka percakapan dengan tokonya '
                      'sendiri. Server mengizinkannya, tapi tidak ada gunanya.',
                      style: XText.caption.copyWith(color: kLightThirdColor),
                    ),
                    12.sbh,
                    for (final conversation in withOwn) ...<Widget>[
                      _ConversationCard(conversation: conversation),
                      12.sbh,
                    ],
                  ],
                  24.sbh,
                  Text('Percakapan Anda sebagai pembeli', style: XText.labelL),
                  4.sbh,
                  Text(
                    'Ini yang dikembalikan API: percakapan tempat akun ini '
                    'berbelanja di toko lain — bukan pesan masuk untuk toko '
                    'Anda.',
                    style: XText.caption.copyWith(color: kLightThirdColor),
                  ),
                  12.sbh,
                  if (asBuyer.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyStateView(
                        icon: Icons.chat_bubble_outline,
                        message: 'Akun ini belum pernah chat sebagai pembeli.',
                      ),
                    )
                  else
                    for (final conversation in asBuyer) ...<Widget>[
                      _ConversationCard(conversation: conversation),
                      12.sbh,
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gap, stated where it matters rather than buried in a doc.
class _MissingEndpointCard extends StatelessWidget {
  const _MissingEndpointCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: kWarningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.inbox_outlined, size: 18, color: kWarningColor),
              8.sbw,
              Expanded(
                child: Text(
                  'Kotak masuk toko belum bisa dibuat',
                  style: XText.labelL,
                ),
              ),
            ],
          ),
          8.sbh,
          Text(
            'API hanya punya satu daftar percakapan, dan daftar itu disaring '
            'berdasarkan pembeli — jadi pemilik toko tidak melihat pesan yang '
            'masuk ke tokonya. Membaca, membalas, dan tanda dibaca semuanya '
            'sudah jalan begitu ID percakapan diketahui; yang kurang hanya '
            'cara menemukannya.',
            style: XText.bodySPrimary,
          ),
          8.sbh,
          Text(
            'Butuh dari backend: GET /stores/{id}/chat/conversations. '
            'Tabelnya bahkan sudah punya indeks untuk query itu.',
            style: XText.caption.copyWith(color: kLightThirdColor),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: () => context.push(SellerRoutes.chatThreadPath(conversation.id)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  conversation.storeName ?? 'Toko #${conversation.storeId}',
                  style: XText.bodyM,
                ),
                2.sbh,
                Text(
                  conversation.hasMessages
                      ? 'Pesan terakhir '
                          '${formatDateTime(conversation.lastMessageAt)}'
                      : 'Belum ada pesan',
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

/// A stopgap while the store-side listing does not exist.
class _OpenByIdDialog extends StatefulWidget {
  const _OpenByIdDialog();

  @override
  State<_OpenByIdDialog> createState() => _OpenByIdDialogState();
}

class _OpenByIdDialogState extends State<_OpenByIdDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final id = int.tryParse(_controller.text.trim());
    if (id == null || id <= 0) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buka percakapan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Masukkan ID percakapan. Server menolak dengan 403 kalau toko '
            'Anda bukan peserta di dalamnya.',
            style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
          ),
          12.sbh,
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ID percakapan',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Buka')),
      ],
    );
  }
}
