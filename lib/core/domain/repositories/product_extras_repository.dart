import '../../data_state.dart';
import '../model/catalog/product_extras.dart';

/// Gallery, MOQ, wholesale, brand, condition, dimensions (S-27).
/// Implemented by `DemoProductExtrasRepository` until the API stores them.
abstract class ProductExtrasRepository {
  Future<DataState<ProductExtras>> getExtras(int productId);

  Future<DataError?> saveExtras(int productId, ProductExtras extras);
}
