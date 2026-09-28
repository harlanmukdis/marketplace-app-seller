import 'package:flutter/material.dart';

import '../../../../../core/domain/model/order/order.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// Building blocks shared by the order list (S-13), order detail (S05) and
/// "Atur Pengiriman" (S-21).

/// The buyer, as the seller is allowed to see them: masked, and a city.
///
/// Design rule 1 — the seller never sees the buyer's name, phone, email or
/// street. Since API v1.6.0 the server enforces it too: an order carries
/// `buyer_id` and the destination city/province, nothing more. There is no
/// name to mask, so the line says so rather than inventing an initial.
class OrderBuyerLine extends StatelessWidget {
  const OrderBuyerLine({super.key, required this.order, this.trailing});

  final Order order;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final city = order.shippingCity;
    return Row(
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 16, color: XColors.textTertiary),
        const SizedBox(width: XSpace.s6),
        Flexible(
          child: Text(
            city.isEmpty ? 'Pembeli ••••••' : 'Pembeli •••••• · $city',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: XText.bodyS,
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: XSpace.s8),
          trailing!,
        ],
      ],
    );
  }
}

class OrderCourierLabel extends StatelessWidget {
  const OrderCourierLabel({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final code = order.courierCode;
    if (code == null || code.isEmpty) return const SizedBox.shrink();
    final service = order.courierService;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.local_shipping_outlined,
            size: 16, color: XColors.textTertiary),
        const SizedBox(width: XSpace.s6),
        Text(
          service == null || service.isEmpty
              ? code.toUpperCase()
              : '${code.toUpperCase()} - $service',
          style: XText.bodyS,
        ),
      ],
    );
  }
}

/// A product line. Order items carry no image — the snapshot has a name,
/// options and price only — so the thumbnail is a neutral placeholder.
class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item, this.showPrice = true});

  final OrderItem item;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final options = item.optionsLabel;
    return Opacity(
      opacity: item.isAvailable ? 1 : 0.5,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const OrderThumb(),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: XText.titleM,
                ),
                const SizedBox(height: XSpace.s2),
                Text(
                  <String>[
                    if (options.isNotEmpty) options,
                    '${item.quantity} barang',
                  ].join(' · '),
                  style: XText.bodyS,
                ),
                if (!item.isAvailable) ...<Widget>[
                  const SizedBox(height: XSpace.s4),
                  const XChip(label: 'Tidak tersedia', tone: XTone.danger),
                ],
                if (showPrice) ...<Widget>[
                  const SizedBox(height: XSpace.s4),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item.quantity} × ${formatRupiah(item.price)}',
                          style: XText.caption,
                        ),
                      ),
                      Text(formatRupiah(item.subtotal), style: XText.priceS),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderThumb extends StatelessWidget {
  const OrderThumb({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: XColors.sunken,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Icon(Icons.inventory_2_outlined,
          size: 24, color: XColors.textTertiary),
    );
  }
}

/// The resi SLA as a banner: red under 24 hours, amber above.
///
/// [OrderSla] explains why this counts 48 plain hours rather than the design's
/// working days — it follows the rule the server actually enforces.
class OrderSlaBanner extends StatelessWidget {
  const OrderSlaBanner({super.key, required this.order, this.compact = false});

  final Order order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final remaining = OrderSla.remaining(order);
    if (remaining == null) return const SizedBox.shrink();
    final urgent = remaining < OrderSla.urgentUnder;
    final tone = urgent ? XTone.danger : XTone.warning;
    final text = remaining.isNegative
        ? 'Batas cetak resi sudah lewat — pesanan akan dibatalkan otomatis.'
        : 'Sisa ${OrderSla.format(remaining)} untuk cetak resi (SLA 2×24 jam)';

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: XSpace.s12,
          vertical: XSpace.s8,
        ),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(XRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.timer_outlined, size: 16, color: tone.foreground),
            const SizedBox(width: XSpace.s8),
            Expanded(
              child: Text(
                text,
                style: XText.labelM.copyWith(color: tone.foreground),
              ),
            ),
          ],
        ),
      );
    }

    return XBanner(
      tone: tone,
      icon: Icons.timer_outlined,
      title: remaining.isNegative
          ? 'Lewat batas SLA.'
          : 'Sisa SLA cetak resi: ${OrderSla.format(remaining)}.',
      message: 'Lewat batas 2×24 jam sejak dibayar, pesanan batal otomatis '
          'dan dana dikembalikan ke pembeli.',
    );
  }
}

