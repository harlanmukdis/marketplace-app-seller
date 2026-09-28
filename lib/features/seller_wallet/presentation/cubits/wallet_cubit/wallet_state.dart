part of 'wallet_cubit.dart';

sealed class WalletState {
  const WalletState();
}

final class WalletInProgress extends WalletState {
  const WalletInProgress();
}

final class WalletNoStore extends WalletState {
  const WalletNoStore();
}

final class WalletFailure extends WalletState {
  const WalletFailure(this.error);

  final DataError error;
}

final class WalletLoaded extends WalletState {
  const WalletLoaded(
    this.wallet, {
    this.accounts = const <BankAccount>[],
    this.isBusy = false,
  });

  final StoreWallet wallet;

  /// Saved payout accounts — per user, not per store.
  final List<BankAccount> accounts;
  final bool isBusy;

  /// Nothing has ever moved through this wallet. Distinct from a zero balance
  /// after withdrawing everything, and the two deserve different words.
  bool get isUntouched => wallet.transactions.isEmpty && wallet.balance == 0;

  bool get canAddAccount => accounts.length < BankAccount.maxPerUser;

  WalletLoaded copyWith({
    StoreWallet? wallet,
    List<BankAccount>? accounts,
    bool? isBusy,
  }) =>
      WalletLoaded(
        wallet ?? this.wallet,
        accounts: accounts ?? this.accounts,
        isBusy: isBusy ?? this.isBusy,
      );
}
