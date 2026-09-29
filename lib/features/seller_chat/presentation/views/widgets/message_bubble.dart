import 'package:flutter/material.dart';

import '../../../../../core/domain/model/chat/chat_message.dart';
import '../../../../../core/function/components.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// One message.
///
/// Which side it sits on comes from comparing `sender_user_id` against the
/// signed-in account — the payload carries no name, no role and no side of its
/// own. A store answered by two staff accounts therefore shows both of them on
/// the store's side, which is the right reading.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode();
    final background = isMine
        ? kLightPrimaryColor
        : (isDark ? kDarkColor : const Color(0xffF1F2F6));
    final foreground =
        isMine ? kWhiteColor : (isDark ? kDarkSecondColor : kLightSecondColor);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (message.type != ChatMessageType.text) ...<Widget>[
                _TypeTag(message: message, foreground: foreground),
                6.sbh,
              ],
              Text(
                // Content is nullable in the schema and never validated, so a
                // message with nothing in it can exist and has to render as
                // something rather than as a blank box.
                message.content?.isNotEmpty == true
                    ? message.content!
                    : '(pesan kosong)',
                style: XText.bodyM.copyWith(color: foreground),
              ),
              4.sbh,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    formatDateTime(message.createdAt),
                    style: XText.caption.copyWith(
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ),
                  if (isMine) ...<Widget>[
                    4.sbw,
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: foreground.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Names a non-text message.
///
/// `image` and `video` have nowhere to put a file — `chat_attachments` exists
/// in the schema but no route writes to it — so whatever URL was sent travels
/// in the content, and this only labels the kind.
class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.message, required this.foreground});

  final ChatMessage message;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final reference = switch (message.type) {
      ChatMessageType.productShare when message.sharedProductId != null =>
        ' #${message.sharedProductId}',
      ChatMessageType.orderShare when message.sharedOrderId != null =>
        ' #${message.sharedOrderId}',
      _ => '',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          switch (message.type) {
            ChatMessageType.image => Icons.image_outlined,
            ChatMessageType.video => Icons.videocam_outlined,
            ChatMessageType.productShare => Icons.inventory_2_outlined,
            ChatMessageType.orderShare => Icons.receipt_long_outlined,
            _ => Icons.chat_bubble_outline,
          },
          size: 13,
          color: foreground.withValues(alpha: 0.8),
        ),
        4.sbw,
        Text(
          '${ChatMessageType.label(message.type)}$reference',
          style:
              XText.caption.copyWith(color: foreground.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
