import '../../../utils/json_parse.dart';

/// One shop owned by the logged-in account.
///
/// Replaces the previous backend's `seller`. The important behavioural
/// difference: a store starts `inactive` and is not publicly readable until it
/// is activated — `GET /stores/{id}` answers `STORE_NOT_FOUND` for an inactive
/// store even to its own owner, so the owner's view has to come from
/// `GET /stores` instead.
class Store {
  const Store({
    required this.id,
    required this.name,
    this.ownerUserId,
    this.slug,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.type = StoreType.physical,
    this.status,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.openedAt,
    this.createdAt,
    this.primaryStatus = StorePrimaryStatus.unverified,
    this.hasSignatureBadge = false,
    this.skuQuota,
  });

  final int id;
  final String name;
  final int? ownerUserId;
  final String? slug;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String type;
  final String? status;
  final double ratingAvg;
  final int ratingCount;
  final DateTime? openedAt;
  final DateTime? createdAt;

  /// Seller status (API v1.14.0): set to verified individual/company when
  /// verification is approved; official store and "managed by Xpedia" are
  /// admin-curated. Design rule 8.
  final String primaryStatus;

  /// Xpedia Signature — a performance award evaluated nightly, separate from
  /// [primaryStatus] and never purchasable.
  final bool hasSignatureBadge;

  /// Maximum products; null means unlimited. Set to 500 when a business
  /// verification is approved (API v1.11.0), enforced as `SKU_QUOTA_EXCEEDED`.
  final int? skuQuota;

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: asInt(json['id']),
        name: asString(json['name']),
        ownerUserId: asIntOrNull(json['owner_user_id']),
        slug: asStringOrNull(json['slug']),
        description: asStringOrNull(json['description']),
        logoUrl: asStringOrNull(json['logo_url']),
        bannerUrl: asStringOrNull(json['banner_url']),
        type: asString(json['type'], fallback: StoreType.physical),
        status: asStringOrNull(json['status']),
        ratingAvg: asDouble(json['rating_avg']),
        ratingCount: asInt(json['rating_count']),
        openedAt: asDateTime(json['opened_at']),
        createdAt: asCreatedDate(json),
        primaryStatus: asString(
          json['primary_status'],
          fallback: StorePrimaryStatus.unverified,
        ),
        hasSignatureBadge: asBool(json['has_signature_badge']),
        skuQuota: asIntOrNull(json['sku_quota']),
      );

  bool get isActive => status == StoreStatus.active;

  /// The slug the server actually assigned, which is not the one that was
  /// requested: it appends a suffix to keep slugs unique.
  String get publicSlug => slug ?? '';
}

abstract class StoreStatus {
  static const String inactive = 'inactive';
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String closed = 'closed';

  static String label(String? status) => switch (status) {
        inactive => 'Belum aktif',
        active => 'Aktif',
        suspended => 'Ditangguhkan',
        closed => 'Tutup',
        _ => status ?? '-',
      };
}

abstract class StoreType {
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

abstract class StorePrimaryStatus {
  static const String unverified = 'unverified';
  static const String verifiedIndividual = 'verified_individual';
  static const String verifiedCompany = 'verified_company';
  static const String officialStore = 'official_store';
  static const String managedByXpedia = 'managed_by_xpedia';

  static String label(String? s) => switch (s) {
        verifiedIndividual => 'Verified Individual',
        verifiedCompany => 'Verified Company',
        officialStore => 'Official Store',
        managedByXpedia => 'Managed by Xpedia',
        _ => 'Belum terverifikasi',
      };

  static bool isVerified(String? s) => s != null && s != unverified;
}
