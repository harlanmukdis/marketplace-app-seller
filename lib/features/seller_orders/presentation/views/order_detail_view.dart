import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/order_detail_cubit/order_detail_cubit.dart';
import 'print_waybill_view.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_widgets.dart';

/// "Detail Pesanan" (S05).
///
/// Laid out in the design's order: header, progress, products, buyer (masked),
/// shipping, earnings, then the sticky action bar with "Cetak Resi" and the
/// "Tolak Pesanan" link beneath it. There is no accept button — a paid order
/// is already Processing.
class OrderDetailView extends StatelessWidget {
  const OrderDetailView({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderDetailCubit>(
      create: (_) => OrderDetailCubit(orderId)..load(),
      child: const _OrderDetailBody(),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody();

  Future<void> _run(
    BuildContext context,
    Future<DataError?> Function() action,
    String success,
  ) async {
    final error = await action();
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, success);
  }

  Future<void> _printWaybill(BuildContext context) async {
    final done = await openPrintWaybill(context, OrderDetailCubit.get(context));
    if (done == true && context.mounted) {
      showSuccessSnackBar(context, 'Resi dicetak. Pesanan dalam pengiriman.');
    }
  }

  Future<void> _reject(BuildContext context) async {
    final cubit = OrderDetailCubit.get(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RejectSheet(),
    );
    if (reason == null || !context.mounted) return;
    await _run(context, () => cubit.cancel(reason), 'Pesanan ditolak.');
  }

  Future<void> _customConfirm(BuildContext context) async {
    final cubit = OrderDetailCubit.get(context);
    final days = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomConfirmSheet(),
    );
    if (days == null || !context.mounted) return;
    await _run(
      context,
      () => cubit.customConfirm(days),
      'Custom order dikonfirmasi.',
    );
  }

  Future<void> _proposePartial(BuildContext context, Order order) async {
    final cubit = OrderDetailCubit.get(context);
    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PartialSheet(items: order.items),
    );
    if (ids == null || ids.isEmpty || !context.mounted) return;
    await _run(
      context,
      () => cubit.proposePartial(ids),
      'Usulan dikirim. Menunggu keputusan pembeli.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Detail Pesanan',
        actions: <Widget>[
          XIconAction(
            icon: Icons.help_outline_rounded,
            tooltip: 'Xpedia 911',
            onPressed: () => context.push(SellerRoutes.support),
          ),
        ],
      ),
      body: BlocBuilder<OrderDetailCubit, OrderDetailState>(
        builder: (context, state) => switch (state) {
          OrderDetailInProgress() => const LoadingIndicatorView(),
          OrderDetailFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => OrderDetailCubit.get(context).load(),
            ),
          OrderDetailLoaded() => _content(context, state),
        },
      ),
      bottomNavigationBar: BlocBuilder<OrderDetailCubit, OrderDetailState>(
        builder: (context, state) {
          if (state is! OrderDetailLoaded) return const SizedBox.shrink();
          return _ActionBar(
            order: state.order,
            busy: state.isBusy,
            onPrint: () => _printWaybill(context),
            onReject: () => _reject(context),
            onCustomConfirm: () => _customConfirm(context),
            onChat: () => context.push(SellerRoutes.chat),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, OrderDetailLoaded state) {
    final order = state.order;
    const gap = SizedBox(height: XSpace.cardGap);

    return RefreshIndicator(
      onRefresh: () => OrderDetailCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          if (state.sealCode != null) ...<Widget>[
            XBanner(
              tone: XTone.securePlus,
              icon: Icons.shield_outlined,
              title: 'Kode segel Secure+: ${state.sealCode}.',
              message: 'Tempel pada segel paket. Kode ini juga dikirim ke '
                  'pembeli dan hanya ditampilkan sekali.',
            ),
            gap,
          ],
          _Header(order: order),
          gap,
          XCard(child: OrderProgress(order: order)),
          gap,
          _Products(order: order),
          gap,
          _BuyerInfo(order: order),
          gap,
          _Shipping(
            order: order,
            shipment: state.shipment,
            onPartial: order.canProposePartial && !state.isBusy
                ? () => _proposePartial(context, order)
                : null,
          ),
          if (order.refund != null) ...<Widget>[
            gap,
            _RefundCard(
              refund: order.refund!,
              canResolve: order.canResolveRefund && !state.isBusy,
              onApprove: () => _run(
                context,
                () => OrderDetailCubit.get(context)
                    .resolveRefund(approve: true),
                'Refund disetujui.',
              ),
              onReject: () => _run(
                context,
                () => OrderDetailCubit.get(context)
                    .resolveRefund(approve: false),
                'Refund ditolak.',
              ),
            ),
          ],
          gap,
          OrderEarningsPanel(order: order),
          if (order.hasInvoice) ...<Widget>[
            gap,
            XCard(
              onTap: () =>
                  context.push(SellerRoutes.orderInvoicePath(order.id)),
              child: Row(
                children: <Widget>[
                  Icon(Icons.receipt_long_outlined, color: XColors.primary),
                  const SizedBox(width: XSpace.s12),
                  Expanded(child: Text('Final Invoice', style: XText.titleM)),
                  Icon(Icons.chevron_right, color: XColors.textTertiary),
                ],
              ),
            ),
          ],
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('NO. PESANAN', style: XText.overline),
              const SizedBox(width: XSpace.s8),
              Flexible(
                child: Text(order.orderNumber,
                    style: XText.titleM, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Salin',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.copy_rounded,
                    size: 16, color: XColors.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: order.orderNumber));
                  showSuccessSnackBar(context, 'Nomor pesanan disalin.');
                },
              ),
              const Spacer(),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.canvas,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Column(
              children: <Widget>[
                XKeyValue(
                  label: 'Waktu Pemesanan',
                  value: formatDateTime(order.createdAt),
                ),
                XKeyValue(
                  label: 'Waktu Pembayaran',
                  value: formatDateTime(order.paidAt),
                ),
                if (order.cancellationFault != null)
                  XKeyValue(
                    label: 'Dibatalkan oleh',
                    value: switch (order.cancellationFault) {
                      'seller' => 'Seller',
                      'buyer' => 'Pembeli',
                      _ => 'Sistem',
                    },
                  ),
              ],
            ),
          ),
          if (order.isAwaitingPayment) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.neutral,
              message: 'Menunggu pembayaran pembeli'
                  '${order.paymentDeadline == null ? '' : ' sampai ${formatDateTime(order.paymentDeadline)}'}'
                  '. Belum ada yang perlu dikerjakan.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Products extends StatelessWidget {
  const _Products({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Detail Produk (${order.itemCount} barang)',
                    style: XText.titleL),
              ),
              Icon(Icons.shopping_bag_outlined,
                  size: 20, color: XColors.textSecondary),
            ],
          ),
          if (order.estimatedLeadTimeDays != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.preOrder,
              title: 'Pesanan mengandung item Pre-Order.',
              message: 'Seluruh pesanan dikirim sekaligus setelah lead time '
                  'terlama, ${order.estimatedLeadTimeDays} hari.',
            ),
          ],
          if (order.requiresCustomConfirmation) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.customOrder,
              title: 'Custom Order.',
              message: order.awaitsCustomConfirmation
                  ? 'Konfirmasi kesanggupan dan lead time dalam 2×24 jam, '
                      'atau pesanan batal otomatis.'
                  : 'Dikonfirmasi, lead time ${order.customLeadTimeDays ?? '-'} '
                      'hari.',
            ),
          ],
          if (order.awaitsPartialDecision) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            const XBanner(
              tone: XTone.warning,
              title: 'Menunggu keputusan pembeli.',
              message: 'Pemenuhan sebagian sudah diusulkan. Pesanan tidak '
                  'bisa dikemas sampai pembeli memilih lanjut atau batal.',
            ),
          ],
          for (var i = 0; i < order.items.length; i++) ...<Widget>[
            if (i == 0)
              const SizedBox(height: XSpace.s16)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: XSpace.s12),
                child: Divider(height: 1, color: XColors.borderSubtle),
              ),
            OrderItemRow(item: order.items[i]),
          ],
        ],
      ),
    );
  }
}

