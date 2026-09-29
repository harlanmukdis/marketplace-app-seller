import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/shipping/courier.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/shipping_repository.dart';
import '../../../../../di/injector.dart';

part 'courier_state.dart';

/// Which couriers the active store ships with.
///
/// An **optional whitelist**: the backend narrows a buyer's shipping options to
/// this list only when it has entries, and leaves every active courier on offer
/// when it is empty. So selecting restricts, and selecting nothing is the
/// permissive default rather than a broken store.
class CourierCubit extends Cubit<CourierState> {
  CourierCubit() : super(const CourierInProgress());

  static CourierCubit get(BuildContext context) => BlocProvider.of(context);

  final ShippingRepository _shipping = injector<ShippingRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const CourierNoStore());
      return;
    }

    emit(const CourierInProgress());

    final all = await _shipping.getCouriers();
    if (isClosed) return;
    if (all is DataFailed<List<Courier>>) {
      emit(CourierFailure(all.failure));
      return;
    }

    final mine = await _shipping.getStoreCouriers(storeId);
    if (isClosed) return;
    if (mine is DataFailed<List<Courier>>) {
      emit(CourierFailure(mine.failure));
      return;
    }

    emit(CourierLoaded(
      available: switch (all) {
        DataSuccess<List<Courier>>(:final value) => value,
        _ => const <Courier>[],
      },
      // Empty is the seeded state, and the one worth warning about.
      selectedCodes: switch (mine) {
        DataSuccess<List<Courier>>(:final value) =>
          value.map((courier) => courier.code).toSet(),
        _ => const <String>{},
      },
    ));
  }

  /// Local until [save] — the endpoint replaces the whole list, so toggling one
  /// courier per request would mean sending the entire set each time anyway.
  void toggle(String code) {
    final current = state;
    if (current is! CourierLoaded) return;

    final next = Set<String>.from(current.selectedCodes);
    if (!next.remove(code)) next.add(code);
    emit(current.copyWith(selectedCodes: next, isDirty: true));
  }

  /// The switch model of S-24: every courier reads as on while nothing is
  /// restricted. Turning one off from that state selects all the others;
  /// turning everything back on returns to the open default. Returns false —
  /// and changes nothing — when the change would switch the last courier off,
  /// because an empty list means "all", not "none".
  bool setActive(String code, bool on) {
    final current = state;
    if (current is! CourierLoaded) return true;

    final all = current.available.map((c) => c.code).toSet();
    final effective = current.hasNone ? all : current.selectedCodes;
    final next = Set<String>.from(effective);
    on ? next.add(code) : next.remove(code);
    if (next.isEmpty) return false;

    emit(current.copyWith(
      selectedCodes: next.containsAll(all) ? const <String>{} : next,
      isDirty: true,
    ));
    return true;
  }

  Future<DataError?> save() async {
    final storeId = _auth.activeStoreId;
    final current = state;
    if (storeId == null || current is! CourierLoaded) return null;

    emit(current.copyWith(isBusy: true));

    final result = await _shipping.setStoreCouriers(
      storeId,
      current.selectedCodes.toList(growable: false),
    );
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<List<Courier>>(:final value):
        emit(current.copyWith(
          selectedCodes: value.map((courier) => courier.code).toSet(),
          isBusy: false,
          isDirty: false,
        ));
        return null;
      case DataEmpty<List<Courier>>():
        // Everything was cleared — a legitimate outcome of saving none.
        emit(current.copyWith(
          selectedCodes: const <String>{},
          isBusy: false,
          isDirty: false,
        ));
        return null;
      case DataFailed<List<Courier>>(:final failure):
        emit(current.copyWith(isBusy: false));
        return failure;
      case DataLoading<List<Courier>>():
        emit(current.copyWith(isBusy: false));
        return null;
    }
  }
}
