import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/wallet/bank_account.dart';
import '../../../../domain/model/wallet/store_wallet.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// The store's earnings and withdrawals.
class WalletService extends BaseService {
  const WalletService(super.dio);

  /// Balance plus the last 50 ledger rows. The wallet row is created on first
  /// read, so this never 404s for a store that exists.
  Future<StoreWallet> getStoreWallet(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.storeWallet(storeId),
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return StoreWallet.fromJson(envelope.map);
  }

  /// Files a withdrawal request and returns its id.
  ///
  /// **The balance is debited immediately**, at request time — not when an
  /// admin approves it — and a rejected request is never credited back (the
  /// backend's own changelog records this as an open bug). So the money
  /// leaves the wallet the moment this succeeds.
  ///
  /// Since API v1.24.0 the bank details are no longer sent: the request names
  /// a saved [bankAccountId] and carries the 6-digit withdrawal [pin]. Every
  /// refusal — below minimum, short balance, wrong PIN, PIN never set, unknown
  /// account — comes back as `422 WITHDRAWAL_REJECTED` with a different
  /// message, and too many wrong PINs as `429 TOO_MANY_REQUESTS` (5 per 15
  /// minutes).
  ///
  /// Sent as JSON; this controller reads `php://input`.
  Future<int> requestWithdrawal(
    int storeId, {
    required int amount,
    required int bankAccountId,
    required String pin,
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.storeWalletWithdraw(storeId),
      body: <String, dynamic>{
        'amount': amount,
        'bank_account_id': bankAccountId,
        'pin': pin,
      },
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return asInt(envelope.map['id']);
  }

  Future<List<BankAccount>> getBankAccounts() async {
    final envelope = await getRequest(ApiEndpoints.bankAccounts);
    return envelope.list.map(BankAccount.fromJson).toList(growable: false);
  }

  /// `422 VALIDATION_ERROR` when the holder name does not match the account's
  /// full name, or the account already has the maximum saved.
  Future<int> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String holderName,
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.bankAccounts,
      body: <String, dynamic>{
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder_name': holderName,
      },
    );
    return asInt(envelope.map['id']);
  }

  Future<void> deleteBankAccount(int id) async {
    await deleteRequest(ApiEndpoints.bankAccount(id));
  }

  /// Sets the 6-digit withdrawal PIN, or changes it — a change must quote the
  /// [currentPin]. There is no endpoint that says whether a PIN is set; the
  /// withdrawal's refusal message is the only way to find out.
  Future<void> setWithdrawalPin({required String pin, String? currentPin}) async {
    await postRequest(
      ApiEndpoints.withdrawalPin,
      body: <String, dynamic>{
        'pin': pin,
        if (currentPin != null) 'current_pin': currentPin,
      },
    );
  }
}
