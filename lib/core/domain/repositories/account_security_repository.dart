import '../../data_state.dart';
import '../model/account/security_status.dart';

/// Credentials and second factors (S-44). Implemented by
/// `DemoAccountSecurityRepository` until the API supports them.
abstract class AccountSecurityRepository {
  Future<DataState<SecurityStatus>> getStatus();

  Future<DataError?> changePassword({
    required String current,
    required String next,
  });

  /// Sends an OTP to the new number / address.
  Future<DataError?> requestContactChange({
    required bool phone,
    required String value,
  });

  Future<DataError?> setTwoFactor(bool enabled);

  Future<DataError?> setBiometric(bool enabled);
}
