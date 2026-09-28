import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../seller_orders/presentation/cubits/order_list_cubit/order_list_cubit.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';
import '../cubits/home_summary_cubit.dart';

/// "Beranda" (S-11): store header, status strip, Info & Update, Perlu
/// Tindakan, Ringkasan Toko, Akses Cepat.
///
/// Assembled from several calls because the backend has no dashboard
/// endpoint. "Info & Update" shows the account's newest notifications: the API
/// has no announcements feed, and inventing one would put words in the
/// platform's mouth.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.onOpenTab});

  /// Jumps the shell to another tab (1 = Pesanan, 2 = Produk, …).
  final ValueChanged<int> onOpenTab;

  Future<void> _refresh(BuildContext context) async {
    await Future.wait<void>(<Future<void>>[
      StoreCubit.get(context).load(),
      OrderListCubit.get(context).load(),
      HomeSummaryCubit.get(context).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) => switch (state) {
        StoreLoadInProgress() => const LoadingIndicatorView(),
        StoreLoadFailure(:final error) => ErrorStateView(
            error: error,
            onRetry: () => StoreCubit.get(context).load(),
          ),
        StoreLoadSuccess(:final activeStore) when activeStore == null =>
          XEmptyState(
            icon: Icons.storefront_outlined,
            title: 'Belum ada toko yang dipilih',
            message: 'Pilih toko untuk mulai mengelola pesanan.',
            actionLabel: 'Pilih toko',
            onAction: () => context.push(SellerRoutes.storePicker),
          ),
        StoreLoadSuccess(:final activeStore) => Scaffold(
            backgroundColor: XColors.canvas,
            appBar: _Header(store: activeStore!),
            body: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                padding: const EdgeInsets.all(XSpace.screen),
                children: <Widget>[
                  _StatusStrip(store: activeStore),
                  const SizedBox(height: XSpace.sectionGap),
                  const _InfoUpdate(),
                  const SizedBox(height: XSpace.sectionGap),
                  _ActionNeeded(onOpenOrders: () => onOpenTab(1)),
                  const SizedBox(height: XSpace.sectionGap),
                  _Summary(onOpenOrders: () => onOpenTab(1)),
                  const SizedBox(height: XSpace.sectionGap),
                  const _QuickAccess(),
                  const SizedBox(height: XSpace.s24),
                ],
              ),
            ),
          ),
      },
    );
  }
}

class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header({required this.store});

  final Store store;

  @override
  Size get preferredSize => const Size.fromHeight(XSize.appBar + 17);

  String get _initials {
    final words = store.name.trim().split(RegExp(r'\s+'));
    return words.take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<HomeSummaryCubit>().state.unread;
    return Material(
      color: XColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                XSpace.screen,
                XSpace.s8,
                XSpace.s4,
                XSpace.s8,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: XSize.storeLogo,
                    height: XSize.storeLogo,
                    decoration: BoxDecoration(
                      color: XColors.sunken,
                      shape: BoxShape.circle,
                      border: Border.all(color: XColors.borderSubtle),
                    ),
                    alignment: Alignment.center,
                    child: Text(_initials, style: XText.titleM),
                  ),
                  const SizedBox(width: XSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: XText.headingM,
                        ),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                StorePrimaryStatus.label(store.primaryStatus),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: XText.bodyS,
                              ),
                            ),
                            if (store.hasSignatureBadge) ...<Widget>[
                              const SizedBox(width: XSpace.s6),
                              const SignatureBadge(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  XIconAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifikasi',
                    badge: unread,
                    onPressed: () => context.push(SellerRoutes.notifications),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: XColors.borderSubtle),
          ],
        ),
      ),
    );
  }
}

