import 'package:flutter/material.dart';

import '../../../../../core/data/datasources/remote/service/merchandising_service.dart'
    show BundleItemDraft;
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/widgets/state_widgets.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

class BundleDraft {
  const BundleDraft({
    required this.name,
    required this.bundlePrice,
    required this.items,
  });

  final String name;
  final int bundlePrice;
  final List<BundleItemDraft> items;
}

Future<BundleDraft?> showBundleFormSheet(
  BuildContext context, {
  required Future<List<Product>> Function() products,
}) =>
    showModalBottomSheet<BundleDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BundleFormSheet(products: products),
    );

/// Creates a bundle.
///
/// **Its contents are final.** `PATCH /bundles/{id}` reaches the name, the
/// price and the status, and nothing reaches the items — so a bundle whose
/// products turn out wrong has to be switched off and replaced. The sheet
/// says so before it submits.
///
/// Quantities are per line and default to one. A variant is not asked for:
/// the API accepts a product alone, in which case it prices from
/// `base_price`, and picking variants here would mean a detail call per
/// product for a choice most bundles do not need.
class _BundleFormSheet extends StatefulWidget {
  const _BundleFormSheet({required this.products});

  final Future<List<Product>> Function() products;

  @override
  State<_BundleFormSheet> createState() => _BundleFormSheetState();
}

class _BundleFormSheetState extends State<_BundleFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();

  late final Future<List<Product>> _productsFuture = widget.products();

  /// product id -> quantity. Absent means not in the bundle.
  final Map<int, int> _chosen = <int, int>{};
  List<Product> _catalogue = const <Product>[];

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  int get _partsTotal => _chosen.entries.fold(0, (sum, entry) {
        final product = _catalogue
            .where((candidate) => candidate.id == entry.key)
            .firstOrNull;
        return sum + (product?.basePrice ?? 0) * entry.value;
      });

  void _toggle(Product product) {
    setState(() {
      if (_chosen.containsKey(product.id)) {
        _chosen.remove(product.id);
      } else {
        _chosen[product.id] = 1;
      }
    });
  }

  void _setQuantity(int productId, int quantity) {
    if (quantity < 1) return;
    setState(() => _chosen[productId] = quantity);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu produk.')),
      );
      return;
    }

    Navigator.of(context).pop(
      BundleDraft(
        name: _name.text.trim(),
        bundlePrice: parseRupiahInput(_price.text) ?? 0,
        items: <BundleItemDraft>[
          for (final entry in _chosen.entries)
            BundleItemDraft(productId: entry.key, quantity: entry.value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partsTotal = _partsTotal;
    final price = parseRupiahInput(_price.text) ?? 0;

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
                Text('Bundel baru', style: XText.headingM),
                4.sbh,
                Text(
                  'Isi bundel tidak bisa diubah setelah dibuat — nama, harga, '
                  'dan status masih bisa, produknya tidak. Bundel juga tidak '
                  'bisa dihapus, hanya dinonaktifkan.',
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _name,
                  labelText: 'Nama bundel',
                  validator: Validators.required('Nama bundel'),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _price,
                  labelText: 'Harga bundel (Rp)',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: Validators.positiveAmount('Harga bundel'),
                ),
                20.sbh,
                Text('Isi bundel', style: XText.labelL),
                8.sbh,
                _ProductPicker(
                  future: _productsFuture,
                  chosen: _chosen,
                  onLoaded: (products) => _catalogue = products,
                  onToggle: _toggle,
                  onQuantity: _setQuantity,
                ),
                if (_chosen.isNotEmpty) ...<Widget>[
                  16.sbh,
                  _SavingsLine(partsTotal: partsTotal, bundlePrice: price),
                ],
                24.sbh,
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Buat bundel'),
                ),
                12.sbh,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the bundle saves against buying the parts separately — the number
/// that decides whether the bundle is worth anything. The server only checks
/// that the price is above zero, so a "bundle" dearer than its parts is
/// perfectly acceptable to it.
class _SavingsLine extends StatelessWidget {
  const _SavingsLine({required this.partsTotal, required this.bundlePrice});

  final int partsTotal;
  final int bundlePrice;

  @override
  Widget build(BuildContext context) {
    final saves = bundlePrice > 0 && bundlePrice < partsTotal;
    final difference = (partsTotal - bundlePrice).abs();

    return Container(
      padding: 12.pa,
      decoration: BoxDecoration(
        color: (saves ? kSuccessColor : kWarningColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Harga satuan bila dibeli terpisah: ${formatRupiah(partsTotal)}',
            style: XText.bodySPrimary,
          ),
          4.sbh,
          Text(
            bundlePrice <= 0
                ? 'Isi harga bundel untuk melihat selisihnya.'
                : saves
                    ? 'Pembeli hemat ${formatRupiah(difference)}.'
                    : 'Bundel ini ${formatRupiah(difference)} lebih mahal '
                        'daripada beli satuan — server tetap menerimanya.',
            style: XText.bodySPrimary
                .copyWith(color: saves ? kSuccessColor : kWarningColor),
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.future,
    required this.chosen,
    required this.onLoaded,
    required this.onToggle,
    required this.onQuantity,
  });

  final Future<List<Product>> future;
  final Map<int, int> chosen;
  final ValueChanged<List<Product>> onLoaded;
  final ValueChanged<Product> onToggle;
  final void Function(int productId, int quantity) onQuantity;

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
        onLoaded(products);

        if (products.isEmpty) {
          return Text(
            'Toko ini belum punya produk untuk dibundel.',
            style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
          );
        }

        return Column(
          children: <Widget>[
            for (final product in products)
              _PickerRow(
                product: product,
                quantity: chosen[product.id],
                onToggle: () => onToggle(product),
                onQuantity: (quantity) => onQuantity(product.id, quantity),
              ),
          ],
        );
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.product,
    required this.quantity,
    required this.onToggle,
    required this.onQuantity,
  });

  final Product product;
  final int? quantity;
  final VoidCallback onToggle;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    final isChosen = quantity != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isChosen,
              onChanged: (_) => onToggle(),
            ),
          ),
          8.sbw,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name, style: XText.bodyM),
                Text(
                  // A draft can go into a bundle; unlike a showcase, the
                  // bundle detail does list it.
                  '${formatRupiah(product.basePrice)}'
                  '${product.isDraft ? ' · draf' : ''}',
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
              ],
            ),
          ),
          if (isChosen)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () => onQuantity(quantity! - 1),
                ),
                Text('$quantity', style: XText.labelL),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () => onQuantity(quantity! + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
