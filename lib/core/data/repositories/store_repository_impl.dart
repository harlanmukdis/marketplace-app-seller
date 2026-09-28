import 'dart:typed_data';

import '../../data_state.dart';
import '../../domain/model/media/uploaded_file.dart';
import '../../domain/model/store/store.dart';
import '../../domain/model/store/store_settings.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/remote/service/media_service.dart';
import '../datasources/remote/service/store_service.dart';
import 'repository_guard.dart';

class StoreRepositoryImpl with RepositoryGuard implements StoreRepository {
  const StoreRepositoryImpl(this._service, this._media);

  final StoreService _service;
  final MediaService _media;

  @override
  Future<DataState<List<Store>>> getMyStores() =>
      guard(() => _service.getMyStores());

  @override
  Future<DataState<int>> createStore({
    required String name,
    String? description,
    String type = StoreType.physical,
  }) =>
      guard(() => _service.createStore(
            name: name,
            description: description,
            type: type,
          ));

  @override
  Future<DataState<Store>> getStore(int storeId) =>
      guard(() => _service.getStore(storeId));

  @override
  Future<DataState<Store>> updateStore(
    int storeId, {
    String? name,
    String? description,
    String? logoUrl,
    String? bannerUrl,
  }) =>
      guard(() => _service.updateStore(
            storeId,
            name: name,
            description: description,
            logoUrl: logoUrl,
            bannerUrl: bannerUrl,
          ));

  @override
  Future<DataState<StoreSettings>> getSettings(int storeId) =>
      guard(() => _service.getSettings(storeId));

  @override
  Future<DataState<StoreSettings>> updateSettings(
    int storeId, {
    bool? autoAcceptOrder,
    bool? vacationMode,
    String? contactPhone,
    String? contactWhatsapp,
  }) =>
      guard(() => _service.updateSettings(
            storeId,
            autoAcceptOrder: autoAcceptOrder,
            vacationMode: vacationMode,
            contactPhone: contactPhone,
            contactWhatsapp: contactWhatsapp,
          ));

  @override
  Future<DataState<UploadedFile>> upload({
    required Uint8List bytes,
    required String fileName,
    String? docType,
    int? storeId,
    String? context,
  }) =>
      guard(() async {
        final uploaded = await _media.upload(
          bytes: bytes,
          fileName: fileName,
          docType: docType,
          storeId: storeId,
          context: context,
        );
        // The server hands back a host that does not serve in this
        // environment; point it at the API host instead.
        return UploadedFile(
          url: normaliseUploadUrl(uploaded.url),
          fileName: uploaded.fileName,
          fileSizeKb: uploaded.fileSizeKb,
          mimeType: uploaded.mimeType,
        );
      });
}
