part of 'chat_thread_cubit.dart';

sealed class ChatThreadState {
  const ChatThreadState();
}

final class ChatThreadInProgress extends ChatThreadState {
  const ChatThreadInProgress();
}

final class ChatThreadFailure extends ChatThreadState {
  const ChatThreadFailure(this.error);

  final DataError error;
}

final class ChatThreadLoaded extends ChatThreadState {
  const ChatThreadLoaded({
    required this.messages,
    this.myUserId,
    this.isSending = false,
    this.isLive = true,
  });

  /// Oldest first, which is the order a thread reads in — the opposite of how
  /// the endpoint returns them.
  final List<ChatMessage> messages;

  /// Who "we" are. A message carries only `sender_user_id`, so this is the
  /// only way to tell the store's replies from the buyer's. Null when the
  /// cached profile is missing, in which case no bubble claims to be ours
  /// rather than every bubble doing so.
  final int? myUserId;

  final bool isSending;

  /// Whether the refresh loop is still running. It gives up after repeated
  /// failures, and the screen says so instead of looking connected.
  final bool isLive;

  /// The newest message on screen. Used to tell an arrival from something
  /// already shown, and it is what `poll?since_id=` would be given if the
  /// long-poll were usable here — zero on an empty thread means "everything".
  int get newestId => messages.isEmpty
      ? 0
      : messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);

  bool isMine(ChatMessage message) =>
      myUserId != null && message.senderUserId == myUserId;

  ChatThreadLoaded copyWith({
    List<ChatMessage>? messages,
    int? myUserId,
    bool? isSending,
    bool? isLive,
  }) =>
      ChatThreadLoaded(
        messages: messages ?? this.messages,
        myUserId: myUserId ?? this.myUserId,
        isSending: isSending ?? this.isSending,
        isLive: isLive ?? this.isLive,
      );
}
