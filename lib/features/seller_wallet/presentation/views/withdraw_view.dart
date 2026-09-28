import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/wallet/store_wallet.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/wallet_cubit/wallet_cubit.dart';
import 'widgets/bank_account_sheet.dart';

Future<void> openWithdraw(BuildContext context, WalletCubit cubit) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<WalletCubit>.value(
          value: cubit,
          child: const WithdrawView(),
        ),
      ),
    );

/// "Tarik Dana" (S-39): pick a saved account, an amount, authorise with PIN.
///
/// Fees are shown as the design lists them but at Rp 0, because the API
/// charges none — the whole amount leaves the wallet and is snapshotted onto
/// the withdrawal request.
class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  int? _accountId;

  @override
  void initState() {
    super.initState();
    final state = WalletCubit.get(context).state;
    if (state is WalletLoaded && state.accounts.isNotEmpty) {
      _accountId = state.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _pin.dispose();
    super.dispose();
  }

  int get _value => parseRupiahInput(_amount.text) ?? 0;

  void _setAmount(int v) {
    _amount.text = formatThousands(v);
    setState(() {});
  }

  Future<void> _addAccount() async {
    final cubit = WalletCubit.get(context);
    final draft = await showBankAccountSheet(context);
    if (draft == null || !mounted) return;
    final error = await cubit.addAccount(
      bankName: draft.bankName,
      accountNumber: draft.accountNumber,
      holderName: draft.holderName,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    final state = cubit.state;
    if (state is WalletLoaded && state.accounts.isNotEmpty) {
      setState(() => _accountId = state.accounts.last.id);
    }
  }

  Future<void> _submit() async {
    final accountId = _accountId;
    if (accountId == null) return;
    final cubit = WalletCubit.get(context);
    final error = await cubit.withdraw(
      amount: _value,
      bankAccountId: accountId,
      pin: _pin.text,
    );
    if (!mounted) return;
    if (error == null) {
      showSuccessSnackBar(
        context,
        'Penarikan ${formatRupiah(_value)} diajukan.',
      );
      Navigator.of(context).pop();
      return;
    }
    _pin.clear();
    // The server has no "is a PIN set" query; this refusal is how it says so.
    if (error.message.toLowerCase().contains('belum di-set')) {
      _offerPinSetup();
      return;
    }
    showErrorSnackBar(context, error);
  }

  Future<void> _offerPinSetup() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PIN penarikan belum dibuat'),
        content: const Text(
          'Buat PIN 6 digit dulu. PIN ini dipakai setiap kali menarik dana.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buat PIN'),
          ),
        ],
      ),
    );
    if (go == true && mounted) await context.push(SellerRoutes.security);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        if (state is! WalletLoaded) {
          return const Scaffold(body: LoadingIndicatorView());
        }
        final balance = state.wallet.balance;
        final amount = _value;
        final amountError = amount == 0
            ? null
            : amount < StoreWallet.minimumWithdrawal
                ? 'Minimum ${formatRupiah(StoreWallet.minimumWithdrawal)}'
                : amount > balance
                    ? 'Melebihi saldo tersedia'
                    : null;
        final ready = _accountId != null &&
            amount >= StoreWallet.minimumWithdrawal &&
            amount <= balance &&
            _pin.text.length == 6 &&
            !state.isBusy;

        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Tarik Dana'),
          body: ListView(
            padding: const EdgeInsets.all(XSpace.screen),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(XSpace.s20),
                decoration: BoxDecoration(
                  color: XColors.brandNavy,
                  borderRadius: BorderRadius.circular(XRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Saldo Dapat Ditarik',
                      style: XText.bodyM.copyWith(
                        color: XColors.textOnBrand.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: XSpace.s4),
                    Text(
                      formatRupiah(balance),
                      style: XText.headingXL
                          .copyWith(color: XColors.textOnBrand, fontSize: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.sectionGap),
              Text('Pilih Rekening Tujuan', style: XText.titleL),
              Text('Rekening atas nama pemilik akun.', style: XText.bodyS),
              const SizedBox(height: XSpace.s12),
              for (final account in state.accounts) ...<Widget>[
                BankAccountTile(
                  account: account,
                  selected: account.id == _accountId,
                  onTap: () => setState(() => _accountId = account.id),
                ),
                const SizedBox(height: XSpace.s8),
              ],
              if (state.canAddAccount)
                XButton.secondary(
                  label: state.accounts.isEmpty
                      ? 'Tambah Rekening'
                      : 'Tambah Rekening (${state.accounts.length}/3 digunakan)',
                  icon: Icons.add_circle_outline,
                  expand: true,
                  onPressed: state.isBusy ? null : _addAccount,
                ),
              const SizedBox(height: XSpace.cardGap),
              XCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Nominal Penarikan', style: XText.titleM),
                        ),
                        Text('Maks. ${formatRupiah(balance)}',
                            style: XText.caption),
                      ],
                    ),
                    const SizedBox(height: XSpace.s12),
                    TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction((old, next) {
                          final n = int.tryParse(next.text);
                          if (n == null) return next;
                          final text = formatThousands(n);
                          return TextEditingValue(
                            text: text,
                            selection:
                                TextSelection.collapsed(offset: text.length),
                          );
                        }),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: XText.headingM,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        errorText: amountError,
                      ),
                    ),
                    const SizedBox(height: XSpace.s12),
                    Wrap(
                      spacing: XSpace.s8,
                      runSpacing: XSpace.s8,
                      children: <Widget>[
                        for (final preset in <int>[500000, 1000000, 2000000])
                          if (preset <= balance)
                            ActionChip(
                              label: Text(formatRupiah(preset)),
                              onPressed: () => _setAmount(preset),
                            ),
                        ActionChip(
                          label: Text('Tarik Semua (${formatRupiah(balance)})'),
                          labelStyle:
                              XText.labelM.copyWith(color: XColors.primary),
                          onPressed: () => _setAmount(balance),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.cardGap),
              XCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Ringkasan Penarikan', style: XText.titleM),
                    const SizedBox(height: XSpace.s8),
                    XKeyValue(
                      label: 'Nominal Penarikan',
                      value: formatRupiah(amount),
                    ),
                    const XKeyValue(label: 'Biaya Antar-Bank', value: 'Rp 0'),
                    Divider(height: XSpace.s24, color: XColors.borderSubtle),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Total Dana Diteruskan',
                              style: XText.titleL),
                        ),
                        Text(
                          formatRupiah(amount),
                          style: XText.priceL.copyWith(color: XColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.cardGap),
              XCard(
                child: Column(
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded,
                        color: XColors.primary, size: 28),
                    const SizedBox(height: XSpace.s8),
                    Text('Masukkan PIN Penarikan', style: XText.titleL),
                    Text('Otorisasi 6 digit untuk memproses transaksi.',
                        style: XText.bodyS),
                    const SizedBox(height: XSpace.s16),
                    Pinput(
                      length: 6,
                      controller: _pin,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      defaultPinTheme: PinTheme(
                        width: 44,
                        height: 52,
                        textStyle: XText.headingM,
                        decoration: BoxDecoration(
                          color: XColors.sunken,
                          borderRadius: BorderRadius.circular(XRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: XSpace.s12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: XButton.ghost(
                        label: 'Atur / ganti PIN',
                        size: XButtonSize.small,
                        onPressed: () => context.push(SellerRoutes.security),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.s24),
            ],
          ),
          bottomNavigationBar: Material(
            color: XColors.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(XSpace.screen),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    XButton(
                      label: 'Konfirmasi Penarikan Dana',
                      icon: Icons.outbox_outlined,
                      size: XButtonSize.large,
                      expand: true,
                      loading: state.isBusy,
                      onPressed: ready ? _submit : null,
                    ),
                    const SizedBox(height: XSpace.s6),
                    Text(
                      'Saldo langsung terpotong saat penarikan diajukan.',
                      style: XText.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
