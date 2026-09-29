import 'package:flutter/material.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

import '../../../../../core/domain/model/merchandising/store_showcase.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

class ShowcaseDraft {
  const ShowcaseDraft({required this.name, required this.sortOrder});

  final String name;
  final int sortOrder;
}

Future<ShowcaseDraft?> showShowcaseFormSheet(
  BuildContext context, {
  StoreShowcase? existing,
  int defaultSortOrder = 0,
}) =>
    showModalBottomSheet<ShowcaseDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShowcaseFormSheet(
        existing: existing,
        defaultSortOrder: defaultSortOrder,
      ),
    );

/// Creates or renames a showcase.
///
/// Short, because a showcase is only a name and a position — the products go
/// in afterwards, from the showcase's own screen. Unlike most things on this
/// API it can also be deleted, so nothing here is one-way.
class _ShowcaseFormSheet extends StatefulWidget {
  const _ShowcaseFormSheet({this.existing, required this.defaultSortOrder});

  final StoreShowcase? existing;
  final int defaultSortOrder;

  @override
  State<_ShowcaseFormSheet> createState() => _ShowcaseFormSheetState();
}

class _ShowcaseFormSheetState extends State<_ShowcaseFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sortOrder;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _sortOrder = TextEditingController(
      text: '${widget.existing?.sortOrder ?? widget.defaultSortOrder}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ShowcaseDraft(
        name: _name.text.trim(),
        sortOrder: parseRupiahInput(_sortOrder.text) ?? 0,
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
              Text(
                _isEditing ? 'Ubah etalase' : 'Etalase baru',
                style: XText.headingM,
              ),
              4.sbh,
              Text(
                'Etalase adalah pengelompokan versi toko sendiri, lepas dari '
                'kategori platform — satu produk boleh masuk ke beberapa '
                'etalase sekaligus.',
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _name,
                labelText: 'Nama etalase',
                validator: Validators.required('Nama etalase'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _sortOrder,
                labelText: 'Urutan tampil',
                keyboardType: TextInputType.number,
                validator: Validators.optional,
              ),
              6.sbh,
              Text(
                'Angka kecil tampil lebih dulu. Server mengizinkan angka yang '
                'sama dan tidak menata ulang, jadi urutan kembar mungkin.',
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              24.sbh,
              XButton(
                label: _isEditing ? 'Simpan' : 'Buat etalase',
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
