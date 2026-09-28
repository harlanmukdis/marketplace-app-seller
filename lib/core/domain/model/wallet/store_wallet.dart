import '../../../utils/json_parse.dart';

/// `GET /stores/{id}/wallet` — the store's earnings, plus its last 50 ledger
/// rows in the same payload.
///
/// The row is created on first read, so a store that has never opened this
/// screen still gets a wallet rather than a 404.
class StoreWallet {
  const StoreWallet({
    required this.id,
    required this.storeId,
    this.balance = 0,
    this.heldBalance = 0,
    this.status = WalletStatus.active,
    this.updatedAt,
    this.transactions = const <WalletTransaction>[],
  });

  final int id;
  final int storeId;

  /// Withdrawable now. A cache of the ledger, not a separate truth — every
  /// change is a `wallet_transactions` row written in the same transaction.
  final int balance;

  /// Present in the schema and **never written by any code**, so it is always
  /// zero today. Do not build a "pending funds" story on it.
  final int heldBalance;

  final String status;
  final DateTime? updatedAt;

  /// Newest first, capped at 50 by the server with no way to page further.
  final List<WalletTransaction> transactions;

  factory StoreWallet.fromJson(Map<String, dynamic> json) => StoreWallet(
        id: asInt(json['id']),
        storeId: asInt(json['store_id']),
        balance: asInt(json['balance']),
        heldBalance: asInt(json['held_balance']),
        status: asString(json['status'], fallback: WalletStatus.active),
        updatedAt: asModifiedDate(json),
        transactions:
            asModelList(json['transactions'], WalletTransaction.fromJson),
      );

  /// A frozen wallet cannot be withdrawn from. Nothing in the API says why.
  bool get isFrozen => status == WalletStatus.frozen;

  /// The floor the server enforces, hardcoded there as a fallback for
  /// `admin_settings.min_withdrawal_amount`. Checked client-side too so the
  /// form can say so before a round trip.
  static const int minimumWithdrawal = 50000;

  bool get canWithdraw => !isFrozen && balance >= minimumWithdrawal;

  /// Money that has actually arrived, for a "total earned" line. Withdrawals
  /// and fees are excluded because they leave.
  int get totalEarned => transactions
      .where((tx) => tx.isCredit)
      .fold(0, (sum, tx) => sum + tx.amount);
}

/// One row of the append-only wallet ledger.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    this.amount = 0,
    this.balanceBefore = 0,
    this.balanceAfter = 0,
    this.referenceType,
    this.referenceId,
    this.createdAt,
  });

  final int id;
  final String type;

  /// **Always positive.** Unlike the stock ledger, direction is not in the
  /// sign — the server stores `abs()` and leaves the meaning to [type]. A UI
  /// that renders this raw shows a withdrawal as if money came in.
  final int amount;

  final int balanceBefore;
  final int balanceAfter;

  /// What caused it: `order`, `refund`, `withdrawal_request`,
  /// `affiliate_commission`, `topup_request`. With [referenceId] this is how a
  /// revenue row is traced back to the order that produced it.
  final String? referenceType;
  final int? referenceId;

  final DateTime? createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: asInt(json['id']),
        type: asString(json['type']),
        amount: asInt(json['amount']),
        balanceBefore: asInt(json['balance_before']),
        balanceAfter: asInt(json['balance_after']),
        referenceType: asStringOrNull(json['reference_type']),
        referenceId: asIntOrNull(json['reference_id']),
        createdAt: asCreatedDate(json),
      );

  /// Derived from the balance either side rather than from [type], because the
  /// balance columns are written by the same code that moved the money — a new
  /// transaction type added later would still be read correctly.
  bool get isCredit => balanceAfter >= balanceBefore;

  /// `+150.000` / `-50.000`, which is how a ledger reads.
  int get signedAmount => isCredit ? amount : -amount;

  /// True when this row is a sale's proceeds, so it can link to the order.
  bool get isOrderRevenue =>
      type == WalletTransactionType.revenue && referenceType == 'order';
}

abstract class WalletStatus {
  static const String active = 'active';
  static const String frozen = 'frozen';

  static String label(String? status) => switch (status) {
        active => 'Aktif',
        frozen => 'Dibekukan',
        _ => status ?? '-',
      };
}

abstract class WalletTransactionType {
  /// The only type that credits a store wallet today, written when an order
  /// reaches `completed` — **not** when it ships. The amount is
  /// `grand_total` minus the platform commission (5% since API v1.6.0) and any
  /// Xpedia Growth commission, so the
  /// ledger shows net proceeds rather than what the buyer paid.
  static const String revenue = 'revenue';

  static const String withdraw = 'withdraw';
  static const String refund = 'refund';
  static const String commission = 'commission';
  static const String fee = 'fee';
  static const String adjustment = 'adjustment';
  static const String cashback = 'cashback';
  static const String topup = 'topup';
  static const String transferIn = 'transfer_in';
  static const String transferOut = 'transfer_out';

  static String label(String? type) => switch (type) {
        revenue => 'Hasil penjualan',
        withdraw => 'Penarikan',
        refund => 'Pengembalian dana',
        commission => 'Komisi',
        fee => 'Biaya',
        adjustment => 'Penyesuaian',
        cashback => 'Cashback',
        topup => 'Top up',
        transferIn => 'Transfer masuk',
        transferOut => 'Transfer keluar',
        _ => type ?? '-',
      };
}
