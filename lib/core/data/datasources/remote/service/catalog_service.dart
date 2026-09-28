import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/catalog/category.dart';
import '../../../../domain/model/catalog/product.dart';
import '../../../../domain/model/catalog/product_certification.dart';
import '../../../../domain/model/catalog/product_growth.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// Categories, products and variants.
///
/// Two rules shape almost everything here. **No write returns what it wrote** —
/// a `POST` answers `{id}` and a `PATCH` answers nothing — so every mutation
/// that a screen needs the result of ends with a read. And **the seller's list
/// is not the public one**: `GET /products` hides drafts, so a store's own
/// catalogue has to come from `GET /stores/{id}/products`.
class CatalogService extends BaseService {
  const CatalogService(super.dio);

  /// The category tree, parents carrying `children`.
  Future<List<Category>> getCategories() async {
    final envelope = await getRequest(ApiEndpoints.categories);
    return envelope.list.map(Category.fromJson).toList(growable: false);
  }

  /// One page of the store's own catalogue, drafts included.
  ///
  /// The response is a bare array with **no `meta`**, which makes this endpoint
  /// easy to misread: it looks unpaged, but it is capped at 20 rows like every
  /// other list. A single call therefore returns a truncated catalogue with
  /// nothing to say so. Use [getAllStoreProducts] unless you are deliberately
  /// paging by hand.
  Future<List<Product>> getStoreProducts(int storeId, {int page = 1}) async {
    final envelope = await getRequest(
      ApiEndpoints.storeProducts(storeId),
      query: <String, dynamic>{'page': page},
    );
    return envelope.list.map(Product.fromJson).toList(growable: false);
  }

  /// The whole catalogue, walked page by page.
  ///
  /// With no total to page against, a short page is the only end-of-list
  /// signal. [maxPages] is a stop so a server that ignored `page` — and so
  /// answered a full page forever — could not spin here indefinitely.
  Future<List<Product>> getAllStoreProducts(
    int storeId, {
    int maxPages = 25,
  }) async {
    const int pageSize = 20;
    final products = <Product>[];

    for (var page = 1; page <= maxPages; page++) {
      final batch = await getStoreProducts(storeId, page: page);
      products.addAll(batch);
      if (batch.length < pageSize) break;
    }

    return List<Product>.unmodifiable(products);
  }

  /// The full row: variants, images, stock, compare-at price, and a
  /// `flash_sale` block while one is running.
  Future<Product> getProduct(int productId) async {
    final envelope = await getRequest(ApiEndpoints.product(productId));
    return Product.fromJson(envelope.map);
  }

