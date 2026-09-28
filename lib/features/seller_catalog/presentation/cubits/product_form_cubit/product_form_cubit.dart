import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/category.dart';
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/model/catalog/product_certification.dart';
import '../../../../../core/domain/model/catalog/product_growth.dart';
import '../../../../../core/domain/model/catalog/product_variant.dart';
import '../../../../../core/domain/model/media/uploaded_file.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../../core/domain/repositories/store_repository.dart';
import '../../../../../di/injector.dart';
import '../../product_errors.dart';

part 'product_form_state.dart';

/// A photo picked on the device, not yet uploaded.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// One variant row of the create form (S-27 "Varian Produk").
class VariantRowDraft {
  const VariantRowDraft({
    required this.price,
    this.value,
    this.sku,
    this.photo,
  });

  /// The option value, e.g. "Black"; null for a product without variants.
  final String? value;
  final int price;

  /// Blank means generate one — SKUs are unique across the whole platform.
  final String? sku;
  final PickedPhoto? photo;
}

/// Everything the create/edit form collected.
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.rows,
    this.categoryId,
    this.productType = ProductType.physical,
    this.description,
    this.weightGrams,
    this.compareAtPrice,
    this.fulfillmentMode = FulfillmentMode.readyStock,
    this.leadTimeDays,
    this.variantType,
    this.coverage = const ShippingCoverage(),
  });

  final String name;
  final int? categoryId;
  final String productType;
  final String? description;
  final int? weightGrams;
  final int? compareAtPrice;
  final String fulfillmentMode;
  final int? leadTimeDays;

  /// The option name ("Warna", "Ukuran"); null when there are no variants.
  final String? variantType;

  /// At least one. The first becomes the server's generated default variant.
  final List<VariantRowDraft> rows;
  final ShippingCoverage coverage;

  /// `base_price` is what cards and search show; the cheapest variant is the
  /// honest "mulai dari" figure.
  int get basePrice =>
      rows.map((r) => r.price).reduce((a, b) => a < b ? a : b);
}

/// Creating one product, or editing one that exists (S-27).
///
/// [productId] null means create. Creating is a chain, because the API has no
/// single call for it: create the product (which also generates one variant),
/// turn that generated variant into the first row, add the other rows, attach
/// each row's photo, apply shipping coverage, and optionally publish. A step
/// that fails after the product exists leaves a draft behind and says so.
class ProductFormCubit extends Cubit<ProductFormState> {
  ProductFormCubit({this.productId}) : super(const ProductFormInProgress());

  static ProductFormCubit get(BuildContext context) => BlocProvider.of(context);

  /// Null when creating.
  final int? productId;

  final CatalogRepository _catalog = injector<CatalogRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  bool get isEditing => productId != null;

