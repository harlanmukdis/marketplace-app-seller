import '../../../utils/json_parse.dart';

/// A saved payout account (`user_bank_accounts`, API v1.24.0).
///
/// Belongs to the **user**, not the store: every store the account owns pays
/// out to the same list. At most three, and the holder name must match the
/// account's registered full name (case-insensitive) or the server refuses it.
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.holderName,
    this.createdAt,
  });

  /// `admin_settings.max_bank_accounts_per_user` default.
  static const int maxPerUser = 3;

  final int id;
  final String bankName;
  final String accountNumber;
  final String holderName;
  final DateTime? createdAt;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: asInt(json['id']),
        bankName: asString(json['bank_name']),
        accountNumber: asString(json['account_number']),
        holderName: asString(json['account_holder_name']),
        createdAt: asCreatedDate(json),
      );

  /// `1234567890` -> `•••• 7890`.
  String get maskedNumber {
    final n = accountNumber;
    return n.length <= 4 ? n : '•••• ${n.substring(n.length - 4)}';
  }
}
