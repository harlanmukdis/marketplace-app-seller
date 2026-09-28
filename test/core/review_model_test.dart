import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/review/product_review.dart';
import 'package:navy_wear/features/seller_reviews/presentation/cubits/review_cubit.dart';

/// Shape taken from `Review_model::list_for_product` (`r.*` plus a `reply`
/// object or null). The seed has no reviews, and none can be created here
/// without a completed order, so this is pinned from the code, not captured.
void main() {
  Map<String, dynamic> row({Object? reply}) => <String, dynamic>{
        'id': '11',
        'order_item_id': '40',
        'user_id': '9',
        'product_id': '3',
        'rating': '4',
        'comment': 'Bagus',
        'is_anonymous': '0',
        'status': 'published',
        'created_at': '2026-09-20 10:00:00',
        'reply': reply,
      };

  test('reads a review without a reply', () {
    final r = ProductReview.fromJson(row(), productName: 'Kopi Gayo');

    expect(r.rating, 4);
    expect(r.productName, 'Kopi Gayo');
    expect(r.isAnonymous, isFalse);
    expect(r.hasReply, isFalse);
  });

  test('reads the joined reply', () {
    final r = ProductReview.fromJson(row(reply: <String, dynamic>{
      'reply_text': 'Terima kasih',
      'created_at': '2026-09-21 08:00:00',
    }));

    expect(r.reply!.text, 'Terima kasih');
    expect(ReviewFilter.unreplied.matches(r), isFalse);
  });

  test('filters and summary figures', () {
    final s = ReviewState(
      loading: false,
      reviews: <ProductReview>[
        ProductReview.fromJson(row()),
        ProductReview.fromJson(row()..['id'] = '12'..['rating'] = '2'),
      ],
    );

    expect(s.countOf(ReviewFilter.four), 1);
    expect(s.countOf(ReviewFilter.unreplied), 2);
    expect(s.average, 3);
    expect(s.replyRate, 0);
  });
}
