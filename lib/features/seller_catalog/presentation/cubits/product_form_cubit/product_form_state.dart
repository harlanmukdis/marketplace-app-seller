part of 'product_form_cubit.dart';

sealed class ProductFormState {
  const ProductFormState();
}

final class ProductFormInProgress extends ProductFormState {
  const ProductFormInProgress();
}

final class ProductFormFailure extends ProductFormState {
  const ProductFormFailure(this.error);

  final DataError error;
}

/// The form can be drawn: categories are loaded, and [product] is set when
/// editing an existing one.
final class ProductFormReady extends ProductFormState {
  const ProductFormReady({
    required this.categories,
    this.product,
    this.isSaving = false,
    this.coverage = const ShippingCoverage(),
    this.moderationPending = false,
    this.certifications = const <ProductCertification>[],
  });

  final List<Category> categories;

  /// Null while creating.
  final Product? product;

  /// A save in flight. Kept on the same state rather than emitting a loading
  /// state, so the fields stay on screen with what the user typed.
  final bool isSaving;

  /// Per-product shipping coverage; unrestricted while creating.
  final ShippingCoverage coverage;

  /// Set when publishing was refused with `RESTRICTION_REVIEW_PENDING`. There
  /// is no seller endpoint that reports a product's moderation state, so this
  /// refusal is the only way the app learns of it (S-28).
  final bool moderationPending;

  /// BPOM / Halal / SNI submissions for this product; empty while creating.
  final List<ProductCertification> certifications;

  /// Flattened for the picker: every category, parents and children alike, each
  /// labelled with its parent so duplicate leaf names stay distinguishable.
  List<CategoryOption> get categoryOptions => flattenCategories(categories);

  bool get isEditing => product != null;

  ProductFormReady copyWith({
    List<Category>? categories,
    Product? product,
    bool? isSaving,
    ShippingCoverage? coverage,
    bool? moderationPending,
    List<ProductCertification>? certifications,
  }) =>
      ProductFormReady(
        categories: categories ?? this.categories,
        product: product ?? this.product,
        isSaving: isSaving ?? this.isSaving,
        coverage: coverage ?? this.coverage,
        moderationPending: moderationPending ?? this.moderationPending,
        certifications: certifications ?? this.certifications,
      );
}
