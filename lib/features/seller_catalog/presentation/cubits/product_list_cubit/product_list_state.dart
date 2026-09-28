part of 'product_list_cubit.dart';

sealed class ProductListState {
  const ProductListState();
}

final class ProductListInProgress extends ProductListState {
  const ProductListInProgress();
}

/// No store is selected, so there is no catalogue to show. Distinct from an
/// empty catalogue: the answer is "pick a store", not "add a product".
final class ProductListNoStore extends ProductListState {
  const ProductListNoStore();
}

final class ProductListFailure extends ProductListState {
  const ProductListFailure(this.error);

  final DataError error;
}

final class ProductListSuccess extends ProductListState {
  const ProductListSuccess({
    required this.products,
    this.filter = ProductStatusFilter.all,
    this.mode,
    this.query = '',
  });

  final List<Product> products;
  final ProductStatusFilter filter;

  /// A `fulfillment_mode` to narrow to, or null for all.
  final String? mode;
  final String query;

  List<Product> get visible {
    final q = query.trim().toLowerCase();
    return products
        .where(filter.matches)
        .where((p) => mode == null || p.fulfillmentMode == mode)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  int countOf(ProductStatusFilter f) => products.where(f.matches).length;

  int get draftCount => products.where((product) => product.isDraft).length;

  bool get isEmpty => products.isEmpty;

  ProductListSuccess copyWith({
    List<Product>? products,
    ProductStatusFilter? filter,
    String? Function()? mode,
    String? query,
  }) =>
      ProductListSuccess(
        products: products ?? this.products,
        filter: filter ?? this.filter,
        mode: mode == null ? this.mode : mode(),
        query: query ?? this.query,
      );
}

/// The S-26 tabs. Applied client-side: the whole catalogue is walked page by
/// page anyway, so the chips switch instantly. "Stok Kosong" from the design
/// is not a tab — the list payload carries no stock, so it could only be
/// guessed; out-of-stock shows on each product's own screen instead.
enum ProductStatusFilter {
  all('Semua'),
  active('Aktif'),
  draft('Draf'),
  inactive('Nonaktif'),
  discontinued('Discontinued');

  const ProductStatusFilter(this.label);

  final String label;

  bool matches(Product p) => switch (this) {
        all => true,
        active => p.status == ProductStatus.active,
        draft => p.status == ProductStatus.draft,
        inactive => p.status == ProductStatus.inactive ||
            p.status == ProductStatus.archived,
        discontinued => p.fulfillmentMode == FulfillmentMode.discontinued,
      };
}
