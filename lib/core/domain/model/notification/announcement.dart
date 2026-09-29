/// Official platform news for sellers — "Info & Update Xpedia" (S-11).
///
/// ⏳ No endpoint: admin broadcasts land in each account's notifications,
/// with nothing marking them as official or promotional.
class Announcement {
  const Announcement({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.cta,
    this.publishedAt,
  });

  final int id;

  /// [AnnouncementKind].
  final String kind;
  final String title;
  final String body;
  final String? cta;
  final DateTime? publishedAt;
}

abstract class AnnouncementKind {
  static const String official = 'official';
  static const String promo = 'promo';

  static String label(String k) =>
      k == promo ? 'PROGRAM PROMO' : 'PENGUMUMAN RESMI';
}

/// An article from the seller help centre, for global search (S-12).
class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.category,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String category;
  final DateTime? updatedAt;
}
