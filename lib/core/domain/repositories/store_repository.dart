import 'dart:typed_data';

import '../../data_state.dart';
import '../model/media/uploaded_file.dart';
import '../model/store/store.dart';
import '../model/store/store_settings.dart';

abstract class StoreRepository {
  /// The owner's own stores. An inactive store is visible only here.
  Future<DataState<List<Store>>> getMyStores();

  Future<DataState<int>> createStore({
    required String name,
    String? description,
    String type,
  });

  Future<DataState<Store>> getStore(int storeId);

  Future<DataState<Store>> updateStore(
    int storeId, {
    String? name,
    String? description,
    String? logoUrl,
    String? bannerUrl,
  });

  Future<DataState<StoreSettings>> getSettings(int storeId);

  /// Writes only the fields that are passed, then returns the row as the server
  /// holds it — the `PATCH` itself answers no data.
  Future<DataState<StoreSettings>> updateSettings(
    int storeId, {
    bool? autoAcceptOrder,
    bool? vacationMode,
    String? contactPhone,
    String? contactWhatsapp,
    Map<String, dynamic>? operationalHours,
  });

  /// Uploads a file and returns a URL usable by the rest of the API.
  Future<DataState<UploadedFile>> upload({
    required Uint8List bytes,
    required String fileName,
    String? docType,
    int? storeId,
    String? context,
  });
}
