import '../../data_state.dart';
import '../../domain/model/catalog/product.dart';
import '../../domain/model/performance/store_insights.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/store_insights_repository.dart';
import '../../utils/format_helper.dart';
import 'demo_support.dart';

/// Sample analytics for S-33. Best sellers borrow the store's own product
/// names so the screen reads naturally; the figures are invented and the
/// section is marked "Data contoh".
class DemoStoreInsightsRepository implements StoreInsightsRepository {
  DemoStoreInsightsRepository(this._catalog);

  final CatalogRepository _catalog;

  static const String _feature = 'Analitik kunjungan';

  @override
  Future<DataState<ConversionFunnel>> getFunnel(int storeId, {int days = 30}) {
    final k = days <= 1 ? 1 / 30 : days / 30;
    int n(int v) => (v * k).round();
    return demoOr(
        _feature,
        () => ConversionFunnel(
              steps: <FunnelStep>[
                FunnelStep(label: 'Kunjungan Toko', count: n(38400)),
                FunnelStep(label: 'Produk Dilihat (PDP)', count: n(22100)),
                FunnelStep(label: 'Tambah ke Keranjang', count: n(4850)),
                FunnelStep(label: 'Menuju Checkout', count: n(1820)),
                FunnelStep(label: 'Pesanan Berhasil Dibayar', count: n(1482)),
              ],
              bestCategory: 'Makanan & Minuman',
            ));
  }

  @override
  Future<DataState<List<TrafficSource>>> getTrafficSources(int storeId) =>
      demoOr(
          _feature,
          () => const <TrafficSource>[
                TrafficSource(label: 'Pencarian Alami Xpedia', percent: 48),
                TrafficSource(
                    label: 'Rekomendasi Algoritma / Growth', percent: 28),
                TrafficSource(
                    label: 'Kunjungan Langsung / Etalase', percent: 14),
                TrafficSource(label: 'Sesi Live Selling', percent: 10),
              ]);

  @override
  Future<DataState<List<TopProduct>>> getTopProducts(int storeId) async {
    final products = await _catalog.getStoreProducts(storeId);
    final names = products is DataSuccess<List<Product>>
        ? products.value.take(3).toList()
        : const <Product>[];
    const units = <int>[412, 284, 156];
    return demoOr(
        'Produk terlaris',
        () => <TopProduct>[
              for (var i = 0; i < 3; i++)
                TopProduct(
                  productId: i < names.length ? names[i].id : null,
                  name: i < names.length ? names[i].name : 'Produk ${i + 1}',
                  unitsSold: units[i],
                  revenue: units[i] *
                      (i < names.length && names[i].basePrice > 0
                          ? names[i].basePrice
                          : 50000),
                ),
            ]);
  }
}

class DemoCatalogQualityRepository implements CatalogQualityRepository {
  DemoCatalogQualityRepository(this._catalog);

  final CatalogRepository _catalog;
  final Map<int, GrowthDuration> _durations = <int, GrowthDuration>{};

  @override
  Future<DataState<List<ProductModeration>>> getModeration(int storeId) async {
    final now = DateTime.now();
    final products = await _catalog.getStoreProducts(storeId);
    final approved = products is DataSuccess<List<Product>>
        ? products.value.where((p) => p.status == 'active').take(2).toList()
        : const <Product>[];
    return demoOr(
        'Status moderasi produk',
        () => <ProductModeration>[
              ProductModeration(
                sku: 'PWB-20K-BLK',
                productName: 'Powerbank 20.000mAh Dual Port Fast Charging',
                category: 'Elektronik & Aksesori Daya',
                state: ModerationState.needsFix,
                issueTitle: 'Pelanggaran Aturan Kategori / Compliance',
                issueDetail:
                    'Produk baterai/powerbank wajib mencantumkan label '
                    'kapasitas Wh (Watt-hour) pada foto fisik dan menyertakan '
                    'dokumen sertifikasi untuk pengiriman antar pulau.',
                submittedAt: now.subtract(const Duration(hours: 20)),
              ),
              ProductModeration(
                sku: 'TS-DRY-01',
                productName: 'T-Shirt Jersey Olahraga Dryfit "Brand Terkenal"',
                category: 'Pakaian Pria & Olahraga',
                state: ModerationState.rejected,
                issueTitle: 'Klaim Merek Terdaftar (HAKI)',
                issueDetail:
                    'Penggunaan merek dagang memerlukan verifikasi Surat '
                    'Penunjukan Distributor Resmi atau sertifikat HAKI. Hapus kata '
                    'kunci merek atau ajukan verifikasi Official Store.',
                decidedAt: now.subtract(const Duration(hours: 6)),
              ),
              ProductModeration(
                sku: 'KOPI-LBK-500',
                productName: 'Kopi Luwak Liar 500g',
                category: 'Makanan & Minuman',
                state: ModerationState.inReview,
                submittedAt: now.subtract(const Duration(hours: 3)),
                estimatedDoneAt: now.add(const Duration(hours: 6)),
              ),
              for (final p in approved)
                ProductModeration(
                  productId: p.id,
                  sku: 'SKU-${p.id}',
                  productName: p.name,
                  category: 'Katalog toko',
                  state: ModerationState.approved,
                  decidedAt: now.subtract(const Duration(days: 1)),
                ),
            ]);
  }

  @override
  Future<DataState<NaturalPerformanceScore>> getNaturalPerformance(
          int storeId) =>
      demoOr(
          'Skor Natural Performance',
          () => const NaturalPerformanceScore(
                score: 78,
                components: <(String, int)>[
                  ('Rating & ulasan', 24),
                  ('Ketepatan kirim', 22),
                  ('Waktu balas chat', 17),
                  ('Tingkat pembatalan', 15),
                ],
              ));

  @override
  Future<DataState<GrowthDuration>> getGrowthDuration(int productId) => demoOr(
      'Durasi Growth', () => _durations[productId] ?? GrowthDuration.sevenDays);

  @override
  Future<DataError?> setGrowthDuration(
      int productId, GrowthDuration value) async {
    final error = await demoWrite('Durasi Growth');
    if (error == null) _durations[productId] = value;
    return error;
  }

  @override
  Future<DataState<GrowthProjection>> getGrowthProjection(
    int productId, {
    required double percent,
    required int price,
  }) {
    // A saturating lift: +0% at 0, about +170% at 10%, capped near +200%.
    final lift = percent <= 0 ? 0.0 : 2.0 * (1 - 1 / (1 + percent / 6));
    String up(num v) => '+${(v * 100).round()}%';
    int w(int base) => (base * (1 + lift)).round();
    const views = 4200, clicks = 310, sold = 14;
    return demoOr(
        'Proyeksi Growth',
        () => GrowthProjection(rows: <(String, String, String, String, String)>[
              (
                'Tayangan Produk',
                'Pencarian & Beranda',
                formatThousands(views),
                formatThousands(w(views)),
                up(lift)
              ),
              (
                'Klik Halaman',
                'Rasio Kunjungan PDP',
                formatThousands(clicks),
                formatThousands(w(clicks)),
                up(lift)
              ),
              (
                'Potensi Terjual',
                'Checkout Sukses',
                '$sold unit',
                '${w(sold)} unit',
                up(lift)
              ),
              (
                'Estimasi Omzet',
                'Gross Nilai Barang',
                formatRupiah(sold * price),
                formatRupiah(w(sold) * price),
                up(lift)
              ),
            ]));
  }
}
