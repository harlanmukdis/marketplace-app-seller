import '../../data_state.dart';
import '../../domain/model/account/login_session.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/remote/service/account_service.dart';
import 'repository_guard.dart';

class AccountRepositoryImpl with RepositoryGuard implements AccountRepository {
  const AccountRepositoryImpl(this._service);

  final AccountService _service;

  @override
  Future<DataState<List<LoginSession>>> getSessions() =>
      guard(_service.getSessions);

  @override
  Future<DataState<List<LoginSession>>> revokeSession(int id) =>
      guard(() => _service.revokeSession(id));
}
