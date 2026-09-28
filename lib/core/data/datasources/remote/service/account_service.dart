import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/account/login_session.dart';
import 'base_service.dart';

/// Account-level security that is not the sign-in flow itself.
class AccountService extends BaseService {
  const AccountService(super.dio);

  /// Newest first.
  Future<List<LoginSession>> getSessions() async {
    final envelope = await getRequest(ApiEndpoints.sessions);
    return envelope.list.map(LoginSession.fromJson).toList(growable: false);
  }

  /// Revokes the refresh token behind [id]. Its access token stays valid for
  /// up to 15 minutes; after that the device is signed out.
  Future<List<LoginSession>> revokeSession(int id) async {
    await deleteRequest(ApiEndpoints.session(id));
    return getSessions();
  }
}
