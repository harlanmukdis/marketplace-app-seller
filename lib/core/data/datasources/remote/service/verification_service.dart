import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/verification/store_verification.dart';
import '../../../../utils/json_parse.dart';
import 'base_service.dart';

/// Store verification — the gate on selling.
///
/// The order is fixed and the server enforces it: **submit first, then upload
/// documents.** Uploading before a request exists answers
/// `404 VERIFICATION_NOT_FOUND`, because a document row has to hang off a
/// verification id.
class VerificationService extends BaseService {
  const VerificationService(super.dio);

  /// Null for a store that has never submitted — the endpoint answers
  /// `data: null`, which is an empty state rather than a failure.
  Future<StoreVerification?> getVerification(int storeId) async {
    final envelope = await getRequest(
      ApiEndpoints.verification(storeId),
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    if (envelope.isNull) return null;
    return StoreVerification.fromJson(envelope.map);
  }

  /// Creates a **new** request and returns its id.
  ///
  /// It never updates the previous one: submitting again inserts another row,
  /// and documents belong to the row they were uploaded against, so a
  /// resubmission starts with none. Only call this when there is no request yet
  /// or the last one was rejected.
  ///
  /// A KTP number already on another seller's verification is refused with
  /// `409 DUPLICATE_IDENTITY` (API v1.7.0) — one identity, one seller.
  ///
  /// `type` is read by the backend without a fallback — omitting it is a 500,
  /// not a validation error — so it is required here.
  Future<int> submit(
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
  }) async {
    final envelope = await postRequest(
      ApiEndpoints.verification(storeId),
      body: <String, dynamic>{
        'type': type,
        'id_card_number': idCardNumber,
        'tax_number': taxNumber,
        'bank_account_name': bankAccountName,
        'bank_account_number': bankAccountNumber,
        'bank_name': bankName,
        // Required for `business` since API v1.7.0 (422 without them); the
        // duplicate-identity check then runs on the PIC's KTP, not the
        // owner's.
        'pic_name': picName,
        'pic_id_card_number': picIdCardNumber,
        'pic_email': picEmail,
      },
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return asInt(envelope.map['id']);
  }

  /// Attaches one document to the store's latest request.
  ///
  /// Its own multipart endpoint rather than a URL collected from
  /// `/media/upload`, with a narrower allowlist — `jpg|jpeg|png|pdf`, 5 MB.
  /// `docType` is **not validated by the server**, so pass a [DocumentType]
  /// constant; a typo would be stored verbatim and silently never satisfy the
  /// reviewer.
  Future<String> uploadDocument(
    int storeId, {
    required Uint8List bytes,
    required String fileName,
    required String docType,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'doc_type': docType,
    });

    final envelope = await postRequest(
      ApiEndpoints.verificationDocuments(storeId),
      data: form,
      headers: <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    // Note the key: this endpoint answers `file_url` where `/media/upload`
    // answers `url`.
    return asString(envelope.map['file_url']);
  }
}
