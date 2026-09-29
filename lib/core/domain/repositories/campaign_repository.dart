import '../../data_state.dart';
import '../model/promotion/platform_campaign.dart';

/// Platform campaigns open to sellers (S-31). Implemented by
/// `DemoCampaignRepository` until the list is exposed to sellers; the
/// submit call exists and will replace the demo write then.
abstract class CampaignRepository {
  Future<DataState<List<PlatformCampaign>>> getOpenCampaigns(int storeId);

  Future<DataError?> submitProducts(
    int storeId,
    int campaignId,
    List<int> productIds,
  );
}
