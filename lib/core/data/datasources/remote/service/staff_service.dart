import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/staff/store_staff.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// Store staff and roles.
///
/// Encoding is mixed: invite and create-role read **form** fields; update,
/// and role permissions read JSON. Two refusals are uncaught exceptions that
/// arrive as an HTML page (an unregistered email on invite, an unknown role
/// on permissions) — `ApiEnvelope` lifts their message out.
class StaffService extends BaseService {
  const StaffService(super.dio);

  Map<String, dynamic> _h(int storeId) =>
      <String, dynamic>{'X-Store-Id': '$storeId'};

  Future<List<StaffMember>> getStaff(int storeId) async {
    final envelope =
        await getRequest(ApiEndpoints.storeStaff(storeId), headers: _h(storeId));
    return envelope.list.map(StaffMember.fromJson).toList(growable: false);
  }

  /// The email must belong to a registered account; the invitee accepts from
  /// the `staff_invitation` notification.
  Future<String?> invite(
    int storeId, {
    required String email,
    required int roleId,
  }) async {
    final envelope = await postFormRequest(
      ApiEndpoints.storeStaffInvite(storeId),
      fields: <String, String>{
        'email': email,
        'store_staff_role_id': '$roleId',
      },
      headers: _h(storeId),
    );
    return asStringOrNull(envelope.map['invitation_token']);
  }

  Future<void> update(int storeId, int staffId, {int? roleId, String? status}) =>
      patchRequest(
        ApiEndpoints.storeStaffMember(storeId, staffId),
        body: <String, dynamic>{
          'store_staff_role_id': roleId,
          'status': status,
        },
        headers: _h(storeId),
      );

  /// A soft delete: the row stays with `status: removed`.
  Future<void> remove(int storeId, int staffId) => deleteRequest(
        ApiEndpoints.storeStaffMember(storeId, staffId),
        headers: _h(storeId),
      );

  Future<List<StaffRole>> getRoles(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.storeStaffRoles(storeId),
      headers: _h(storeId),
    );
    return envelope.list.map(StaffRole.fromJson).toList(growable: false);
  }

  Future<void> createRole(int storeId, {required String code, required String name}) =>
      postFormRequest(
        ApiEndpoints.storeStaffRoles(storeId),
        fields: <String, String>{'code': code, 'name': name},
        headers: _h(storeId),
      );

  /// Replace-all.
  Future<void> setPermissions(int storeId, int roleId, List<String> codes) =>
      patchRequest(
        ApiEndpoints.storeStaffRolePermissions(storeId, roleId),
        body: <String, dynamic>{'permissions': codes},
        headers: _h(storeId),
      );

  Future<void> acceptInvitation(String token) =>
      postRequest(ApiEndpoints.staffInvitationAccept(token));
}
