import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/data/datasources/remote/service/media_service.dart';
import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product_extras.dart';
import '../../../../../core/domain/model/media/uploaded_file.dart';
import '../../../../../core/domain/repositories/product_extras_repository.dart';
import '../../../../../core/domain/repositories/store_repository.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../../di/injector.dart';

/// "Detail Tambahan" on the product form (S-27): gallery, MOQ, wholesale
/// tiers, brand, condition, package dimensions — none of which the API
/// stores yet. Saved on its own through [ProductExtrasRepository], and only
/// for a product that already exists.
class ProductExtrasSection extends StatelessWidget {
  const ProductExtrasSection({super.key, required this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context) {
    final id = productId;
    return Container(
      padding: const EdgeInsets.all(XSpace.s20),
      decoration: BoxDecoration(
        color: XColors.surface,
        borderRadius: BorderRadius.circular(XRadius.lg),
        border: Border.all(color: XColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Detail Tambahan', style: XText.headingM)),
              const DemoBadge(),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(
              'Galeri, minimum pembelian, harga grosir, merek, kondisi, '
              'dan dimensi kemasan.',
              style: XText.bodyS),
          const SizedBox(height: XSpace.s16),
          if (id == null)
            Text('Tersedia setelah produk disimpan.', style: XText.bodyS)
          else
            PendingBuilder<ProductExtras>(
              compact: true,
              load: () => injector<ProductExtrasRepository>().getExtras(id),
              builder: (context, extras, _) =>
                  _ExtrasForm(productId: id, initial: extras),
            ),
        ],
      ),
    );
  }
}

class _ExtrasForm extends StatefulWidget {
  const _ExtrasForm({required this.productId, required this.initial});

  final int productId;
  final ProductExtras initial;

  @override
  State<_ExtrasForm> createState() => _ExtrasFormState();
}

class _TierInput {
  _TierInput([WholesaleTier? t])
      : qty = TextEditingController(text: t == null ? '' : '${t.minQuantity}'),
        price = TextEditingController(text: t == null ? '' : '${t.unitPrice}');

  final TextEditingController qty;
  final TextEditingController price;

  WholesaleTier? get value {
    final q = int.tryParse(qty.text), p = parseRupiahInput(price.text);
    return q == null || p == null
        ? null
        : WholesaleTier(minQuantity: q, unitPrice: p);
  }

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _ExtrasFormState extends State<_ExtrasForm> {
  late final List<String> _photos = <String>[...widget.initial.photos];
  late final TextEditingController _brand =
      TextEditingController(text: widget.initial.brand ?? '');
  late final TextEditingController _moq =
      TextEditingController(text: '${widget.initial.minOrder}');
  late final TextEditingController _l =
      TextEditingController(text: '${widget.initial.lengthCm ?? ''}');
  late final TextEditingController _w =
      TextEditingController(text: '${widget.initial.widthCm ?? ''}');
  late final TextEditingController _h =
      TextEditingController(text: '${widget.initial.heightCm ?? ''}');
  late final List<_TierInput> _tiers = <_TierInput>[
    for (final t in widget.initial.wholesale) _TierInput(t),
  ];
  late String _condition = widget.initial.condition;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in <TextEditingController>[_brand, _moq, _l, _w, _h]) {
      c.dispose();
    }
    for (final t in _tiers) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    final result = await injector<StoreRepository>().upload(
      bytes: bytes,
      fileName: file!.name,
      context: 'product_photo',
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (result is DataSuccess<UploadedFile>) _photos.add(result.value.url);
    });
    if (result is DataFailed<UploadedFile>) {
      showDemoActionResult(context, result.failure, '');
    }
  }

  ProductExtras get _value {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    return ProductExtras(
      photos: _photos,
      minOrder: n(_moq) ?? 1,
      wholesale: <WholesaleTier>[
        for (final t in _tiers)
          if (t.value != null) t.value!,
      ],
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      condition: _condition,
      lengthCm: n(_l),
      widthCm: n(_w),
      heightCm: n(_h),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await injector<ProductExtrasRepository>()
        .saveExtras(widget.productId, _value);
    if (!mounted) return;
    setState(() => _saving = false);
    showDemoActionResult(context, error, 'Detail tambahan disimpan');
  }

  Widget _number(TextEditingController c, String label, {String? suffix}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final vol = _value.volumetricGrams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Galeri Foto (${_photos.length}/${ProductExtras.maxPhotos})',
            style: XText.titleM),
        const SizedBox(height: XSpace.s8),
        Wrap(
          spacing: XSpace.s8,
          runSpacing: XSpace.s8,
          children: <Widget>[
            for (var i = 0; i < _photos.length; i++)
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(XRadius.md),
                    child: Image.network(
                      normaliseUploadUrl(_photos[i]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: XColors.sunken,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (_photos.length < ProductExtras.maxPhotos)
              InkWell(
                onTap: _uploading ? null : _addPhoto,
                borderRadius: BorderRadius.circular(XRadius.md),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: XColors.brandSubtle,
                    borderRadius: BorderRadius.circular(XRadius.md),
                    border: Border.all(
                        color: XColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(Icons.add_a_photo_outlined,
                          color: XColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: XSpace.s16),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _brand,
                decoration: const InputDecoration(labelText: 'Merek'),
              ),
            ),
            const SizedBox(width: XSpace.s8),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                    value: ProductCondition.newItem, label: Text('Baru')),
                ButtonSegment<String>(
                    value: ProductCondition.used, label: Text('Bekas')),
              ],
              selected: <String>{_condition},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _condition = s.first),
            ),
          ],
        ),
        const SizedBox(height: XSpace.s12),
        _number(_moq, 'Minimum pembelian (MOQ)', suffix: 'pcs'),
        const SizedBox(height: XSpace.s16),
        Row(
          children: <Widget>[
            Expanded(child: Text('Harga Grosir', style: XText.titleM)),
            if (_tiers.length < ProductExtras.maxTiers)
              XButton.ghost(
                label: 'Tambah Tingkat',
                icon: Icons.add,
                size: XButtonSize.small,
                onPressed: () => setState(() => _tiers.add(_TierInput())),
              ),
          ],
        ),
        if (_tiers.isEmpty)
          Text('Belum ada harga grosir.', style: XText.bodyS)
        else
          for (var i = 0; i < _tiers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: XSpace.s8),
              child: Row(
                children: <Widget>[
                  Expanded(child: _number(_tiers[i].qty, 'Min. jumlah')),
                  const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: TextField(
                      controller: _tiers[i].price,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Harga / pcs',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus tingkat',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _tiers.removeAt(i).dispose();
                    }),
                  ),
                ],
              ),
            ),
        const SizedBox(height: XSpace.s12),
        Text('Dimensi Kemasan', style: XText.titleM),
        const SizedBox(height: XSpace.s8),
        Row(
          children: <Widget>[
            Expanded(child: _number(_l, 'Panjang', suffix: 'cm')),
            const SizedBox(width: XSpace.s8),
            Expanded(child: _number(_w, 'Lebar', suffix: 'cm')),
            const SizedBox(width: XSpace.s8),
            Expanded(child: _number(_h, 'Tinggi', suffix: 'cm')),
          ],
        ),
        if (vol != null) ...<Widget>[
          const SizedBox(height: XSpace.s4),
          Text('Berat volumetrik ≈ ${formatThousands(vol)} gram',
              style: XText.caption),
        ],
        const SizedBox(height: XSpace.s16),
        XButton.secondary(
          label: 'Simpan Detail Tambahan',
          icon: Icons.save_outlined,
          expand: true,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
