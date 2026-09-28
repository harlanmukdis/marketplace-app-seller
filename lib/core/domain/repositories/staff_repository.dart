import '../../data_state.dart';
import '../model/staff/store_staff.dart';

abstract class StaffRepository {
  Future<DataState<List<StaffMember>>> getStaff(int storeId);

  Future<DataState<List<StaffMember>>> invite(
    int storeId, {
    required String email,
    required int roleId,
  });

  Future<DataState<List<StaffMember>>> changeRole(
    int storeId,
    int staffId,
    int roleId,
  );

  Future<DataState<List<StaffMember>>> remove(int storeId, int staffId);

  Future<DataState<List<StaffRole>>> getRoles(int storeId);

  Future<DataState<List<StaffRole>>> createRole(
    int storeId, {
    required String code,
    required String name,
  });

  Future<DataState<List<StaffRole>>> setPermissions(
    int storeId,
    int roleId,
    List<String> codes,
  );

  Future<DataState<void>> acceptInvitation(String token);
}
