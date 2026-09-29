import 'package:flutter/material.dart';

import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/model/catalog/product_variant.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/widgets/state_widgets.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

class FlashSaleProductDraft {
  const FlashSaleProductDraft({
    required this.productVariantId,
    required this.originalPrice,
    required this.flashPrice,
    required this.stockQuota,
    required this.maxQtyPerUser,
  });

  final int productVariantId;
  final int originalPrice;
  final int flashPrice;
  final int stockQuota;
  final int maxQtyPerUser;
}

Future<FlashSaleProductDraft?> showFlashSaleProductSheet(
  BuildContext context, {
  required Future<List<Product>> Function() products,
  required Future<List<ProductVariant>> Function(int productId) variantsOf,
  required Set<int> takenVariantIds,
}) =>
    showModalBottomSheet<FlashSaleProductDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlashSaleProductSheet(
        products: products,
        variantsOf: variantsOf,
        takenVariantIds: takenVariantIds,
      ),
    );

/// Picks a variant and sets its sale price.
///
/// Three steps rather than one list, because stock and pricing live on the
/// **variant** while the catalogue listing carries no variants at all — they
/// are detail-only. Asking for the product first means one extra call for the
/// product that was chosen, instead of an N+1 across the whole catalogue just
/// to fill a dropdown.
class _FlashSaleProductSheet extends StatefulWidget {
  const _FlashSaleProductSheet({
    required this.products,
    required this.variantsOf,
    required this.takenVariantIds,
  });

  final Future<List<Product>> Function() products;
  final Future<List<ProductVariant>> Function(int productId) variantsOf;
  final Set<int> takenVariantIds;

  @override
  State<_FlashSaleProductSheet> createState() => _FlashSaleProductSheetState();
}

