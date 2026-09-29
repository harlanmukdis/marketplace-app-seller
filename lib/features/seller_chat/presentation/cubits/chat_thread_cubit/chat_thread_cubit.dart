import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/chat/chat_message.dart';
import '../../../../../core/domain/model/media/uploaded_file.dart';
import '../../../../../core/domain/repositories/store_repository.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/chat_repository.dart';
import '../../../../../di/injector.dart';

part 'chat_thread_state.dart';

/// One conversation, kept current by re-reading it on a timer.
///
/// There is no WebSocket in this build, and the purpose-built alternative —
/// `GET .../poll?since_id=`, which holds the request open for ~25 seconds —
/// **cannot be used while the API runs on `php -S`**. That server is
/// single-threaded, so one held request blocks every other one: measured
/// against this backend, a trivial `GET /health` took 23.9s during a poll
/// against 0.00s otherwise, and sending a message from this very screen took
/// 24 seconds to come back. Realtime delivery is not worth making the rest of
/// the app unreachable.
///
/// So this re-reads the thread every few seconds instead. Each request is
/// short, nothing queues behind it, and the cost is a few seconds of latency
/// on an inbound message. [ChatRepository.pollMessages] is kept, verified and
/// documented for the day the backend runs behind a real worker pool.
class ChatThreadCubit extends Cubit<ChatThreadState> {
  ChatThreadCubit(this.conversationId) : super(const ChatThreadInProgress());

  static ChatThreadCubit get(BuildContext context) => BlocProvider.of(context);

  final int conversationId;

  final ChatRepository _chat = injector<ChatRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  /// Guards the refresh loop so it stops when the screen goes away, and so a
  /// reload cannot leave two loops running against the same thread.
  int _pollGeneration = 0;

  /// Consecutive failures. A failing refresh must not become a tight loop
  /// against the server, so it gives up and the screen says so rather than
  /// hammering on.
  int _failures = 0;
  static const int _maxFailures = 3;

  /// Short enough to feel current, long enough that a thread left open does
  /// not make a request per second.
  static const Duration _refreshInterval = Duration(seconds: 4);

