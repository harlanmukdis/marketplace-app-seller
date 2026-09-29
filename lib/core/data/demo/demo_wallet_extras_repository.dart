import '../../data_state.dart';
import '../../domain/model/wallet/wallet_extras.dart';
import '../../domain/repositories/wallet_extras_repository.dart';
import 'demo_support.dart';

class DemoWalletExtrasRepository implements WalletExtrasRepository {
  const DemoWalletExtrasRepository();

  @override
  Future<DataState<HeldBalance>> getHeldBalance(int storeId) => demoOr(
      'Saldo ditahan', () => const HeldBalance(amount: 560000, orderCount: 2));

  @override
  Future<DataState<List<WithdrawalRecord>>> getWithdrawals(int storeId) {
    final now = DateTime.now();
    return demoOr(
        'Riwayat penarikan',
        () => <WithdrawalRecord>[
              WithdrawalRecord(
                reference: 'WD-${_d(now)}-051',
                bankName: 'BCA',
                accountMasked: '8801••••291',
                amount: 1500000,
                status: WithdrawalStatus.processing,
                requestedAt: now.subtract(const Duration(hours: 3)),
              ),
              WithdrawalRecord(
                reference:
                    'WD-${_d(now.subtract(const Duration(days: 4)))}-042',
                bankName: 'BCA',
                accountMasked: '8801••••291',
                amount: 5000000,
                status: WithdrawalStatus.success,
                requestedAt: now.subtract(const Duration(days: 4, hours: 2)),
                completedAt: now.subtract(const Duration(days: 4)),
              ),
              WithdrawalRecord(
                reference:
                    'WD-${_d(now.subtract(const Duration(days: 12)))}-017',
                bankName: 'Mandiri',
                accountMasked: '1270••••8392',
                amount: 750000,
                status: WithdrawalStatus.rejected,
                requestedAt: now.subtract(const Duration(days: 12)),
                rejectReason:
                    'Nama pemilik rekening tidak sesuai KTP. Saldo dikembalikan.',
              ),
            ]);
  }

  static String _d(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';
}
