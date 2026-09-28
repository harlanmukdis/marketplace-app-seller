import '../../data_state.dart';
import '../../domain/model/review/product_review.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/remote/service/review_service.dart';
import 'repository_guard.dart';

class ReviewRepositoryImpl with RepositoryGuard implements ReviewRepository {
  const ReviewRepositoryImpl(this._service);

  final ReviewService _service;

  @override
  Future<DataState<List<ProductReview>>> getProductReviews(
    int productId, {
    String productName = '',
  }) =>
      guard(() =>
          _service.getProductReviews(productId, productName: productName));

  @override
  Future<DataState<void>> reply(int reviewId, {required String text}) =>
      guard(() => _service.reply(reviewId, text: text));

  @override
  Future<DataState<void>> report(int reviewId, {required String reason}) =>
      guard(() => _service.report(reviewId, reason: reason));
}
