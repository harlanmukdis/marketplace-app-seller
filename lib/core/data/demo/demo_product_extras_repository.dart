import '../../data_state.dart';
import '../../domain/model/catalog/product_extras.dart';
import '../../domain/repositories/product_extras_repository.dart';
import 'demo_support.dart';

/// Kept in memory for the session; photos themselves are really uploaded.
class DemoProductExtrasRepository implements ProductExtrasRepository {
  DemoProductExtrasRepository();

  final Map<int, ProductExtras> _store = <int, ProductExtras>{};

  @override
  Future<DataState<ProductExtras>> getExtras(int productId) => demoOr(
      'Detail tambahan produk',
      () => _store[productId] ?? const ProductExtras());

  @override
  Future<DataError?> saveExtras(int productId, ProductExtras extras) async {
    if (extras.minOrder < 1) {
      return const DataError(
        code: DataErrorCode.validationError,
        message: 'Minimum pembelian paling sedikit 1.',
      );
    }
    for (var i = 1; i < extras.wholesale.length; i++) {
      if (extras.wholesale[i].minQuantity <=
              extras.wholesale[i - 1].minQuantity ||
          extras.wholesale[i].unitPrice >= extras.wholesale[i - 1].unitPrice) {
        return const DataError(
          code: DataErrorCode.validationError,
          message: 'Tiap tingkat grosir harus berjumlah lebih banyak dan '
              'berharga lebih murah dari tingkat sebelumnya.',
        );
      }
    }
    final error = await demoWrite('Detail tambahan produk');
    if (error == null) _store[productId] = extras;
    return error;
  }
}
