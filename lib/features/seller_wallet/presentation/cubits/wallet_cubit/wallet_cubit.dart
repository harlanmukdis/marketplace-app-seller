import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/wallet/bank_account.dart';
import '../../../../../core/domain/model/wallet/store_wallet.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/wallet_repository.dart';
import '../../../../../di/injector.dart';

part 'wallet_state.dart';

/// The active store's earnings.
class WalletCubit extends Cubit<WalletState> {
  WalletCubit() : super(const WalletInProgress());

  static WalletCubit get(BuildContext context) => BlocProvider.of(context);

  final WalletRepository _wallet = injector<WalletRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const WalletNoStore());
      return;
    }

    emit(const WalletInProgress());

    final results = await Future.wait<Object>(<Future<Object>>[
      _wallet.getStoreWallet(storeId),
      _wallet.getBankAccounts(),
    ]);
    if (isClosed) return;
    final result = results[0] as DataState<StoreWallet>;
    final accounts = results[1] as DataState<List<BankAccount>>;

    switch (result) {
      case DataSuccess<StoreWallet>(:final value):
        emit(WalletLoaded(value, accounts: _accountsOf(accounts)));
      case DataFailed<StoreWallet>(:final failure):
        emit(WalletFailure(failure));
      default:
        emit(const WalletFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Dompet toko tidak bisa dibaca.',
          ),
        ));
    }
  }

  List<BankAccount> _accountsOf(DataState<List<BankAccount>> result) =>
      result is DataSuccess<List<BankAccount>>
          ? result.value
          : const <BankAccount>[];

  /// Files a withdrawal. Refuses locally first for what the client can know —
  /// frozen wallet, minimum, balance, PIN shape — so the seller is told before
  /// a round trip rather than by a generic `WITHDRAWAL_REJECTED`.
  Future<DataError?> withdraw({
    required int amount,
    required int bankAccountId,
    required String pin,
  }) async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! WalletLoaded) return null;

    final refusal = _refuse(current.wallet, amount) ??
        (RegExp(r'^\d{6}$').hasMatch(pin)
            ? null
            : const DataError(
                code: 'VALIDATION_ERROR',
                message: 'PIN penarikan terdiri dari 6 digit angka.',
              ));
    if (refusal != null) return refusal;

    emit(current.copyWith(isBusy: true));
    final result = await _wallet.requestWithdrawal(
      storeId,
      amount: amount,
      bankAccountId: bankAccountId,
      pin: pin,
    );
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<StoreWallet>(:final value):
        emit(current.copyWith(wallet: value, isBusy: false));
        return null;
      case DataFailed<StoreWallet>(:final failure):
        emit(current.copyWith(isBusy: false));
        return failure;
      default:
        await load();
        return null;
    }
  }

  Future<DataError?> addAccount({
    required String bankName,
    required String accountNumber,
    required String holderName,
  }) =>
      _accountsAction(() => _wallet.addBankAccount(
            bankName: bankName,
            accountNumber: accountNumber,
            holderName: holderName,
          ));

  Future<DataError?> deleteAccount(int id) =>
      _accountsAction(() => _wallet.deleteBankAccount(id));

  Future<DataError?> _accountsAction(
    Future<DataState<List<BankAccount>>> Function() action,
  ) async {
    final current = state;
    if (current is! WalletLoaded) return null;
    emit(current.copyWith(isBusy: true));
    final result = await action();
    if (isClosed) return null;
    if (result is DataFailed<List<BankAccount>>) {
      emit(current.copyWith(isBusy: false));
      return result.failure;
    }
    emit(current.copyWith(accounts: _accountsOf(result), isBusy: false));
    return null;
  }

  DataError? _refuse(StoreWallet wallet, int amount) {
    if (wallet.isFrozen) {
      return const DataError(
        code: 'WALLET_FROZEN',
        message: 'Dompet toko sedang dibekukan, jadi penarikan tidak bisa '
            'diajukan. Hubungi admin marketplace.',
      );
    }
    if (amount < StoreWallet.minimumWithdrawal) {
      return const DataError(
        code: 'WITHDRAWAL_BELOW_MINIMUM',
        message: 'Minimum penarikan Rp50.000.',
      );
    }
    if (amount > wallet.balance) {
      return DataError(
        code: 'WITHDRAWAL_REJECTED',
        message: 'Saldo tidak mencukupi.',
        details: <String, dynamic>{'saldo': wallet.balance},
      );
    }
    return null;
  }
}
