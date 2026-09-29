import '../../data_state.dart';
import '../../domain/model/account/security_status.dart';
import '../../domain/repositories/account_security_repository.dart';
import 'demo_support.dart';

class DemoAccountSecurityRepository implements AccountSecurityRepository {
  DemoAccountSecurityRepository();

  static const String _feature = 'Pengaturan keamanan akun';

  SecurityStatus _status = SecurityStatus(
    passwordChangedAt: DateTime.now().subtract(const Duration(days: 92)),
    phoneMasked: '0812****456',
    phoneVerified: true,
    emailMasked: 'b***@kedaikopi.id',
    emailVerified: true,
  );

  @override
  Future<DataState<SecurityStatus>> getStatus() =>
      demoOr(_feature, () => _status);

  @override
  Future<DataError?> changePassword({
    required String current,
    required String next,
  }) async {
    if (next.length < 8 ||
        !next.contains(RegExp(r'[A-Za-z]')) ||
        !next.contains(RegExp(r'[0-9]'))) {
      return const DataError(
        code: DataErrorCode.validationError,
        message: 'Kata sandi baru minimal 8 karakter, berisi huruf dan angka.',
      );
    }
    final error = await demoWrite(_feature);
    if (error == null) {
      _status = _status.copyWith(passwordChangedAt: DateTime.now());
    }
    return error;
  }

  @override
  Future<DataError?> requestContactChange({
    required bool phone,
    required String value,
  }) =>
      demoWrite(_feature);

  @override
  Future<DataError?> setTwoFactor(bool enabled) async {
    final error = await demoWrite(_feature);
    if (error == null) _status = _status.copyWith(twoFactor: enabled);
    return error;
  }

  @override
  Future<DataError?> setBiometric(bool enabled) async {
    final error = await demoWrite(_feature);
    if (error == null) _status = _status.copyWith(biometric: enabled);
    return error;
  }
}
