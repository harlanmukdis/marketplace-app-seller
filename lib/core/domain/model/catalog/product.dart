import '../../../utils/json_parse.dart';
import 'flash_sale_info.dart';
import 'product_variant.dart';

/// A catalogue entry.
///
/// Two payloads produce one of these:
///
/// * `GET /stores/{id}/products` — the seller's own list, **drafts included**,
///   a bare array with no `meta`. Rows are the table only: no variants, images,
///   stock or couriers.
/// * `GET /products/{id}` — the full row, with [variants], [images], [stock]
///   and, while one is running, [flashSale].
///
/// A product is created `draft` and only sells once it is patched to `active`,
/// so [status] is the field the catalogue screen is really about.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.storeId,
    this.slug,
    this.productType = ProductType.physical,
    this.description,
    this.basePrice = 0,
    this.compareAtPrice,
    this.weightGrams,
    this.status = ProductStatus.draft,
    this.soldCount = 0,
    this.viewCount = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.stock,
    this.variants = const <ProductVariant>[],
    this.images = const <ProductImage>[],
    this.flashSale,
    this.badges = const <String>[],
    this.createdAt,
    this.fulfillmentMode = FulfillmentMode.readyStock,
    this.fulfillmentLeadTimeDays,
    this.availability,
    this.growthCommissionPercent = 0,
    this.growthLockedUntil,
  });

  final int id;
  final String name;
  final int? storeId;
  final String? slug;
  final String productType;
  final String? description;
  final int basePrice;

  /// The struck-through "was" price. Independent of a flash sale; both can be
  /// set at once.
  final int? compareAtPrice;

  final int? weightGrams;
  final String status;
  final int soldCount;
  final int viewCount;
  final double ratingAvg;
  final int ratingCount;

  /// Total `quantity_available` across every variant and warehouse. Detail
  /// payload only — null means "not in this payload", never "no stock".
  final int? stock;

  final List<ProductVariant> variants;

  /// Readable, but nothing in the app can add to it: the API exposes no write
  /// path for product images. A seller's own image goes on a variant instead.
  final List<ProductImage> images;

  /// The **aggregate** sale across variants, absent (not null) when none runs.
  /// For a multi-variant product prefer each variant's own `flashSale`: the
  /// aggregate prices undiscounted variants as if they were on sale.
  final FlashSaleInfo? flashSale;

  /// How buyers see this product on a card: a subset of `new`, `best_seller`,
  /// `hot` and `sale` (v1.4.0). The server derives them from columns it
  /// already has — age, `sold_count`, `view_count`, and the better of the
  /// `compare_at_price` and flash-sale discounts — so they cost no extra
  /// query and cannot be set by the seller.
  ///
  /// **Only on the public listing and on `GET /products/{id}`.** The seller's
  /// own catalogue, `GET /stores/{id}/products`, does not attach them, so this
  /// is empty there — a product card in this app cannot show badges, but the
  /// product's own screen can.
  final List<String> badges;

  final DateTime? createdAt;

  /// How the product is fulfilled (API v1.7.0). `pre_order` and `custom_order`
  /// require [fulfillmentLeadTimeDays] — create and patch both refuse without.
  final String fulfillmentMode;
  final int? fulfillmentLeadTimeDays;

  /// Detail payload only: [fulfillmentMode], except that `ready_stock` is
  /// split into `ready_stock` / `low_stock` (≤ 10) / `out_of_stock` from live
  /// stock. The store list does not carry it.
  final String? availability;

  /// Xpedia Growth — extra commission, 0 (off) to 15, charged only on
  /// completed sales. Any change locks the setting until [growthLockedUntil].
  final double growthCommissionPercent;
  final DateTime? growthLockedUntil;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: asInt(json['id']),
        name: asString(json['name']),
        storeId: asIntOrNull(json['store_id']),
        slug: asStringOrNull(json['slug']),
        productType:
            asString(json['product_type'], fallback: ProductType.physical),
        description: asStringOrNull(json['description']),
        basePrice: asInt(json['base_price']),
        compareAtPrice: asIntOrNull(json['compare_at_price']),
        weightGrams: asIntOrNull(json['weight_grams']),
        status: asString(json['status'], fallback: ProductStatus.draft),
        soldCount: asInt(json['sold_count']),
        viewCount: asInt(json['view_count']),
        ratingAvg: asDouble(json['rating_avg']),
        ratingCount: asInt(json['rating_count']),
        stock: asIntOrNull(json['stock']),
        variants: asModelList(json['variants'], ProductVariant.fromJson),
        images: asModelList(json['images'], ProductImage.fromJson),
        flashSale: FlashSaleInfo.maybeFrom(json['flash_sale']),
        badges: asStringList(json['badges']),
        fulfillmentMode: asString(
          json['fulfillment_mode'],
          fallback: FulfillmentMode.readyStock,
        ),
        fulfillmentLeadTimeDays: asIntOrNull(json['fulfillment_lead_time_days']),
        availability: asStringOrNull(json['availability']),
        growthCommissionPercent: asDouble(json['growth_commission_percent']),
        growthLockedUntil: asDateTime(json['growth_locked_until']),
        createdAt: asCreatedDate(json),
      );

  bool get isActive => status == ProductStatus.active;

  /// The stock chip to show: live [availability] when the detail supplied it,
  /// otherwise the configured mode.
  String get stockMode => availability ?? fulfillmentMode;

  bool get isGrowthActive => growthCommissionPercent > 0;

  bool isGrowthLockedAt(DateTime now) =>
      growthLockedUntil != null && growthLockedUntil!.isAfter(now);
  bool get isDraft => status == ProductStatus.draft;

  /// What a buyer would pay for the product as a whole. Honest only for a
  /// single-variant product — otherwise read [ProductVariant.effectivePrice].
  int get effectivePrice => flashSale?.flashPrice ?? basePrice;

  /// Some variants discounted and others not — the case where the
  /// product-level price misleads, and the reason the backend added a
  /// per-variant block in v1.1.0.
  bool get hasPartialFlashSale {
    if (variants.length < 2) return false;
    final discounted =
        variants.where((variant) => variant.flashSale != null).length;
    return discounted > 0 && discounted < variants.length;
  }

  /// Only the variants the seller made — the generated default is an artefact
  /// of creation rather than a choice, and listing it as a variant alongside
  /// real ones reads as a duplicate.
  List<ProductVariant> get authoredVariants =>
      variants.where((variant) => !variant.isGenerated).toList(growable: false);
}

