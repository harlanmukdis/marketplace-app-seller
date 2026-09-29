import '../../data_state.dart';
import '../model/wallet/wallet_extras.dart';

/// Held balance and the seller's own withdrawal history (S-38).
/// Implemented by `DemoWalletExtrasRepository` until the API has both.
abstract class WalletExtrasRepository {
  Future<DataState<HeldBalance>> getHeldBalance(int storeId);

  Future<DataState<List<WithdrawalRecord>>> getWithdrawals(int storeId);
}