class _FlashSaleProductSheetState extends State<_FlashSaleProductSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _quota = TextEditingController();
  final TextEditingController _perUser = TextEditingController(text: '1');

  late Future<List<Product>> _productsFuture = widget.products();

  Product? _product;
  Future<List<ProductVariant>>? _variantsFuture;
  ProductVariant? _variant;

  @override
  void dispose() {
    _price.dispose();
    _quota.dispose();
    _perUser.dispose();
    super.dispose();
  }

  void _chooseProduct(Product product) {
    setState(() {
      _product = product;
      _variant = null;
      _variantsFuture = widget.variantsOf(product.id);
    });
  }

  void _chooseVariant(ProductVariant variant) {
    setState(() {
      _variant = variant;
      // Seeded with a round 10% off, which is at least a valid discount and
      // saves the common case a calculation.
      if (_price.text.isEmpty && variant.price > 0) {
        _price.text = (variant.price * 9 ~/ 10).toString();
      }
    });
  }

  String? _validatePrice(String? input) {
    final parsed = parseRupiahInput(input);
    if (parsed == null || parsed <= 0) return 'Wajib diisi, lebih dari 0';
    final original = _variant?.price ?? 0;
    if (original > 0 && parsed >= original) {
      return 'Harus di bawah harga normal (${formatRupiah(original)})';
    }
    return null;
  }

  void _submit() {
    final variant = _variant;
    if (variant == null) return;
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      FlashSaleProductDraft(
        productVariantId: variant.id,
        originalPrice: variant.price,
        flashPrice: parseRupiahInput(_price.text) ?? 0,
        stockQuota: parseRupiahInput(_quota.text) ?? 0,
        maxQtyPerUser: parseRupiahInput(_perUser.text) ?? 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: 20.pa,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Tambah produk ke flash sale', style: XText.headingM),
                4.sbh,
                Text(
                  'Sekali masuk, produk tidak bisa dikeluarkan dari flash sale '
                  'ini dan harganya tidak bisa diubah.',
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
                16.sbh,
                const _StepLabel(index: 1, label: 'Pilih produk'),
                8.sbh,
                _ProductPicker(
                  future: _productsFuture,
                  selected: _product,
                  onSelected: _chooseProduct,
                  onRetry: () => setState(
                    () => _productsFuture = widget.products(),
                  ),
                ),
                if (_variantsFuture != null) ...<Widget>[
                  20.sbh,
                  const _StepLabel(index: 2, label: 'Pilih varian'),
                  8.sbh,
                  _VariantPicker(
                    future: _variantsFuture!,
                    selected: _variant,
                    takenVariantIds: widget.takenVariantIds,
                    onSelected: _chooseVariant,
                  ),
                ],
                if (_variant != null) ...<Widget>[
                  20.sbh,
                  const _StepLabel(index: 3, label: 'Harga & kuota'),
                  8.sbh,
                  Text(
                    'Harga normal ${formatRupiah(_variant!.price)}',
                    style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
                  ),
                  12.sbh,
                  CustomTextFormField(
                    controller: _price,
                    labelText: 'Harga flash sale (Rp)',
                    keyboardType: TextInputType.number,
                    validator: _validatePrice,
                  ),
                  16.sbh,
                  CustomTextFormField(
                    controller: _quota,
                    labelText: 'Kuota stok flash sale',
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveAmount('Kuota stok'),
                  ),
                  6.sbh,
                  Text(
                    'Kuota ini berdiri sendiri — server tidak mencocokkannya '
                    'dengan stok gudang, jadi angka di atas stok nyata akan '
                    'terjual melebihi persediaan.',
                    style: XText.caption.copyWith(color: kLightThirdColor),
                  ),
                  16.sbh,
                  CustomTextFormField(
                    controller: _perUser,
                    labelText: 'Maksimal per pembeli',
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveAmount('Batas per pembeli'),
                  ),
                  24.sbh,
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Tambahkan'),
                  ),
                ],
                12.sbh,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kLightPrimaryColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: XText.caption.copyWith(color: kWhiteColor),
          ),
        ),
        8.sbw,
        Text(label, style: XText.labelL),
      ],
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.future,
    required this.selected,
    required this.onSelected,
    required this.onRetry,
  });

  final Future<List<Product>> future;
  final Product? selected;
  final ValueChanged<Product> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingIndicatorView(),
          );
        }
        final products = snapshot.data ?? const <Product>[];
        if (products.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Toko ini belum punya produk untuk didiskon.',
                style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
              ),
              8.sbh,
              TextButton(onPressed: onRetry, child: const Text('Muat ulang')),
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final product in products)
              ChoiceChip(
                label: Text(product.name),
                selected: selected?.id == product.id,
                onSelected: (_) => onSelected(product),
              ),
          ],
        );
      },
    );
  }
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.future,
    required this.selected,
    required this.takenVariantIds,
    required this.onSelected,
  });

  final Future<List<ProductVariant>> future;
  final ProductVariant? selected;
  final Set<int> takenVariantIds;
  final ValueChanged<ProductVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductVariant>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingIndicatorView(),
          );
        }
        final all = snapshot.data ?? const <ProductVariant>[];
        // Already in this sale: adding one twice breaks a UNIQUE key and comes
        // back as an HTML 500, so they are not offered at all.
        final available = all
            .where((variant) => !takenVariantIds.contains(variant.id))
            .toList(growable: false);

        if (all.isEmpty) {
          return Text(
            'Produk ini tidak punya varian yang bisa dibaca.',
            style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
          );
        }
        if (available.isEmpty) {
          return Text(
            'Semua varian produk ini sudah ada di flash sale tersebut.',
            style: XText.bodySPrimary.copyWith(color: kWarningColor),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final variant in available)
              ChoiceChip(
                label: Text('${variant.sku} · ${formatRupiah(variant.price)}'),
                selected: selected?.id == variant.id,
                onSelected: (_) => onSelected(variant),
              ),
          ],
        );
      },
    );
  }
}
