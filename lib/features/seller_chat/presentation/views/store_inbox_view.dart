import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/chat/chat_message.dart';
import '../../../../core/domain/model/chat/store_conversation.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';

enum _InboxFilter {
  all('Semua'),
  unread('Belum Dibaca'),
  order('Terkait Pesanan'),
  complaint('Komplain & Retur');

  const _InboxFilter(this.label);

  final String label;

  bool accepts(StoreConversation c) => switch (this) {
        all => true,
        unread => c.isUnread,
        order => c.topic == ConversationTopic.order ||
            c.topic == ConversationTopic.product ||
            c.topic == ConversationTopic.completed,
        complaint => c.topic == ConversationTopic.complaint,
      };
}

/// "Chat" (S-29): the store's conversations, newest first, with unread
/// counts and what each one is about. Buyers are masked and located by city
/// only.
class StoreInboxView extends StatefulWidget {
  const StoreInboxView({
    super.key,
    required this.conversations,
    required this.onRefresh,
    required this.onOpenById,
  });

  final List<StoreConversation> conversations;
  final VoidCallback onRefresh;
  final VoidCallback onOpenById;

  @override
  State<StoreInboxView> createState() => _StoreInboxViewState();
}

class _StoreInboxViewState extends State<StoreInboxView> {
  _InboxFilter _filter = _InboxFilter.all;
  String _query = '';
  bool _showTip = true;

