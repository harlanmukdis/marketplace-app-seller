part of 'showcase_detail_cubit.dart';

sealed class ShowcaseDetailState {
  const ShowcaseDetailState();
}

final class ShowcaseDetailInProgress extends ShowcaseDetailState {
  const ShowcaseDetailInProgress();
}

final class ShowcaseDetailNoStore extends ShowcaseDetailState {
  const ShowcaseDetailNoStore();
}

final class ShowcaseDetailFailure extends ShowcaseDetailState {
  const ShowcaseDetailFailure(this.error);

  final DataError error;
}

final class ShowcaseDetailLoaded extends ShowcaseDetailState {
  const ShowcaseDetailLoaded({
    required this.showcase,
    required this.products,
    this.isBusy = false,
  });

  final StoreShowcase showcase;

  /// **Active products only.** A draft added to this showcase is stored and
  /// then filtered out of every read, so this can be shorter than what was
  /// put in and nothing reports the difference.
  final List<ShowcaseProduct> products;

  final bool isBusy;

  Set<int> get productIds => products.map((product) => product.id).toSet();

  ShowcaseDetailLoaded copyWith({
    StoreShowcase? showcase,
    List<ShowcaseProduct>? products,
    bool? isBusy,
  }) =>
      ShowcaseDetailLoaded(
        showcase: showcase ?? this.showcase,
        products: products ?? this.products,
        isBusy: isBusy ?? this.isBusy,
      );
}