  /// Answers `{ "id": N }`. The product is created `draft`, and the server also
  /// generates a default variant for it — see [ProductVariant].
  ///
  /// Refusals added since v1.7.0: `SKU_QUOTA_EXCEEDED` (store at its product
  /// cap), `PRODUCT_PROHIBITED` (403, category or keyword banned outright), and
  /// a `VALIDATION_ERROR` when a pre-order/custom mode has no lead time. A
  /// *restricted* (not prohibited) match is created but flagged for review, and
  /// then cannot be published until an admin clears it.
  Future<int> createProduct(
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
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.storeProducts(storeId),
      body: <String, dynamic>{
        'name': name,
        'category_id': categoryId,
        'product_type': productType,
        'description': description,
        'base_price': basePrice,
        'weight_grams': weightGrams,
        'compare_at_price': compareAtPrice,
        'fulfillment_mode': fulfillmentMode,
        'fulfillment_lead_time_days': fulfillmentLeadTimeDays,
      },
    );
    return asInt(envelope.map['id']);
  }

  /// Patches and re-reads, because the patch itself answers `data: null`.
  ///
  /// Only the fields passed are sent — the caller can flip `status` alone
  /// without restating the whole product. The server's whitelist is `name`,
  /// `description`, `base_price`, `compare_at_price`, `weight_grams`,
  /// `status`, `fulfillment_mode`, `fulfillment_lead_time_days`:
  /// **`category_id` and `product_type` are not updatable**, so both are
  /// settled at creation.
  ///
  /// Publishing can be refused with `CERTIFICATION_REQUIRED` (the category
  /// needs a verified certificate) or `RESTRICTION_REVIEW_PENDING` (the
  /// product was flagged as restricted and awaits an admin).
  Future<Product> updateProduct(
    int productId, {
    String? name,
    String? description,
    int? basePrice,
    int? compareAtPrice,
    int? weightGrams,
    String? status,
    String? fulfillmentMode,
    int? fulfillmentLeadTimeDays,
  }) async {
    await patchRequest(
      ApiEndpoints.product(productId),
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'base_price': basePrice,
        'compare_at_price': compareAtPrice,
        'weight_grams': weightGrams,
        'status': status,
        'fulfillment_mode': fulfillmentMode,
        'fulfillment_lead_time_days': fulfillmentLeadTimeDays,
      },
    );
    return getProduct(productId);
  }

  /// Adds a variant and returns the product as it stands afterwards, so the
  /// caller sees the new row alongside the generated default.
  ///
  /// `variant_options` is sent as a real object; the server stores it as a JSON
  /// string and hands it back that way.
  Future<Product> createVariant(
    int productId, {
    required String sku,
    required int price,
    Map<String, dynamic> options = const <String, dynamic>{},
    int? weightGrams,
    String? imageUrl,
  }) async {
    await postRequest(
      ApiEndpoints.productVariants(productId),
      body: <String, dynamic>{
        'sku': sku,
        'price': price,
        'weight_grams': weightGrams,
        'image_url': imageUrl,
        if (options.isNotEmpty) 'variant_options': options,
      },
    );
    return getProduct(productId);
  }

  Future<Product> updateVariant(
    int productId,
    int variantId, {
    String? sku,
    int? price,
    int? weightGrams,
    String? imageUrl,
    bool? isActive,
    Map<String, dynamic>? options,
  }) async {
    await patchRequest(
      ApiEndpoints.productVariant(productId, variantId),
      body: <String, dynamic>{
        'sku': sku,
        'price': price,
        'weight_grams': weightGrams,
        'image_url': imageUrl,
        'is_active': isActive == null ? null : (isActive ? 1 : 0),
        'variant_options': options,
      },
    );
    return getProduct(productId);
  }

  /// Sets Xpedia Growth, 0 (off) to 15%.
  ///
  /// **Every accepted call locks the setting for seven days — including a call
  /// that changes nothing.** Verified: patching 0 onto a product already at 0
  /// answered 200 and locked it. Callers must not send a no-op.
  ///
  /// Refusals: `GROWTH_LOCKED` (message names the unlock time) and, only when
  /// switching on from 0, `NATURAL_PERFORMANCE_TOO_LOW` (live score under 60).
  Future<void> setGrowth(int productId, {required int commissionPercent}) async {
    await patchRequest(
      ApiEndpoints.productGrowth(productId),
      body: <String, dynamic>{'commission_percent': commissionPercent},
    );
  }

  Future<GrowthPerformance> getGrowthPerformance(int productId) async {
    final envelope =
        await getRequest(ApiEndpoints.productGrowthPerformance(productId));
    return GrowthPerformance.fromJson(envelope.map);
  }

  Future<ShippingCoverage> getShippingCoverage(int productId) async {
    final envelope =
        await getRequest(ApiEndpoints.productShippingCoverage(productId));
    return ShippingCoverage.fromRows(envelope.list);
  }

  /// Replace-all. `none` clears every restriction; the other modes need at
  /// least one location, each naming a city **or** a province.
  Future<ShippingCoverage> setShippingCoverage(
    int productId, {
    required String mode,
    List<CoverageLocation> locations = const <CoverageLocation>[],
  }) async {
    await patchRequest(
      ApiEndpoints.productShippingCoverage(productId),
      body: <String, dynamic>{
        'mode': mode,
        'locations': <Map<String, dynamic>>[
          for (final l in locations) l.toJson(),
        ],
      },
    );
    return getShippingCoverage(productId);
  }

  Future<List<ProductCertification>> getCertifications(int productId) async {
    final envelope =
        await getRequest(ApiEndpoints.productCertifications(productId));
    return envelope.list
        .map(ProductCertification.fromJson)
        .toList(growable: false);
  }

  /// JSON body. Validate before calling — see [ProductCertification].
  Future<List<ProductCertification>> submitCertification(
    int productId, {
    required String type,
    required String number,
    required String documentUrl,
    String? issuedBy,
    String? validUntil,
  }) async {
    await postRequest(
      ApiEndpoints.productCertifications(productId),
      body: <String, dynamic>{
        'certification_type': type,
        'certificate_number': number,
        'document_url': documentUrl,
        'issued_by': issuedBy,
        'valid_until': validUntil,
      },
    );
    return getCertifications(productId);
  }
}
