import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';
import '../cubits/order_list_cubit/order_list_cubit.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_widgets.dart';

/// "Daftar Pesanan" (S-13).
///
/// Used both as a pushed route and as the Pesanan tab of the shell; [embedded]
/// drops the back button when it is a tab.
class OrderListView extends StatelessWidget {
  const OrderListView({
    super.key,
    this.embedded = false,
    this.initial = OrderFilter.processing,
  });

  final bool embedded;
  final OrderFilter initial;

  /// As a tab, the shell already provides the cubit — the same one Beranda
  /// reads its counts from — so the two never disagree.
  @override
  Widget build(BuildContext context) {
    if (embedded) return const _OrderListBody(embedded: true);
    return BlocProvider<OrderListCubit>(
      create: (_) => OrderListCubit(initial: initial)..load(),
      child: const _OrderListBody(embedded: false),
    );
  }
}

class _OrderListBody extends StatelessWidget {
  const _OrderListBody({required this.embedded});

  final bool embedded;

  Future<void> _open(BuildContext context, Order order) async {
    await context.push(SellerRoutes.orderDetailPath(order.id));
    if (context.mounted) await OrderListCubit.get(context).load();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreCubit>().state;
    final store =
        storeState is StoreLoadSuccess ? storeState.activeStore : null;

    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Daftar Pesanan',
        subtitle: store?.name,
        showBack: !embedded,
        actions: <Widget>[
          XIconAction(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifikasi',
            onPressed: () => context.push(SellerRoutes.notifications),
          ),
        ],
      ),
      body: BlocBuilder<OrderListCubit, OrderListState>(
        builder: (context, state) => switch (state) {
          OrderListInProgress() => const LoadingIndicatorView(),
          OrderListNoStore() => XEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada toko yang dipilih',
              actionLabel: 'Pilih toko',
              onAction: () => context.push(SellerRoutes.storePicker),
            ),
          OrderListFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => OrderListCubit.get(context).load(),
            ),
          OrderListLoaded() => _loaded(context, state),
        },
      ),
    );
  }

  Widget _loaded(BuildContext context, OrderListLoaded state) {
    final cubit = OrderListCubit.get(context);
    final orders = state.orders;

    return Column(
      children: <Widget>[
        Container(
          color: XColors.surface,
          padding: const EdgeInsets.fromLTRB(
            XSpace.screen,
            XSpace.s12,
            XSpace.screen,
            0,
          ),
          child: TextField(
            onChanged: cubit.search,
            style: XText.bodyM,
            decoration: const InputDecoration(
              hintText: 'Cari no. pesanan atau nama produk',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        _Tabs(state: state, onSelect: cubit.setFilter),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.all(XSpace.screen),
              children: <Widget>[
                const XBanner(
                  tone: XTone.info,
                  icon: Icons.shield_outlined,
                  bordered: true,
                  title: 'Proteksi Privasi Pembeli Aktif:',
                  message: 'nama dan kontak pembeli dimasking otomatis. '
                      'Cetak resi untuk penyerahan ke kurir mitra.',
                ),
                const SizedBox(height: XSpace.cardGap),
                if (orders.isEmpty)
                  XEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: state.query.isNotEmpty
                        ? 'Tidak ada pesanan yang cocok'
                        : 'Belum ada pesanan ${state.filter.label}',
                    message: state.filter == OrderFilter.processing
                        ? 'Pesanan yang sudah dibayar muncul di sini.'
                        : null,
                    actionLabel: 'Muat ulang',
                    onAction: cubit.load,
                  )
                else
                  for (final order in orders) ...<Widget>[
                    _OrderCard(
                      order: order,
                      loadingDetail: order.items.isEmpty &&
                          !state.details.containsKey(order.id),
                      onOpen: () => _open(context, order),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.state, required this.onSelect});

  final OrderListLoaded state;
  final ValueChanged<OrderFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: XColors.surface,
        border: Border(bottom: BorderSide(color: XColors.borderSubtle)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: XSpace.s8),
        children: <Widget>[
          for (final f in OrderFilter.values)
            _Tab(
              label: f.label,
              count: f.showsCount ? state.countOf(f) : null,
              selected: f == state.filter,
              onTap: () => onSelect(f),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: XSpace.s12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? XColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: XText.labelL.copyWith(
                color: selected ? XColors.primary : XColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count != null && count! > 0) ...<Widget>[
              const SizedBox(width: XSpace.s6),
              XChip(
                label: '$count',
                tone: selected ? XTone.processing : XTone.neutral,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Design.md §4 order card, in its prescribed order: order id + status chip,
/// masked buyer, product, total, SLA countdown when action is required, then
/// the actions. The buyer's address, phone and email never appear.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.loadingDetail,
    required this.onOpen,
  });

  final Order order;
  final bool loadingDetail;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    final more = order.items.length - 1;

    return XCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('ORDER', style: XText.overline),
              const SizedBox(width: XSpace.s8),
              Flexible(
                child: Text(
                  order.orderNumber,
                  overflow: TextOverflow.ellipsis,
                  style: XText.titleM,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: order.orderNumber));
                  showSuccessSnackBar(context, 'Nomor pesanan disalin.');
                },
                child: Padding(
                  padding: const EdgeInsets.all(XSpace.s6),
                  child: Icon(Icons.copy_rounded,
                      size: 16, color: XColors.textTertiary),
                ),
              ),
              const Spacer(),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          OrderBuyerLine(order: order, trailing: OrderCourierLabel(order: order)),
          const SizedBox(height: XSpace.s12),
          if (first != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const OrderThumb(),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        first.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: XText.titleM,
                      ),
                      const SizedBox(height: XSpace.s2),
                      Text(
                        <String>[
                          if (first.optionsLabel.isNotEmpty) first.optionsLabel,
                          '${order.itemCount} barang',
                          if (more > 0) '+$more produk lain',
                        ].join(' · '),
                        style: XText.bodyS,
                      ),
                    ],
                  ),
                ),
                if (order.estimatedLeadTimeDays != null)
                  XChip(
                    label: 'Pre-Order (${order.estimatedLeadTimeDays} hari)',
                    tone: XTone.preOrder,
                  )
                else if (order.requiresCustomConfirmation)
                  const XChip(label: 'Custom Order', tone: XTone.customOrder),
              ],
            )
          else if (loadingDetail)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: XSpace.s12),
            child: Divider(height: 1, color: XColors.borderSubtle),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Total Pesanan', style: XText.bodyS),
              ),
              Text(formatRupiah(order.grandTotal), style: XText.priceM),
            ],
          ),
          if (order.needsAction && OrderSla.deadlineFor(order) != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            OrderSlaBanner(order: order, compact: true),
          ],
          if (order.canPrintWaybill || order.canCustomConfirm) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            Row(
              children: <Widget>[
                Expanded(
                  child: XButton.secondary(
                    label: 'Chat Pembeli',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => context.push(SellerRoutes.chat),
                  ),
                ),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: XButton(
                    label: order.canCustomConfirm
                        ? 'Konfirmasi'
                        : 'Cetak Resi',
                    icon: order.canCustomConfirm
                        ? Icons.handyman_outlined
                        : Icons.print_outlined,
                    onPressed: onOpen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
