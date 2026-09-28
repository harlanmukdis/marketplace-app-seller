import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../../di/injector.dart';
import '../../product_errors.dart';

part 'product_list_state.dart';

/// The active store's catalogue.
///
/// Reads `GET /stores/{id}/products` rather than the public list, because that
/// is the only one that shows drafts — and a seller's unpublished products are
/// the ones they most need to see.
class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit() : super(const ProductListInProgress());

  static ProductListCubit get(BuildContext context) => BlocProvider.of(context);

  final CatalogRepository _catalog = injector<CatalogRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  ProductStatusFilter _filter = ProductStatusFilter.all;

  ProductStatusFilter get filter => _filter;

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const ProductListNoStore());
      return;
    }

    emit(const ProductListInProgress());

    final result = await _catalog.getStoreProducts(storeId);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<List<Product>>(:final value):
        emit(ProductListSuccess(products: value, filter: _filter));
      case DataEmpty<List<Product>>():
        emit(ProductListSuccess(products: const <Product>[], filter: _filter));
      case DataFailed<List<Product>>(:final failure):
        emit(ProductListFailure(failure));
      case DataLoading<List<Product>>():
        break;
    }
  }

  /// Filtering is local: every page is walked on load anyway, so switching
  /// tabs needs no request.
  void setFilter(ProductStatusFilter filter) {
    _filter = filter;
    final current = state;
    if (current is ProductListSuccess) {
      emit(current.copyWith(filter: filter));
    }
  }

  void setMode(String? mode) {
    final current = state;
    if (current is ProductListSuccess) emit(current.copyWith(mode: () => mode));
  }

  void search(String query) {
    final current = state;
    if (current is ProductListSuccess) emit(current.copyWith(query: query));
  }

  /// Publishes or unpublishes a product. `PATCH` answers nothing, so the
  /// service re-reads and the updated row is folded back into the list in
  /// place — reloading the whole catalogue would lose the scroll position.
  Future<DataError?> setStatus(int productId, String status) async {
    final result = await _catalog.updateProduct(productId, status: status);
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<Product>(:final value):
        final current = state;
        if (current is ProductListSuccess) {
          emit(current.copyWith(products: _replace(current.products, value)));
        }
        return null;
      case DataFailed<Product>(:final failure):
        return explainProductError(failure);
      default:
        return const DataError(
          code: DataErrorCode.unexpected,
          message: 'Server tidak mengembalikan produk yang diperbarui.',
        );
    }
  }

  List<Product> _replace(List<Product> products, Product updated) => products
      .map((product) => product.id == updated.id ? updated : product)
      .toList(growable: false);
}
