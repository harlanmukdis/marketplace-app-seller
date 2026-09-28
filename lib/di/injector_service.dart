import 'package:dio/dio.dart';

import '../core/data/datasources/remote/service/account_service.dart';
import '../core/data/datasources/remote/service/auth_service.dart';
import '../core/data/datasources/remote/service/catalog_service.dart';
import '../core/data/datasources/remote/service/chat_service.dart';
import '../core/data/datasources/remote/service/inventory_service.dart';
import '../core/data/datasources/remote/service/location_service.dart';
import '../core/data/datasources/remote/service/media_service.dart';
import '../core/data/datasources/remote/service/merchandising_service.dart';
import '../core/data/datasources/remote/service/notification_service.dart';
import '../core/data/datasources/remote/service/order_service.dart';
import '../core/data/datasources/remote/service/performance_service.dart';
import '../core/data/datasources/remote/service/promotion_service.dart';
import '../core/data/datasources/remote/service/review_service.dart';
import '../core/data/datasources/remote/service/shipping_service.dart';
import '../core/data/datasources/remote/service/store_service.dart';
import '../core/data/datasources/remote/service/support_service.dart';
import '../core/data/datasources/remote/service/verification_service.dart';
import '../core/data/datasources/remote/service/wallet_service.dart';
import '../config/network/dio_client.dart';
import 'injector.dart';

/// Services take the named `"api"` Dio instance and are registered before the
/// repositories that depend on them.
void initializeService() {
  final dio = injector<Dio>(instanceName: DioClient.apiInstanceName);

  injector.registerLazySingleton<AuthService>(() => AuthService(dio));
  injector.registerLazySingleton<StoreService>(() => StoreService(dio));
  injector.registerLazySingleton<MediaService>(() => MediaService(dio));
  injector.registerLazySingleton<CatalogService>(() => CatalogService(dio));
  injector
      .registerLazySingleton<VerificationService>(() => VerificationService(dio));
  injector.registerLazySingleton<InventoryService>(() => InventoryService(dio));
  injector.registerLazySingleton<ShippingService>(() => ShippingService(dio));
  injector.registerLazySingleton<OrderService>(() => OrderService(dio));
  injector.registerLazySingleton<WalletService>(() => WalletService(dio));
  injector.registerLazySingleton<PromotionService>(() => PromotionService(dio));
  injector.registerLazySingleton<ChatService>(() => ChatService(dio));
  injector.registerLazySingleton<LocationService>(() => LocationService(dio));
  injector.registerLazySingleton<MerchandisingService>(
      () => MerchandisingService(dio));
  injector.registerLazySingleton<NotificationService>(
      () => NotificationService(dio));
  injector.registerLazySingleton<SupportService>(() => SupportService(dio));
  injector.registerLazySingleton<PerformanceService>(
      () => PerformanceService(dio));
  injector.registerLazySingleton<ReviewService>(() => ReviewService(dio));
  injector.registerLazySingleton<AccountService>(() => AccountService(dio));
}
