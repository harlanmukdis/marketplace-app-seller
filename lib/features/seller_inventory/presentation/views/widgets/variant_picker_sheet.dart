import 'package:flutter/material.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/model/catalog/product_variant.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/widgets/state_widgets.dart';
import '../../../../../di/injector.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// The variant a stock movement will apply to.
class PickedVariant {
  const PickedVariant({required this.variant, required this.productName});

  final ProductVariant variant;
  final String productName;

  String get label => variant.optionsLabel.isEmpty
      ? productName
      : '$productName · ${variant.optionsLabel}';
}

Future<PickedVariant?> showVariantPicker(BuildContext context) =>
    showModalBottomSheet<PickedVariant>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VariantPicker(),
    );

/// Picks a product, then one of its variants.
///
/// Two steps rather than one flat list on purpose: the store's product list
/// carries no variants, and they only arrive with a product's detail. Loading
/// every product's detail up front to flatten the list would be one request per
/// product for a screen the seller may close immediately.
class _VariantPicker extends StatefulWidget {
  const _VariantPicker();

  @override
  State<_VariantPicker> createState() => _VariantPickerState();
}

class _VariantPickerState extends State<_VariantPicker> {
  final CatalogRepository _catalog = injector<CatalogRepository>();

  List<Product>? _products;
  DataError? _error;

  /// Set once a product is chosen and its detail has loaded.
  Product? _openProduct;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) return;

    final result = await _catalog.getStoreProducts(storeId);
    if (!mounted) return;

    setState(() {
      switch (result) {
        case DataSuccess<List<Product>>(:final value):
          _products = value;
        case DataEmpty<List<Product>>():
          _products = const <Product>[];
        case DataFailed<List<Product>>(:final failure):
          _error = failure;
        case DataLoading<List<Product>>():
          break;
      }
    });
  }

  Future<void> _openVariants(Product product) async {
    setState(() => _loadingDetail = true);
    final result = await _catalog.getProduct(product.id);
    if (!mounted) return;

    setState(() {
      _loadingDetail = false;
      switch (result) {
        case DataSuccess<Product>(:final value):
          _openProduct = value;
        case DataFailed<Product>(:final failure):
          _error = failure;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.screenHeight * 0.7,
      child: Padding(
        padding: 20.pa,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (_openProduct != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => setState(() => _openProduct = null),
                  ),
                Expanded(
                  child: Text(
                    _openProduct == null ? 'Pilih produk' : 'Pilih varian',
                    style: XText.headingM,
                  ),
                ),
              ],
            ),
            12.sbh,
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final error = _error;
    if (error != null) return ErrorStateView(error: error);
    if (_loadingDetail) return const LoadingIndicatorView();

    final open = _openProduct;
    if (open != null) return _variantList(open);

    final products = _products;
    if (products == null) return const LoadingIndicatorView();
    if (products.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_2_outlined,
        message: 'Belum ada produk di toko ini.',
      );
    }

    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(product.name, style: XText.bodyM),
          subtitle: Text(
            ProductStatus.label(product.status),
            style: XText.caption.copyWith(color: XColors.textTertiary),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => _openVariants(product),
        );
      },
    );
  }

  Widget _variantList(Product product) {
    if (product.variants.isEmpty) {
      return const EmptyStateView(
        message: 'Produk ini belum punya varian.',
      );
    }

    return ListView.separated(
      itemCount: product.variants.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final variant = product.variants[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            variant.optionsLabel.isEmpty
                ? 'Varian bawaan'
                : variant.optionsLabel,
            style: XText.bodyM,
          ),
          subtitle: Text(
            '${variant.sku} · ${formatRupiah(variant.price)}',
            style: XText.caption.copyWith(color: XColors.textTertiary),
          ),
          onTap: () => Navigator.of(context).pop(
            PickedVariant(variant: variant, productName: product.name),
          ),
        );
      },
    );
  }
}
