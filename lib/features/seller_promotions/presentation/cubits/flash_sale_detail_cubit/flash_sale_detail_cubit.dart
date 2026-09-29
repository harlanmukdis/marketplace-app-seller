import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product.dart';
import '../../../../../core/domain/model/catalog/product_variant.dart';
import '../../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../../core/domain/model/promotion/flash_sale_product.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../../core/domain/repositories/promotion_repository.dart';
import '../../../../../di/injector.dart';

part 'flash_sale_detail_state.dart';

/// One flash sale and what is in it.
///
/// There is **no `GET /flash-sales/{id}`** — only its products — so the sale's
/// own row is recovered by reading the store's list and picking it out. That
/// keeps the route a plain path parameter rather than something passed through
/// `state.extra`.
class FlashSaleDetailCubit extends Cubit<FlashSaleDetailState> {
  FlashSaleDetailCubit(this.flashSaleId)
      : super(const FlashSaleDetailInProgress());

  static FlashSaleDetailCubit get(BuildContext context) =>
      BlocProvider.of(context);

  final int flashSaleId;

  final PromotionRepository _promotions = injector<PromotionRepository>();
  final CatalogRepository _catalog = injector<CatalogRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  /// The store's catalogue, fetched once and kept for the picker. The listing
  /// carries no variants, so choosing one is a second call — see
  /// [variantsOf].
  List<Product>? _pickerProducts;

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const FlashSaleDetailNoStore());
      return;
    }

    emit(const FlashSaleDetailInProgress());

    final sales = await _promotions.getStoreFlashSales(storeId);
    if (isClosed) return;

    final sale = switch (sales) {
      DataSuccess<List<FlashSale>>(:final value) =>
        value.where((one) => one.id == flashSaleId).firstOrNull,
      _ => null,
    };

    if (sales is DataFailed<List<FlashSale>>) {
      emit(FlashSaleDetailFailure(sales.failure));
      return;
    }
    if (sale == null) {
      emit(const FlashSaleDetailFailure(
        DataError(
          code: 'FLASH_SALE_NOT_FOUND',
          message: 'Flash sale ini tidak ada di toko yang sedang aktif.',
        ),
      ));
      return;
    }

    final products = await _promotions.getFlashSaleProducts(flashSaleId);
    if (isClosed) return;

    switch (products) {
      case DataSuccess<List<FlashSaleProduct>>(:final value):
        emit(FlashSaleDetailLoaded(sale: sale, products: value));
      case DataEmpty<List<FlashSaleProduct>>():
        emit(FlashSaleDetailLoaded(
            sale: sale, products: const <FlashSaleProduct>[]));
      case DataFailed<List<FlashSaleProduct>>(:final failure):
        emit(FlashSaleDetailFailure(failure));
      default:
        emit(const FlashSaleDetailFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Isi flash sale tidak bisa dibaca.',
          ),
        ));
    }
  }

  /// The store's products, for choosing one to discount. Cached, because the
  /// picker reopens per addition and the catalogue is walked page by page.
  Future<List<Product>> pickerProducts() async {
    final cached = _pickerProducts;
    if (cached != null) return cached;

    final storeId = _auth.activeStoreId;
    if (storeId == null) return const <Product>[];

    final result = await _catalog.getStoreProducts(storeId);
    final products = switch (result) {
      DataSuccess<List<Product>>(:final value) => value,
      _ => const <Product>[],
    };
    _pickerProducts = products;
    return products;
  }

  /// A product's variants. The catalogue listing does not carry them —
  /// variants, images, stock and couriers are all detail-only — so picking a
  /// variant costs one call for the product that was chosen, rather than an
  /// N+1 across the whole catalogue.
  Future<List<ProductVariant>> variantsOf(int productId) async {
    final result = await _catalog.getProduct(productId);
    return switch (result) {
      DataSuccess<Product>(:final value) => value.variants,
      _ => const <ProductVariant>[],
    };
  }

  /// Puts a variant into the sale.
  ///
  /// Refuses two things the server answers with an HTML 500 or a nonsense
  /// success: the same variant twice — which breaks a `UNIQUE` key — and a
  /// flash price that is not actually below the variant's own price.
  Future<DataError?> addProduct({
    required int productVariantId,
    required int flashPrice,
    required int stockQuota,
    required int originalPrice,
    int maxQtyPerUser = 1,
  }) async {
    final current = state;
    if (current is! FlashSaleDetailLoaded) return null;

    if (current.products
        .any((row) => row.productVariantId == productVariantId)) {
      return const DataError(
        code: 'FLASH_SALE_VARIANT_DUPLICATE',
        message: 'Varian ini sudah ada di flash sale tersebut.',
      );
    }
    if (flashPrice <= 0) {
      return const DataError(
        code: 'FLASH_PRICE_INVALID',
        message: 'Harga flash sale harus lebih dari 0.',
      );
    }
    if (originalPrice > 0 && flashPrice >= originalPrice) {
      return const DataError(
        code: 'FLASH_PRICE_INVALID',
        message: 'Harga flash sale harus lebih murah dari harga normal.',
      );
    }
    if (stockQuota <= 0) {
      return const DataError(
        code: 'FLASH_QUOTA_INVALID',
        message: 'Kuota stok harus lebih dari 0.',
      );
    }

    emit(current.copyWith(isBusy: true));
    final result = await _promotions.addFlashSaleProduct(
      flashSaleId,
      productVariantId: productVariantId,
      flashPrice: flashPrice,
      stockQuota: stockQuota,
      maxQtyPerUser: maxQtyPerUser,
    );
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<List<FlashSaleProduct>>(:final value):
        emit(current.copyWith(products: value, isBusy: false));
        return null;
      case DataFailed<List<FlashSaleProduct>>(:final failure):
        emit(current.copyWith(isBusy: false));
        return failure;
      default:
        await load();
        return null;
    }
  }
}
