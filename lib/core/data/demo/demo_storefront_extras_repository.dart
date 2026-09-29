import '../../data_state.dart';
import '../../domain/model/store/storefront_extras.dart';
import '../../domain/repositories/storefront_extras_repository.dart';
import 'demo_support.dart';

/// Kept in memory for the session. The image itself is uploaded for real
/// (`/media/upload`); only where it is attached is simulated.
class DemoStorefrontExtrasRepository implements StorefrontExtrasRepository {
  DemoStorefrontExtrasRepository();

  final Map<int, String> _banners = <int, String>{};
  final Map<String, bool> _highlights = <String, bool>{
    HighlightKey.flashSale: true,
    HighlightKey.signature: true,
    HighlightKey.videoReviews: false,
  };

  @override
  Future<DataState<List<MiniBanner>>> getMiniBanners(int storeId) => demoOr(
      'Banner mini',
      () => <MiniBanner>[
            MiniBanner(
                slot: 1, imageUrl: _banners[1], caption: 'Voucher Diskon Toko'),
            MiniBanner(
                slot: 2, imageUrl: _banners[2], caption: 'Produk Baru Rilis'),
          ]);

  @override
  Future<DataError?> setMiniBanner(
      int storeId, int slot, String imageUrl) async {
    final error = await demoWrite('Banner mini');
    if (error == null) _banners[slot] = imageUrl;
    return error;
  }

  @override
  Future<DataState<List<StorefrontHighlight>>> getHighlights(int storeId) =>
      demoOr(
          'Sorotan beranda toko',
          () => <StorefrontHighlight>[
                StorefrontHighlight(
                  key: HighlightKey.flashSale,
                  title: 'Produk Flash Sale / Diskon',
                  description:
                      'Pita promo berbatas waktu di bagian paling atas '
                      'beranda.',
                  enabled: _highlights[HighlightKey.flashSale]!,
                ),
                StorefrontHighlight(
                  key: HighlightKey.signature,
                  title: 'Badge Signature & Garansi',
                  description: 'Sinyal kepercayaan: 100% original & 7 hari '
                      'garansi pengembalian.',
                  enabled: _highlights[HighlightKey.signature]!,
                ),
                StorefrontHighlight(
                  key: HighlightKey.videoReviews,
                  title: 'Video Ulasan Teratas',
                  description: 'Sematkan cuplikan video unboxing dari pembeli '
                      'terverifikasi.',
                  enabled: _highlights[HighlightKey.videoReviews]!,
                ),
              ]);

  @override
  Future<DataError?> setHighlight(int storeId, String key, bool enabled) async {
    final error = await demoWrite('Sorotan beranda toko');
    if (error == null) _highlights[key] = enabled;
    return error;
  }
}
