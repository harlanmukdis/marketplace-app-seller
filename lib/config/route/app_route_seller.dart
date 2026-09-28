import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_routes.dart';
import '../../features/seller_auth/presentation/views/seller_login_view.dart';
import '../../features/seller_catalog/presentation/views/product_form_view.dart';
import '../../features/seller_chat/presentation/views/chat_inbox_view.dart';
import '../../features/seller_chat/presentation/views/chat_thread_view.dart';
import '../../features/seller_catalog/presentation/views/product_list_view.dart';
import '../../features/seller_auth/presentation/views/seller_register_view.dart';
import '../../features/seller_home/presentation/views/seller_home_shell.dart';
import '../../features/seller_merchandising/presentation/views/bundle_detail_view.dart';
import '../../features/seller_merchandising/presentation/views/merchandising_view.dart';
import '../../features/seller_merchandising/presentation/views/showcase_detail_view.dart';
import '../../features/seller_notifications/presentation/views/notification_inbox_view.dart';
import '../../features/seller_inventory/presentation/views/stock_view.dart';
import '../../features/seller_account/presentation/views/security_view.dart';
import '../../features/seller_growth/presentation/views/growth_view.dart';
import '../../features/seller_orders/presentation/views/order_detail_view.dart';
import '../../features/seller_performance/presentation/views/analytics_view.dart';
import '../../features/seller_performance/presentation/views/performance_view.dart';
import '../../features/seller_reviews/presentation/views/review_view.dart';
import '../../features/seller_orders/presentation/views/order_invoice_view.dart';
import '../../features/seller_store/presentation/views/store_settings_view.dart';
import '../../features/seller_support/presentation/views/support_view.dart';
import '../../features/seller_support/presentation/views/ticket_detail_view.dart';
import '../../features/seller_orders/presentation/views/order_list_view.dart';
import '../../features/seller_promotions/presentation/views/flash_sale_detail_view.dart';
import '../../features/seller_promotions/presentation/views/promotion_view.dart';
import '../../features/seller_inventory/presentation/views/warehouse_list_view.dart';
import '../../features/seller_shipping/presentation/views/courier_view.dart';
import '../../features/seller_verification/presentation/views/verification_view.dart';
import '../../features/seller_wallet/presentation/views/wallet_view.dart';
import '../../features/seller_shell/presentation/views/seller_bootstrap_view.dart';
import '../../features/seller_store/presentation/views/store_create_view.dart';
import '../../features/seller_store/presentation/views/store_picker_view.dart';

/// Paths for the seller domain.
///
/// Kept separate from the UI kit's [AppRoutes] and spread into the single
/// [router] — the per-domain split the target architecture asks for.
abstract class SellerRoutes {
  static const String bootstrap = '/';
  static const String login = '/seller/login';
  static const String register = '/seller/register';

  /// The main shell once an account has a store selected.
  static const String home = '/seller/home';

  /// An account can own several stores, so which one the app is acting as is
  /// an explicit choice rather than an identity baked into the token.
  static const String storePicker = '/seller/stores';
  static const String storeCreate = '/seller/stores/new';

  /// The catalogue of whichever store is active.
  static const String products = '/seller/products';
  static const String productCreate = '/seller/products/new';

  /// Declared with a path parameter rather than `state.extra`, so a product
  /// screen survives a reload and is linkable — `extra` is the kit's habit, not
  /// something the seller domain has to inherit.
  static const String productEdit = '/seller/products/:id';

  static String productEditPath(int productId) => '/seller/products/$productId';

  /// Verification is the only route out of `inactive`, so it hangs off the
  /// dashboard rather than being buried in settings.
  static const String verification = '/seller/verification';

  /// Warehouses, and the stock held in one of them.
  static const String warehouses = '/seller/warehouses';
  static const String warehouseStock = '/seller/warehouses/:id/stock';

  static String warehouseStockPath(int warehouseId) =>
      '/seller/warehouses/$warehouseId/stock';

  /// Which couriers the store ships with — an optional whitelist; picking none
  /// leaves every courier on offer.
  static const String couriers = '/seller/couriers';

  /// Incoming orders, and one of them.
  static const String orders = '/seller/orders';
  static const String orderDetail = '/seller/orders/:id';

  static String orderDetailPath(int orderId) => '/seller/orders/$orderId';

  /// The Final Invoice — only for a completed order.
  static const String orderInvoice = '/seller/orders/:id/invoice';

  static String orderInvoicePath(int orderId) =>
      '/seller/orders/$orderId/invoice';

  /// Profile, vacation mode, private contacts (S-43).
  static const String storeSettings = '/seller/store/settings';

  /// Withdrawal PIN (S-44).
  static const String security = '/seller/account/security';

  /// Xpedia Growth (S-32), optionally opened on one product.
  static const String growth = '/seller/growth';
  static const String growthProduct = '/seller/growth/:productId';

  static String growthProductPath(int productId) =>
      '/seller/growth/$productId';

  /// Partners Performance (S-35) and Analytics (S-33).
  static const String performance = '/seller/performance';
  static const String analytics = '/seller/analytics';

  /// Product reviews across the store (S-37).
  static const String reviews = '/seller/reviews';

  /// Xpedia 911 — tickets to the platform (S-41, S-42).
  static const String support = '/seller/support';
  static const String supportTicket = '/seller/support/:id';