class _BuyerInfo extends StatelessWidget {
  const _BuyerInfo({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final city = order.shippingCity;
    final province = order.shippingProvince;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Informasi Pembeli', style: XText.titleL)),
              Icon(Icons.contact_mail_outlined,
                  size: 20, color: XColors.textSecondary),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.brandSubtle,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Column(
              children: <Widget>[
                const XKeyValue(label: 'Nama Akun', value: '••••••'),
                const XKeyValue(label: 'No. Telepon', value: '••••••••'),
                XKeyValue(
                  label: 'Tujuan Pengiriman',
                  value: city.isEmpty
                      ? '-'
                      : province.isEmpty
                          ? city
                          : '$city, $province',
                ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: XColors.textTertiary),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text(
                  'Proteksi privasi pembeli aktif. Nama, kontak dan alamat '
                  'lengkap hanya dipakai untuk label pengiriman kurir.',
                  style: XText.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Shipping extends StatelessWidget {
  const _Shipping({
    required this.order,
    required this.shipment,
    required this.onPartial,
  });

  final Order order;
  final OrderShipment? shipment;
  final VoidCallback? onPartial;

  @override
  Widget build(BuildContext context) {
    final awb = shipment?.awbNumber ?? order.trackingNumber;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Pengiriman', style: XText.titleL)),
              Icon(Icons.local_shipping_outlined,
                  size: 20, color: XColors.textSecondary),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          OrderSlaBanner(order: order, compact: true),
          if (OrderSla.deadlineFor(order) != null)
            const SizedBox(height: XSpace.s12),
          XKeyValue(
            label: 'Kurir',
            value: (order.courierCode ?? '-').toUpperCase(),
          ),
          XKeyValue(label: 'Ongkos kirim', value: formatRupiah(order.shippingCost)),
          if (shipment?.handoverMethod != null)
            XKeyValue(
              label: 'Penyerahan',
              value: shipment!.handoverMethod == HandoverMethod.pickup
                  ? 'Dijemput kurir'
                  : 'Drop-off ke kurir',
            ),
          const SizedBox(height: XSpace.s8),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.canvas,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.qr_code_2_rounded, color: XColors.textSecondary),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('STATUS WAYBILL / RESI', style: XText.overline),
                      Text(
                        awb == null || awb.isEmpty
                            ? 'Nomor resi terisi saat Cetak Resi.'
                            : awb,
                        style: awb == null || awb.isEmpty
                            ? XText.bodyS
                            : XText.titleM,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onPartial != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XButton.ghost(
              label: 'Ada item tidak tersedia? Usulkan pemenuhan sebagian',
              size: XButtonSize.small,
              onPressed: onPartial,
            ),
          ],
        ],
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  const _RefundCard({
    required this.refund,
    required this.canResolve,
    required this.onApprove,
    required this.onReject,
  });

  final OrderRefund refund;
  final bool canResolve;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Komplain & Refund', style: XText.titleL)),
              XChip(
                label: refund.isPending ? 'Perlu Tindakan' : (refund.status ?? '-'),
                tone: refund.isPending ? XTone.actionNeeded : XTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XKeyValue(label: 'Nominal', value: formatRupiah(refund.amount)),
          XKeyValue(label: 'Diajukan', value: formatDateTime(refund.createdAt)),
          if (refund.reason != null) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text(refund.reason!, style: XText.bodyM),
          ],
          if (canResolve) ...<Widget>[
            const SizedBox(height: XSpace.s16),
            Row(
              children: <Widget>[
                Expanded(
                  child: XButton.secondary(label: 'Tolak', onPressed: onReject),
                ),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: XButton(label: 'Setujui refund', onPressed: onApprove),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.order,
    required this.busy,
    required this.onPrint,
    required this.onReject,
    required this.onCustomConfirm,
    required this.onChat,
  });

  final Order order;
  final bool busy;
  final VoidCallback onPrint;
  final VoidCallback onReject;
  final VoidCallback onCustomConfirm;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final primary = order.canCustomConfirm
        ? XButton(
            label: 'Konfirmasi Custom',
            icon: Icons.handyman_outlined,
            size: XButtonSize.large,
            loading: busy,
            onPressed: onCustomConfirm,
          )
        : order.canPrintWaybill
            ? XButton(
                label: 'Cetak Resi',
                icon: Icons.print_outlined,
                size: XButtonSize.large,
                loading: busy,
                onPressed: onPrint,
              )
            : null;

    return Material(
      color: XColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            XSpace.screen,
            XSpace.s12,
            XSpace.screen,
            XSpace.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: XButton.secondary(
                      label: 'Chat Pembeli',
                      icon: Icons.chat_bubble_outline_rounded,
                      size: XButtonSize.large,
                      onPressed: onChat,
                    ),
                  ),
                  if (primary != null) ...<Widget>[
                    const SizedBox(width: XSpace.s12),
                    Expanded(child: primary),
                  ],
                ],
              ),
              if (order.canCancel && !order.isAwaitingPayment) ...<Widget>[
                TextButton(
                  onPressed: busy ? null : onReject,
                  style: TextButton.styleFrom(
                    foregroundColor: XColors.danger,
                    minimumSize: const Size(48, 36),
                  ),
                  child: const Text('Tolak Pesanan'),
                ),
                Text(
                  'Menolak pesanan memengaruhi skor performa toko Anda.',
                  style: XText.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// S-15 — reason is required and visible to the buyer; a seller rejection is
/// recorded as seller fault.
class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  static const List<String> _reasons = <String>[
    'Stok produk habis',
    'Produk rusak atau cacat',
    'Tidak dapat memenuhi spesifikasi pesanan',
    'Tujuan di luar jangkauan pengiriman toko',
    'Lainnya',
  ];

  String? _picked;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _picked == 'Lainnya';
    final reason = isOther ? _note.text.trim() : _picked;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Tolak Pesanan', style: XText.headingM),
              const SizedBox(height: XSpace.s12),
              const XBanner(
                tone: XTone.danger,
                icon: Icons.warning_amber_rounded,
                title: 'Berdampak ke performa toko.',
                message: 'Penolakan dicatat sebagai kesalahan seller dan dana '
                    'pembeli dikembalikan penuh.',
              ),
              const SizedBox(height: XSpace.s16),
              Text('Alasan penolakan', style: XText.titleM),
              const SizedBox(height: XSpace.s8),
              RadioGroup<String>(
                groupValue: _picked,
                onChanged: (v) => setState(() => _picked = v),
                child: Column(
                  children: <Widget>[
                    for (final r in _reasons)
                      RadioListTile<String>(
                        value: r,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(r, style: XText.bodyM),
                      ),
                  ],
                ),
              ),
              if (isOther)
                TextField(
                  controller: _note,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(hintText: 'Tulis alasannya'),
                ),
              const SizedBox(height: XSpace.s16),
              XButton.danger(
                label: 'Tolak Pesanan',
                size: XButtonSize.large,
                expand: true,
                onPressed: reason == null || reason.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(reason),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S-16 — the lead time the seller commits to for a custom order.
class _CustomConfirmSheet extends StatefulWidget {
  const _CustomConfirmSheet();

  @override
  State<_CustomConfirmSheet> createState() => _CustomConfirmSheetState();
}

class _CustomConfirmSheetState extends State<_CustomConfirmSheet> {
  final TextEditingController _days = TextEditingController();

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = int.tryParse(_days.text.trim());
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Konfirmasi Custom Order', style: XText.headingM),
              const SizedBox(height: XSpace.s8),
              Text(
                'Tetapkan berapa hari kerja yang dibutuhkan untuk membuat '
                'pesanan ini. Pembeli melihat angka ini.',
                style: XText.bodyS,
              ),
              const SizedBox(height: XSpace.s16),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Lead time',
                  suffixText: 'hari',
                ),
              ),
              const SizedBox(height: XSpace.s16),
              XButton(
                label: 'Konfirmasi',
                size: XButtonSize.large,
                expand: true,
                onPressed: days == null || days <= 0
                    ? null
                    : () => Navigator.of(context).pop(days),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S-17 — which items cannot be fulfilled. Packing is then held for the buyer.
class _PartialSheet extends StatefulWidget {
  const _PartialSheet({required this.items});

  final List<OrderItem> items;

  @override
  State<_PartialSheet> createState() => _PartialSheetState();
}

class _PartialSheetState extends State<_PartialSheet> {
  final Set<int> _unavailable = <int>{};

  @override
  Widget build(BuildContext context) {
    // Proposing every item unavailable is a rejection, not a partial.
    final valid =
        _unavailable.isNotEmpty && _unavailable.length < widget.items.length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(XSpace.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Pemenuhan Sebagian', style: XText.headingM),
            const SizedBox(height: XSpace.s8),
            Text(
              'Tandai item yang tidak tersedia. Pembeli memilih lanjut dengan '
              'sisa item atau membatalkan seluruh pesanan — pembatalan tetap '
              'dicatat sebagai kesalahan seller.',
              style: XText.bodyS,
            ),
            const SizedBox(height: XSpace.s12),
            for (final item in widget.items)
              CheckboxListTile(
                value: _unavailable.contains(item.id),
                contentPadding: EdgeInsets.zero,
                title: Text(item.productName, style: XText.bodyM),
                subtitle: Text('${item.quantity} barang', style: XText.bodyS),
                onChanged: (v) => setState(() {
                  v == true
                      ? _unavailable.add(item.id)
                      : _unavailable.remove(item.id);
                }),
              ),
            const SizedBox(height: XSpace.s12),
            XButton(
              label: 'Kirim usulan ke pembeli',
              size: XButtonSize.large,
              expand: true,
              onPressed: valid
                  ? () => Navigator.of(context).pop(_unavailable.toList())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
