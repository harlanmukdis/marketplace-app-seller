import '../../data_state.dart';
import '../model/store/storefront_extras.dart';

/// Mini banners and home highlights (S-34). Implemented by
/// `DemoStorefrontExtrasRepository` until the store profile has them.
abstract class StorefrontExtrasRepository {
  Future<DataState<List<MiniBanner>>> getMiniBanners(int storeId);

  Future<DataError?> setMiniBanner(int storeId, int slot, String imageUrl);

  Future<DataState<List<StorefrontHighlight>>> getHighlights(int storeId);

  Future<DataError?> setHighlight(int storeId, String key, bool enabled);
}
