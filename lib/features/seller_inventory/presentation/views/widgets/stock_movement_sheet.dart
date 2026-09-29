import 'package:flutter/material.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

import '../../../../../core/domain/model/inventory/warehouse_stock.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import 'variant_picker_sheet.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// Which ledger row the sheet is about to write.
enum StockAction {
  stockIn('Stok masuk', 'Catat barang yang baru datang.'),
  stockOut('Stok keluar', 'Barang hilang, rusak, atau dipakai sendiri.'),
  adjustment('Penyesuaian', 'Koreksi selisih hasil hitung fisik.');

  const StockAction(this.title, this.hint);

  final String title;
  final String hint;
}

class StockMovementDraft {
  const StockMovementDraft({
    required this.productVariantId,
    required this.quantity,
    this.notes,
  });

  final int productVariantId;

  /// A magnitude for stock in and out; a **signed delta** for an adjustment.
  final int quantity;

  final String? notes;
}

Future<StockMovementDraft?> showStockMovementSheet(
  BuildContext context, {
  required StockAction action,
  WarehouseStock? stock,
}) =>
    showModalBottomSheet<StockMovementDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StockMovementSheet(action: action, stock: stock),
    );

/// Records one stock movement.
///
/// [stock] pre-selects a row the seller tapped; without it the sheet asks which
/// variant, because stock is held per variant and a product on its own is not
/// specific enough to move.
class _StockMovementSheet extends StatefulWidget {
  const _StockMovementSheet({required this.action, this.stock});

  final StockAction action;
  final WarehouseStock? stock;

  @override
  State<_StockMovementSheet> createState() => _StockMovementSheetState();
}

class _StockMovementSheetState extends State<_StockMovementSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  int? _variantId;
  String? _variantLabel;

  bool get _isAdjustment => widget.action == StockAction.adjustment;

  @override
  void initState() {
    super.initState();
    final stock = widget.stock;
    if (stock != null) {
      _variantId = stock.productVariantId;
      _variantLabel = <String?>[stock.productName, stock.sku]
          .where((part) => part != null && part.isNotEmpty)
          .join(' · ');
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickVariant() async {
    final picked = await showVariantPicker(context);
    if (picked == null || !mounted) return;
    setState(() {
      _variantId = picked.variant.id;
      _variantLabel = picked.label;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final variantId = _variantId;
    if (variantId == null) return;

    final raw = _quantity.text.trim();
    final magnitude = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    // An adjustment is a difference and may be negative; the other two are
    // magnitudes the server signs itself.
    final quantity =
        _isAdjustment && raw.startsWith('-') ? -magnitude : magnitude;

    Navigator.of(context).pop(
      StockMovementDraft(
        productVariantId: variantId,
        quantity: quantity,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;

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
              Text(widget.action.title, style: XText.headingM),
              4.sbh,
              Text(
                widget.action.hint,
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              16.sbh,
              Text('Varian', style: XText.labelL),
              8.sbh,
              InkWell(
                onTap: widget.stock != null ? null : _pickVariant,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: 14.pa,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: XColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _variantLabel ?? 'Pilih varian',
                          style: XText.bodyM.copyWith(
                            color: _variantLabel == null
                                ? XColors.textTertiary
                                : null,
                          ),
                        ),
                      ),
                      if (widget.stock == null)
                        const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
              if (stock != null) ...<Widget>[
                8.sbh,
                Text(
                  'Tersedia ${stock.quantityAvailable} dari '
                  '${stock.quantityOnHand} di gudang ini'
                  '${stock.quantityReserved > 0 ? ' — ${stock.quantityReserved} sedang direservasi checkout' : ''}.',
                  style: XText.caption.copyWith(color: XColors.textTertiary),
                ),
              ],
              16.sbh,
              CustomTextFormField(
                controller: _quantity,
                labelText:
                    _isAdjustment ? 'Selisih (boleh minus, mis. -2)' : 'Jumlah',
                keyboardType: TextInputType.text,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Jumlah wajib diisi';
                  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty) return 'Jumlah harus berupa angka';
                  if (int.parse(digits) == 0) return 'Jumlah tidak boleh nol';
                  return null;
                },
              ),
              16.sbh,
              CustomTextFormField(
                controller: _notes,
                labelText: _isAdjustment ? 'Alasan' : 'Catatan (opsional)',
                validator: _isAdjustment
                    ? Validators.required('Alasan')
                    : Validators.optional,
              ),
              24.sbh,
              XButton(
                label: widget.action.title,
                size: XButtonSize.large,
                expand: true,
                onPressed: _variantId == null ? null : _submit,
              ),
              12.sbh,
            ],
          ),
        ),
      ),
    );
  }
}
