import '../../data_state.dart';
import '../../domain/model/wallet/bank_account.dart';
import '../../domain/model/wallet/store_wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/remote/service/wallet_service.dart';
import 'repository_guard.dart';

class WalletRepositoryImpl with RepositoryGuard implements WalletRepository {
  const WalletRepositoryImpl(this._service);

  final WalletService _service;

  @override
  Future<DataState<StoreWallet>> getStoreWallet(int storeId) =>
      guard(() => _service.getStoreWallet(storeId));

  @override
  Future<DataState<StoreWallet>> requestWithdrawal(
    int storeId, {
    required int amount,
    required int bankAccountId,
    required String pin,
  }) =>
      guard(() async {
        await _service.requestWithdrawal(
          storeId,
          amount: amount,
          bankAccountId: bankAccountId,
          pin: pin,
        );
        return _service.getStoreWallet(storeId);
      });

  @override
  Future<DataState<List<BankAccount>>> getBankAccounts() =>
      guard(_service.getBankAccounts);

  @override
  Future<DataState<List<BankAccount>>> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String holderName,
  }) =>
      guard(() async {
        await _service.addBankAccount(
          bankName: bankName,
          accountNumber: accountNumber,
          holderName: holderName,
        );
        return _service.getBankAccounts();
      });

  @override
  Future<DataState<List<BankAccount>>> deleteBankAccount(int id) =>
      guard(() async {
        await _service.deleteBankAccount(id);
        return _service.getBankAccounts();
      });

  @override
  Future<DataState<void>> setWithdrawalPin({
    required String pin,
    String? currentPin,
  }) =>
      guard(() => _service.setWithdrawalPin(pin: pin, currentPin: currentPin));
}
