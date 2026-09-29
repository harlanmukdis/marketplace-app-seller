import 'package:flutter/material.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

import '../../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

class VoucherDraft {
  const VoucherDraft({
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.quota,
    required this.validFrom,
    required this.validUntil,
    this.code,
    this.maxDiscount,
    this.minSpend = 0,
    this.maxUsePerUser = 1,
  });

  final String name;
  final String discountType;
  final int discountValue;
  final int quota;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? code;
  final int? maxDiscount;
  final int minSpend;
  final int maxUsePerUser;
}

Future<VoucherDraft?> showVoucherFormSheet(BuildContext context) =>
    showModalBottomSheet<VoucherDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VoucherFormSheet(),
    );

/// Creates a store voucher.
///
/// Every field here is validated client-side because the server validates
/// almost none of it: only `name` is checked, and each of the other required
/// keys is read without a fallback, so leaving one out answers an HTML 500
/// rather than a 422. The `discount_type` enum is unenforced too — MySQL is not
/// in strict mode, so an unrecognised value is silently stored as an empty
/// string, leaving a voucher that discounts nothing.
class _VoucherFormSheet extends StatefulWidget {
  const _VoucherFormSheet();

  @override
  State<_VoucherFormSheet> createState() => _VoucherFormSheetState();
}

class _VoucherFormSheetState extends State<_VoucherFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _maxDiscount = TextEditingController();
  final TextEditingController _minSpend = TextEditingController();
  final TextEditingController _quota = TextEditingController();
  final TextEditingController _maxPerUser = TextEditingController(text: '1');

  String _type = VoucherDiscountType.percentage;
  late DateTime _from = _startOfToday();
  late DateTime _until = _startOfToday().add(const Duration(days: 30));

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isPercentage => _type == VoucherDiscountType.percentage;

  /// Free shipping and cashback still need a value — the column is `NOT NULL`
  /// and the model reads it without a fallback.
  String get _valueLabel => _isPercentage ? 'Besar diskon (%)' : 'Nilai (Rp)';

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _value.dispose();
    _maxDiscount.dispose();
    _minSpend.dispose();
    _quota.dispose();
    _maxPerUser.dispose();
    super.dispose();
  }

  String? _validateValue(String? input) {
    final parsed = parseRupiahInput(input);
    if (parsed == null || parsed <= 0) return 'Wajib diisi, lebih dari 0';
    if (_isPercentage && parsed > 100) return 'Maksimal 100%';
    return null;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _from : _until;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
        if (!_until.isAfter(_from)) {
          _until = _from.add(const Duration(days: 30));
        }
      } else {
        _until = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_until.isAfter(_from)) return;

    Navigator.of(context).pop(
      VoucherDraft(
        name: _name.text.trim(),
        discountType: _type,
        discountValue: parseRupiahInput(_value.text) ?? 0,
        quota: parseRupiahInput(_quota.text) ?? 0,
        // The window runs to the end of the chosen day; the column is a
        // DATETIME compared against NOW(), so midnight would cut a day short.
        validFrom: _from,
        validUntil: DateTime(_until.year, _until.month, _until.day, 23, 59, 59),
        code: _code.text.trim().toUpperCase(),
        maxDiscount: _isPercentage ? parseRupiahInput(_maxDiscount.text) : null,
        minSpend: parseRupiahInput(_minSpend.text) ?? 0,
        maxUsePerUser: parseRupiahInput(_maxPerUser.text) ?? 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: 20.pa,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Voucher baru', style: XText.headingM),
              4.sbh,
              Text(
                'Voucher tidak bisa diubah, dijeda, atau dihapus setelah '
                'dibuat — API-nya tidak menyediakan jalan itu. Periksa dulu '
                'sebelum mengirim.',
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _name,
                labelText: 'Nama voucher',
                validator: Validators.required('Nama voucher'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _code,
                labelText: 'Kode (opsional)',
                validator: Validators.optional,
              ),
              6.sbh,
              Text(
                'Dikosongkan berarti server yang membuatkan kodenya. Kode '
                'harus unik di seluruh marketplace, termasuk terhadap toko '
                'lain yang tidak bisa dilihat dari sini.',
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              20.sbh,
              AppDropdownField<String>(
                label: 'Jenis diskon',
                value: _type,
                items: VoucherDiscountType.all,
                itemLabel: VoucherDiscountType.label,
                onChanged: (value) => setState(
                  () => _type = value ?? VoucherDiscountType.percentage,
                ),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _value,
                labelText: _valueLabel,
                keyboardType: TextInputType.number,
                validator: _validateValue,
              ),
              if (_isPercentage) ...<Widget>[
                16.sbh,
                CustomTextFormField(
                  controller: _maxDiscount,
                  labelText: 'Maksimal potongan (opsional, Rp)',
                  keyboardType: TextInputType.number,
                  validator: Validators.optionalAmount,
                ),
              ],
              16.sbh,
              CustomTextFormField(
                controller: _minSpend,
                labelText: 'Minimal belanja (opsional, Rp)',
                keyboardType: TextInputType.number,
                validator: Validators.optionalAmount,
              ),
              16.sbh,
              CustomTextFormField(
                controller: _quota,
                labelText: 'Kuota voucher',
                keyboardType: TextInputType.number,
                validator: Validators.positiveAmount('Kuota'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _maxPerUser,
                labelText: 'Maksimal dipakai per pembeli',
                keyboardType: TextInputType.number,
                validator: Validators.positiveAmount('Batas per pembeli'),
              ),
              20.sbh,
              Text('Masa berlaku', style: XText.labelL),
              8.sbh,
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateField(
                      label: 'Mulai',
                      value: _from,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  12.sbw,
                  Expanded(
                    child: _DateField(
                      label: 'Berakhir',
                      value: _until,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              24.sbh,
              XButton(
                label: 'Buat voucher',
                size: XButtonSize.large,
                expand: true,
                onPressed: _submit,
              ),
              12.sbh,
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable date, styled close enough to [CustomTextFormField] to sit beside
/// one.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(
          formatDate(value),
          style: XText.bodyM,
        ),
      ),
    );
  }
}
