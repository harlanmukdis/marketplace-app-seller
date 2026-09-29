/// Wallet figures the API does not keep yet (S-38).
///
/// ⏳ `seller_wallets.held_balance` is never written, and a seller cannot
/// list their own withdrawal requests (only `/admin/withdrawals` can).
class HeldBalance {
  const HeldBalance({required this.amount, required this.orderCount});

  /// Revenue of shipped orders not yet completed.
  final int amount;
  final int orderCount;
}

class WithdrawalRecord {
  const WithdrawalRecord({
    required this.reference,
    required this.bankName,
    required this.accountMasked,
    required this.amount,
    required this.status,
    this.requestedAt,
    this.completedAt,
    this.rejectReason,
  });

  final String reference;
  final String bankName;
  final String accountMasked;
  final int amount;

  /// [WithdrawalStatus].
  final String status;
  final DateTime? requestedAt;
  final DateTime? completedAt;
  final String? rejectReason;
}

abstract class WithdrawalStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String success = 'success';
  static const String rejected = 'rejected';

  static String label(String s) => switch (s) {
        pending => 'Diajukan',
        processing => 'Diproses',
        success => 'Berhasil',
        rejected => 'Ditolak',
        _ => s,
      };
}
