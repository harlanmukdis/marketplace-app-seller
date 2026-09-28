import 'dart:typed_data';

import '../../data_state.dart';
import '../model/verification/store_verification.dart';

/// Store verification: submit, attach documents, watch the status.
///
/// Approval is an admin action (`POST /admin/verifications/{id}/approve`), and
/// it is what flips the store to `active`. Nothing here can do that.
abstract class VerificationRepository {
  /// [DataEmpty] for a store that has never submitted — the server answers
  /// `data: null` and that is an empty state, not a failure.
  Future<DataState<StoreVerification>> getVerification(int storeId);

  /// Creates a new request. Documents can only be attached afterwards, and a
  /// second submission starts again with none.
  Future<DataState<int>> submit(
    int storeId, {
    required String type,
    String? idCardNumber,
    String? taxNumber,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? picName,
    String? picIdCardNumber,
    String? picEmail,
  });

  /// Attaches one document, then returns the request as it stands.
  Future<DataState<StoreVerification>> uploadDocument(
    int storeId, {
    required Uint8List bytes,
    required String fileName,
    required String docType,
  });
}
