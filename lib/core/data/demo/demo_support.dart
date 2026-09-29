import '../../../config/env/app_config.dart';
import '../../data_state.dart';

/// The one switch every sample-data repository goes through.
///
/// With `DEMO_DATA` off (the default) the answer is
/// [DataError.apiPending], which screens render as "Menunggu API". With it
/// on, [build] supplies the sample, after a short pause so loading states are
/// seen the way they will be once the real endpoint exists.
///
/// When the backend ships an endpoint, its `*RepositoryImpl` replaces the
/// demo class in `injector_repository.dart`; nothing on screen changes.
Future<DataState<T>> demoOr<T>(String feature, T Function() build) async {
  if (!AppConfig.demoData) return DataFailed<T>(DataError.apiPending(feature));
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final value = build();
  if (value is Iterable && value.isEmpty) return DataEmpty<T>();
  return DataSuccess<T>(value);
}

/// A write that has nowhere to go yet. Succeeds in demo mode — the screen
/// updates locally — and is refused otherwise.
Future<DataError?> demoWrite(String feature) async {
  if (!AppConfig.demoData) return DataError.apiPending(feature);
  await Future<void>.delayed(const Duration(milliseconds: 250));
  return null;
}
