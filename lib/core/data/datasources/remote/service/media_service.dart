import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../../config/env/app_config.dart';
import '../../../../../config/network/api_endpoints.dart';
import '../../../../domain/model/media/uploaded_file.dart';
import 'base_service.dart';

/// File upload — the capability the previous backend simply did not have, and
/// which blocked verification documents, product photos and delivery proof.
///
/// Sends `multipart/form-data` with a single `file` part. Bytes rather than a
/// path because the target is web, where there is no filesystem to hand over.
class MediaService extends BaseService {
  const MediaService(super.dio);

  Future<UploadedFile> upload({
    required Uint8List bytes,
    required String fileName,
    String? docType,
    int? storeId,
    String? context,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (docType != null) 'doc_type': docType,
      // `product_photo` makes the server stamp a subtle "XPEDIA" watermark
      // (API v1.11.0); `support_ticket_evidence` tags ticket attachments.
      // Any other value, or none, uploads the file untouched.
      if (context != null) 'context': context,
    });

    final envelope = await postRequest(
      ApiEndpoints.mediaUpload,
      data: form,
      headers: storeId == null
          ? null
          : <String, dynamic>{'X-Store-Id': '$storeId'},
    );
    return UploadedFile.fromJson(envelope.map);
  }
}

/// The server builds upload URLs from its own configured host, which in this
/// environment is `localhost:8080` — a port nothing listens on. The same file
/// is served by the API host itself, so point the URL back there rather than
/// render a broken image and blame the upload.
///
/// Harmless when the two already agree: the path is preserved either way.
String normaliseUploadUrl(String url) {
  final parsed = Uri.tryParse(url);
  final apiBase = Uri.tryParse(AppConfig.apiBaseUrl);
  if (parsed == null || apiBase == null || !parsed.hasAuthority) return url;
  if (parsed.host != 'localhost' && parsed.host != '127.0.0.1') return url;
  if (parsed.port == apiBase.port) return url;

  // Keep only the trailing `/uploads/...` segment; the server prefixes it with
  // a deployment folder that the API host does not use.
  final index = parsed.path.indexOf('/uploads/');
  final path = index >= 0 ? parsed.path.substring(index) : parsed.path;
  return apiBase.replace(path: path, query: null).toString();
}