  static String supportTicketPath(int ticketId) => '/seller/support/$ticketId';

  /// Where the store's earnings land, and the only route out of them.
  static const String wallet = '/seller/wallet';

  /// Vouchers and flash sales, both create-and-list only.
  static const String promotions = '/seller/promotions';

  /// One sale's contents. There is no `GET /flash-sales/{id}` on the backend,
  /// so the screen recovers the sale from the store's list by this id.
  static const String flashSaleDetail = '/seller/flash-sales/:id';

  static String flashSaleDetailPath(int flashSaleId) =>
      '/seller/flash-sales/$flashSaleId';

  /// Chat. The inbox is not an inbox yet — the backend has no store-scoped
  /// conversation list — so it explains the gap and hands off to a thread,
  /// which does work.
  static const String chat = '/seller/chat';
  static const String chatThread = '/seller/chat/:id';

  static String chatThreadPath(int conversationId) =>
      '/seller/chat/$conversationId';

  /// The account's notifications — per user, not per store.
  static const String notifications = '/seller/notifications';

  /// Bundles and showcases, the two ways products are grouped.
  static const String merchandising = '/seller/merchandising';

  /// A bundle's contents. Readable only while the bundle is active — the
  /// screen handles that rather than hiding it.
  static const String bundleDetail = '/seller/bundles/:id';

  static String bundleDetailPath(int bundleId) => '/seller/bundles/$bundleId';

  /// A showcase's products. There is no `GET /showcases/{id}`, so the row is
  /// recovered from the store's list by this id.
  static const String showcaseDetail = '/seller/showcases/:id';

  static String showcaseDetailPath(int showcaseId) =>
      '/seller/showcases/$showcaseId';
}

/// Every route uses the same fade-through wrapper as the rest of the app.
///
/// Order matters: `/seller/products/new` has to come before the greedier
/// `/seller/products/:id`, or "new" is read as a product id.
final List<RouteBase> appRouterSeller = <RouteBase>[
  _sellerRoute(SellerRoutes.bootstrap, const SellerBootstrapView()),
  _sellerRoute(SellerRoutes.login, const SellerLoginView()),
  _sellerRoute(SellerRoutes.register, const SellerRegisterView()),
  _sellerRoute(SellerRoutes.home, const SellerHomeShell()),
  _sellerRoute(SellerRoutes.storePicker, const StorePickerView()),
  _sellerRoute(SellerRoutes.storeCreate, const StoreCreateView()),
  _sellerRoute(SellerRoutes.products, const ProductListView()),
  _sellerRoute(SellerRoutes.productCreate, const ProductFormView()),
  _sellerRouteBuilder(
    SellerRoutes.productEdit,
    (state) => ProductFormView(
      productId: int.tryParse(state.pathParameters['id'] ?? ''),
    ),
  ),
  _sellerRoute(SellerRoutes.verification, const VerificationView()),
  _sellerRoute(SellerRoutes.couriers, const CourierView()),
  _sellerRoute(SellerRoutes.orders, const OrderListView()),
  _sellerRoute(SellerRoutes.wallet, const WalletView()),
  _sellerRoute(SellerRoutes.promotions, const PromotionView()),
  _sellerRoute(SellerRoutes.chat, const ChatInboxView()),
  _sellerRoute(SellerRoutes.notifications, const NotificationInboxView()),
  _sellerRoute(SellerRoutes.merchandising, const MerchandisingView()),
  _sellerRouteBuilder(
    SellerRoutes.bundleDetail,
    (state) => BundleDetailView(
      bundleId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.showcaseDetail,
    (state) => ShowcaseDetailView(
      showcaseId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.chatThread,
    (state) => ChatThreadView(
      conversationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.flashSaleDetail,
    (state) => FlashSaleDetailView(
      flashSaleId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRoute(SellerRoutes.storeSettings, const StoreSettingsView()),
  _sellerRoute(SellerRoutes.security, const SecurityView()),
  _sellerRoute(SellerRoutes.support, const SupportView()),
  _sellerRoute(SellerRoutes.performance, const PerformanceView()),
  _sellerRoute(SellerRoutes.analytics, const AnalyticsView()),
  _sellerRoute(SellerRoutes.reviews, const ReviewView()),
  _sellerRoute(SellerRoutes.growth, const GrowthView()),
  _sellerRouteBuilder(
    SellerRoutes.growthProduct,
    (state) => GrowthView(
      productId: int.tryParse(state.pathParameters['productId'] ?? ''),
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.supportTicket,
    (state) => TicketDetailView(
      ticketId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.orderInvoice,
    (state) => OrderInvoiceView(
      orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRouteBuilder(
    SellerRoutes.orderDetail,
    (state) => OrderDetailView(
      orderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
  _sellerRoute(SellerRoutes.warehouses, const WarehouseListView()),
  _sellerRouteBuilder(
    SellerRoutes.warehouseStock,
    (state) => StockView(
      warehouseId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
    ),
  ),
];

GoRoute _sellerRoute(String path, Widget page) =>
    _sellerRouteBuilder(path, (_) => page);

GoRoute _sellerRouteBuilder(
  String path,
  Widget Function(GoRouterState state) builder,
) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => FadeThroughTransitionPageWrapper(
        transitionKey: state.pageKey,
        page: builder(state),
      ),
    );