/// A row of `product_images`. Read-only in practice: no endpoint writes one.
class ProductImage {
  const ProductImage({required this.id, required this.imageUrl, this.sortOrder = 0});

  final int id;
  final String imageUrl;
  final int sortOrder;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
        id: asInt(json['id']),
        imageUrl: asString(json['image_url']),
        sortOrder: asInt(json['sort_order']),
      );
}

/// The `badges` vocabulary, and the thresholds behind each one.
///
/// The thresholds are hardcoded fallbacks on the server, overridable through
/// `admin_settings` — so the numbers quoted here are what a default install
/// uses, not a guarantee. They are worth showing the seller anyway: a badge
/// is free promotion, and knowing "50 sold" is the bar makes it actionable.
abstract class ProductBadge {
  static const String isNew = 'new';
  static const String bestSeller = 'best_seller';
  static const String hot = 'hot';
  static const String sale = 'sale';

  static String label(String badge) => switch (badge) {
        isNew => 'Baru',
        bestSeller => 'Terlaris',
        hot => 'Populer',
        sale => 'Diskon',
        _ => badge,
      };

  static String explain(String badge) => switch (badge) {
        isNew => 'Dibuat dalam 14 hari terakhir',
        bestSeller => 'Terjual minimal 50',
        hot => 'Dilihat minimal 500 kali',
        sale => 'Diskon minimal 20%',
        _ => 'Dihitung otomatis oleh server',
      };
}

abstract class ProductStatus {
  static const String draft = 'draft';
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String archived = 'archived';

  /// `archived` is reachable only by patching status: there is no delete
  /// endpoint, so it is the nearest thing to removing a product.
  static const List<String> all = <String>[draft, active, inactive, archived];

  static String label(String? status) => switch (status) {
        draft => 'Draf',
        active => 'Aktif',
        inactive => 'Nonaktif',
        archived => 'Diarsipkan',
        _ => status ?? '-',
      };
}

abstract class ProductType {
  static const String physical = 'physical';
  static const String digital = 'digital';
  static const String service = 'service';

  static const List<String> all = <String>[physical, digital, service];

  static String label(String? type) => switch (type) {
        physical => 'Barang fisik',
        digital => 'Produk digital',
        service => 'Jasa',
        _ => type ?? '-',
      };
}

/// `products.fulfillment_mode` (API v1.7.0).
abstract class FulfillmentMode {
  static const String readyStock = 'ready_stock';
  static const String infinite = 'infinite';
  static const String preOrder = 'pre_order';
  static const String customOrder = 'custom_order';
  static const String discontinued = 'discontinued';

  /// What a seller can set. `low_stock` and `out_of_stock` are derived by the
  /// server from `ready_stock`, never chosen.
  static const List<String> settable = <String>[
    readyStock,
    preOrder,
    customOrder,
    infinite,
    discontinued,
  ];

  static bool needsLeadTime(String mode) =>
      mode == preOrder || mode == customOrder;
}

/// The seven stock chips of design rule 9 — the settable modes plus the two
/// the server derives from live stock.
abstract class StockMode {
  static const String lowStock = 'low_stock';
  static const String outOfStock = 'out_of_stock';

  static String label(String mode, {int? leadTimeDays}) => switch (mode) {
        FulfillmentMode.readyStock => 'Ready Stock',
        FulfillmentMode.infinite => 'Infinite',
        FulfillmentMode.preOrder =>
          leadTimeDays == null ? 'Pre-Order' : 'Pre-Order ($leadTimeDays hari)',
        FulfillmentMode.customOrder => leadTimeDays == null
            ? 'Custom Order'
            : 'Custom Order ($leadTimeDays hari)',
        FulfillmentMode.discontinued => 'Discontinued',
        lowStock => 'Low Stock',
        outOfStock => 'Stok Kosong',
        _ => mode,
      };

  static String describe(String mode) => switch (mode) {
        FulfillmentMode.readyStock => 'Dikirim dari stok gudang.',
        FulfillmentMode.infinite => 'Selalu tersedia, stok tidak dihitung.',
        FulfillmentMode.preOrder =>
          'Dibuat atau dipesan setelah dibayar; dikirim setelah lead time.',
        FulfillmentMode.customOrder =>
          'Dibuat khusus; tiap pesanan wajib dikonfirmasi dalam 2×24 jam.',
        FulfillmentMode.discontinued =>
          'Tidak dijual lagi; hilang dari pencarian, halaman tetap ada.',
        _ => '',
      };
}