/// The five-stage progress of S05: Payment Success → Processing → Delivery →
/// Diterima → Selesai.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.order});

  final Order order;

  static const List<String> _labels = <String>[
    'Dibayar',
    'Processing',
    'Delivery',
    'Diterima',
    'Selesai',
  ];

  int get _reached => switch (order.status) {
        OrderStatus.pending => -1,
        OrderStatus.paid || OrderStatus.processed || OrderStatus.packed => 1,
        OrderStatus.shipped => 2,
        OrderStatus.delivered => 3,
        OrderStatus.completed ||
        OrderStatus.refundRequested ||
        OrderStatus.refundRejected ||
        OrderStatus.refundApproved =>
          4,
        _ => -1,
      };

  DateTime? _timeOf(int stage) {
    final wanted = switch (stage) {
      0 => <String>[OrderStatus.paid],
      1 => <String>[OrderStatus.packed, OrderStatus.processed],
      2 => <String>[OrderStatus.shipped],
      3 => <String>[OrderStatus.delivered],
      _ => <String>[OrderStatus.completed],
    };
    for (final event in order.statusHistory) {
      if (wanted.contains(event.toStatus)) return event.createdAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reached = _reached;
    final cancelled = order.status == OrderStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Status Progres Pesanan', style: XText.titleM),
            ),
            XChip(
              label: cancelled
                  ? 'Dibatalkan'
                  : reached < 0
                      ? 'Belum dibayar'
                      : 'Tahap ${reached + 1} dari 5',
              tone: cancelled ? XTone.cancelled : XTone.info,
            ),
          ],
        ),
        const SizedBox(height: XSpace.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: _Stage(
                  label: _labels[i],
                  time: _timeOf(i),
                  done: !cancelled && i < reached,
                  current: !cancelled && i == reached,
                  first: i == 0,
                  last: i == _labels.length - 1,
                  lineDone: !cancelled && i <= reached,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.first,
    required this.last,
    required this.lineDone,
  });

  final String label;
  final DateTime? time;
  final bool done;
  final bool current;
  final bool first;
  final bool last;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? XColors.success
        : current
            ? XColors.primary
            : XColors.borderDefault;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 2,
                color: first
                    ? Colors.transparent
                    : lineDone
                        ? XColors.success
                        : XColors.borderSubtle,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || current ? color : XColors.surface,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : current
                      ? const Icon(Icons.circle, size: 8, color: Colors.white)
                      : null,
            ),
            Expanded(
              child: Container(
                height: 2,
                color: last
                    ? Colors.transparent
                    : done
                        ? XColors.success
                        : XColors.borderSubtle,
              ),
            ),
          ],
        ),
        const SizedBox(height: XSpace.s6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: XText.labelS.copyWith(
            color: current ? XColors.primary : XColors.textPrimary,
            fontWeight: current ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          time == null ? '-' : _short(time!),
          textAlign: TextAlign.center,
          style: XText.caption,
        ),
      ],
    );
  }

  static String _short(DateTime t) {
    final full = formatDateTime(t);
    // "18 Jan 2025, 14:32" -> "18 Jan, 14:32"
    final parts = full.split(', ');
    final date = parts.first.split(' ');
    return date.length >= 2 && parts.length == 2
        ? '${date[0]} ${date[1]}, ${parts[1]}'
        : full;
  }
}

/// "Rincian Pendapatan Seller" — six lines, in a fixed order, with `Rp 0`
/// shown rather than hidden (design rule 4).
class OrderEarningsPanel extends StatelessWidget {
  const OrderEarningsPanel({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final s = order.effectiveSettlement;
    final pct = OrderSettlement.commissionPercent.toStringAsFixed(0);
    TextStyle deduction(int amount) => XText.bodyM.copyWith(
          color: amount > 0 ? XColors.danger : XColors.textPrimary,
        );
    String minus(int amount) => '−${formatRupiah(amount)}';

    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Rincian Pendapatan Seller', style: XText.titleL),
              ),
              Icon(Icons.account_balance_outlined,
                  size: 20, color: XColors.textSecondary),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XKeyValue(
            label: 'Total Nilai Barang',
            value: formatRupiah(s.grossMerchandiseValue),
          ),
          XKeyValue(
            label: 'Support Ongkir Seller',
            value: minus(s.shippingSupportSeller),
            valueStyle: deduction(s.shippingSupportSeller),
          ),
          XKeyValue(
            label: 'Komisi Xpedia ($pct%)',
            value: minus(s.platformCommission),
            valueStyle: deduction(s.platformCommission),
          ),
          XKeyValue(
            label: 'Xpedia Growth',
            value: minus(s.growthCommission),
            valueStyle: deduction(s.growthCommission),
          ),
          XKeyValue(
            label: 'Biaya Layanan',
            value: formatRupiah(s.serviceAdjustment),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: XSpace.s8),
            child: Divider(height: 1, color: XColors.borderSubtle),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Total Pendapatan Seller', style: XText.titleL),
              ),
              Text(
                formatRupiah(s.netSellerRevenue),
                style: XText.priceL.copyWith(color: XColors.primary),
              ),
            ],
          ),
          if (s.isEstimate) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text(
              'Estimasi. Angka final dihitung saat pesanan selesai — '
              'komisi Xpedia Growth baru dipotong pada saat itu.',
              style: XText.caption,
            ),
          ],
        ],
      ),
    );
  }
}
