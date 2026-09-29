import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/merchandising/store_showcase.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/merchandising_repository.dart';
import '../../../../../di/injector.dart';

part 'showcase_state.dart';

/// The store's showcases.
///
/// Unusually for this API the whole life cycle is here: create, rename,
/// reorder and delete all exist.
class ShowcaseCubit extends Cubit<ShowcaseState> {
  ShowcaseCubit() : super(const ShowcaseInProgress());

  static ShowcaseCubit get(BuildContext context) => BlocProvider.of(context);

  final MerchandisingRepository _merchandising =
      injector<MerchandisingRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const ShowcaseNoStore());
      return;
    }

    emit(const ShowcaseInProgress());

    final result = await _merchandising.getStoreShowcases(storeId);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<List<StoreShowcase>>(:final value):
        emit(ShowcaseLoaded(value));
      case DataEmpty<List<StoreShowcase>>():
        emit(const ShowcaseLoaded(<StoreShowcase>[]));
      case DataFailed<List<StoreShowcase>>(:final failure):
        emit(ShowcaseFailure(failure));
      default:
        emit(const ShowcaseFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Etalase toko tidak bisa dibaca.',
          ),
        ));
    }
  }

  Future<DataError?> create({required String name, int sortOrder = 0}) async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! ShowcaseLoaded) return null;

    if (name.trim().isEmpty) {
      return const DataError(
        code: 'SHOWCASE_NAME_REQUIRED',
        message: 'Nama etalase wajib diisi.',
      );
    }

    emit(current.copyWith(isBusy: true));
    final result = await _merchandising.createShowcase(
      storeId,
      name: name,
      sortOrder: sortOrder,
    );
    if (isClosed) return null;
    return _apply(result, current);
  }

  Future<DataError?> rename(
    int showcaseId, {
    required String name,
    int? sortOrder,
  }) async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! ShowcaseLoaded) return null;

    if (name.trim().isEmpty) {
      return const DataError(
        code: 'SHOWCASE_NAME_REQUIRED',
        message: 'Nama etalase wajib diisi.',
      );
    }

    emit(current.copyWith(isBusy: true));
    final result = await _merchandising.updateShowcase(
      storeId,
      showcaseId,
      name: name,
      sortOrder: sortOrder,
    );
    if (isClosed) return null;
    return _apply(result, current);
  }

  /// Drag-to-reorder (S-34). The API has no bulk reorder, so each showcase
  /// whose position changed gets its own PATCH with the new `sort_order`,
  /// one after another; the list shown afterwards is the server's.
  Future<DataError?> reorder(List<StoreShowcase> ordered) async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! ShowcaseLoaded) return null;

    emit(ShowcaseLoaded(ordered, isBusy: true));
    DataState<List<StoreShowcase>>? last;
    for (var i = 0; i < ordered.length; i++) {
      final s = ordered[i];
      if (s.sortOrder == i) continue;
      last = await _merchandising.updateShowcase(
        storeId,
        s.id,
        name: s.name,
        sortOrder: i,
      );
      if (isClosed) return null;
      if (last is DataFailed<List<StoreShowcase>>) break;
    }
    if (last == null) {
      emit(ShowcaseLoaded(ordered));
      return null;
    }
    return _apply(last, current);
  }

  /// Removes the grouping only — the products themselves are untouched.
  Future<DataError?> remove(int showcaseId) async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! ShowcaseLoaded) return null;

    emit(current.copyWith(isBusy: true));
    final result = await _merchandising.deleteShowcase(storeId, showcaseId);
    if (isClosed) return null;
    return _apply(result, current);
  }

  DataError? _apply(
    DataState<List<StoreShowcase>> result,
    ShowcaseLoaded previous,
  ) {
    switch (result) {
      case DataSuccess<List<StoreShowcase>>(:final value):
        emit(ShowcaseLoaded(value));
        return null;
      case DataEmpty<List<StoreShowcase>>():
        emit(const ShowcaseLoaded(<StoreShowcase>[]));
        return null;
      case DataFailed<List<StoreShowcase>>(:final failure):
        emit(previous.copyWith(isBusy: false));
        return failure;
      default:
        emit(previous.copyWith(isBusy: false));
        return null;
    }
  }
}
