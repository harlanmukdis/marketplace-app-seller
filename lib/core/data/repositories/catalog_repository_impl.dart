import '../../data_state.dart';
import '../../domain/model/catalog/category.dart';
import '../../domain/model/catalog/product.dart';
import '../../domain/model/catalog/product_certification.dart';
import '../../domain/model/catalog/product_growth.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/remote/service/catalog_service.dart';
import 'repository_guard.dart';

class CatalogRepositoryImpl with RepositoryGuard implements CatalogRepository {
  const CatalogRepositoryImpl(this._service);

  final CatalogService _service;

  @override
  Future<DataState<List<Category>>> getCategories() =>
      guard(() => _service.getCategories());

  @override
  Future<DataState<List<Product>>> getStoreProducts(int storeId) =>
      guard(() => _service.getAllStoreProducts(storeId));

  @override
  Future<DataState<Product>> getProduct(int productId) =>
      guard(() => _service.getProduct(productId));

  @override
  Future<DataState<int>> createProduct(
    int storeId, {
    required String name,
    required int categoryId,
    required int basePrice,
    String productType = ProductType.physical,
    String? description,
    int? weightGrams,
    int? compareAtPrice,
    String fulfillmentMode = FulfillmentMode.readyStock,
    int? fulfillmentLeadTimeDays,
  }) =>
      guard(() => _service.createProduct(
            storeId,
            name: name,
            categoryId: categoryId,
            basePrice: basePrice,
            productType: productType,
            description: description,
            weightGrams: weightGrams,
            compareAtPrice: compareAtPrice,
            fulfillmentMode: fulfillmentMode,
            fulfillmentLeadTimeDays: fulfillmentLeadTimeDays,
          ));

  @override
  Future<DataState<Product>> updateProduct(
    int productId, {
    String? name,
    String? description,
    int? basePrice,
    int? compareAtPrice,
    int? weightGrams,
    String? status,
    String? fulfillmentMode,
    int? fulfillmentLeadTimeDays,
  }) =>
      guard(() => _service.updateProduct(
            productId,
            name: name,
            description: description,
            basePrice: basePrice,
            compareAtPrice: compareAtPrice,
            weightGrams: weightGrams,
            status: status,
            fulfillmentMode: fulfillmentMode,
            fulfillmentLeadTimeDays: fulfillmentLeadTimeDays,
          ));

  @override
  Future<DataState<Product>> setGrowth(
    int productId, {
    required int commissionPercent,
  }) =>
      guard(() async {
        await _service.setGrowth(
          productId,
          commissionPercent: commissionPercent,
        );
        return _service.getProduct(productId);
      });

  @override
  Future<DataState<GrowthPerformance>> getGrowthPerformance(int productId) =>
      guard(() => _service.getGrowthPerformance(productId));

  @override
  Future<DataState<ShippingCoverage>> getShippingCoverage(int productId) =>
      guard(() => _service.getShippingCoverage(productId));

  @override
  Future<DataState<ShippingCoverage>> setShippingCoverage(
    int productId, {
    required String mode,
    List<CoverageLocation> locations = const <CoverageLocation>[],
  }) =>
      guard(() => _service.setShippingCoverage(
            productId,
            mode: mode,
            locations: locations,
          ));

  @override
  Future<DataState<Product>> createVariant(
    int productId, {
    required String sku,
    required int price,
    Map<String, dynamic> options = const <String, dynamic>{},
    int? weightGrams,
    String? imageUrl,
  }) =>
      guard(() => _service.createVariant(
            productId,
            sku: sku,
            price: price,
            options: options,
            weightGrams: weightGrams,
            imageUrl: imageUrl,
          ));

  @override
  Future<DataState<Product>> updateVariant(
    int productId,
    int variantId, {
    String? sku,
    int? price,
    int? weightGrams,
    String? imageUrl,
    bool? isActive,
    Map<String, dynamic>? options,
  }) =>
      guard(() => _service.updateVariant(
            productId,
            variantId,
            sku: sku,
            price: price,
            weightGrams: weightGrams,
            imageUrl: imageUrl,
            isActive: isActive,
            options: options,
          ));

  @override
  Future<DataState<List<ProductCertification>>> getCertifications(
    int productId,
  ) =>
      guard(() => _service.getCertifications(productId));

  @override
  Future<DataState<List<ProductCertification>>> submitCertification(
    int productId, {
    required String type,
    required String number,
    required String documentUrl,
    String? issuedBy,
    String? validUntil,
  }) =>
      guard(() => _service.submitCertification(
            productId,
            type: type,
            number: number,
            documentUrl: documentUrl,
            issuedBy: issuedBy,
            validUntil: validUntil,
          ));
}
