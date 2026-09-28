import '../../data_state.dart';
import '../../domain/model/staff/store_staff.dart';
import '../../domain/repositories/staff_repository.dart';
import '../datasources/remote/service/staff_service.dart';
import 'repository_guard.dart';

class StaffRepositoryImpl with RepositoryGuard implements StaffRepository {
  const StaffRepositoryImpl(this._service);

  final StaffService _service;

  @override
  Future<DataState<List<StaffMember>>> getStaff(int storeId) =>
      guard(() => _service.getStaff(storeId));

  @override
  Future<DataState<List<StaffMember>>> invite(
    int storeId, {
    required String email,
    required int roleId,
  }) =>
      guard(() async {
        await _service.invite(storeId, email: email, roleId: roleId);
        return _service.getStaff(storeId);
      });

  @override
  Future<DataState<List<StaffMember>>> changeRole(
    int storeId,
    int staffId,
    int roleId,
  ) =>
      guard(() async {
        await _service.update(storeId, staffId, roleId: roleId);
        return _service.getStaff(storeId);
      });

  @override
  Future<DataState<List<StaffMember>>> remove(int storeId, int staffId) =>
      guard(() async {
        await _service.remove(storeId, staffId);
        return _service.getStaff(storeId);
      });

  @override
  Future<DataState<List<StaffRole>>> getRoles(int storeId) =>
      guard(() => _service.getRoles(storeId));

  @override
  Future<DataState<List<StaffRole>>> createRole(
    int storeId, {
    required String code,
    required String name,
  }) =>
      guard(() async {
        await _service.createRole(storeId, code: code, name: name);
        return _service.getRoles(storeId);
      });

  @override
  Future<DataState<List<StaffRole>>> setPermissions(
    int storeId,
    int roleId,
    List<String> codes,
  ) =>
      guard(() async {
        await _service.setPermissions(storeId, roleId, codes);
        return _service.getRoles(storeId);
      });

  @override
  Future<DataState<void>> acceptInvitation(String token) =>
      guard(() => _service.acceptInvitation(token));
}
