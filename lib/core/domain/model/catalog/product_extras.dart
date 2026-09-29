/// Listing fields S-27 asks for that `products` cannot store (⏳ no
/// columns or endpoints): a 9-photo gallery (`product_images` is
/// read-only), minimum order, wholesale tiers, brand, condition and package
/// dimensions (the `dimensions` column exists, nothing writes it).
class ProductExtras {
  const ProductExtras({
    this.photos = const <String>[],
    this.minOrder = 1,
    this.wholesale = const <WholesaleTier>[],
    this.brand,
    this.condition = ProductCondition.newItem,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
  });

  static const int maxPhotos = 9;
  static const int maxTiers = 5;

  final List<String> photos;
  final int minOrder;
  final List<WholesaleTier> wholesale;
  final String? brand;

  /// [ProductCondition].
  final String condition;
  final int? lengthCm;
  final int? widthCm;
  final int? heightCm;

  /// Volumetric weight in grams at the common 6000 divisor.
  int? get volumetricGrams {
    final l = lengthCm, w = widthCm, h = heightCm;
    if (l == null || w == null || h == null) return null;
    return (l * w * h / 6000 * 1000).round();
  }
}

class WholesaleTier {
  const WholesaleTier({required this.minQuantity, required this.unitPrice});

  final int minQuantity;
  final int unitPrice;
}

abstract class ProductCondition {
  static const String newItem = 'new';
  static const String used = 'used';
}
