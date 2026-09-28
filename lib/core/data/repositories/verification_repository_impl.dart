import 'dart:typed_data';

import '../../data_state.dart';
import '../../domain/model/verification/store_verification.dart';
import '../../domain/repositories/verification_repository.dart';
import '../datasources/remote/service/verification_service.dart';
import 'repository_guard.dart';

class VerificationRepositoryImpl
    with RepositoryGuard
    implements VerificationRepository {
  const VerificationRepositoryImpl(this._service);

  final VerificationService _service;

  @override
  Future<DataState<StoreVerification>> getVerification(int storeId) async {
    final result = await guard(() => _service.getVerification(storeId));

    // `guard` maps an empty *collection* to DataEmpty; a null single object is
    // the same kind of "nothing yet" and deserves the same state rather than a
    // DataSuccess wrapping null.
    return switch (result) {
      DataSuccess<StoreVerification?>(:final value) when value != null =>
        DataSuccess<StoreVerification>(value),
      DataSuccess<StoreVerification?>() => const DataEmpty<StoreVerification>(),
      DataFailed<StoreVerification?>(:final failure) =>
        DataFailed<StoreVerification>(failure),
      _ => const DataEmpty<StoreVerification>(),
    };
  }

  @override
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
  }) =>
      guard(() => _service.submit(
            storeId,
            type: type,
            idCardNumber: idCardNumber,
            taxNumber: taxNumber,
            bankAccountName: bankAccountName,
            bankAccountNumber: bankAccountNumber,
            bankName: bankName,
            picName: picName,
            picIdCardNumber: picIdCardNumber,
            picEmail: picEmail,
          ));

  @override
  Future<DataState<StoreVerification>> uploadDocument(
    int storeId, {
    required Uint8List bytes,
    required String fileName,
    required String docType,
  }) async {
    final upload = await guard(() => _service.uploadDocument(
          storeId,
          bytes: bytes,
          fileName: fileName,
          docType: docType,
        ));
    if (upload is DataFailed<String>) {
      return DataFailed<StoreVerification>(upload.failure);
    }
    return getVerification(storeId);
  }
}
