/// Parts of S-34 the store profile has no columns for: two mini banners
/// beside the main one, and the home-page highlight switches.
class MiniBanner {
  const MiniBanner({required this.slot, this.imageUrl, this.caption});

  /// 1 or 2.
  final int slot;
  final String? imageUrl;
  final String? caption;
}

class StorefrontHighlight {
  const StorefrontHighlight({
    required this.key,
    required this.title,
    required this.description,
    this.enabled = false,
  });

  final String key;
  final String title;
  final String description;
  final bool enabled;

  StorefrontHighlight withEnabled(bool value) => StorefrontHighlight(
        key: key,
        title: title,
        description: description,
        enabled: value,
      );
}

abstract class HighlightKey {
  static const String flashSale = 'flash_sale';
  static const String signature = 'signature';
  static const String videoReviews = 'video_reviews';
}
