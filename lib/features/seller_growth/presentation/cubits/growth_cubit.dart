import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/catalog/product_growth.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../di/injector.dart';
import '../../../seller_catalog/presentation/product_errors.dart';

sealed class GrowthState {
  const GrowthState();
}

final class GrowthInProgress extends GrowthState {
  const GrowthInProgress();
}

final class GrowthFailure extends GrowthState {
  const GrowthFailure(this.error);

  final DataError error;
}

final class GrowthLoaded extends GrowthState {
  const GrowthLoaded({
    required this.products,
    this.product,
    this.performance,
    this.isSaving = false,
  });

  /// The store's catalogue, for the picker.
  final List<Product> products;

  /// The selected product, read in full; null until one is picked.
  final Product? product;
  final GrowthPerformance? performance;
  final bool isSaving;

  GrowthLoaded copyWith({
    Product? product,
    GrowthPerformance? performance,
    bool? isSaving,
  }) =>
      GrowthLoaded(
        products: products,
        product: product ?? this.product,
        performance: performance ?? this.performance,
        isSaving: isSaving ?? this.isSaving,
      );
}

/// Xpedia Growth for one product at a time (S-32).
///
/// The one rule this cubit exists to enforce: **never send a value equal to
/// the current one.** The server locks the setting for seven days on every
/// accepted call, a no-op included, so a careless "save" would freeze a
/// product for a week with nothing changed.
class GrowthCubit extends Cubit<GrowthState> {
  GrowthCubit({this.initialProductId}) : super(const GrowthInProgress());

  static GrowthCubit get(BuildContext context) => BlocProvider.of(context);

  final int? initialProductId;
  final CatalogRepository _catalog = injector<CatalogRepository>();

  Future<void> load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) {
      emit(const GrowthFailure(DataError(
        code: 'NO_STORE',
        message: 'Belum ada toko yang dipilih.',
      )));
      return;
    }
    emit(const GrowthInProgress());
    final result = await _catalog.getStoreProducts(storeId);
    if (isClosed) return;
    final products = switch (result) {
      DataSuccess<List<Product>>(:final value) => value,
      _ => const <Product>[],
    };
    if (result is DataFailed<List<Product>>) {
      emit(GrowthFailure(result.failure));
      return;
    }
    emit(GrowthLoaded(products: products));
    final initial =
        initialProductId ?? (products.isEmpty ? null : products.first.id);
    if (initial != null) await select(initial);
  }

  Future<void> select(int productId) async {
    final current = state;
    if (current is! GrowthLoaded) return;
    emit(current.copyWith(isSaving: true));
    final results = await Future.wait<Object>(<Future<Object>>[
      _catalog.getProduct(productId),
      _catalog.getGrowthPerformance(productId),
    ]);
    if (isClosed) return;
    final product = results[0];
    final performance = results[1];
    emit(GrowthLoaded(
      products: current.products,
      product: product is DataSuccess<Product> ? product.value : null,
      performance: performance is DataSuccess<GrowthPerformance>
          ? performance.value
          : null,
    ));
  }

  Future<DataError?> save(int percent) async {
    final current = state;
    final product = current is GrowthLoaded ? current.product : null;
    if (current is! GrowthLoaded || product == null) return null;

    if (percent == product.growthCommissionPercent.round()) {
      return const DataError(
        code: 'GROWTH_UNCHANGED',
        message: 'Tidak ada perubahan. Menyimpan nilai yang sama tetap '
            'mengunci pengaturan 7×24 jam, jadi tidak dikirim.',
      );
    }
    final lockedUntil = product.growthLockedUntil;
    if (product.isGrowthLockedAt(DateTime.now()) && lockedUntil != null) {
      return DataError(
        code: 'GROWTH_LOCKED',
        message: 'Pengaturan terkunci sampai ${_fmt(lockedUntil)}.',
      );
    }

    emit(current.copyWith(isSaving: true));
    final result =
        await _catalog.setGrowth(product.id, commissionPercent: percent);
    if (isClosed) return null;
    if (result is DataFailed<Product>) {
      emit(current.copyWith(isSaving: false));
      return explainProductError(result.failure);
    }
    await select(product.id);
    return null;
  }

  static String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}
