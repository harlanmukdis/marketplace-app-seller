import '../../../utils/json_parse.dart';

/// A published review of one of the store's products.
///
/// The API joins neither the reviewer's name nor the review's photos
/// (`review_media` exists but is never read back), so a review here is a
/// rating, a comment and at most one seller reply.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.rating,
    this.productName = '',
    this.comment,
    this.isAnonymous = false,
    this.createdAt,
    this.reply,
  });

  final int id;
  final int productId;

  /// Filled in by the app from the product the review was fetched for.
  final String productName;
  final int rating;
  final String? comment;
  final bool isAnonymous;
  final DateTime? createdAt;
  final ReviewReply? reply;

  factory ProductReview.fromJson(
    Map<String, dynamic> json, {
    String productName = '',
  }) =>
      ProductReview(
        id: asInt(json['id']),
        productId: asInt(json['product_id']),
        productName: productName,
        rating: asInt(json['rating']),
        comment: asStringOrNull(json['comment']),
        isAnonymous: asBool(json['is_anonymous']),
        createdAt: asCreatedDate(json),
        reply: json['reply'] is Map<String, dynamic>
            ? ReviewReply.fromJson(json['reply'] as Map<String, dynamic>)
            : null,
      );

  bool get hasReply => reply != null;

  ProductReview withReply(String text) => ProductReview(
        id: id,
        productId: productId,
        productName: productName,
        rating: rating,
        comment: comment,
        isAnonymous: isAnonymous,
        createdAt: createdAt,
        reply: ReviewReply(text: text, createdAt: DateTime.now()),
      );
}

/// `review_replies` — one per review; the column is UNIQUE, so a second reply
/// is a duplicate-key 500 on the server. The app offers exactly one.
class ReviewReply {
  const ReviewReply({required this.text, this.createdAt});

  final String text;
  final DateTime? createdAt;

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        text: asString(json['reply_text']),
        createdAt: asDateTime(json['created_at']),
      );
}
