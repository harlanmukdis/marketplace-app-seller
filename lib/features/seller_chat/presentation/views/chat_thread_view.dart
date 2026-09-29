import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/function/custom_app_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Percakapan #${widget.conversationId}'),
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
                    return MessageBubble(
                      message: message,
                      isMine: state.isMine(message),
                    );
                  },
                ),
        ),
        MessageComposer(isSending: state.isSending, onSend: _send),
      ],
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