/// Xpedia Signature — compact, black and gold, never a loud pill.
class SignatureBadge extends StatelessWidget {
  const SignatureBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: XSpace.s6, vertical: 2),
      decoration: BoxDecoration(
        color: XColors.signatureBlack,
        borderRadius: BorderRadius.circular(XRadius.xs),
        border: Border.all(color: XColors.signatureGold, width: 0.5),
      ),
      child: Text(
        'SIGNATURE',
        style: XText.labelS.copyWith(
          color: XColors.signatureGoldLight,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final active = store.isActive;
    final tone = active ? XTone.success : XTone.warning;
    return Material(
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(color: tone.foreground.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(XRadius.md),
        onTap: () => context.push(
          active ? SellerRoutes.storeSettings : SellerRoutes.verification,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: XSpace.s12,
            vertical: XSpace.s12,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                active ? Icons.circle : Icons.info_outline_rounded,
                size: active ? 10 : 18,
                color: tone.foreground,
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text(
                  active
                      ? 'Status Toko: Buka · SLA resi 2×24 jam'
                      : 'Toko belum aktif. Ajukan verifikasi untuk mulai '
                          'berjualan.',
                  style: XText.labelM.copyWith(color: tone.foreground),
                ),
              ),
              Text(
                active ? 'Pengaturan Toko ›' : 'Verifikasi ›',
                style: XText.labelM.copyWith(color: tone.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoUpdate extends StatelessWidget {
  const _InfoUpdate();

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<HomeSummaryCubit>().state;
    final items = summary.notifications.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        XSectionHeader(
          title: 'Info & Update Xpedia',
          trailing: 'Lihat Semua',
          onTrailing: () => context.push(SellerRoutes.notifications),
        ),
        if (summary.loading && items.isEmpty)
          const LinearProgressIndicator(minHeight: 2)
        else if (items.isEmpty)
          XCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.campaign_outlined, color: XColors.textTertiary),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Text('Belum ada pembaruan untuk akun Anda.',
                      style: XText.bodyS),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: XSpace.cardGap),
              itemBuilder: (context, i) {
                final n = items[i];
                return SizedBox(
                  width: 280,
                  child: XCard(
                    onTap: n.orderId != null
                        ? () => context
                            .push(SellerRoutes.orderDetailPath(n.orderId!))
                        : () => context.push(SellerRoutes.notifications),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          n.isAboutOrder ? 'PESANAN' : 'PEMBERITAHUAN',
                          style: XText.overline,
                        ),
                        const SizedBox(height: XSpace.s6),
                        Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: XText.titleM,
                        ),
                        if (n.body != null) ...<Widget>[
                          const SizedBox(height: XSpace.s4),
                          Expanded(
                            child: Text(
                              n.body!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: XText.bodyS,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        Text(formatDateTime(n.createdAt), style: XText.caption),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ActionNeeded extends StatelessWidget {
  const _ActionNeeded({required this.onOpenOrders});

  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrderListCubit>().state;
    if (state is! OrderListLoaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const XSectionHeader(title: 'Perlu Tindakan'),
          if (state is OrderListInProgress)
            const LinearProgressIndicator(minHeight: 2),
        ],
      );
    }

    final processing = state.all
        .where((o) => OrderFilter.processing.matches(o.status))
        .map((o) => state.details[o.id] ?? o)
        .toList();
    final urgent = processing.where((o) {
      final r = OrderSla.remaining(o);
      return r != null && r < OrderSla.urgentUnder;
    }).length;
    final custom = processing.where((o) => o.canCustomConfirm).length;
    final complaints = state.countOf(OrderFilter.complaint);
    final toPrint = processing.length;

    final rows = <Widget>[
      if (urgent > 0)
        XListRow(
          icon: Icons.schedule_rounded,
          iconColor: XColors.danger,
          title: '$urgent pesanan mendekati batas SLA',
          trailing: const XChip(label: "Sisa < 24 jam", tone: XTone.danger),
          onTap: onOpenOrders,
        ),
      if (toPrint > 0)
        XListRow(
          icon: Icons.print_outlined,
          title: '$toPrint pesanan siap cetak resi',
          onTap: onOpenOrders,
        ),
      if (custom > 0)
        XListRow(
          icon: Icons.handyman_outlined,
          title: '$custom custom order perlu konfirmasi',
          trailing: const XChip(label: '2×24 jam', tone: XTone.customOrder),
          onTap: onOpenOrders,
        ),
      if (complaints > 0)
        XListRow(
          icon: Icons.assignment_return_outlined,
          title: '$complaints komplain / refund',
          trailing: const XChip(label: 'Perlu respon', tone: XTone.danger),
          onTap: onOpenOrders,
        ),
    ];
    final total = urgent + custom + complaints + (urgent == 0 ? toPrint : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        XSectionHeader(
          title: 'Perlu Tindakan',
          count: rows.isEmpty ? null : total,
        ),
        if (rows.isEmpty)
          XCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, color: XColors.success),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Text('Tidak ada yang menunggu tindakan.',
                      style: XText.bodyM),
                ),
              ],
            ),
          )
        else
          XListGroup(children: rows),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.onOpenOrders});

  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderListCubit>().state;
    final summary = context.watch<HomeSummaryCubit>().state;
    String count(OrderFilter f) =>
        orders is OrderListLoaded ? '${orders.countOf(f)}' : '–';

    final today = DateTime.now();
    final newToday = orders is OrderListLoaded
        ? orders.all.where((o) {
            final c = o.createdAt;
            return c != null &&
                c.year == today.year &&
                c.month == today.month &&
                c.day == today.day;
          }).length
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const XSectionHeader(title: 'Ringkasan Toko'),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: 'Pesanan Baru',
                icon: Icons.shopping_cart_outlined,
                value: newToday == null ? '–' : '$newToday',
                caption: 'Hari ini',
                onTap: onOpenOrders,
              ),
            ),
            const SizedBox(width: XSpace.cardGap),
            Expanded(
              child: _StatTile(
                label: 'Perlu Dikirim',
                icon: Icons.inventory_2_outlined,
                value: count(OrderFilter.processing),
                caption: 'Siap cetak resi',
                onTap: onOpenOrders,
              ),
            ),
          ],
        ),
        const SizedBox(height: XSpace.cardGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: 'Dalam Pengiriman',
                icon: Icons.local_shipping_outlined,
                value: count(OrderFilter.shipping),
                caption: 'Di kurir',
                onTap: onOpenOrders,
              ),
            ),
            const SizedBox(width: XSpace.cardGap),
            Expanded(
              child: _StatTile(
                label: 'Saldo Xpedia Wallet',
                icon: Icons.account_balance_wallet_outlined,
                value: summary.wallet == null
                    ? '–'
                    : formatRupiah(summary.wallet!.balance),
                valueSmall: true,
                caption: 'Tarik Dana →',
                captionLink: true,
                onTap: () => context.push(SellerRoutes.wallet),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.caption,
    this.onTap,
    this.valueSmall = false,
    this.captionLink = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final String caption;
  final VoidCallback? onTap;
  final bool valueSmall;
  final bool captionLink;

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XText.bodyS,
                ),
              ),
              Icon(icon, size: 20, color: XColors.textPrimary),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: valueSmall ? XText.priceL : XText.stat),
          ),
          const SizedBox(height: XSpace.s8),
          Text(
            caption,
            style: captionLink
                ? XText.labelM.copyWith(color: XColors.primary)
                : XText.caption,
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.add_rounded, 'Tambah Produk', SellerRoutes.productCreate),
      (Icons.local_offer_outlined, 'Atur Promo', SellerRoutes.promotions),
      (Icons.warehouse_outlined, 'Gudang & Stok', SellerRoutes.warehouses),
      (Icons.support_agent_outlined, 'Xpedia 911', SellerRoutes.support),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const XSectionHeader(title: 'Akses Cepat'),
        Row(
          children: <Widget>[
            for (var i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: XSpace.s8),
              Expanded(
                child: XCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XSpace.s4,
                    vertical: XSpace.s16,
                  ),
                  onTap: () => context.push(items[i].$3),
                  child: Column(
                    children: <Widget>[
                      Icon(items[i].$1, color: XColors.textPrimary),
                      const SizedBox(height: XSpace.s8),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: XText.labelM,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
