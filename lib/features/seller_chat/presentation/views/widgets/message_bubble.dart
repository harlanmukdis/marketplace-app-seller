import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../config/route/app_route_seller.dart';
import '../../../../../core/data/datasources/remote/service/media_service.dart';
import '../../../../../core/domain/model/chat/chat_message.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// One message (S-30).
///
/// Which side it sits on comes from comparing `sender_user_id` against the
/// signed-in account — the payload carries no name, no role and no side of its
/// own. A store answered by two staff accounts therefore shows both of them on
/// the store's side, which is the right reading.
///
/// Four states, per design rule 7: pending (clock — client-side only),
/// sent (one grey tick), delivered (two grey), read (two blue).
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
    final background = isMine ? XColors.primary : XColors.surface;
    final foreground = isMine ? XColors.textOnBrand : XColors.textPrimary;
    final muted = isMine
        ? XColors.textOnBrand.withValues(alpha: 0.75)
        : XColors.textTertiary;

    final body = switch (message.type) {
      ChatMessageType.productShare => _ProductCard(message: message),
      ChatMessageType.orderShare => _OrderCard(message: message),
      ChatMessageType.image => _Image(url: message.content),
      _ => Text(
          // Content is nullable in the schema and never validated.
          (message.content ?? '').isEmpty ? '(pesan kosong)' : message.content!,
          style: XText.bodyM.copyWith(color: foreground),
        ),
    };
    final isCard = message.type == ChatMessageType.productShare ||
        message.type == ChatMessageType.orderShare;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: XSpace.s4),
          padding: const EdgeInsets.fromLTRB(
            XSpace.s12,
            XSpace.s12,
            XSpace.s12,
            XSpace.s8,
          ),
          decoration: BoxDecoration(
            color: isCard ? XColors.surface : background,
            border: isCard || !isMine
                ? Border.all(color: XColors.borderSubtle)
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(XRadius.lg),
              topRight: const Radius.circular(XRadius.lg),
              bottomLeft: Radius.circular(isMine ? XRadius.lg : XRadius.xs),
              bottomRight: Radius.circular(isMine ? XRadius.xs : XRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(alignment: Alignment.centerLeft, child: body),
              const SizedBox(height: XSpace.s4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _time(message.createdAt),
                    style: XText.caption.copyWith(
                      color: isCard ? XColors.textTertiary : muted,
                    ),
                  ),
                  if (isMine) ...<Widget>[
                    const SizedBox(width: XSpace.s4),
                    _Ticks(status: message.status, onBrand: !isCard),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime? t) {
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}

class _Ticks extends StatelessWidget {
  const _Ticks({required this.status, required this.onBrand});

  final String status;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final grey = onBrand
        ? XColors.textOnBrand.withValues(alpha: 0.7)
        : XColors.textTertiary;
    // Read is blue; on a blue bubble a light blue stays visible.
    final blue = onBrand ? const Color(0xff9EC5FF) : XColors.primary;
    final (IconData icon, Color color, String label) = switch (status) {
      ChatMessageStatus.pending => (Icons.schedule_rounded, grey, 'Mengirim'),
      ChatMessageStatus.delivered => (Icons.done_all_rounded, grey, 'Terkirim'),
      ChatMessageStatus.read => (Icons.done_all_rounded, blue, 'Dibaca'),
      _ => (Icons.done_rounded, grey, 'Dikirim'),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: 16, color: color, semanticLabel: label),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final id = message.sharedProductId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: XColors.sunken,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child:
                  Icon(Icons.inventory_2_outlined, color: XColors.textTertiary),
            ),
            const SizedBox(width: XSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('PRODUK', style: XText.overline),
                  Text(
                    message.content ?? 'Produk #${id ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: XText.titleM,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (id != null) ...<Widget>[
          const SizedBox(height: XSpace.s8),
          Material(
            color: XColors.brandSubtle,
            borderRadius: BorderRadius.circular(XRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(XRadius.md),
              onTap: () => context.push(SellerRoutes.productEditPath(id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: XSpace.s8),
                child: Text(
                  'Lihat Detail Produk →',
                  textAlign: TextAlign.center,
                  style: XText.labelL.copyWith(color: XColors.primary),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final id = message.sharedOrderId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.receipt_long_outlined, color: XColors.primary),
            const SizedBox(width: XSpace.s8),
            Expanded(
              child: Text(
                'Pesanan ${message.content ?? '#${id ?? '-'}'}',
                style: XText.titleM,
              ),
            ),
          ],
        ),
        if (id != null) ...<Widget>[
          const SizedBox(height: XSpace.s8),
          Material(
            color: XColors.primary,
            borderRadius: BorderRadius.circular(XRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(XRadius.md),
              onTap: () => context.push(SellerRoutes.orderDetailPath(id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: XSpace.s8),
                child: Text(
                  'Lihat Ringkasan Pesanan',
                  textAlign: TextAlign.center,
                  style: XText.labelL.copyWith(color: XColors.textOnBrand),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const Icon(Icons.broken_image_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(XRadius.md),
      child: Image.network(
        normaliseUploadUrl(u),
        width: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 220,
          height: 120,
          color: XColors.sunken,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

/// A day divider ("Hari ini, 18 Jan 2025").
class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'Hari Ini, ${formatDate(day)}'
        : day == today.subtract(const Duration(days: 1))
            ? 'Kemarin, ${formatDate(day)}'
            : formatDate(day);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: XSpace.s8),
        padding: const EdgeInsets.symmetric(
          horizontal: XSpace.s12,
          vertical: XSpace.s4,
        ),
        decoration: BoxDecoration(
          color: XColors.brandSubtle,
          borderRadius: BorderRadius.circular(XRadius.full),
        ),
        child: Text(label, style: XText.labelS),
      ),
    );
  }
}
