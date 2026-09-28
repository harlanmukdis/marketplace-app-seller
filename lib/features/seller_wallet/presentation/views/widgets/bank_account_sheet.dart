import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/data/local/session_store.dart';
import '../../../../../core/domain/model/wallet/bank_account.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../../di/injector.dart';

class BankAccountDraft {
  const BankAccountDraft({
    required this.bankName,
    required this.accountNumber,
    required this.holderName,
  });

  final String bankName;
  final String accountNumber;
  final String holderName;
}

Future<BankAccountDraft?> showBankAccountSheet(BuildContext context) =>
    showModalBottomSheet<BankAccountDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BankAccountSheet(),
    );

/// Adds a payout account.
///
/// The holder name is pre-filled from the account's registered full name and
/// is **not editable**: the server refuses any other name
/// (case-insensitively), so offering a free field would only produce a 422.
class _BankAccountSheet extends StatefulWidget {
  const _BankAccountSheet();

  @override
  State<_BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends State<_BankAccountSheet> {
  static const List<String> _banks = <String>[
    'BCA',
    'Mandiri',
    'BNI',
    'BRI',
    'CIMB Niaga',
    'Permata',
    'BSI',
    'Danamon',
    'BTN',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _number = TextEditingController();
  String? _bank;
  late final String _holder = injector<SessionStore>().fullName ?? '';

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(BankAccountDraft(
      bankName: _bank!,
      accountNumber: _number.text.trim(),
      holderName: _holder,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Tambah Rekening Bank', style: XText.headingM),
                const SizedBox(height: XSpace.s4),
                Text(
                  'Maksimal ${BankAccount.maxPerUser} rekening per akun, '
                  'dipakai bersama oleh semua toko Anda.',
                  style: XText.bodyS,
                ),
                const SizedBox(height: XSpace.s16),
                DropdownButtonFormField<String>(
                  initialValue: _bank,
                  decoration: const InputDecoration(labelText: 'Bank'),
                  items: <DropdownMenuItem<String>>[
                    for (final b in _banks)
                      DropdownMenuItem<String>(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() => _bank = v),
                  validator: (v) => v == null ? 'Pilih bank' : null,
                ),
                const SizedBox(height: XSpace.s12),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Nomor rekening'),
                  validator: (v) => (v ?? '').trim().length < 6
                      ? 'Nomor rekening tidak valid'
                      : null,
                ),
                const SizedBox(height: XSpace.s12),
                TextFormField(
                  initialValue: _holder,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Nama pemilik rekening',
                    helperText: 'Harus sama dengan nama akun terdaftar.',
                  ),
                  validator: (_) => _holder.isEmpty
                      ? 'Nama akun belum terbaca. Keluar lalu masuk lagi.'
                      : null,
                ),
                const SizedBox(height: XSpace.s20),
                XButton(
                  label: 'Simpan Rekening',
                  size: XButtonSize.large,
                  expand: true,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A saved account as a card row, shared by the wallet and the withdrawal
/// screen.
class BankAccountTile extends StatelessWidget {
  const BankAccountTile({
    super.key,
    required this.account,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final BankAccount account;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? XColors.brandSubtle : XColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(
          color: selected ? XColors.primary : XColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XSpace.s12),
          child: Row(
            children: <Widget>[
              if (onTap != null) ...<Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? XColors.primary : XColors.borderStrong,
                ),
                const SizedBox(width: XSpace.s12),
              ] else ...<Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: XColors.brandSubtle,
                    borderRadius: BorderRadius.circular(XRadius.md),
                  ),
                  child: Icon(Icons.account_balance_outlined,
                      color: XColors.primary),
                ),
                const SizedBox(width: XSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(account.bankName, style: XText.titleM),
                    Text(account.maskedNumber, style: XText.bodyM),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            account.holderName.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: XText.labelM,
                          ),
                        ),
                        const SizedBox(width: XSpace.s4),
                        Icon(Icons.verified_outlined,
                            size: 14, color: XColors.success),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
