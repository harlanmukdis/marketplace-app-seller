import 'package:flutter/material.dart';

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
    this.onPhoto,
    this.onShareProduct,
    this.onShareOrder,
  });

  final bool isSending;

  /// Returns true when the message went out, which is when the box clears.
  final Future<bool> Function(String content) onSend;

  /// Photo, product card and order reference — the only attachments design
  /// rule 7 allows (no files, video or audio).
  final VoidCallback? onPhoto;
  final VoidCallback? onShareProduct;
  final VoidCallback? onShareOrder;

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
    return Material(
      color: XColors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: XColors.borderSubtle)),
        ),
        padding: const EdgeInsets.fromLTRB(
          XSpace.s8,
          XSpace.s8,
          XSpace.s12,
          XSpace.s4,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  PopupMenuButton<int>(
                    tooltip: 'Bagikan',
                    enabled: !widget.isSending,
                    icon: Icon(Icons.add_circle_outline,
                        color: XColors.textSecondary),
                    onSelected: (v) => v == 0
                        ? widget.onShareProduct?.call()
                        : widget.onShareOrder?.call(),
                    itemBuilder: (_) => <PopupMenuEntry<int>>[
                      if (widget.onShareProduct != null)
                        const PopupMenuItem<int>(
                          value: 0,
                          child: ListTile(
                            leading: Icon(Icons.inventory_2_outlined),
                            title: Text('Kartu Produk'),
                          ),
                        ),
                      if (widget.onShareOrder != null)
                        const PopupMenuItem<int>(
                          value: 1,
                          child: ListTile(
                            leading: Icon(Icons.receipt_long_outlined),
                            title: Text('Referensi Pesanan'),
                          ),
                        ),
                    ],
                  ),
                  if (widget.onPhoto != null)
                    IconButton(
                      tooltip: 'Kirim foto',
                      onPressed: widget.isSending ? null : widget.onPhoto,
                      icon: Icon(Icons.photo_camera_outlined,
                          color: XColors.textSecondary),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: XText.bodyM,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan untuk pembeli',
                        hintStyle: XText.bodyM
                            .copyWith(color: XColors.textPlaceholder),
                        filled: true,
                        fillColor: XColors.sunken,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(XRadius.xxl),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(XRadius.xxl),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: XSpace.s8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.filled(
                            // Disabled on an empty box: the server stores a
                            // message with null content without complaint.
                            onPressed: _hasText ? _send : null,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            tooltip: 'Kirim',
                          ),
                  ),
                ],
              ),
              const SizedBox(height: XSpace.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.lock_outline_rounded,
                      size: 12, color: XColors.textTertiary),
                  const SizedBox(width: XSpace.s4),
                  Flexible(
                    child: Text(
                      'Pesan yang terkirim tidak dapat disunting atau dihapus.',
                      style: XText.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
