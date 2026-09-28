import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/review/product_review.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../core/domain/repositories/review_repository.dart';
import '../../../../di/injector.dart';

enum ReviewFilter { all, unreplied, five, four, three, two, one }

extension ReviewFilterX on ReviewFilter {
  String get label => switch (this) {
        ReviewFilter.all => 'Semua',
        ReviewFilter.unreplied => 'Belum Dibalas',
        ReviewFilter.five => '5 ★',
        ReviewFilter.four => '4 ★',
        ReviewFilter.three => '3 ★',
        ReviewFilter.two => '2 ★',
        ReviewFilter.one => '1 ★',
      };

  bool matches(ProductReview r) => switch (this) {
        ReviewFilter.all => true,
        ReviewFilter.unreplied => !r.hasReply,
        ReviewFilter.five => r.rating == 5,
        ReviewFilter.four => r.rating == 4,
        ReviewFilter.three => r.rating == 3,
        ReviewFilter.two => r.rating == 2,
        ReviewFilter.one => r.rating == 1,
      };
}

class ReviewState {
  const ReviewState({
    this.loading = true,
    this.reviews = const <ProductReview>[],
    this.filter = ReviewFilter.all,
    this.error,
    this.busyId,
    this.truncated = false,
  });

  final bool loading;

  /// Across every product read, newest first.
  final List<ProductReview> reviews;
  final ReviewFilter filter;
  final DataError? error;

  /// The review whose reply/report is in flight.
  final int? busyId;

  /// True when the product cap was hit and older products were not read.
  final bool truncated;

  List<ProductReview> get visible =>
      reviews.where(filter.matches).toList(growable: false);

  int countOf(ReviewFilter f) => reviews.where(f.matches).length;

  double get average => reviews.isEmpty
      ? 0
      : reviews.fold(0, (s, r) => s + r.rating) / reviews.length;

  double get replyRate => reviews.isEmpty
      ? 0
      : reviews.where((r) => r.hasReply).length / reviews.length * 100;

  ReviewState copyWith({
    List<ProductReview>? reviews,
    ReviewFilter? filter,
    int? Function()? busyId,
  }) =>
      ReviewState(
        loading: loading,
        reviews: reviews ?? this.reviews,
        filter: filter ?? this.filter,
        error: error,
        busyId: busyId == null ? this.busyId : busyId(),
        truncated: truncated,
      );
}

/// "Ulasan Produk" (S-37).
///
/// The API has no store-wide review list, so this reads the store's products
/// and then each product's first page of reviews, five at a time — an N+1,
/// bounded by [_productCap].
class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit() : super(const ReviewState());

  static ReviewCubit get(BuildContext context) => BlocProvider.of(context);

  final ReviewRepository _reviews = injector<ReviewRepository>();
  final CatalogRepository _catalog = injector<CatalogRepository>();

  static const int _productCap = 40;
  static const int _batch = 5;

  Future<void> load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) {
      emit(const ReviewState(
        loading: false,
        error: DataError(code: 'NO_STORE', message: 'Belum ada toko dipilih.'),
      ));
      return;
    }
    emit(ReviewState(filter: state.filter));

    final productsResult = await _catalog.getStoreProducts(storeId);
    if (isClosed) return;
    if (productsResult is DataFailed<List<Product>>) {
      emit(ReviewState(loading: false, error: productsResult.failure));
      return;
    }
    final products = productsResult is DataSuccess<List<Product>>
        ? productsResult.value
        : const <Product>[];
    // Reviews exist only for sold products; read the busiest first.
    final ordered = List<Product>.of(products)
      ..sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    final targets = ordered.take(_productCap).toList();

    final collected = <ProductReview>[];
    for (var i = 0; i < targets.length; i += _batch) {
      final chunk = targets.skip(i).take(_batch);
      final results = await Future.wait(chunk.map(
        (p) => _reviews.getProductReviews(p.id, productName: p.name),
      ));
      if (isClosed) return;
      for (final r in results) {
        if (r is DataSuccess<List<ProductReview>>) collected.addAll(r.value);
      }
    }
    collected.sort((a, b) {
      final l = a.createdAt, r = b.createdAt;
      if (l == null || r == null) return b.id.compareTo(a.id);
      return r.compareTo(l);
    });

    emit(ReviewState(
      loading: false,
      reviews: collected,
      filter: state.filter,
      truncated: products.length > _productCap,
    ));
  }

  void setFilter(ReviewFilter f) => emit(state.copyWith(filter: f));

  Future<DataError?> reply(ProductReview review, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Balasan tidak boleh kosong.',
      );
    }
    if (review.hasReply) {
      return const DataError(
        code: 'REVIEW_ALREADY_REPLIED',
        message: 'Ulasan ini sudah dibalas; balasan tidak bisa diubah.',
      );
    }
    emit(state.copyWith(busyId: () => review.id));
    final result = await _reviews.reply(review.id, text: trimmed);
    if (isClosed) return null;
    if (result is DataFailed<void>) {
      emit(state.copyWith(busyId: () => null));
      return result.failure;
    }
    emit(state.copyWith(
      busyId: () => null,
      reviews: <ProductReview>[
        for (final r in state.reviews)
          r.id == review.id ? r.withReply(trimmed) : r,
      ],
    ));
    return null;
  }

  Future<DataError?> report(ProductReview review, String reason) async {
    emit(state.copyWith(busyId: () => review.id));
    final result = await _reviews.report(review.id, reason: reason);
    if (isClosed) return null;
    emit(state.copyWith(busyId: () => null));
    return result is DataFailed<void> ? result.failure : null;
  }
}
