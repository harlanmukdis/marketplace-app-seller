import '../../data_state.dart';
import '../model/account/login_session.dart';

abstract class AccountRepository {
  Future<DataState<List<LoginSession>>> getSessions();

  /// Returns the sessions left afterwards.
  Future<DataState<List<LoginSession>>> revokeSession(int id);
}
