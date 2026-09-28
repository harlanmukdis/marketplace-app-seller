import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/staff/store_staff.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/staff_repository.dart';
import '../../../../di/injector.dart';

class StaffState {
  const StaffState({
    this.loading = true,
    this.staff = const <StaffMember>[],
    this.roles = const <StaffRole>[],
    this.busy = false,
    this.error,
  });

  final bool loading;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final bool busy;
  final DataError? error;

  /// Removed rows stay in the list with `status: removed`; hide them.
  List<StaffMember> get current =>
      staff.where((s) => !s.isRemoved).toList(growable: false);

  /// Roles a staff member can be given — the owner role is the owner's.
  List<StaffRole> get assignable =>
      roles.where((r) => !r.isOwner).toList(growable: false);

  StaffState copyWith({
    List<StaffMember>? staff,
    List<StaffRole>? roles,
    bool? busy,
  }) =>
      StaffState(
        loading: false,
        staff: staff ?? this.staff,
        roles: roles ?? this.roles,
        busy: busy ?? this.busy,
      );
}

class StaffCubit extends Cubit<StaffState> {
  StaffCubit() : super(const StaffState());

  static StaffCubit get(BuildContext context) => BlocProvider.of(context);

  final StaffRepository _repo = injector<StaffRepository>();
  int? get _storeId => injector<AuthRepository>().activeStoreId;

  Future<void> load() async {
    final storeId = _storeId;
    if (storeId == null) {
      emit(const StaffState(
        loading: false,
        error: DataError(code: 'NO_STORE', message: 'Belum ada toko dipilih.'),
      ));
      return;
    }
    final results = await Future.wait<Object>(<Future<Object>>[
      _repo.getStaff(storeId),
      _repo.getRoles(storeId),
    ]);
    if (isClosed) return;
    final staff = results[0];
    final roles = results[1];
    emit(StaffState(
      loading: false,
      staff: staff is DataSuccess<List<StaffMember>>
          ? staff.value
          : const <StaffMember>[],
      roles: roles is DataSuccess<List<StaffRole>>
          ? roles.value
          : const <StaffRole>[],
      error: roles is DataFailed<List<StaffRole>> ? roles.failure : null,
    ));
  }

  Future<DataError?> invite(String email, int roleId) async {
    final e = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Email tidak valid.',
      );
    }
    if (state.current.any((s) => s.email.toLowerCase() == e.toLowerCase())) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Email ini sudah menjadi staf atau sudah diundang.',
      );
    }
    return _staffAction(() => _repo.invite(_storeId!, email: e, roleId: roleId));
  }

  Future<DataError?> changeRole(StaffMember m, int roleId) =>
      _staffAction(() => _repo.changeRole(_storeId!, m.id, roleId));

  Future<DataError?> remove(StaffMember m) =>
      _staffAction(() => _repo.remove(_storeId!, m.id));

  Future<DataError?> createRole(String name) async {
    final n = name.trim();
    if (n.isEmpty) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Nama peran wajib diisi.',
      );
    }
    final code = 'custom_${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    if (state.roles.any((r) => r.code == code)) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Peran dengan nama itu sudah ada.',
      );
    }
    return _roleAction(() => _repo.createRole(_storeId!, code: code, name: n));
  }

  Future<DataError?> setPermissions(StaffRole role, List<String> codes) {
    if (role.isOwner) {
      return Future<DataError?>.value(const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Pemilik toko selalu punya akses penuh.',
      ));
    }
    return _roleAction(() => _repo.setPermissions(_storeId!, role.id, codes));
  }

  Future<DataError?> _staffAction(
    Future<DataState<List<StaffMember>>> Function() call,
  ) async {
    if (_storeId == null) return null;
    emit(state.copyWith(busy: true));
    final result = await call();
    if (isClosed) return null;
    if (result is DataFailed<List<StaffMember>>) {
      emit(state.copyWith(busy: false));
      return result.failure;
    }
    emit(state.copyWith(
      busy: false,
      staff: result is DataSuccess<List<StaffMember>>
          ? result.value
          : const <StaffMember>[],
    ));
    return null;
  }

  Future<DataError?> _roleAction(
    Future<DataState<List<StaffRole>>> Function() call,
  ) async {
    if (_storeId == null) return null;
    emit(state.copyWith(busy: true));
    final result = await call();
    if (isClosed) return null;
    if (result is DataFailed<List<StaffRole>>) {
      emit(state.copyWith(busy: false));
      return result.failure;
    }
    emit(state.copyWith(
      busy: false,
      roles: result is DataSuccess<List<StaffRole>> ? result.value : null,
    ));
    return null;
  }
}
