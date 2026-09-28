import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data/datasources/remote/service/media_service.dart';
import '../../../../core/domain/model/catalog/category.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/catalog/product_certification.dart';
import '../../../../core/domain/model/catalog/product_growth.dart';
import '../../../../core/domain/model/catalog/product_variant.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/product_form_cubit/product_form_cubit.dart';
import 'widgets/certification_sheet.dart';
import 'widgets/coverage_sheet.dart';
import 'widgets/product_card.dart';
import 'widgets/variant_sheet.dart';

/// "Tambah / Edit Produk" (S-27), in the design's order: Foto Produk,
/// Informasi Produk, Mode Stok & Pemenuhan, Varian Produk, Pengiriman &
/// Logistik, Deskripsi & Regulasi, then Simpan Draf / Simpan & Tayangkan.
///
/// Left out because the API has no field for them (checked against the
/// schema and every route): Merek, Kondisi, Harga Grosir, Dimensi Kemasan
/// (the column exists but no endpoint writes it) and the Dangerous Goods /
/// MSDS box. Secure+ is not a product setting at all — the buyer opts in per
/// transaction. In place of the MSDS box sits BPOM / Halal / SNI, which the
/// API does support and which decides whether a product may go live.
///
/// Photos: the API cannot write a product gallery, only one image per
/// variant — and the product falls back to its variants' images. So the
/// gallery here is one photo per variant, the first marked "Utama".
class ProductFormView extends StatelessWidget {
  const ProductFormView({super.key, this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductFormCubit>(
      create: (_) => ProductFormCubit(productId: productId)..load(),
      child: _ProductFormBody(productId: productId),
    );
  }
}

/// One variant row while creating.
class _RowInput {
  _RowInput({String? value})
      : value = TextEditingController(text: value ?? ''),
        price = TextEditingController(),
        sku = TextEditingController();

  final TextEditingController value;
  final TextEditingController price;
  final TextEditingController sku;
  PickedPhoto? photo;

  void dispose() {
    value.dispose();
    price.dispose();
    sku.dispose();
  }
}

class _ProductFormBody extends StatefulWidget {
  const _ProductFormBody({this.productId});

  final int? productId;

  @override
  State<_ProductFormBody> createState() => _ProductFormBodyState();
}

class _ProductFormBodyState extends State<_ProductFormBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _compareAt = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _variantType =
      TextEditingController(text: 'Warna');

  /// Create mode: the variant rows being composed. Starts with one row with
  /// no option — a product without variants.
  final List<_RowInput> _rows = <_RowInput>[_RowInput()];

  int? _categoryId;
  String _type = ProductType.physical;
  String _mode = FulfillmentMode.readyStock;
  int _leadTime = 7;

  /// Create mode only; edit mode reads coverage from the cubit.
  ShippingCoverage _coverageDraft = const ShippingCoverage();

  bool _prefilled = false;

