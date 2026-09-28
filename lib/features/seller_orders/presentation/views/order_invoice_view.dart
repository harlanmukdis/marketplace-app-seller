import 'package:flutter/material.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/repositories/order_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// "Final Invoice" (S-20) — the legal document, separate from the waybill and
/// available only for a completed order (design rule 5). The API returns data
/// rather than a PDF, so it is rendered here.
class OrderInvoiceView extends StatefulWidget {
  const OrderInvoiceView({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderInvoiceView> createState() => _OrderInvoiceViewState();
}

class _OrderInvoiceViewState extends State<OrderInvoiceView> {
  late Future<DataState<OrderInvoice>> _future;

  @override
  void initState() {
    super.initState();
    _future = injector<OrderRepository>().getInvoice(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Final Invoice'),
      body: FutureBuilder<DataState<OrderInvoice>>(
        future: _future,
        builder: (context, snapshot) {
          final result = snapshot.data;
          return switch (result) {
            null => const LoadingIndicatorView(),
            DataSuccess<OrderInvoice>(:final value) => _Invoice(value),
            DataFailed<OrderInvoice>(:final failure) => ErrorStateView(
                error: failure,
                onRetry: () => setState(() {
                  _future =
                      injector<OrderRepository>().getInvoice(widget.orderId);
                }),
              ),
            _ => const XEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Invoice belum tersedia',
                message: 'Final Invoice terbit setelah pesanan selesai.',
              ),
          };
        },
      ),
    );
  }
}

class _Invoice extends StatelessWidget {
  const _Invoice(this.invoice);

  final OrderInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final city = invoice.shippingAddress['city'];
    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        XCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text('INVOICE', style: XText.overline)),
                  const XChip(label: 'Lunas', tone: XTone.completed),
                ],
              ),
              const SizedBox(height: XSpace.s4),
              Text(invoice.invoiceNumber, style: XText.headingM),
              const SizedBox(height: XSpace.s12),
              XKeyValue(label: 'No. Pesanan', value: invoice.orderNumber),
              XKeyValue(
                label: 'Tanggal Pesanan',
                value: formatDateTime(invoice.orderDate),
              ),
              XKeyValue(
                label: 'Tanggal Terbit',
                value: formatDateTime(invoice.generatedAt),
              ),
              XKeyValue(label: 'Penjual', value: invoice.storeName),
              XKeyValue(
                label: 'Tujuan',
                value: city == null ? '-' : '$city',
              ),
            ],
          ),
        ),
        const SizedBox(height: XSpace.cardGap),
        XCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Rincian Barang', style: XText.titleL),
              const SizedBox(height: XSpace.s8),
              for (final item in invoice.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: XSpace.s6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.productName, style: XText.bodyM),
                            Text(
                              '${item.quantity} × ${formatRupiah(item.price)}',
                              style: XText.caption,
                            ),
                          ],
                        ),
                      ),
                      Text(formatRupiah(item.subtotal), style: XText.priceS),
                    ],
                  ),
                ),
              Divider(height: XSpace.s24, color: XColors.borderSubtle),
              XKeyValue(label: 'Subtotal', value: formatRupiah(invoice.subtotal)),
              XKeyValue(
                label: 'Ongkos Kirim',
                value: formatRupiah(invoice.shippingCost),
              ),
              XKeyValue(
                label: 'Diskon',
                value: '−${formatRupiah(invoice.discountTotal)}',
              ),
              const SizedBox(height: XSpace.s8),
              Row(
                children: <Widget>[
                  Expanded(child: Text('Total', style: XText.titleL)),
                  Text(
                    formatRupiah(invoice.grandTotal),
                    style: XText.priceL.copyWith(color: XColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
