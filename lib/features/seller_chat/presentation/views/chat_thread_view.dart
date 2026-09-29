import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../core/domain/repositories/order_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/chat_thread_cubit/chat_thread_cubit.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// One conversation with a buyer.
///
/// Fully working against the live API — reading, replying, read receipts and
/// long-polled delivery all do what they say. The part that is missing sits
/// upstream: nothing tells the seller *which* conversations exist. See
/// [ChatInboxView].
class ChatThreadView extends StatelessWidget {
  const ChatThreadView({super.key, required this.conversationId});

  final int conversationId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatThreadCubit>(
      create: (_) => ChatThreadCubit(conversationId)..load(),
      child: _ChatThreadBody(conversationId: conversationId),
    );
  }
}

class _ChatThreadBody extends StatefulWidget {
  const _ChatThreadBody({required this.conversationId});

  final int conversationId;

  @override
  State<_ChatThreadBody> createState() => _ChatThreadBodyState();
}

class _ChatThreadBodyState extends State<_ChatThreadBody> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A thread reads from the bottom, and a message arriving while it is open
  /// should not leave the newest one off-screen.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<bool> _send(String content) async {
    final error = await ChatThreadCubit.get(context).send(content);
    if (!mounted) return false;
    if (error != null) {
      showErrorSnackBar(context, error);
      return false;
    }
    _scrollToEnd();
    return true;
  }

  Future<void> _report(Future<DataError?> future) async {
    final error = await future;
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    _scrollToEnd();
  }

  Future<void> _sendPhoto() async {
    final cubit = ChatThreadCubit.get(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    await _report(cubit.sendImage(bytes, file!.name));
  }

  Future<void> _shareProduct() async {
    final cubit = ChatThreadCubit.get(context);
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) return;
    final result =
        await injector<CatalogRepository>().getStoreProducts(storeId);
    if (!mounted) return;
    final products = result is DataSuccess<List<Product>>
        ? result.value.where((p) => p.isActive).toList()
        : const <Product>[];
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _Picker<Product>(
        title: 'Bagikan Produk',
        empty: 'Belum ada produk aktif.',
        items: products,
        label: (p) => p.name,
        subtitle: (p) => formatRupiah(p.effectivePrice),
      ),
    );
    if (picked == null || !mounted) return;
    await _report(cubit.shareProduct(picked.id, picked.name));
  }

  Future<void> _shareOrder() async {
    final cubit = ChatThreadCubit.get(context);
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) return;
    final result = await injector<OrderRepository>().getStoreOrders(storeId);
    if (!mounted) return;
    final orders =
        result is DataSuccess<List<Order>> ? result.value : const <Order>[];
    final picked = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _Picker<Order>(
        title: 'Referensi Pesanan',
        empty: 'Belum ada pesanan.',
        items: orders,
        label: (o) => o.orderNumber,
        subtitle: (o) =>
            '${OrderStatus.label(o.status)} · ${formatRupiah(o.grandTotal)}',
      ),
    );
    if (picked == null || !mounted) return;
    await _report(cubit.shareOrder(picked.id, picked.orderNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(title: 'Percakapan #${widget.conversationId}'),
      body: SafeArea(
        child: BlocConsumer<ChatThreadCubit, ChatThreadState>(
          listener: (context, state) {
            if (state is ChatThreadLoaded) _scrollToEnd();
          },
          builder: (context, state) => switch (state) {
            ChatThreadInProgress() => const LoadingIndicatorView(),
            ChatThreadFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => ChatThreadCubit.get(context).load(),
              ),
            ChatThreadLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChatThreadLoaded state) {
    return Column(
      children: <Widget>[
        if (!state.isLive) const _ConnectionLostNotice(),
        if (state.myUserId == null) const _UnknownIdentityNotice(),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            XSpace.screen,
            XSpace.s12,
            XSpace.screen,
            0,
          ),
          child: XBanner(
            tone: XTone.warning,
            icon: Icons.shield_outlined,
            title: 'Keamanan Percakapan.',
            message: 'Jangan bagikan nomor WhatsApp, rekening di luar Xpedia, '
                'atau link platform lain — pesan seperti itu diblokir.',
          ),
        ),
        Expanded(
          child: state.messages.isEmpty
              ? const EmptyStateView(
                  icon: Icons.forum_outlined,
                  message: 'Belum ada pesan di percakapan ini.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    final day = _day(message.createdAt);
                    final prev = index == 0
                        ? null
                        : _day(state.messages[index - 1].createdAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (day != null && day != prev) DayDivider(day: day),
                        MessageBubble(
                          message: message,
                          isMine: state.isMine(message),
                        ),
                      ],
                    );
                  },
                ),
        ),
        MessageComposer(
          isSending: state.isSending,
          onSend: _send,
          onPhoto: _sendPhoto,
          onShareProduct: _shareProduct,
          onShareOrder: _shareOrder,
        ),
      ],
    );
  }
}

DateTime? _day(DateTime? t) =>
    t == null ? null : DateTime(t.year, t.month, t.day);

class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.title,
    required this.empty,
    required this.items,
    required this.label,
    required this.subtitle,
  });

  final String title;
  final String empty;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: Text(title, style: XText.headingM),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(empty, style: XText.bodyS))
                  : ListView(
                      children: <Widget>[
                        for (final item in items)
                          ListTile(
                            title: Text(label(item), style: XText.bodyM),
                            subtitle: Text(subtitle(item), style: XText.bodyS),
                            onTap: () => Navigator.of(context).pop(item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The long-poll gave up after repeated failures. Said plainly, because the
/// screen otherwise looks connected and simply stops updating.
class _ConnectionLostNotice extends StatelessWidget {
  const _ConnectionLostNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: kWarningColor.withValues(alpha: 0.1),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sync_problem_outlined,
              size: 16, color: kWarningColor),
          8.sbw,
          Expanded(
            child: Text(
              'Pesan baru tidak lagi masuk otomatis. Buka ulang percakapan '
              'ini untuk menyambungkannya lagi.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Without the cached profile there is no way to tell the store's own replies
/// from the buyer's, so the screen says so rather than guessing a side.
class _UnknownIdentityNotice extends StatelessWidget {
  const _UnknownIdentityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: kLightPrimaryColor.withValues(alpha: 0.08),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded,
              size: 16, color: kLightPrimaryColor),
          8.sbw,
          Expanded(
            child: Text(
              'Identitas akun belum termuat, jadi semua pesan ditampilkan di '
              'sisi pembeli. Masuk ulang untuk memperbaikinya.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
