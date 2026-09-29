import '../../data_state.dart';
import '../../domain/model/promotion/platform_campaign.dart';
import '../../domain/repositories/campaign_repository.dart';
import 'demo_support.dart';

class DemoCampaignRepository implements CampaignRepository {
  DemoCampaignRepository();

  final Map<int, List<int>> _submitted = <int, List<int>>{};

  @override
  Future<DataState<List<PlatformCampaign>>> getOpenCampaigns(int storeId) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return demoOr(
        'Daftar campaign Xpedia',
        () => <PlatformCampaign>[
              PlatformCampaign(
                id: 501,
                name: 'Xpedia Mega Brand Festival',
                description:
                    'Festival belanja nasional dengan subsidi ongkir dari '
                    'platform untuk produk terpilih.',
                startAt: day.add(const Duration(days: 10)),
                endAt: day.add(const Duration(days: 13)),
                registerBy: day.add(const Duration(days: 5)),
                minDiscountPercent: 10,
                benefit: 'Subsidi ongkir hingga 100% + slot banner beranda',
                submittedProductIds: _submitted[501] ?? const <int>[],
              ),
              PlatformCampaign(
                id: 502,
                name: 'Gajian Hemat Akhir Bulan',
                description: 'Promo berkala tanggal 25–31 untuk kategori '
                    'kebutuhan harian.',
                startAt: DateTime(now.year, now.month, 25),
                endAt: DateTime(now.year, now.month + 1, 0),
                registerBy: DateTime(now.year, now.month, 22),
                minDiscountPercent: 5,
                benefit:
                    'Label "Gajian Hemat" dan prioritas di halaman campaign',
                submittedProductIds: _submitted[502] ?? const <int>[],
              ),
            ]);
  }

  @override
  Future<DataError?> submitProducts(
    int storeId,
    int campaignId,
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) {
      return const DataError(
        code: DataErrorCode.validationError,
        message: 'Pilih minimal satu produk.',
      );
    }
    final error = await demoWrite('Pendaftaran campaign');
    if (error == null) {
      _submitted[campaignId] = <int>{
        ...?_submitted[campaignId],
        ...productIds,
      }.toList();
    }
    return error;
  }
}
