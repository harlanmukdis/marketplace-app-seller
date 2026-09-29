import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/model/order/order.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../../di/injector.dart';

/// Result of one margin simulation — kept apart from the widget so the
/// arithmetic can be tested on its own.
class MarginSimulation {
  const MarginSimulation({
    required this.normalPrice,
    required this.discount,
    required this.shippingSupport,
    required this.commission,
    required this.growthCommission,
    required this.cost,
  });

  /// Works a promotion through the same six lines as the order earnings panel.
  /// Commission is charged on what the buyer pays for the item, at the
  /// platform rate plus the product's Growth rate, if any.
  factory MarginSimulation.of({
    required int normalPrice,
    required int cost,
    required int discountValue,
    required bool discountIsPercent,
    int shippingSupport = 0,
    double growthPercent = 0,
  }) {
    final rawDiscount = discountIsPercent
        ? (normalPrice * discountValue.clamp(0, 100) / 100).round()
        : discountValue;
    final discount = rawDiscount.clamp(0, normalPrice);
    final buyerPrice = normalPrice - discount;
    return MarginSimulation(
      normalPrice: normalPrice,
      discount: discount,
      shippingSupport: shippingSupport,
      commission:
          (buyerPrice * OrderSettlement.commissionPercent / 100).round(),
      growthCommission: (buyerPrice * growthPercent / 100).round(),
      cost: cost,
    );
  }

  final int normalPrice;
  final int discount;
  final int shippingSupport;
  final int commission;
  final int growthCommission;

  /// HPP — the seller's own cost; never sent anywhere.
  final int cost;

  int get buyerPrice => normalPrice - discount;

  int get payout =>
      buyerPrice - shippingSupport - commission - growthCommission;

  /// Null until a cost is entered.
  double? get marginPercent => cost <= 0 ? null : (payout - cost) * 100 / cost;

  bool get isLoss => cost > 0 && payout < cost;
}

/// "Proteksi Margin Toko" (S-31): a what-if before a promotion goes live.
///
/// Pure UI — the API neither stores a product's cost nor refuses a discount
/// below it, so this protects nothing by itself. It shows the seller what the
/// payout would be, using the platform commission and the product's Growth
/// rate, so a loss is visible before the voucher is created.
class MarginProtectionCard extends StatefulWidget {
  const MarginProtectionCard({super.key});

  @override
  State<MarginProtectionCard> createState() => _MarginProtectionCardState();
}

class _MarginProtectionCardState extends State<MarginProtectionCard> {
  final TextEditingController _price = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _discount = TextEditingController(text: '10');
  final TextEditingController _shipping = TextEditingController(text: '0');
  bool _percent = true;
  List<Product> _products = const <Product>[];
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    for (final c in <TextEditingController>[
      _price,
      _cost,
      _discount,
      _shipping,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _loadProducts() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) return;
    final result =
        await injector<CatalogRepository>().getStoreProducts(storeId);
    if (!mounted || result is! DataSuccess<List<Product>>) return;
    setState(() => _products = result.value);
  }

  @override
  void dispose() {
    _price.dispose();
    _cost.dispose();
    _discount.dispose();
    _shipping.dispose();
    super.dispose();
  }