  bool get _isEditing => widget.productId != null;
  bool get _hasVariants =>
      _rows.length > 1 || _rows.first.value.text.isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _compareAt.dispose();
    _weight.dispose();
    _variantType.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _prefill(Product product) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = product.name;
    _description.text = product.description ?? '';
    _compareAt.text = product.compareAtPrice?.toString() ?? '';
    _weight.text = product.weightGrams?.toString() ?? '';
    _type = product.productType;
    _mode = product.fulfillmentMode;
    _leadTime = product.fulfillmentLeadTimeDays ?? 7;
  }

  ProductDraft _draft(ProductFormReady state) {
    final product = state.product;
    final description = _description.text.trim();
    final rows = product != null
        ? <VariantRowDraft>[
            for (final v in product.variants) VariantRowDraft(price: v.price),
          ]
        : <VariantRowDraft>[
            for (final r in _rows)
              VariantRowDraft(
                value:
                    r.value.text.trim().isEmpty ? null : r.value.text.trim(),
                price: parseRupiahInput(r.price.text) ?? 0,
                sku: r.sku.text.trim(),
                photo: r.photo,
              ),
          ];
    return ProductDraft(
      name: _name.text.trim(),
      categoryId: _categoryId,
      productType: _type,
      description: description.isEmpty ? null : description,
      weightGrams: int.tryParse(_weight.text.trim()),
      compareAtPrice: parseRupiahInput(_compareAt.text),
      fulfillmentMode: _mode,
      leadTimeDays: _leadTime,
      variantType: _hasVariants && _variantType.text.trim().isNotEmpty
          ? _variantType.text.trim()
          : null,
      rows: rows.isEmpty
          ? <VariantRowDraft>[VariantRowDraft(price: product?.basePrice ?? 0)]
          : rows,
      coverage: _coverageDraft,
    );
  }

  Future<void> _submit(ProductFormReady state, {required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = ProductFormCubit.get(context);
    final draft = _draft(state);

    if (!_isEditing) {
      final (error, id) = await cubit.create(draft, publish: publish);
      if (!mounted) return;
      if (error != null) {
        showErrorSnackBar(context, error);
        // The product exists; a follow-up failed. Leave rather than invite a
        // second create that would duplicate it.
        if (id != null) Navigator.of(context).pop();
        return;
      }
      showSuccessSnackBar(
        context,
        publish
            ? 'Produk tersimpan dan tayang.'
            : 'Produk disimpan sebagai draf.',
      );
      Navigator.of(context).pop();
      return;
    }

    var error = await cubit.update(draft);
    if (error == null && publish) {
      error = await cubit.setStatus(ProductStatus.active);
    }
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(
      context,
      publish ? 'Produk tersimpan dan tayang.' : 'Perubahan tersimpan.',
    );
  }

  Future<PickedPhoto?> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null) return null;
    return PickedPhoto(bytes: bytes, fileName: file!.name);
  }

  Future<void> _addPhotoCreate() async {
    final free = _rows.where((r) => r.photo == null).firstOrNull;
    if (free == null) return;
    final photo = await _pickImage();
    if (photo == null || !mounted) return;
    setState(() => free.photo = photo);
  }

  Future<void> _setVariantPhoto(ProductVariant variant) async {
    final cubit = ProductFormCubit.get(context);
    final photo = await _pickImage();
    if (photo == null || !mounted) return;
    final error = await cubit.setVariantPhoto(variant.id, photo);
    if (!mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Foto tersimpan.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _pickCategory(ProductFormReady state) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(options: state.categoryOptions),
    );
    if (id != null) setState(() => _categoryId = id);
  }

  Future<void> _editCoverage(ProductFormReady state) async {
    final current = _isEditing ? state.coverage : _coverageDraft;
    final draft = await showCoverageSheet(context, current);
    if (draft == null || !mounted) return;
    if (!_isEditing) {
      setState(() => _coverageDraft = ShippingCoverage(
            mode: draft.mode,
            locations: draft.mode == CoverageMode.none
                ? const <CoverageLocation>[]
                : draft.locations,
          ));
      return;
    }
    final error = await ProductFormCubit.get(context)
        .setCoverage(draft.mode, draft.locations);
    if (!mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Cakupan pengiriman tersimpan.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _addRow() async {
    final type = _variantType.text.trim();
    final value = await _askText(
      title: 'Tambah ${type.isEmpty ? 'varian' : type}',
      hint: 'Contoh: Black',
    );
    if (value == null || value.isEmpty) return;
    setState(() {
      if (_rows.length == 1 && _rows.first.value.text.isEmpty) {
        _rows.first.value.text = value;
      } else {
        final row = _RowInput(value: value);
        row.price.text = _rows.first.price.text;
        _rows.add(row);
      }
    });
  }

  Future<String?> _askText({
    required String title,
    String? hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _editVariantPrice(ProductVariant variant) async {
    final cubit = ProductFormCubit.get(context);
    final text = await _askText(
      title: 'Harga '
          '${variant.optionsLabel.isEmpty ? 'varian' : variant.optionsLabel}',
      initial: '${variant.price}',
    );
    final price = parseRupiahInput(text);
    if (price == null || price <= 0 || !mounted) return;
    final error = await cubit.setVariantPrice(variant, price);
    if (!mounted) return;
    if (error != null) showErrorSnackBar(context, error);
  }

  Future<void> _addVariantEdit() async {
    final cubit = ProductFormCubit.get(context);
    final result = await showVariantSheet(context);
    if (result == null || !mounted) return;
    final error = await cubit.addVariant(
      sku: result.sku,
      price: result.price,
      options: result.options,
      weightGrams: result.weightGrams,
    );
    if (!mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Varian ditambahkan.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _addCertification() async {
    final cubit = ProductFormCubit.get(context);
    final draft = await showCertificationSheet(context);
    if (draft == null || !mounted) return;
    final error = await cubit.submitCertification(
      type: draft.type,
      number: draft.number,
      document: draft.document,
      issuedBy: draft.issuedBy,
      validUntil: draft.validUntil,
    );
    if (!mounted) return;
    error == null
        ? showSuccessSnackBar(
            context, 'Sertifikat dikirim untuk diverifikasi.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _setStatus(String status) async {
    final error = await ProductFormCubit.get(context).setStatus(status);
    if (!mounted) return;
    error == null
        ? showSuccessSnackBar(
            context,
            status == ProductStatus.active
                ? 'Produk tayang.'
                : 'Produk nonaktif.',
          )
        : showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductFormCubit, ProductFormState>(
      builder: (context, state) => Scaffold(
        backgroundColor: XColors.canvas,
        appBar: XAppBar(
          title: _isEditing ? 'Ubah Produk' : 'Tambah Produk',
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: XSpace.s12),
              child: Center(
                child: Text(
                  state is ProductFormReady && state.product != null
                      ? ProductStatus.label(state.product!.status)
                      : 'Draf',
                  style: XText.labelL.copyWith(color: XColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
        body: switch (state) {
          ProductFormInProgress() => const LoadingIndicatorView(),
          ProductFormFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => ProductFormCubit.get(context).load(),
            ),
          ProductFormReady() => _form(state),
        },
        bottomNavigationBar:
            state is ProductFormReady ? _bottomBar(state) : null,
      ),
    );
  }

  Widget _bottomBar(ProductFormReady state) {
    final live = state.product?.isActive ?? false;
    return Material(
      color: XColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Row(
            children: <Widget>[
              Expanded(
                child: XButton.secondary(
                  label: _isEditing ? 'Simpan' : 'Simpan Draf',
                  size: XButtonSize.large,
                  onPressed: state.isSaving
                      ? null
                      : () => _submit(state, publish: false),
                ),
              ),
              if (!live) ...<Widget>[
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: XButton(
                    label: 'Simpan & Tayangkan',
                    size: XButtonSize.large,
                    loading: state.isSaving,
                    onPressed: () => _submit(state, publish: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(ProductFormReady state) {
    final product = state.product;
    if (product != null) _prefill(product);
    const gap = SizedBox(height: XSpace.cardGap);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          _StatusBanner(
            product: product,
            busy: state.isSaving,
            moderationPending: state.moderationPending,
            onUnpublish: () => _setStatus(ProductStatus.inactive),
          ),
          gap,
          _photoSection(state),
          gap,
          _infoSection(state),
          gap,
          _modeSection(),
          gap,
          _variantSection(state),
          gap,
          _shippingSection(state),
          gap,
          _descriptionSection(state),
          if (product != null) ...<Widget>[
            gap,
            _GrowthRow(product: product),
            gap,
            _BadgeSection(product: product),
          ],
          gap,
          const _GuaranteeBanner(),
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ foto
  Widget _photoSection(ProductFormReady state) {
    final product = state.product;
    final List<Widget> tiles;
    final int max;
    final int filled;

    if (product != null) {
      final variants = product.variants;
      max = variants.length;
      filled = variants.where((v) => (v.imageUrl ?? '').isNotEmpty).length;
      tiles = <Widget>[
        for (var i = 0; i < variants.length; i++)
          _PhotoTile(
            url: variants[i].imageUrl,
            primary: i == 0,
            caption: variants[i].optionsLabel.isEmpty
                ? null
                : variants[i].optionsLabel,
            onTap: state.isSaving ? null : () => _setVariantPhoto(variants[i]),
          ),
      ];
    } else {
      max = _rows.length;
      final withPhoto = _rows.where((r) => r.photo != null).toList();
      filled = withPhoto.length;
      tiles = <Widget>[
        for (var i = 0; i < withPhoto.length; i++)
          _PhotoTile(
            bytes: withPhoto[i].photo!.bytes,
            primary: i == 0,
            caption: withPhoto[i].value.text.isEmpty
                ? null
                : withPhoto[i].value.text,
            onRemove: () => setState(() => withPhoto[i].photo = null),
          ),
        if (filled < max) _AddPhotoTile(onTap: _addPhotoCreate),
        for (var i = filled + 1; i < max; i++) const _EmptyPhotoTile(),
      ];
    }

    return _Section(
      title: 'Foto Produk',
      titleNote: '(Maks. $max Foto)',
      trailing: XChip(label: '$filled/$max Terisi', tone: XTone.info),
      children: <Widget>[
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tiles.length,
            separatorBuilder: (_, __) => const SizedBox(width: XSpace.s8),
            itemBuilder: (_, i) => tiles[i],
          ),
        ),
        const SizedBox(height: XSpace.s12),
        const _InfoBox(
          icon: Icons.verified_user_outlined,
          text: 'Format JPG/PNG, min. 800×800px. Satu foto per varian; foto '
              'pertama menjadi foto utama. Semua foto diberi watermark resmi '
              'Xpedia untuk mencegah plagiarisme katalog.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ informasi
  Widget _infoSection(ProductFormReady state) {
    String? categoryLabel;
    for (final o in state.categoryOptions) {
      if (o.id == _categoryId) categoryLabel = o.label;
    }

    return _Section(
      title: 'Informasi Produk',
      children: <Widget>[
        _FieldLabel(
          'Nama Produk',
          required: true,
          trailing: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _name,
            builder: (_, v, __) =>
                Text('${v.text.length}/120 karakter', style: XText.caption),
          ),
        ),
        TextFormField(
          controller: _name,
          maxLength: 120,
          style: XText.bodyL,
          decoration: _filled(hint: 'Nama produk').copyWith(counterText: ''),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Nama produk wajib diisi' : null,
        ),
        const SizedBox(height: XSpace.s6),
        Text(
          'Gunakan rumus: Tipe Produk + Merek + Seri Model + Spesifikasi '
          'Utama.',
          style: XText.caption,
        ),
        const SizedBox(height: XSpace.s16),
        if (_isEditing) ...<Widget>[
          const _FieldLabel('Kategori & jenis'),
          _RowField(
            icon: Icons.lock_outline_rounded,
            text: '${ProductType.label(state.product?.productType)} · '
                'tidak bisa diubah setelah dibuat',
          ),
        ] else ...<Widget>[
          const _FieldLabel('Kategori', required: true),
          FormField<int>(
            validator: (_) =>
                _categoryId == null ? 'Kategori wajib dipilih' : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _RowField(
                  icon: Icons.category_outlined,
                  text: categoryLabel ?? 'Pilih kategori',
                  muted: categoryLabel == null,
                  onTap: () async {
                    await _pickCategory(state);
                    field.didChange(_categoryId);
                  },
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: XSpace.s4),
                    child: Text(
                      field.errorText!,
                      style: XText.bodyS.copyWith(color: XColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s16),
          const _FieldLabel('Jenis produk', required: true),
          _Segmented<String>(
            value: _type,
            options: <(String, String, IconData)>[
              for (final t in ProductType.all)
                (
                  t,
                  ProductType.label(t),
                  switch (t) {
                    ProductType.digital => Icons.cloud_download_outlined,
                    ProductType.service => Icons.handshake_outlined,
                    _ => Icons.inventory_2_outlined,
                  },
                ),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ mode stok
  Widget _modeSection() {
    const grid = <String>[
      FulfillmentMode.readyStock,
      FulfillmentMode.preOrder,
      FulfillmentMode.customOrder,
      FulfillmentMode.infinite,
    ];
    return _Section(
      title: 'Mode Stok & Pemenuhan',
      trailing: Tooltip(
        message: StockMode.describe(_mode),
        child:
            Icon(Icons.help_outline, size: 20, color: XColors.textTertiary),
      ),
      children: <Widget>[
        for (var r = 0; r < 2; r++) ...<Widget>[
          if (r > 0) const SizedBox(height: XSpace.s8),
          Row(
            children: <Widget>[
              for (var c = 0; c < 2; c++) ...<Widget>[
                if (c > 0) const SizedBox(width: XSpace.s8),
                Expanded(
                  child: _ModeButton(
                    mode: grid[r * 2 + c],
                    selected: _mode == grid[r * 2 + c],
                    onTap: () => setState(() => _mode = grid[r * 2 + c]),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (FulfillmentMode.needsLeadTime(_mode)) ...<Widget>[
          const SizedBox(height: XSpace.s12),
          _LeadTimeBox(
            value: _leadTime,
            preOrder: _mode == FulfillmentMode.preOrder,
            onChanged: (v) => setState(() => _leadTime = v),
          ),
        ],
        if (_isEditing)
          CheckboxListTile(
            value: _mode == FulfillmentMode.discontinued,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Hentikan penjualan (Discontinued)',
                style: XText.bodyM),
            subtitle: Text(StockMode.describe(FulfillmentMode.discontinued),
                style: XText.caption),
            onChanged: (v) => setState(() => _mode = v == true
                ? FulfillmentMode.discontinued
                : FulfillmentMode.readyStock),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- varian
  Widget _variantSection(ProductFormReady state) {
    final product = state.product;
    return _Section(
      title: 'Varian Produk',
      subtitle: 'Kelola harga, stok, & SKU tiap kombinasi',
      trailing: XButton.ghost(
        label: 'Tambah',
        icon: Icons.add_circle_outline,
        size: XButtonSize.small,
        onPressed: state.isSaving
            ? null
            : product != null
                ? _addVariantEdit
                : _addRow,
      ),
      children: <Widget>[
        if (product != null)
          ..._existingVariants(product, state.isSaving)
        else
          ..._draftVariants(),
        const SizedBox(height: XSpace.s12),
        const _FieldLabel('Harga coret (opsional)'),
        TextFormField(
          controller: _compareAt,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: XText.bodyL,
          decoration: _filled(hint: 'Harga sebelum diskon', prefix: 'Rp '),
        ),
      ],
    );
  }

  InputDecoration get _bare => const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      );

  List<Widget> _draftVariants() {
    return <Widget>[
      if (_hasVariants) ...<Widget>[
        Row(
          children: <Widget>[
            Text('Tipe Varian: ', style: XText.bodyM),
            Expanded(
              child: TextField(
                controller: _variantType,
                style: XText.titleM,
                decoration: _bare,
              ),
            ),
          ],
        ),
        const SizedBox(height: XSpace.s8),
        Wrap(
          spacing: XSpace.s8,
          runSpacing: XSpace.s8,
          children: <Widget>[
            for (var i = 0; i < _rows.length; i++)
              InputChip(
                label: Text(_rows[i].value.text),
                labelStyle: XText.labelL,
                backgroundColor: XColors.sunken,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                onDeleted: () => setState(() {
                  if (_rows.length > 1) {
                    _rows.removeAt(i).dispose();
                  } else {
                    _rows.first.value.clear();
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: XSpace.s12),
      ],
      for (final row in _rows) ...<Widget>[
        _VariantCard(
          title: row.value.text.isEmpty ? 'Varian utama' : row.value.text,
          sku: TextField(
            controller: row.sku,
            style: XText.caption.copyWith(color: XColors.textPrimary),
            textAlign: TextAlign.end,
            decoration: _bare.copyWith(hintText: 'otomatis'),
          ),
          price: TextFormField(
            controller: row.price,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: XText.priceM.copyWith(color: XColors.brandNavy),
            decoration: _bare.copyWith(prefixText: 'Rp ', hintText: '0'),
            validator: (v) =>
                (parseRupiahInput(v) ?? 0) <= 0 ? 'Harga wajib diisi' : null,
          ),
          stock: Text('Atur di Gudang', style: XText.bodyS),
        ),
        const SizedBox(height: XSpace.s8),
      ],
    ];
  }

  List<Widget> _existingVariants(Product product, bool busy) {
    // The generated default first: stock lands on it for a product with no
    // real options, so hiding it would hide the thing being stocked.
    final ordered = <ProductVariant>[
      ...product.variants.where((v) => v.isGenerated),
      ...product.authoredVariants,
    ];
    return <Widget>[
      for (final v in ordered) ...<Widget>[
        _VariantCard(
          title: v.optionsLabel.isEmpty ? 'Varian utama' : v.optionsLabel,
          sku: Text(
            v.sku,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: XText.caption.copyWith(color: XColors.textPrimary),
          ),
          price: InkWell(
            onTap: busy ? null : () => _editVariantPrice(v),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    formatRupiah(v.price),
                    style: XText.priceM.copyWith(color: XColors.brandNavy),
                  ),
                ),
                const SizedBox(width: XSpace.s4),
                Icon(Icons.edit_outlined,
                    size: 14, color: XColors.textTertiary),
              ],
            ),
          ),
          stock: Text(
            v.stock == null ? 'Atur di Gudang' : '${v.stock} unit',
            style: v.stock == null ? XText.bodyS : XText.titleL,
          ),
        ),
        const SizedBox(height: XSpace.s8),
      ],
    ];
  }

  // ----------------------------------------------------------- pengiriman
  Widget _shippingSection(ProductFormReady state) {
    final coverage = _isEditing ? state.coverage : _coverageDraft;
    final summary = !coverage.isRestricted
        ? 'Seluruh Indonesia'
        : coverage.mode == CoverageMode.exclude
            ? 'Seluruh Indonesia (Kecuali ${coverage.locations.length} '
                'lokasi)'
            : 'Hanya ${coverage.locations.length} lokasi';

    return _Section(
      title: 'Pengiriman & Logistik',
      children: <Widget>[
        _FieldLabel('Berat Paket (Gram)',
            required: _type == ProductType.physical),
        TextFormField(
          controller: _weight,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: XText.bodyL,
          decoration: _filled(hint: '0', suffix: 'Gram'),
          validator: (v) => _type == ProductType.physical &&
                  (int.tryParse((v ?? '').trim()) ?? 0) <= 0
              ? 'Berat wajib diisi'
              : null,
        ),
        const SizedBox(height: XSpace.s16),
        const _FieldLabel('Cakupan Pengiriman', required: true),
        _RowField(
          icon: Icons.local_shipping_outlined,
          text: summary,
          onTap: state.isSaving ? null : () => _editCoverage(state),
        ),
        const SizedBox(height: XSpace.s12),
        const _InfoBox(
          icon: Icons.verified_outlined,
          tone: XTone.info,
          title: 'Xpedia Secure+',
          text: 'Dipilih pembeli per transaksi. Pesanan Secure+ wajib foto dan '
              'video pengemasan saat Cetak Resi.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ deskripsi
  Widget _descriptionSection(ProductFormReady state) {
    return _Section(
      title: 'Deskripsi & Regulasi',
      children: <Widget>[
        _FieldLabel(
          'Deskripsi Lengkap',
          trailing: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _description,
            builder: (_, v, __) =>
                Text('${v.text.length}/3000', style: XText.caption),
          ),
        ),
        TextFormField(
          controller: _description,
          maxLines: 6,
          maxLength: 3000,
          style: XText.bodyM,
          decoration: _filled(
            hint: 'Jelaskan produk, spesifikasi, dan isi paket.',
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: XSpace.s6),
        Text(
          'Pertanyaan pembeli hanya lewat Chat — tidak ada diskusi publik.',
          style: XText.caption,
        ),
        const SizedBox(height: XSpace.s16),
        _CertificationBox(
          certifications: state.certifications,
          enabled: state.product != null && !state.isSaving,
          onAdd: _addCertification,
        ),
      ],
    );
  }
}

// ======================================================================
// S-27's visual building blocks: filled fields, labels above, 12dp cards.
// ======================================================================

InputDecoration _filled({String? hint, String? prefix, String? suffix}) {
  final radius = BorderRadius.circular(XRadius.md);
  return InputDecoration(
    hintText: hint,
    prefixText: prefix,
    suffixText: suffix,
    filled: true,
    fillColor: XColors.sunken,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: XSpace.s16,
      vertical: XSpace.s16,
    ),
    border:
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder:
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: XColors.primary, width: 2),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.subtitle,
    this.titleNote,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? titleNote;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: title, style: XText.headingM),
                      if (titleNote != null)
                        TextSpan(text: ' $titleNote', style: XText.bodyS),
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: XSpace.s4),
            Text(subtitle!, style: XText.bodyS),
          ],
          const SizedBox(height: XSpace.s16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false, this.trailing});

  final String text;
  final bool required;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: text),
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: XColors.danger),
                    ),
                ],
              ),
              style: XText.labelL,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A filled, tappable row: category, coverage.
class _RowField extends StatelessWidget {
  const _RowField({
    required this.icon,
    required this.text,
    this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XColors.sunken,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XSpace.s16),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: XColors.primary),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Text(
                  text,
                  style: XText.bodyL.copyWith(
                    color: muted ? XColors.textPlaceholder : null,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: XColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s4),
      decoration: BoxDecoration(
        color: XColors.sunken,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        children: <Widget>[
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.$1),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        o.$1 == value ? XColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(XRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (o.$1 == value) ...<Widget>[
                        Icon(o.$3, size: 16, color: XColors.primary),
                        const SizedBox(width: XSpace.s4),
                      ],
                      Flexible(
                        child: Text(
                          o.$2,
                          overflow: TextOverflow.ellipsis,
                          style: XText.labelL.copyWith(
                            color: o.$1 == value
                                ? XColors.primary
                                : XColors.textSecondary,
                            fontWeight: o.$1 == value
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.title,
    this.tone,
  });

  final IconData icon;
  final String text;
  final String? title;
  final XTone? tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone?.foreground ?? XColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: tone?.background ?? XColors.canvas,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: XSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(title!, style: XText.titleM.copyWith(color: fg)),
                Text(text, style: XText.bodyS.copyWith(color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.product,
    required this.busy,
    required this.moderationPending,
    required this.onUnpublish,
  });

  final Product? product;
  final bool busy;
  final bool moderationPending;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final live = p?.isActive ?? false;
    final dot = moderationPending
        ? XColors.danger
        : live
            ? XColors.success
            : XColors.warning;
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.surface,
        borderRadius: BorderRadius.circular(XRadius.lg),
        border: Border.all(color: XColors.borderSubtle),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  p == null
                      ? 'Produk Baru — Disimpan sebagai Draf'
                      : moderationPending
                          ? 'Menunggu Moderasi Tim Kurasi'
                          : 'Status: ${ProductStatus.label(p.status)}',
                  style: XText.titleM,
                ),
                Text(
                  p == null
                      ? 'Belum terlihat pembeli sampai ditayangkan.'
                      : moderationPending
                          ? 'Kategori terbatas; bisa tayang setelah disetujui.'
                          : live
                              ? 'Tayang dan terlihat pembeli.'
                              : 'Belum terlihat pembeli.',
                  style: XText.bodyS,
                ),
                if (p?.stock != null)
                  Text('Stok tersedia: ${p!.stock} unit',
                      style: XText.caption),
              ],
            ),
          ),
          if (p != null)
            StockModeChip(
              mode: p.stockMode,
              leadTimeDays: p.fulfillmentLeadTimeDays,
            ),
          if (live)
            PopupMenuButton<int>(
              tooltip: 'Lainnya',
              enabled: !busy,
              onSelected: (_) => onUnpublish(),
              itemBuilder: (_) => const <PopupMenuEntry<int>>[
                PopupMenuItem<int>(value: 0, child: Text('Nonaktifkan')),
              ],
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    this.url,
    this.bytes,
    this.primary = false,
    this.caption,
    this.onTap,
    this.onRemove,
  });

  final String? url;
  final Uint8List? bytes;
  final bool primary;
  final String? caption;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final image = url;
    final empty = bytes == null && (image == null || image.isEmpty);
    final Widget content;
    if (bytes != null) {
      content = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (!empty) {
      content = Image.network(
        normaliseUploadUrl(image!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image_outlined, color: XColors.textTertiary),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.add_a_photo_outlined, color: XColors.primary),
          const SizedBox(height: XSpace.s4),
          Text('Tambah Foto',
              style: XText.labelS.copyWith(color: XColors.primary)),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(XRadius.md),
                child: ColoredBox(
                  color: empty ? XColors.brandSubtle : XColors.sunken,
                  child: content,
                ),
              ),
            ),
            if (primary && !empty)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: XColors.primary,
                    borderRadius: BorderRadius.circular(XRadius.xs),
                  ),
                  child: Text('Utama',
                      style:
                          XText.labelS.copyWith(color: XColors.textOnBrand)),
                ),
              ),
            if (onRemove != null)
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0x99111827),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            if (caption != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0x99111827),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(XRadius.md),
                    ),
                  ),
                  child: Text(
                    caption!,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: XText.labelS.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: XColors.brandSubtle,
          borderRadius: BorderRadius.circular(XRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add_a_photo_outlined, color: XColors.primary),
            const SizedBox(height: XSpace.s6),
            Text('+ Tambah Foto',
                style: XText.labelM.copyWith(color: XColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotoTile extends StatelessWidget {
  const _EmptyPhotoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: XColors.canvas,
        borderRadius: BorderRadius.circular(XRadius.md),
        border: Border.all(color: XColors.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.image_outlined, color: XColors.textPlaceholder),
          const SizedBox(height: XSpace.s4),
          Text('Kosong', style: XText.caption),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? XColors.textOnBrand : XColors.textSecondary;
    return Material(
      color: selected ? XColors.primary : XColors.sunken,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: SizedBox(
          height: XSize.touchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(StockModeChip.iconOf(mode), size: 20, color: fg),
              const SizedBox(width: XSpace.s8),
              Flexible(
                child: Text(
                  StockMode.label(mode),
                  overflow: TextOverflow.ellipsis,
                  style: XText.labelL.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadTimeBox extends StatelessWidget {
  const _LeadTimeBox({
    required this.value,
    required this.preOrder,
    required this.onChanged,
  });

  final int value;
  final bool preOrder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s16),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          const TextSpan(text: 'Lead Time Pengerjaan (Hari)'),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: XColors.danger),
                          ),
                        ],
                      ),
                      style: XText.titleM.copyWith(color: XColors.brandNavy),
                    ),
                    Text('Waktu produksi sebelum serah terima kurir',
                        style: XText.caption),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: XColors.surface,
                  borderRadius: BorderRadius.circular(XRadius.md),
                  border: Border.all(color: XColors.borderSubtle),
                ),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Kurangi',
                      onPressed:
                          value > 1 ? () => onChanged(value - 1) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$value Hari', style: XText.titleM),
                    IconButton(
                      tooltip: 'Tambah hari',
                      style: IconButton.styleFrom(
                        backgroundColor: XColors.primary,
                        foregroundColor: XColors.textOnBrand,
                      ),
                      onPressed:
                          value < 90 ? () => onChanged(value + 1) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.surface,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 20, color: XColors.primary),
                const SizedBox(width: XSpace.s8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: preOrder
                              ? 'Pesanan wajib diserahkan ke kurir maksimal '
                                  'dalam '
                              : 'Setiap pesanan wajib dikonfirmasi dalam '
                                  '2×24 jam, lalu diserahkan ke kurir '
                                  'dalam ',
                        ),
                        TextSpan(
                          text: '$value hari',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: ' sejak dibayar. Keterlambatan memengaruhi '
                              'skor performa toko Anda.',
                        ),
                      ],
                    ),
                    style: XText.bodyS.copyWith(color: XColors.brandNavy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.title,
    required this.sku,
    required this.price,
    required this.stock,
  });

  final String title;
  final Widget sku;
  final Widget price;
  final Widget stock;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, Widget child) => Container(
          padding: const EdgeInsets.all(XSpace.s12),
          decoration: BoxDecoration(
            color: XColors.surface,
            borderRadius: BorderRadius.circular(XRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: XText.overline),
              const SizedBox(height: XSpace.s4),
              child,
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.canvas,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: XColors.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(child: Text(title, style: XText.titleL)),
              Text('SKU: ', style: XText.caption),
              SizedBox(width: 110, child: sku),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: tile('HARGA SATUAN', price)),
              const SizedBox(width: XSpace.s8),
              Expanded(child: tile('ALOKASI STOK', stock)),
            ],
          ),
        ],
      ),
    );
  }
}

/// BPOM / Halal / SNI — the regulation box the API actually supports, in the
/// place the design gives its Dangerous Goods / MSDS box.
class _CertificationBox extends StatelessWidget {
  const _CertificationBox({
    required this.certifications,
    required this.enabled,
    required this.onAdd,
  });

  final List<ProductCertification> certifications;
  final bool enabled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    const fg = XColors.warningStrong;
    return Container(
      padding: const EdgeInsets.all(XSpace.s16),
      decoration: BoxDecoration(
        color: XTone.warning.background,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.fact_check_outlined, color: fg),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text('Sertifikasi Produk (BPOM / Halal / SNI)',
                    style: XText.titleM.copyWith(color: fg)),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(
            'Kategori tertentu wajib punya sertifikat terverifikasi sebelum '
            'produk bisa ditayangkan.',
            style: XText.bodyS.copyWith(color: fg),
          ),
          for (final c in certifications) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Container(
              padding: const EdgeInsets.all(XSpace.s12),
              decoration: BoxDecoration(
                color: XColors.surface,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.task_outlined,
                    color: c.status == CertificationStatus.verified
                        ? XColors.success
                        : XColors.textSecondary,
                  ),
                  const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${CertificationType.label(c.type)} · ${c.number}',
                          style: XText.titleM,
                        ),
                        Text(
                          CertificationStatus.label(c.status),
                          style: XText.bodyS.copyWith(
                            color: c.status == CertificationStatus.verified
                                ? XColors.success
                                : c.status == CertificationStatus.rejected
                                    ? XColors.danger
                                    : XColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: XSpace.s12),
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: XButton.secondary(
                label: 'Unggah Sertifikat',
                icon: Icons.upload_file_outlined,
                size: XButtonSize.small,
                onPressed: onAdd,
              ),
            )
          else
            Text('Sertifikat bisa diunggah setelah produk disimpan.',
                style: XText.caption.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _GuaranteeBanner extends StatelessWidget {
  const _GuaranteeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s16),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield, color: XColors.primary),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Text.rich(
              const TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'Katalog produk ini dilindungi '),
                  TextSpan(
                    text: 'Xpedia Partner Guarantee',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '. Perubahan harga dan stok langsung berlaku untuk '
                        'pembeli.',
                  ),
                ],
              ),
              style: XText.bodyS.copyWith(color: XColors.brandNavy),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.options});

  final List<CategoryOption> options;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = widget.options
        .where((o) => q.isEmpty || o.label.toLowerCase().contains(q))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(XSpace.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Kategori Produk', style: XText.headingM),
                const SizedBox(height: XSpace.s12),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: _filled(hint: 'Cari kategori')
                      .copyWith(prefixIcon: const Icon(Icons.search)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              itemCount: shown.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: XColors.borderSubtle),
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i].label, style: XText.bodyM),
                trailing:
                    Icon(Icons.chevron_right, color: XColors.textTertiary),
                onTap: () => Navigator.of(context).pop(shown[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  const _GrowthRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: () => context.push(SellerRoutes.growthProductPath(product.id)),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: XColors.brandSubtle,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Icon(Icons.trending_up_rounded, color: XColors.primary),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Xpedia Growth', style: XText.titleM),
                Text(
                  product.isGrowthActive
                      ? 'Aktif · komisi tambahan '
                          '${product.growthCommissionPercent.toStringAsFixed(0)}%'
                      : 'Belum aktif · komisi tambahan hanya saat terjual',
                  style: XText.bodyS,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: XColors.textTertiary),
        ],
      ),
    );
  }
}

/// The labels buyers see on this product's card — derived by the server from
/// age, sales, views and discount; read-only. Detail payload only.
class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final earned = product.badges;
    return _Section(
      title: 'Label pembeli',
      subtitle: earned.isEmpty
          ? 'Dihitung otomatis dari umur produk, penjualan, jumlah dilihat, '
              'dan besar diskon.'
          : 'Dihitung otomatis oleh server, tidak bisa diatur manual.',
      children: <Widget>[
        Wrap(
          spacing: XSpace.s8,
          runSpacing: XSpace.s8,
          children: <Widget>[
            for (final badge in <String>[
              ProductBadge.isNew,
              ProductBadge.bestSeller,
              ProductBadge.hot,
              ProductBadge.sale,
            ])
              Tooltip(
                message: ProductBadge.explain(badge),
                child: XChip(
                  label: ProductBadge.label(badge),
                  tone:
                      earned.contains(badge) ? XTone.success : XTone.neutral,
                  icon: earned.contains(badge)
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