  void _open(StoreConversation c) {
    context.push(
      c.isSample
          ? SellerRoutes.chatSamplePath(c.id)
          : SellerRoutes.chatThreadPath(c.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final all = <StoreConversation>[...widget.conversations]..sort((a, b) =>
        (b.lastMessageAt ?? DateTime(0))
            .compareTo(a.lastMessageAt ?? DateTime(0)));
    final shown = all
        .where(_filter.accepts)
        .where((c) =>
            q.isEmpty ||
            c.buyerName.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q) ||
            (c.topicLabel ?? '').toLowerCase().contains(q))
        .toList();

    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Chat',
        showBack: false,
        actions: <Widget>[
          XIconAction(
            icon: Icons.tag,
            tooltip: 'Buka percakapan lewat ID',
            onPressed: widget.onOpenById,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.onRefresh(),
        child: ListView(
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Cari pembeli atau pesan…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: XSpace.s12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final f in _InboxFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: XSpace.s8),
                      child: _FilterPill(
                        label: f.label,
                        count: f == _InboxFilter.unread
                            ? all.fold<int>(0, (n, c) => n + c.unreadCount)
                            : all.where(f.accepts).length,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: XSpace.s12),
            if (_showTip) ...<Widget>[
              _SlaTip(onClose: () => setState(() => _showTip = false)),
              const SizedBox(height: XSpace.s12),
            ],
            const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
            const SizedBox(height: XSpace.s8),
            if (shown.isEmpty)
              const XCard(
                child: XEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Percakapan Tidak Ditemukan',
                  message: 'Tidak ada pesan atau nama pembeli yang cocok '
                      'dengan filter pencarian.',
                ),
              )
            else
              for (final c in shown) ...<Widget>[
                _ConversationRow(conversation: c, onTap: () => _open(c)),
                const SizedBox(height: XSpace.s8),
              ],
            const SizedBox(height: XSpace.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 14, color: XColors.textTertiary),
                const SizedBox(width: XSpace.s4),
                Flexible(
                  child: Text(
                    'Identitas dan nomor telepon pembeli dilindungi sesuai '
                    'privasi Xpedia.',
                    textAlign: TextAlign.center,
                    style: XText.caption,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? XColors.primary : XColors.brandSubtle,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: XSpace.s12,
            vertical: XSpace.s8,
          ),
          child: Row(
            children: <Widget>[
              Text(
                label,
                style: XText.labelL.copyWith(
                  color: selected ? XColors.textOnBrand : XColors.primary,
                ),
              ),
              const SizedBox(width: XSpace.s4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : XColors.primary,
                  borderRadius: BorderRadius.circular(XRadius.full),
                ),
                child: Text(
                  '$count',
                  style: XText.labelS.copyWith(color: XColors.textOnBrand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlaTip extends StatelessWidget {
  const _SlaTip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: XColors.surface,
            child: Icon(Icons.bolt, size: 18, color: XColors.primary),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Respon Cepat', style: XText.titleM),
                Text(
                  'Pertahankan rata-rata waktu balas chat < 5 menit untuk '
                  'menjaga skor Service Performance.',
                  style: XText.bodyS,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            child: Icon(Icons.close, size: 18, color: XColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final StoreConversation conversation;
  final VoidCallback onTap;

  static String _when(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}';
    if (day == today) return '$time WIB';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin, $time';
    return formatDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final accent = c.isImportant
        ? XColors.danger
        : c.isUnread
            ? XColors.primary
            : Colors.transparent;
    final (IconData topicIcon, XTone topicTone) = switch (c.topic) {
      ConversationTopic.order => (Icons.receipt_long_outlined, XTone.warning),
      ConversationTopic.complaint => (Icons.report_outlined, XTone.danger),
      ConversationTopic.product => (Icons.inventory_2_outlined, XTone.neutral),
      ConversationTopic.question => (Icons.sell_outlined, XTone.preOrder),
      ConversationTopic.completed => (Icons.star_rounded, XTone.success),
      _ => (Icons.chat_bubble_outline, XTone.neutral),
    };
    final (IconData tick, Color tickColor) = switch (c.lastStatus) {
      ChatMessageStatus.read => (Icons.done_all_rounded, XColors.primary),
      ChatMessageStatus.delivered => (
          Icons.done_all_rounded,
          XColors.textTertiary
        ),
      _ => (Icons.done_rounded, XColors.textTertiary),
    };

    return Material(
      color: XColors.surface,
      borderRadius: BorderRadius.circular(XRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          padding: const EdgeInsets.all(XSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: c.isImportant
                        ? XColors.dangerSubtle
                        : XColors.brandSubtle,
                    child: Text(
                      c.initials,
                      style: XText.titleM.copyWith(
                        color: c.isImportant
                            ? XColors.dangerStrong
                            : XColors.primary,
                      ),
                    ),
                  ),
                  if (c.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: XColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: XColors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  c.buyerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: XText.titleM,
                                ),
                              ),
                              if (c.isImportant) ...<Widget>[
                                const SizedBox(width: XSpace.s8),
                                const XChip(
                                    label: 'Penting', tone: XTone.danger),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _when(c.lastMessageAt),
                          style: XText.caption.copyWith(
                            color: c.isImportant
                                ? XColors.danger
                                : c.isUnread
                                    ? XColors.primary
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    if (c.buyerCity != null)
                      Row(
                        children: <Widget>[
                          Icon(Icons.location_on_outlined,
                              size: 12, color: XColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(c.buyerCity!, style: XText.caption),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (c.lastFromStore) ...<Widget>[
                          Icon(tick, size: 14, color: tickColor),
                          const SizedBox(width: XSpace.s4),
                        ],
                        Expanded(
                          child: Text(
                            c.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: c.isUnread
                                ? XText.bodyM
                                    .copyWith(fontWeight: FontWeight.w600)
                                : XText.bodyM
                                    .copyWith(color: XColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (c.topicLabel != null) ...<Widget>[
                      const SizedBox(height: XSpace.s8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: XChip(
                                label: c.topicStatus == null ||
                                        c.topic == ConversationTopic.product ||
                                        c.topic ==
                                            ConversationTopic.completed ||
                                        c.topic == ConversationTopic.question
                                    ? c.topicLabel!
                                    : '${c.topicLabel} • ${c.topicStatus}',
                                icon: topicIcon,
                                tone: topicTone,
                              ),
                            ),
                          ),
                          if (c.isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: c.isImportant
                                    ? XColors.danger
                                    : XColors.primary,
                                borderRadius:
                                    BorderRadius.circular(XRadius.full),
                              ),
                              child: Text(
                                '${c.unreadCount}',
                                style: XText.labelS
                                    .copyWith(color: XColors.textOnBrand),
                              ),
                            )
                          else if (c.topicStatus != null &&
                              (c.topic == ConversationTopic.product ||
                                  c.topic == ConversationTopic.completed ||
                                  c.topic == ConversationTopic.question))
                            Text(
                              c.topicStatus!,
                              style: XText.labelS.copyWith(
                                color: c.topic == ConversationTopic.question
                                    ? XColors.textTertiary
                                    : XColors.success,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
