import '../../data_state.dart';
import '../../domain/model/notification/announcement.dart';
import '../../domain/repositories/discovery_repository.dart';
import 'demo_support.dart';

class DemoDiscoveryRepository implements DiscoveryRepository {
  const DemoDiscoveryRepository();

  @override
  Future<DataState<List<Announcement>>> getAnnouncements() {
    final now = DateTime.now();
    return demoOr(
        'Pengumuman resmi Xpedia',
        () => <Announcement>[
              Announcement(
                id: 1,
                kind: AnnouncementKind.official,
                title: 'Penyesuaian Skema Komisi 5%',
                body: 'Berlaku efektif per tanggal 1 bulan depan untuk seluruh '
                    'kategori produk.',
                cta: 'Pelajari Selengkapnya',
                publishedAt: now.subtract(const Duration(days: 2)),
              ),
              Announcement(
                id: 2,
                kind: AnnouncementKind.promo,
                title: 'Xpedia Mega Brand Festival',
                body:
                    'Daftarkan produk Anda sekarang dan dapatkan subsidi ongkir '
                    'hingga 100%.',
                cta: 'Daftar Campaign',
                publishedAt: now.subtract(const Duration(days: 1)),
              ),
            ]);
  }

  static final List<HelpArticle> _articles = <HelpArticle>[
    HelpArticle(
      id: 1,
      title: 'Cara Mengajukan Penambahan Kuota Katalog di Atas 500 SKU',
      category: 'Panduan Resmi Operasional',
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    const HelpArticle(
      id: 2,
      title: 'Batas Waktu Cetak Resi dan Pembatalan Otomatis',
      category: 'Pesanan & SLA',
    ),
    const HelpArticle(
      id: 3,
      title: 'Menanggapi Komplain & Retur dengan Bukti Unboxing',
      category: 'Komplain & Retur',
    ),
    const HelpArticle(
      id: 4,
      title: 'Penarikan Dana: PIN, Rekening, dan Waktu Proses',
      category: 'Xpedia Wallet',
    ),
    const HelpArticle(
      id: 5,
      title: 'Mengapa Produk Saya Ditinjau Tim Kurasi?',
      category: 'Moderasi Produk',
    ),
  ];

  @override
  Future<DataState<List<HelpArticle>>> searchHelp(String query) {
    final q = query.trim().toLowerCase();
    return demoOr(
        'Pusat bantuan',
        () => _articles
            .where((a) =>
                q.isEmpty ||
                a.title.toLowerCase().contains(q) ||
                a.category.toLowerCase().contains(q))
            .toList());
  }
}
