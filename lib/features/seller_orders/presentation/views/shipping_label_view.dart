import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/demo/demo_support.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/repositories/order_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';

/// "Cetak Label Pengiriman" (S-22), drawn from the order itself.
///
/// ⏳ There is no label endpoint: no courier-issued label, no sorting code,
/// no scannable barcode. Everything printed here comes from the order — AWB,
/// courier, destination city, items, the store — and the buyer appears only
/// as the masked name and city the API already limits the seller to. The
/// barcode is a visual placeholder; print, download and share are simulated.
class ShippingLabelView extends StatelessWidget {
  const ShippingLabelView({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return PendingBuilder<Order>(
      load: () => injector<OrderRepository>().getOrder(orderId),
      builder: (context, order, _) => _LabelScreen(order: order),
    );
  }
}

class _LabelScreen extends StatelessWidget {
  const _LabelScreen({required this.order});

  final Order order;

  Future<void> _act(BuildContext context, String done) async {
    final error = await demoWrite('Label pengiriman resmi');
    if (!context.mounted) return;
    showDemoActionResult(context, error, done);
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreCubit>().state;
    final store =
        storeState is StoreLoadSuccess ? storeState.activeStore : null;
    final courier = (order.courierCode ?? '-').toUpperCase();
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Cetak Label Pengiriman'),
      body: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          Row(
            children: <Widget>[
              const XChip(
                label: 'Siap Cetak • A6 (100 × 150 mm)',
                tone: XTone.success,
              ),
              const Spacer(),
              Text('PDF Thermal',
                  style: XText.labelM.copyWith(color: XColors.primary)),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          const XBanner(
            tone: XTone.preOrder,
            icon: Icons.science_outlined,
            title: 'Pratinjau',
            message: 'Disusun dari data pesanan. Label resmi kurir dan barcode '
                'yang bisa dipindai menunggu API.',
          ),
          const SizedBox(height: XSpace.s12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _Label(
                  order: order, storeName: store?.name, courier: courier),
            ),
          ),
          const SizedBox(height: XSpace.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: XButton.secondary(
                  label: 'Unduh PDF',
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: () => _act(context, 'Label diunduh'),
                ),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: XButton.secondary(
                  label: 'Bagikan Label',
                  icon: Icons.share_outlined,
                  expand: true,
                  onPressed: () => _act(context, 'Label dibagikan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XBanner(
            message: 'Tempelkan resi pada sisi datar paket tanpa tertutup '
                'lakban tebal agar barcode mudah dipindai oleh kurir $courier.',
          ),
          const SizedBox(height: XSpace.s24),
        ],
      ),
      bottomNavigationBar: Material(
        color: XColors.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(XSpace.screen),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Status Dokumen', style: XText.bodyS),
                      Text('1 Salinan A6', style: XText.titleM),
                    ],
                  ),
                ),
                XButton(
                  label: 'Cetak Sekarang',
                  icon: Icons.print_outlined,
                  size: XButtonSize.large,
                  onPressed: () => _act(context, 'Label dikirim ke printer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The thermal label itself: black on white, monospace where a courier
/// would expect it.
class _Label extends StatelessWidget {
  const _Label({
    required this.order,
    required this.storeName,
    required this.courier,
  });

  final Order order;
  final String? storeName;
  final String courier;

  static const TextStyle _mono = TextStyle(
    fontFamily: 'Courier',
    fontFamilyFallback: <String>['Menlo', 'monospace'],
    color: Colors.black,
    fontSize: 11,
  );

  @override
  Widget build(BuildContext context) {
    final awb = order.trackingNumber ?? '-';
    final city = order.shippingCity.isEmpty ? '-' : order.shippingCity;
    final black = XText.labelM.copyWith(color: Colors.black);
    final bold = XText.titleM.copyWith(color: Colors.black);
    Widget rule() => Container(height: 2, color: Colors.black);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(XRadius.sm),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(XSpace.s12),
      child: DefaultTextStyle(
        style: black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('X',
                                style: bold.copyWith(color: Colors.white)),
                          ),
                          const SizedBox(width: 4),
                          Text('Xpedia',
                              style:
                                  XText.headingM.copyWith(color: Colors.black)),
                        ],
                      ),
                      Text('LOGISTICS BEYOND LIMITS',
                          style: XText.overline.copyWith(color: Colors.black)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(courier, style: bold),
                        if (order.courierService != null) ...<Widget>[
                          const SizedBox(width: 4),
                          Container(
                            color: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(
                              order.courierService!.toUpperCase(),
                              style: XText.labelS.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text('DROP OFF / PICKUP',
                        style: XText.labelS.copyWith(color: Colors.black)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            rule(),
            const SizedBox(height: XSpace.s8),
            SizedBox(
              height: 56,
              child: CustomPaint(painter: _BarsPainter(awb)),
            ),
            const SizedBox(height: 4),
            Text(
              awb.split('').join(' '),
              textAlign: TextAlign.center,
              style: _mono.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Text('No. Pesanan: ', style: _mono),
                Expanded(
                  child: Text(order.orderNumber,
                      style: _mono.copyWith(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  color: const Color(0xffEEEEEE),
                  child: const Text('NON-COD', style: _mono),
                ),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            rule(),
            const SizedBox(height: XSpace.s8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: const Color(0xffF3F3F3),
              ),
              child: Text(city.toUpperCase(), style: bold),
            ),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: 'PENERIMA: '),
                  TextSpan(
                    text: 'Pembeli Xpedia',
                    style: bold.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              <String>[city, order.shippingProvince]
                  .where((s) => s.isNotEmpty)
                  .join(', '),
            ),
            Row(
              children: <Widget>[
                const Icon(Icons.lock_outline, size: 12, color: Colors.black54),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Alamat lengkap terenkripsi untuk kurir $courier',
                    style: XText.caption.copyWith(color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            rule(),
            const SizedBox(height: XSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('PENGIRIM:'),
                      Text(storeName ?? 'Toko', style: bold),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    const Text('ONGKOS KIRIM:'),
                    Text('LUNAS', style: bold),
                    Text('Marketplace Payout',
                        style: XText.caption.copyWith(color: Colors.black)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            rule(),
            const SizedBox(height: XSpace.s8),
            Row(
              children: <Widget>[
                Expanded(
                    child: Text('DESKRIPSI PRODUK',
                        style: bold.copyWith(fontSize: 11))),
                Text('JUMLAH', style: bold.copyWith(fontSize: 11)),
              ],
            ),
            for (var i = 0; i < order.items.length; i++)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('${i + 1}. ${order.items[i].productName}'),
                  ),
                  Text('${order.items[i].quantity}x'),
                ],
              ),
            const SizedBox(height: XSpace.s8),
            rule(),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final (icon, label) in <(IconData, String)>[
                  (Icons.wine_bar_outlined, 'FRAGILE'),
                  (Icons.water_drop_outlined, 'KERING'),
                  (Icons.arrow_upward, 'ATAS'),
                ]) ...<Widget>[
                  Icon(icon, size: 14, color: Colors.black),
                  Text(label,
                      style: XText.labelS.copyWith(color: Colors.black)),
                  const SizedBox(width: XSpace.s8),
                ],
                const Spacer(),
                Text(formatDate(order.createdAt), style: _mono),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stripes derived from the AWB, so every label looks distinct. Not a
/// real symbology — the courier's own label will carry that.
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final codes = seed.codeUnits.isEmpty ? <int>[42] : seed.codeUnits;
    final widths = <double>[];
    for (var i = 0; i < 64; i++) {
      final c = codes[i % codes.length] + i * 7;
      widths.add(1 + (c % 3).toDouble());
    }
    final total = widths.fold<double>(0, (a, b) => a + b) * 2;
    final unit = size.width / total;
    var x = 0.0;
    for (final w in widths) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w * unit, size.height), paint);
      x += w * unit * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.seed != seed;
}
