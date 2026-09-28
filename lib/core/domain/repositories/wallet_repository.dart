import '../../data_state.dart';
import '../model/wallet/bank_account.dart';
import '../model/wallet/store_wallet.dart';

/// The store's earnings and withdrawals, plus the account-level payout setup
/// (saved bank accounts and the withdrawal PIN) that withdrawals depend on.
abstract class WalletRepository {
  Future<DataState<StoreWallet>> getStoreWallet(int storeId);

  /// Files a withdrawal and returns the wallet as it stands afterwards — the
  /// balance is debited at request time, so the screen must not keep showing
  /// the old figure.
  Future<DataState<StoreWallet>> requestWithdrawal(
    int storeId, {
    required int amount,
    required int bankAccountId,
    required String pin,
  });

  Future<DataState<List<BankAccount>>> getBankAccounts();

  /// Returns the list as it stands afterwards.
  Future<DataState<List<BankAccount>>> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String holderName,
  });

  Future<DataState<List<BankAccount>>> deleteBankAccount(int id);

  Future<DataState<void>> setWithdrawalPin({
    required String pin,
    String? currentPin,
  });
}
