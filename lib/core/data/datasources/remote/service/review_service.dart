import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/review/product_review.dart';
import 'base_service.dart';

/// Reviews of the store's products, and the seller's two moves on them.
///
/// There is no store-wide list — reviews are read per product. Reply and
/// report read **form** fields (`$this->post()`); a JSON body would arrive
/// empty, and an empty reply reaches a `NOT NULL` column as a 500.
class ReviewService extends BaseService {
  const ReviewService(super.dio);

  /// Published reviews only, newest first, 20 a page (this one has `meta`).
  Future<List<ProductReview>> getProductReviews(
    int productId, {
    String productName = '',
    int page = 1,
  }) async {
    final envelope = await getRequest(
      ApiEndpoints.productReviews(productId),
      query: <String, dynamic>{'page': page},
    );
    return envelope.list
        .map((j) => ProductReview.fromJson(j, productName: productName))
        .toList(growable: false);
  }

  Future<void> reply(int reviewId, {required String text}) async {
    await postFormRequest(
      ApiEndpoints.reviewReply(reviewId),
      fields: <String, String>{'reply_text': text},
    );
  }

  /// Queues the review for a human moderator; it is not hidden by a report.
  /// A second report by the same account is refused with a 422.
  Future<void> report(int reviewId, {required String reason}) async {
    await postFormRequest(
      ApiEndpoints.reviewReport(reviewId),
      fields: <String, String>{'reason': reason},
    );
  }
}
