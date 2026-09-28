import '../core/data/datasources/remote/service/auth_service.dart';
import '../core/data/datasources/remote/service/catalog_service.dart';
import '../core/data/datasources/remote/service/chat_service.dart';
import '../core/data/datasources/remote/service/inventory_service.dart';
import '../core/data/datasources/remote/service/location_service.dart';
import '../core/data/datasources/remote/service/media_service.dart';
import '../core/data/datasources/remote/service/merchandising_service.dart';
import '../core/data/datasources/remote/service/notification_service.dart';
import '../core/data/datasources/remote/service/order_service.dart';
import '../core/data/datasources/remote/service/promotion_service.dart';
import '../core/data/datasources/remote/service/shipping_service.dart';
import '../core/data/datasources/remote/service/store_service.dart';
import '../core/data/datasources/remote/service/support_service.dart';
import '../core/data/datasources/remote/service/verification_service.dart';
import '../core/data/datasources/remote/service/wallet_service.dart';
import '../core/data/local/session_store.dart';
import '../core/data/repositories/auth_repository_impl.dart';
import '../core/data/repositories/catalog_repository_impl.dart';
import '../core/data/repositories/chat_repository_impl.dart';
import '../core/data/repositories/inventory_repository_impl.dart';
import '../core/data/repositories/location_repository_impl.dart';
import '../core/data/repositories/merchandising_repository_impl.dart';
import '../core/data/repositories/notification_repository_impl.dart';
import '../core/data/repositories/order_repository_impl.dart';
import '../core/data/repositories/promotion_repository_impl.dart';
import '../core/data/repositories/shipping_repository_impl.dart';
import '../core/data/repositories/store_repository_impl.dart';
import '../core/data/repositories/support_repository_impl.dart';
import '../core/data/repositories/verification_repository_impl.dart';
import '../core/data/repositories/wallet_repository_impl.dart';
import '../core/domain/repositories/auth_repository.dart';
import '../core/domain/repositories/catalog_repository.dart';
import '../core/domain/repositories/support_repository.dart';
import '../core/domain/repositories/chat_repository.dart';
import '../core/domain/repositories/inventory_repository.dart';
import '../core/domain/repositories/location_repository.dart';
import '../core/domain/repositories/merchandising_repository.dart';
import '../core/domain/repositories/notification_repository.dart';
import '../core/domain/repositories/order_repository.dart';
import '../core/domain/repositories/promotion_repository.dart';
import '../core/domain/repositories/shipping_repository.dart';
import '../core/domain/repositories/store_repository.dart';
import '../core/domain/repositories/verification_repository.dart';
import '../core/domain/repositories/wallet_repository.dart';
import 'injector.dart';

/// Repositories take services, so this runs after [initializeService].
void initializeRepository() {
  injector.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      injector<AuthService>(),
      injector<SessionStore>(),
    ),
  );

  injector.registerLazySingleton<StoreRepository>(
    () => StoreRepositoryImpl(
      injector<StoreService>(),
      injector<MediaService>(),
    ),
  );

  injector.registerLazySingleton<CatalogRepository>(
    () => CatalogRepositoryImpl(injector<CatalogService>()),
  );

  injector.registerLazySingleton<VerificationRepository>(
    () => VerificationRepositoryImpl(injector<VerificationService>()),
  );

  injector.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(injector<InventoryService>()),
  );

  injector.registerLazySingleton<ShippingRepository>(
    () => ShippingRepositoryImpl(injector<ShippingService>()),
  );

  injector.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(injector<OrderService>()),
  );

  injector.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(injector<WalletService>()),
  );

  injector.registerLazySingleton<PromotionRepository>(
    () => PromotionRepositoryImpl(injector<PromotionService>()),
  );

  injector.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(injector<ChatService>()),
  );

  injector.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(injector<LocationService>()),
  );

  injector.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(injector<NotificationService>()),
  );

  injector.registerLazySingleton<MerchandisingRepository>(
    () => MerchandisingRepositoryImpl(injector<MerchandisingService>()),
  );

  injector.registerLazySingleton<SupportRepository>(
    () => SupportRepositoryImpl(injector<SupportService>()),
  );
}
