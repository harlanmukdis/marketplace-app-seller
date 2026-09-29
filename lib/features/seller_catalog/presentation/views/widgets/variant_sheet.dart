import 'package:flutter/material.dart';

import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// What the sheet collected. Null from [showVariantSheet] means cancelled.
class VariantDraft {
  const VariantDraft({
    required this.sku,
    required this.price,
    this.options = const <String, dynamic>{},
    this.weightGrams,
  });

  final String sku;
  final int price;
  final Map<String, dynamic> options;
  final int? weightGrams;
}

Future<VariantDraft?> showVariantSheet(BuildContext context) =>
    showModalBottomSheet<VariantDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VariantSheet(),
    );

/// Adds one variant.
///
/// Options are two free-text pairs rather than a schema: the backend stores
/// `variant_options` as opaque JSON with no list of allowed keys, so anything
/// stricter here would be invented rather than enforced.
class _VariantSheet extends StatefulWidget {
  const _VariantSheet();

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _optionKey1 = TextEditingController();
  final TextEditingController _optionValue1 = TextEditingController();
  final TextEditingController _optionKey2 = TextEditingController();
  final TextEditingController _optionValue2 = TextEditingController();

  @override
  void dispose() {
    _skuController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    _optionKey1.dispose();
    _optionValue1.dispose();
    _optionKey2.dispose();
    _optionValue2.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final options = <String, dynamic>{};
    void collect(TextEditingController key, TextEditingController value) {
      final k = key.text.trim();
      final v = value.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) options[k] = v;
    }

    collect(_optionKey1, _optionValue1);
    collect(_optionKey2, _optionValue2);

    Navigator.of(context).pop(
      VariantDraft(
        sku: _skuController.text.trim(),
        price: parseRupiahInput(_priceController.text) ?? 0,
        options: options,
        weightGrams: int.tryParse(_weightController.text.trim()),
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
              Text('Varian baru', style: XText.headingM),
              16.sbh,
              CustomTextFormField(
                controller: _skuController,
                labelText: 'SKU',
                textInputAction: TextInputAction.next,
                validator: Validators.required('SKU'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _priceController,
                labelText: 'Harga (Rp)',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: Validators.positiveAmount('Harga'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _weightController,
                labelText: 'Berat (gram, opsional)',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: Validators.optionalAmount,
              ),
              20.sbh,
              Text('Opsi', style: XText.labelL),
              4.sbh,
              Text(
                'Misalnya warna: merah, ukuran: L. Kosongkan kalau varian ini '
                'tidak punya opsi.',
                style: XText.caption.copyWith(color: kLightThirdColor),
              ),
              12.sbh,
              _OptionRow(
                  keyController: _optionKey1, valueController: _optionValue1),
              12.sbh,
              _OptionRow(
                  keyController: _optionKey2, valueController: _optionValue2),
              24.sbh,
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Tambah varian'),
              ),
              12.sbh,
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow(
      {required this.keyController, required this.valueController});

  final TextEditingController keyController;
  final TextEditingController valueController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: CustomTextFormField(
            controller: keyController,
            labelText: 'Nama opsi',
            textInputAction: TextInputAction.next,
            validator: Validators.optional,
          ),
        ),
        12.sbw,
        Expanded(
          child: CustomTextFormField(
            controller: valueController,
            labelText: 'Nilai',
            textInputAction: TextInputAction.next,
            validator: Validators.optional,
          ),
        ),
      ],
    );
  }
}
