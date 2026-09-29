import 'package:flutter/material.dart';

import '../../../../../core/function/components.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// The write box.
///
/// Only `text` is offered. The enum has `image`, `video`, `product_share` and
/// `order_share`, but nothing can be uploaded into a message — the attachment
/// table has no route — so a picker here would produce messages carrying a URL
/// the seller has no way to obtain.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.isSending,
    required this.onSend,
  });

  final bool isSending;

  /// Returns true when the message went out, which is when the box clears.
  final Future<bool> Function(String content) onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_hasText || widget.isSending) return;
    final sent = await widget.onSend(_controller.text);
    if (sent && mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? kBlackColor : kWhiteColor,
        border: const Border(top: BorderSide(color: kBorderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: XText.bodyM,
                decoration: InputDecoration(
                  hintText: 'Tulis balasan…',
                  hintStyle: XText.bodyM.copyWith(color: kLightThirdColor),
                  filled: true,
                  fillColor: isDark ? kDarkColor : const Color(0xffF6F7FB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            8.sbw,
            SizedBox(
              width: 48,
              height: 48,
              child: widget.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton.filled(
                      // Disabled on an empty box: the server stores a message
                      // with null content without complaint.
                      onPressed: _hasText ? _send : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      tooltip: 'Kirim',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
