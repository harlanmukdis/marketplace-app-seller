import '../../data_state.dart';
import '../model/review/product_review.dart';

abstract class ReviewRepository {
  Future<DataState<List<ProductReview>>> getProductReviews(
    int productId, {
    String productName,
  });

  Future<DataState<void>> reply(int reviewId, {required String text});

  Future<DataState<void>> report(int reviewId, {required String reason});
}