  int _read(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _pick(Product? p) {
    setState(() => _product = p);
    if (p != null) _price.text = '${p.basePrice}';
  }

  @override
  Widget build(BuildContext context) {
    final sim = MarginSimulation.of(
      normalPrice: _read(_price),
      cost: _read(_cost),
      discountValue: _read(_discount),
      discountIsPercent: _percent,
      shippingSupport: _read(_shipping),
      growthPercent: _product?.growthCommissionPercent ?? 0,
    );
    final margin = sim.marginPercent;
    final discountLabel = _percent
        ? 'Potongan Promo Toko (-${_read(_discount).clamp(0, 100)}%)'
        : 'Potongan Promo Toko';

    return Container(
      padding: const EdgeInsets.all(XSpace.card),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
        border: Border.all(color: XColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, color: XColors.primary),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text(
                  'Proteksi Margin Toko',
                  style: XText.headingM.copyWith(color: XColors.primary),
                ),
              ),
              if (margin != null)
                XChip(
                  label: sim.isLoss
                      ? 'Rugi (${_pct(margin)})'
                      : 'Margin Aman (+${_pct(margin)})',
                  tone: sim.isLoss ? XTone.danger : XTone.success,
                ),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(
            'Simulasikan payout sebelum membuat promo. Harga modal tidak '
            'disimpan dan tidak dikirim ke server.',
            style: XText.bodyS,
          ),
          const SizedBox(height: XSpace.s12),
          XCard(
            padding: const EdgeInsets.all(XSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<Product?>(
                  initialValue: _product,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Contoh simulasi SKU',
                  ),
                  items: <DropdownMenuItem<Product?>>[
                    const DropdownMenuItem<Product?>(
                      value: null,
                      child: Text('Isi harga manual'),
                    ),
                    for (final p in _products)
                      DropdownMenuItem<Product?>(
                        value: p,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _pick,
                ),
                const SizedBox(height: XSpace.s12),
                Row(
                  children: <Widget>[
                    Expanded(child: _money(_price, 'Harga normal')),
                    const SizedBox(width: XSpace.s8),
                    Expanded(child: _money(_cost, 'Harga modal (HPP)')),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _discount,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Diskon',
                          prefixText: _percent ? null : 'Rp ',
                          suffixText: _percent ? '%' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(value: true, label: Text('%')),
                        ButtonSegment<bool>(value: false, label: Text('Rp')),
                      ],
                      selected: <bool>{_percent},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _percent = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                _money(_shipping, 'Support ongkir seller / paket'),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s12),
          XCard(
            padding: const EdgeInsets.all(XSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                XKeyValue(
                  label: 'Harga Normal Produk',
                  value: formatRupiah(sim.normalPrice),
                ),
                XKeyValue(
                  label: discountLabel,
                  value: '-${formatRupiah(sim.discount)}',
                  labelStyle: XText.bodyM.copyWith(color: XColors.danger),
                  valueStyle: XText.bodyM.copyWith(color: XColors.danger),
                ),
                XKeyValue(
                  label: 'Harga Tampil ke Pembeli',
                  value: formatRupiah(sim.buyerPrice),
                  valueStyle: XText.titleM,
                ),
                XKeyValue(
                  label: 'Support Ongkir Seller',
                  value: sim.shippingSupport == 0
                      ? formatRupiah(0)
                      : '-${formatRupiah(sim.shippingSupport)}',
                ),
                XKeyValue(
                  label: 'Komisi Xpedia '
                      '${OrderSettlement.commissionPercent.toStringAsFixed(0)}%',
                  value: '-${formatRupiah(sim.commission)}',
                ),
                if (sim.growthCommission > 0)
                  XKeyValue(
                    label: 'Komisi Growth '
                        '${_product!.growthCommissionPercent.toStringAsFixed(0)}%',
                    value: '-${formatRupiah(sim.growthCommission)}',
                  ),
                XKeyValue(label: 'Biaya Layanan', value: formatRupiah(0)),
                const Divider(height: XSpace.s16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Estimasi Payout Bersih Toko',
                              style: XText.labelM),
                          Text(
                            margin == null
                                ? 'Isi harga modal untuk cek batas rugi'
                                : sim.isLoss
                                    ? 'Batas rugi: di bawah HPP'
                                    : 'Batas rugi: Terlindungi',
                            style: XText.caption.copyWith(
                              color: margin == null
                                  ? null
                                  : sim.isLoss
                                      ? XColors.danger
                                      : XColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatRupiah(sim.payout),
                      style: XText.priceL.copyWith(
                        color: sim.isLoss ? XColors.danger : XColors.brandNavy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _pct(double v) =>
      '${v.abs().toStringAsFixed(1).replaceAll('.', ',')}%';

  Widget _money(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
      );
}
