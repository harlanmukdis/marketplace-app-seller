import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/wallet/bank_account.dart';
import '../../../../core/domain/model/wallet/store_wallet.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/wallet_cubit/wallet_cubit.dart';
import 'widgets/bank_account_sheet.dart';
import 'withdraw_view.dart';

/// "Xpedia Wallet" (S-38): balance, payout accounts, ledger.
///
/// Departures from the design, each because of the API:
/// * No "Saldo Ditahan" figure — `seller_wallets.held_balance` is never written
///   and would always read zero. This month's earnings take its place.
/// * No "Belanja" button — the store wallet is not a payment method.
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletCubit>(
      create: (_) => WalletCubit()..load(),
      child: const _WalletBody(),
    );
  }
}

class _WalletBody extends StatelessWidget {
  const _WalletBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Xpedia Wallet',
        actions: <Widget>[
          XIconAction(
            icon: Icons.help_outline_rounded,
            tooltip: 'Xpedia 911',
            onPressed: () => context.push(SellerRoutes.support),
          ),
          XIconAction(
            icon: Icons.lock_outline_rounded,
            tooltip: 'PIN penarikan',
            onPressed: () => context.push(SellerRoutes.security),
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) => switch (state) {
          WalletInProgress() => const LoadingIndicatorView(),
          WalletNoStore() => XEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada toko yang dipilih',
              actionLabel: 'Pilih toko',
              onAction: () => context.push(SellerRoutes.storePicker),
            ),
          WalletFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => WalletCubit.get(context).load(),
            ),
          WalletLoaded() => _content(context, state),
        },
      ),
    );
  }

  Widget _content(BuildContext context, WalletLoaded state) {
    final cubit = WalletCubit.get(context);
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          _BalanceHero(
            wallet: state.wallet,
            onWithdraw: state.wallet.canWithdraw
                ? () => openWithdraw(context, cubit)
                : null,
          ),
          const SizedBox(height: XSpace.sectionGap),
          _Accounts(state: state),
          const SizedBox(height: XSpace.sectionGap),
          _Ledger(state: state),
          const SizedBox(height: XSpace.sectionGap),
          const XBanner(
            tone: XTone.info,
            icon: Icons.lock_outline_rounded,
            title: 'Keamanan Finansial.',
            message: 'Setiap penarikan wajib PIN 6 digit dan hanya ke rekening '
                'atas nama pemilik akun. Saldo terpotong saat penarikan '
                'diajukan.',
          ),
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.wallet, required this.onWithdraw});

  final StoreWallet wallet;
  final VoidCallback? onWithdraw;

  int get _thisMonth {
    final now = DateTime.now();
    return wallet.transactions
        .where((t) =>
            t.type == WalletTransactionType.revenue &&
            t.createdAt != null &&
            t.createdAt!.year == now.year &&
            t.createdAt!.month == now.month)
        .fold(0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    const onBrand = XColors.textOnBrand;
    final muted = onBrand.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.all(XSpace.s20),
      decoration: BoxDecoration(
        color: XColors.brandNavy,
        borderRadius: BorderRadius.circular(XRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Saldo Tersedia',
                    style: XText.bodyM.copyWith(color: muted)),
              ),
              XChip(
                label: WalletStatus.label(wallet.status),
                tone: wallet.isFrozen ? XTone.danger : XTone.success,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(
            formatRupiah(wallet.balance),
            style: XText.headingXL.copyWith(color: onBrand, fontSize: 30),
          ),
          const SizedBox(height: XSpace.s16),
          Divider(height: 1, color: onBrand.withValues(alpha: 0.2)),
          const SizedBox(height: XSpace.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Pendapatan Bulan Ini',
                        style: XText.bodyS.copyWith(color: muted)),
                    Text(
                      formatRupiah(_thisMonth),
                      style: XText.titleL.copyWith(color: onBrand),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Minimum Penarikan',
                        style: XText.bodyS.copyWith(color: muted)),
                    Text(
                      formatRupiah(StoreWallet.minimumWithdrawal),
                      style: XText.titleL.copyWith(color: onBrand),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s16),
          Material(
            color: onWithdraw == null
                ? onBrand.withValues(alpha: 0.4)
                : XColors.surface,
            borderRadius: BorderRadius.circular(XRadius.md),
            child: InkWell(
              onTap: onWithdraw,
              borderRadius: BorderRadius.circular(XRadius.md),
              child: SizedBox(
                height: XSize.controlLarge,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.south_rounded,
                        size: 20, color: XColors.brandNavy),
                    const SizedBox(width: XSpace.s8),
                    Text(
                      'Tarik Dana',
                      style: XText.titleM.copyWith(color: XColors.brandNavy),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onWithdraw == null) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text(
              wallet.isFrozen
                  ? 'Wallet dibekukan. Hubungi Xpedia 911.'
                  : 'Saldo belum mencapai minimum penarikan.',
              style: XText.bodyS.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Accounts extends StatelessWidget {
  const _Accounts({required this.state});

  final WalletLoaded state;

  Future<void> _add(BuildContext context) async {
    final cubit = WalletCubit.get(context);
    final draft = await showBankAccountSheet(context);
    if (draft == null || !context.mounted) return;
    final error = await cubit.addAccount(
      bankName: draft.bankName,
      accountNumber: draft.accountNumber,
      holderName: draft.holderName,
    );
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Rekening ditambahkan.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _delete(BuildContext context, BankAccount account) async {
    final cubit = WalletCubit.get(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus rekening?'),
        content: Text(
          '${account.bankName} ${account.maskedNumber} tidak bisa dipakai '
          'untuk penarikan lagi. Riwayat penarikan lama tetap tersimpan.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: XColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await cubit.deleteAccount(account.id);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Rekening dihapus.')
        : showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text('Rekening Bank Pencairan', style: XText.titleL),
            ),
            const SizedBox(width: XSpace.s8),
            Text(
              '(${state.accounts.length}/${BankAccount.maxPerUser})',
              style: XText.bodyS,
            ),
          ],
        ),
        const SizedBox(height: XSpace.s4),
        Text(
          'Nama pemilik rekening wajib sama dengan nama akun terdaftar.',
          style: XText.bodyS,
        ),
        const SizedBox(height: XSpace.s12),
        for (final account in state.accounts) ...<Widget>[
          BankAccountTile(
            account: account,
            trailing: IconButton(
              tooltip: 'Hapus',
              icon: Icon(Icons.more_vert, color: XColors.textTertiary),
              onPressed: state.isBusy ? null : () => _delete(context, account),
            ),
          ),
          const SizedBox(height: XSpace.s8),
        ],
        if (state.canAddAccount)
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : () => _add(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(XSize.controlLarge),
              foregroundColor: XColors.primary,
              side: BorderSide(color: XColors.borderDefault),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tambah Rekening Bank'),
          ),
      ],
    );
  }
}

class _Ledger extends StatefulWidget {
  const _Ledger({required this.state});

  final WalletLoaded state;

  @override
  State<_Ledger> createState() => _LedgerState();
}

enum _LedgerFilter { all, credit, debit }

class _LedgerState extends State<_Ledger> {
  _LedgerFilter _filter = _LedgerFilter.all;

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.state.wallet.transactions.where((t) => switch (_filter) {
              _LedgerFilter.all => true,
              _LedgerFilter.credit => t.isCredit,
              _LedgerFilter.debit => !t.isCredit,
            });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Riwayat Transaksi', style: XText.titleL),
        const SizedBox(height: XSpace.s12),
        Wrap(
          spacing: XSpace.s8,
          children: <Widget>[
            for (final f in _LedgerFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  _LedgerFilter.all => 'Semua',
                  _LedgerFilter.credit => 'Dana Masuk',
                  _LedgerFilter.debit => 'Dana Keluar',
                }),
                selected: _filter == f,
                showCheckmark: false,
                labelStyle: XText.labelM.copyWith(
                  color:
                      _filter == f ? XColors.textOnBrand : XColors.textPrimary,
                ),
                selectedColor: XColors.primary,
                backgroundColor: XColors.surface,
                side: BorderSide(color: XColors.borderSubtle),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: XSpace.s12),
        if (rows.isEmpty)
          XEmptyState(
            icon: Icons.receipt_long_outlined,
            title: widget.state.isUntouched
                ? 'Belum ada transaksi'
                : 'Tidak ada transaksi di filter ini',
            message: widget.state.isUntouched
                ? 'Hasil penjualan masuk saat pesanan selesai.'
                : null,
          )
        else
          for (final t in rows) ...<Widget>[
            _LedgerRow(transaction: t),
            const SizedBox(height: XSpace.s8),
          ],
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final tone = t.isCredit ? XTone.success : XTone.neutral;
    final icon = switch (t.type) {
      WalletTransactionType.revenue => Icons.add_task_rounded,
      WalletTransactionType.withdraw => Icons.logout_rounded,
      WalletTransactionType.refund => Icons.undo_rounded,
      _ => Icons.receipt_outlined,
    };

    return XCard(
      padding: const EdgeInsets.all(XSpace.s12),
      onTap: t.isOrderRevenue && t.referenceId != null
          ? () => context.push(SellerRoutes.orderDetailPath(t.referenceId!))
          : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: tone.foreground),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  WalletTransactionType.label(t.type),
                  style: XText.titleM,
                ),
                if (t.referenceType != null)
                  Text(
                    '${t.referenceType} #${t.referenceId ?? '-'}',
                    style: XText.bodyS,
                  ),
                Text(formatDateTime(t.createdAt), style: XText.caption),
              ],
            ),
          ),
          Text(
            '${t.isCredit ? '+' : '−'}${formatRupiah(t.amount)}',
            style: XText.priceS.copyWith(
              color: t.isCredit ? XColors.success : XColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