  Future<void> load() async {
    if (isClosed) return;
    emit(const ChatThreadInProgress());

    final result = await _chat.getMessages(conversationId);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<List<ChatMessage>>(:final value):
        emit(_loaded(value));
      case DataEmpty<List<ChatMessage>>():
        emit(_loaded(const <ChatMessage>[]));
      case DataFailed<List<ChatMessage>>(:final failure):
        emit(ChatThreadFailure(failure));
        return;
      default:
        emit(const ChatThreadFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Percakapan tidak bisa dibaca.',
          ),
        ));
        return;
    }

    // Best-effort: a thread that cannot be marked read is still readable, so
    // the failure is not worth surfacing.
    await _chat.markRead(conversationId);
    _startPolling();
  }

  ChatThreadLoaded _loaded(List<ChatMessage> messages) => ChatThreadLoaded(
        messages: messages,
        myUserId: _auth.currentUserId,
      );

  Future<DataError?> send(String content) async {
    final trimmed = content.trim();
    // The server stores an empty message without complaint, so it is refused
    // here instead.
    if (trimmed.isEmpty) {
      return const DataError(
        code: 'CHAT_EMPTY_MESSAGE',
        message: 'Pesan tidak boleh kosong.',
      );
    }
    return _send(type: ChatMessageType.text, content: trimmed);
  }

  /// Uploads the photo, then sends its URL as an `image` message — the only
  /// place a file can travel, since `chat_attachments` has no writer.
  Future<DataError?> sendImage(Uint8List bytes, String fileName) async {
    final current = state;
    if (current is! ChatThreadLoaded) return null;
    emit(current.copyWith(isSending: true));
    final uploaded = await injector<StoreRepository>().upload(
      bytes: bytes,
      fileName: fileName,
      storeId: _auth.activeStoreId,
    );
    if (isClosed) return null;
    if (uploaded is! DataSuccess<UploadedFile>) {
      emit((state as ChatThreadLoaded).copyWith(isSending: false));
      return uploaded is DataFailed<UploadedFile> ? uploaded.failure : null;
    }
    return _send(type: ChatMessageType.image, content: uploaded.value.url);
  }

  /// A product card. `content` carries the name so the bubble reads without
  /// a lookup.
  Future<DataError?> shareProduct(int productId, String name) => _send(
        type: ChatMessageType.productShare,
        content: name,
        sharedProductId: productId,
      );

  /// An order reference — the order number, never buyer details.
  Future<DataError?> shareOrder(int orderId, String orderNumber) => _send(
        type: ChatMessageType.orderShare,
        content: orderNumber,
        sharedOrderId: orderId,
      );

  int _localSeq = 0;

  /// Shows the message at once as `pending`, then replaces the thread with
  /// the server's once the POST lands. A failure removes the placeholder.
  Future<DataError?> _send({
    required String type,
    required String content,
    int? sharedProductId,
    int? sharedOrderId,
  }) async {
    final current = state;
    if (current is! ChatThreadLoaded) return null;
    final pending = ChatMessage.pending(
      localId: ++_localSeq,
      conversationId: conversationId,
      senderUserId: current.myUserId ?? 0,
      type: type,
      content: content,
      sharedProductId: sharedProductId,
      sharedOrderId: sharedOrderId,
    );
    emit(current.copyWith(
      messages: <ChatMessage>[...current.messages, pending],
      isSending: true,
    ));

    final result = await _chat.sendMessage(
      conversationId,
      content: content,
      type: type,
      sharedProductId: sharedProductId,
      sharedOrderId: sharedOrderId,
    );
    if (isClosed) return null;
    final latest = state as ChatThreadLoaded;

    switch (result) {
      case DataSuccess<List<ChatMessage>>(:final value):
        emit(latest.copyWith(messages: value, isSending: false));
        return null;
      case DataFailed<List<ChatMessage>>(:final failure):
        emit(latest.copyWith(
          messages: latest.messages.where((m) => m.id != pending.id).toList(),
          isSending: false,
        ));
        if (failure.code == 'CHAT_CONTENT_BLOCKED') {
          return DataError(
            code: failure.code,
            message: 'Pesan tidak terkirim: nomor telepon, email, link, atau '
                'nama platform lain tidak boleh dibagikan di chat. Semua '
                'transaksi harus lewat Xpedia.',
          );
        }
        return failure;
      default:
        emit(latest.copyWith(isSending: false));
        return null;
    }
  }

  /// Re-reads the thread on a timer until the cubit closes or it fails too
  /// often.
  void _startPolling() {
    _failures = 0;
    final generation = ++_pollGeneration;
    unawaited(_pollLoop(generation));
  }

  Future<void> _pollLoop(int generation) async {
    while (!isClosed && generation == _pollGeneration) {
      await Future<void>.delayed(_refreshInterval);
      if (isClosed || generation != _pollGeneration) return;

      final current = state;
      if (current is! ChatThreadLoaded) return;

      // Skipped while a send is in flight, so the refresh cannot overwrite the
      // thread with a copy that predates the message being sent.
      if (current.isSending) continue;

      final result = await _chat.getMessages(conversationId);
      if (isClosed || generation != _pollGeneration) return;

      switch (result) {
        case DataSuccess<List<ChatMessage>>(:final value):
          _failures = 0;
          await _merge(value);
        case DataEmpty<List<ChatMessage>>():
          _failures = 0;
        case DataFailed<List<ChatMessage>>():
          _failures++;
          if (_failures >= _maxFailures) {
            final latest = state;
            if (latest is ChatThreadLoaded && !isClosed) {
              emit(latest.copyWith(isLive: false));
            }
            return;
          }
        default:
          _failures = 0;
      }
    }
  }

  Future<void> _merge(List<ChatMessage> arrived) async {
    final current = state;
    if (current is! ChatThreadLoaded || arrived.isEmpty) return;

    // Merge by id rather than replacing: a refresh returns only the newest
    // page, so replacing would drop older messages already on screen.
    final byId = <int, ChatMessage>{
      for (final message in current.messages) message.id: message,
      for (final message in arrived) message.id: message,
    };
    final merged = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));

    final hasNewFromBuyer = arrived.any(
      (message) => message.id > current.newestId && !current.isMine(message),
    );

    if (merged.length != current.messages.length || hasNewFromBuyer) {
      emit(current.copyWith(messages: merged, isLive: true));
    }

    // Only when the buyer actually said something — otherwise this would be a
    // write every few seconds for nothing.
    if (hasNewFromBuyer) await _chat.markRead(conversationId);
  }

  @override
  Future<void> close() {
    // Abandons the loop: it checks the generation after every await, so it
    // exits rather than emitting into a closed cubit.
    _pollGeneration++;
    return super.close();
  }
}