  Future<void> load() async {
    emit(const ProductFormInProgress());

    final categoriesResult = await _catalog.getCategories();
    if (isClosed) return;

    final List<Category> categories;
    switch (categoriesResult) {
      case DataSuccess<List<Category>>(:final value):
        categories = value;
      case DataEmpty<List<Category>>():
        // A catalogue cannot be built without categories, and the seed has
        // shipped empty before — say so rather than showing a blank picker.
        emit(const ProductFormFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Server belum punya kategori, jadi produk belum bisa '
                'dibuat. Minta admin menambahkan kategori dulu.',
          ),
        ));
        return;
      case DataFailed<List<Category>>(:final failure):
        emit(ProductFormFailure(failure));
        return;
      case DataLoading<List<Category>>():
        return;
    }

    final id = productId;
    if (id == null) {
      emit(ProductFormReady(categories: categories));
      return;
    }

    final productResult = await _catalog.getProduct(id);
    if (isClosed) return;

    switch (productResult) {
      case DataSuccess<Product>(:final value):
        // Coverage and certifications are separate calls; a failure in either
        // must not block editing, so each degrades to empty.
        final extras = await Future.wait<Object>(<Future<Object>>[
          _catalog.getShippingCoverage(id),
          _catalog.getCertifications(id),
        ]);
        if (isClosed) return;
        final coverage = extras[0];
        final certs = extras[1];
        emit(ProductFormReady(
          categories: categories,
          product: value,
          coverage: coverage is DataSuccess<ShippingCoverage>
              ? coverage.value
              : const ShippingCoverage(),
          certifications: certs is DataSuccess<List<ProductCertification>>
              ? certs.value
              : const <ProductCertification>[],
        ));
      case DataFailed<Product>(:final failure):
        emit(ProductFormFailure(failure));
      default:
        emit(const ProductFormFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Produk tidak ditemukan.',
          ),
        ));
    }
  }

  DataError? _validate(ProductDraft draft) {
    if (FulfillmentMode.needsLeadTime(draft.fulfillmentMode) &&
        (draft.leadTimeDays == null || draft.leadTimeDays! <= 0)) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Pre-Order dan Custom Order wajib punya lead time (hari).',
      );
    }
    if (draft.rows.isEmpty || draft.rows.any((r) => r.price <= 0)) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Setiap varian wajib punya harga.',
      );
    }
    return null;
  }

  /// Creates a product from [draft] and returns its id, with a warning when a
  /// follow-up step failed after the product already existed.
  Future<(DataError?, int?)> create(
    ProductDraft draft, {
    bool publish = false,
  }) async {
    final current = state;
    if (current is! ProductFormReady) return (null, null);
    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      return (
        const DataError(
          code: DataErrorCode.unexpected,
          message: 'Belum ada toko yang dipilih.',
        ),
        null,
      );
    }
    final invalid = _validate(draft);
    if (invalid != null) return (invalid, null);
    final categoryId = draft.categoryId;
    if (categoryId == null) {
      return (
        const DataError(
          code: 'VALIDATION_LOCAL',
          message: 'Kategori wajib dipilih.',
        ),
        null,
      );
    }

    emit(current.copyWith(isSaving: true));

    final created = await _catalog.createProduct(
      storeId,
      name: draft.name,
      categoryId: categoryId,
      basePrice: draft.basePrice,
      productType: draft.productType,
      description: draft.description,
      weightGrams: draft.weightGrams,
      compareAtPrice: draft.compareAtPrice,
      fulfillmentMode: draft.fulfillmentMode,
      fulfillmentLeadTimeDays: FulfillmentMode.needsLeadTime(
        draft.fulfillmentMode,
      )
          ? draft.leadTimeDays
          : null,
    );
    if (isClosed) return (null, null);
    if (created is! DataSuccess<int>) {
      emit(current.copyWith(isSaving: false));
      return (
        created is DataFailed<int>
            ? explainProductError(created.failure)
            : _noResultError,
        null,
      );
    }
    final id = created.value;

    final followUp = await _completeCreate(id, storeId, draft, publish);
    if (isClosed) return (null, null);
    emit(current.copyWith(isSaving: false));
    return (followUp, id);
  }

  /// Everything after the product exists. Returns the first failure, worded
  /// so the seller knows the product itself was saved.
  Future<DataError?> _completeCreate(
    int id,
    int storeId,
    ProductDraft draft,
    bool publish,
  ) async {
    DataError? partial(String step, DataError e) => DataError(
          code: e.code,
          message: 'Produk tersimpan sebagai draf, tapi $step gagal: '
              '${e.message}',
          details: e.details,
        );

    final detail = await _catalog.getProduct(id);
    if (detail is! DataSuccess<Product>) {
      return detail is DataFailed<Product>
          ? partial('memuat varian', detail.failure)
          : null;
    }
    final generated = detail.value.variants.isEmpty
        ? null
        : detail.value.variants.first;

    for (var i = 0; i < draft.rows.length; i++) {
      final row = draft.rows[i];
      final options = row.value == null || draft.variantType == null
          ? const <String, dynamic>{}
          : <String, dynamic>{draft.variantType!: row.value};
      final sku = (row.sku == null || row.sku!.isEmpty)
          ? _generateSku(id, i)
          : row.sku!;

      String? imageUrl;
      final photo = row.photo;
      if (photo != null) {
        final uploaded = await injector<StoreRepository>().upload(
          bytes: photo.bytes,
          fileName: photo.fileName,
          storeId: storeId,
          context: 'product_photo',
        );
        if (uploaded is DataFailed<UploadedFile>) {
          return partial('unggah foto', uploaded.failure);
        }
        if (uploaded is DataSuccess<UploadedFile>) {
          imageUrl = uploaded.value.url;
        }
      }

      final DataState<Product> result;
      if (i == 0 && generated != null) {
        // The server's generated default becomes the first row, so the
        // product never carries a phantom variant.
        result = await _catalog.updateVariant(
          id,
          generated.id,
          sku: row.sku == null || row.sku!.isEmpty ? null : sku,
          price: row.price,
          options: options.isEmpty ? null : options,
          imageUrl: imageUrl,
        );
      } else {
        result = await _catalog.createVariant(
          id,
          sku: sku,
          price: row.price,
          options: options,
          weightGrams: draft.weightGrams,
          imageUrl: imageUrl,
        );
      }
      if (result is DataFailed<Product>) {
        return partial('menyimpan varian ${row.value ?? ''}'.trim(),
            result.failure);
      }
    }

    if (draft.coverage.isRestricted) {
      final coverage = await _catalog.setShippingCoverage(
        id,
        mode: draft.coverage.mode,
        locations: draft.coverage.locations,
      );
      if (coverage is DataFailed<ShippingCoverage>) {
        return partial('menyimpan cakupan pengiriman', coverage.failure);
      }
    }

    if (publish) {
      final published =
          await _catalog.updateProduct(id, status: ProductStatus.active);
      if (published is DataFailed<Product>) {
        return explainProductError(published.failure);
      }
    }
    return null;
  }

  static String _generateSku(int productId, int index) {
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'XP-$productId-$stamp-${index + 1}'.toUpperCase();
  }

  /// Saves the product fields of an existing product. Variants, photos,
  /// coverage and certifications have their own calls.
  Future<DataError?> update(ProductDraft draft) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    final invalid = _validate(draft);
    if (invalid != null) return invalid;

    emit(current.copyWith(isSaving: true));
    // `category_id` and `product_type` are absent on purpose: the backend's
    // PATCH whitelists neither, so both are settled at creation.
    final result = await _catalog.updateProduct(
      id,
      name: draft.name,
      description: draft.description,
      basePrice: draft.basePrice,
      compareAtPrice: draft.compareAtPrice,
      weightGrams: draft.weightGrams,
      fulfillmentMode: draft.fulfillmentMode,
      fulfillmentLeadTimeDays:
          FulfillmentMode.needsLeadTime(draft.fulfillmentMode)
              ? draft.leadTimeDays
              : null,
    );
    if (isClosed) return null;
    return _settle(current, result);
  }

  Future<DataError?> setStatus(String status) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    emit(current.copyWith(isSaving: true));

    final result = await _catalog.updateProduct(id, status: status);
    if (isClosed) return null;
    if (result is DataFailed<Product>) {
      emit(current.copyWith(
        isSaving: false,
        moderationPending: result.failure.code == 'RESTRICTION_REVIEW_PENDING',
      ));
      return explainProductError(result.failure);
    }
    return _settle(current, result);
  }

  Future<DataError?> addVariant({
    required String sku,
    required int price,
    Map<String, dynamic> options = const <String, dynamic>{},
    int? weightGrams,
  }) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    emit(current.copyWith(isSaving: true));
    final result = await _catalog.createVariant(
      id,
      sku: sku,
      price: price,
      options: options,
      weightGrams: weightGrams,
    );
    if (isClosed) return null;
    return _settle(current, result);
  }

  Future<DataError?> setVariantPrice(ProductVariant variant, int price) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    emit(current.copyWith(isSaving: true));
    final result = await _catalog.updateVariant(id, variant.id, price: price);
    if (isClosed) return null;
    return _settle(current, result);
  }

  /// Uploads a photo for one variant — the only product image this backend
  /// lets a seller write — then points the variant at it. Uploaded with
  /// `context=product_photo` so the server watermarks it.
  Future<DataError?> setVariantPhoto(int variantId, PickedPhoto photo) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    emit(current.copyWith(isSaving: true));

    final uploaded = await injector<StoreRepository>().upload(
      bytes: photo.bytes,
      fileName: photo.fileName,
      storeId: _auth.activeStoreId,
      context: 'product_photo',
    );
    if (isClosed) return null;
    if (uploaded is! DataSuccess<UploadedFile>) {
      emit(current.copyWith(isSaving: false));
      return uploaded is DataFailed<UploadedFile>
          ? uploaded.failure
          : _noResultError;
    }

    final result = await _catalog.updateVariant(
      id,
      variantId,
      imageUrl: uploaded.value.url,
    );
    if (isClosed) return null;
    return _settle(current, result);
  }

  /// Replaces the product's shipping coverage.
  Future<DataError?> setCoverage(
    String mode,
    List<CoverageLocation> locations,
  ) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    if (mode != CoverageMode.none && locations.isEmpty) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Pilih minimal satu kota atau provinsi.',
      );
    }
    emit(current.copyWith(isSaving: true));
    final result = await _catalog.setShippingCoverage(
      id,
      mode: mode,
      locations:
          mode == CoverageMode.none ? const <CoverageLocation>[] : locations,
    );
    if (isClosed) return null;
    switch (result) {
      case DataSuccess<ShippingCoverage>(:final value):
        emit(current.copyWith(coverage: value, isSaving: false));
        return null;
      case DataFailed<ShippingCoverage>(:final failure):
        emit(current.copyWith(isSaving: false));
        return failure;
      default:
        emit(current.copyWith(isSaving: false));
        return _noResultError;
    }
  }

  /// Uploads the document, then records the certification for review.
  Future<DataError?> submitCertification({
    required String type,
    required String number,
    required PickedPhoto document,
    String? issuedBy,
    String? validUntil,
  }) async {
    final id = productId;
    final current = state;
    if (id == null || current is! ProductFormReady) return null;
    if (!CertificationType.all.contains(type) || number.trim().isEmpty) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Jenis dan nomor sertifikat wajib diisi.',
      );
    }
    emit(current.copyWith(isSaving: true));

    final uploaded = await injector<StoreRepository>().upload(
      bytes: document.bytes,
      fileName: document.fileName,
      storeId: _auth.activeStoreId,
    );
    if (isClosed) return null;
    if (uploaded is! DataSuccess<UploadedFile>) {
      emit(current.copyWith(isSaving: false));
      return uploaded is DataFailed<UploadedFile>
          ? uploaded.failure
          : _noResultError;
    }

    final result = await _catalog.submitCertification(
      id,
      type: type,
      number: number.trim(),
      documentUrl: uploaded.value.url,
      issuedBy: issuedBy,
      validUntil: validUntil,
    );
    if (isClosed) return null;
    switch (result) {
      case DataSuccess<List<ProductCertification>>(:final value):
        emit(current.copyWith(certifications: value, isSaving: false));
        return null;
      case DataFailed<List<ProductCertification>>(:final failure):
        emit(current.copyWith(isSaving: false));
        return failure;
      default:
        emit(current.copyWith(isSaving: false));
        return null;
    }
  }

  DataError? _settle(ProductFormReady current, DataState<Product> result) {
    switch (result) {
      case DataSuccess<Product>(:final value):
        emit(current.copyWith(product: value, isSaving: false));
        return null;
      case DataFailed<Product>(:final failure):
        emit(current.copyWith(isSaving: false));
        return explainProductError(failure);
      default:
        emit(current.copyWith(isSaving: false));
        return _noResultError;
    }
  }

  static const DataError _noResultError = DataError(
    code: DataErrorCode.unexpected,
    message: 'Server tidak mengembalikan hasil yang diharapkan.',
  );
}
