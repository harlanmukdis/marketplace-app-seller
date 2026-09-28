import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/model/performance/store_performance.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/order_repository.dart';
import '../../../../core/domain/repositories/performance_repository.dart';
import '../../../../di/injector.dart';

/// Partners Performance (S-35). Four independent reads; each tile degrades on
/// its own rather than failing the screen.
class PerformanceSnapshot {
  const PerformanceSnapshot({
    this.loading = true,
    this.performance,
    this.tier,
    this.health,
    this.error,
  });

  final bool loading;
  final PartnersPerformance? performance;
  final SellerTier? tier;
  final HealthScore? health;

  /// Set only when the main block failed — the rest is optional.
  final DataError? error;
}

class PerformanceCubit extends Cubit<PerformanceSnapshot> {
  PerformanceCubit() : super(const PerformanceSnapshot());

  static PerformanceCubit get(BuildContext context) => BlocProvider.of(context);

  final PerformanceRepository _repo = injector<PerformanceRepository>();

  Future<void> load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) {
      emit(const PerformanceSnapshot(
        loading: false,
        error: DataError(code: 'NO_STORE', message: 'Belum ada toko dipilih.'),
      ));
      return;
    }
    emit(const PerformanceSnapshot());
    final results = await Future.wait<Object>(<Future<Object>>[
      _repo.getPartnersPerformance(storeId),
      _repo.getTier(storeId),
      _repo.getHealthScore(storeId),
    ]);
    if (isClosed) return;
    final pp = results[0] as DataState<PartnersPerformance>;
    final tier = results[1] as DataState<SellerTier>;
    final health = results[2] as DataState<(HealthScore?, List<HealthScore>)>;
    emit(PerformanceSnapshot(
      loading: false,
      performance: pp is DataSuccess<PartnersPerformance> ? pp.value : null,
      error: pp is DataFailed<PartnersPerformance> ? pp.failure : null,
      tier: tier is DataSuccess<SellerTier> ? tier.value : null,
      health: health is DataSuccess<(HealthScore?, List<HealthScore>)>
          ? health.value.$1
          : null,
    ));
  }
}

/// Analytics (S-33).
///
/// Sales figures are computed here from the store's own orders, because the
/// API's `/stores/{id}/analytics` reads a table nothing ever writes. Per the
/// blueprint only **completed** orders count, and the period is compared with
/// the one before it. Funnel, traffic source, visitors and best products have
/// no server data at all and are not shown as numbers.
enum AnalyticsPeriod {
  today('Hari Ini'),
  week('7 Hari Terakhir'),
  month('Bulan Ini');

  const AnalyticsPeriod(this.label);

  final String label;

  /// [start, end) of this period and of the one before it.
  (DateTime, DateTime, DateTime, DateTime) ranges(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case AnalyticsPeriod.today:
        final end = today.add(const Duration(days: 1));
        return (today, end, today.subtract(const Duration(days: 1)), today);
      case AnalyticsPeriod.week:
        final end = today.add(const Duration(days: 1));
        final start = end.subtract(const Duration(days: 7));
        return (start, end, start.subtract(const Duration(days: 7)), start);
      case AnalyticsPeriod.month:
        final start = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1);
        return (start, end, DateTime(now.year, now.month - 1), start);
    }
  }
}

class SalesFigures {
  const SalesFigures({this.gmv = 0, this.orders = 0});

  final int gmv;
  final int orders;

  int get averageOrder => orders == 0 ? 0 : (gmv / orders).round();
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    this.loading = true,
    this.period = AnalyticsPeriod.month,
    this.completed = const <Order>[],
    this.segmentation,
    this.mismatches = const <StockMismatchEvent>[],
    this.error,
  });

  final bool loading;
  final AnalyticsPeriod period;

  /// Completed orders of the store, all time.
  final List<Order> completed;
  final CustomerSegmentation? segmentation;
  final List<StockMismatchEvent> mismatches;
  final DataError? error;

  (SalesFigures, SalesFigures) figures({DateTime? now}) {
    final (start, end, prevStart, prevEnd) =
        period.ranges(now ?? DateTime.now());
    SalesFigures sum(DateTime a, DateTime b) {
      final rows = completed.where((o) {
        final t = o.createdAt;
        return t != null && !t.isBefore(a) && t.isBefore(b);
      });
      return SalesFigures(
        gmv: rows.fold(0, (s, o) => s + o.subtotal),
        orders: rows.length,
      );
    }

    return (sum(start, end), sum(prevStart, prevEnd));
  }

  AnalyticsSnapshot copyWith({AnalyticsPeriod? period}) => AnalyticsSnapshot(
        loading: loading,
        period: period ?? this.period,
        completed: completed,
        segmentation: segmentation,
        mismatches: mismatches,
        error: error,
      );
}

class AnalyticsCubit extends Cubit<AnalyticsSnapshot> {
  AnalyticsCubit() : super(const AnalyticsSnapshot());

  static AnalyticsCubit get(BuildContext context) => BlocProvider.of(context);

  final PerformanceRepository _repo = injector<PerformanceRepository>();
  final OrderRepository _orders = injector<OrderRepository>();

  static const int _pageSize = 20;
  static const int _pageCap = 25;

  void setPeriod(AnalyticsPeriod p) => emit(state.copyWith(period: p));

  Future<void> load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) {
      emit(const AnalyticsSnapshot(
        loading: false,
        error: DataError(code: 'NO_STORE', message: 'Belum ada toko dipilih.'),
      ));
      return;
    }
    final period = state.period;
    emit(AnalyticsSnapshot(period: period));

    final completed = <Order>[];
    DataError? error;
    // The status filter keeps this to completed orders; still capped at 20 a
    // page with no meta, so walk until a short page.
    for (var page = 1; page <= _pageCap; page++) {
      final result = await _orders.getStoreOrders(
        storeId,
        status: OrderStatus.completed,
        page: page,
      );
      if (isClosed) return;
      if (result is DataSuccess<List<Order>>) {
        completed.addAll(result.value);
        if (result.value.length < _pageSize) break;
      } else {
        if (result is DataFailed<List<Order>>) error = result.failure;
        break;
      }
    }

    final extras = await Future.wait<Object>(<Future<Object>>[
      _repo.getCustomerSegmentation(storeId),
      _repo.getStockMismatchEvents(storeId),
    ]);
    if (isClosed) return;
    final seg = extras[0];
    final mis = extras[1];
    emit(AnalyticsSnapshot(
      loading: false,
      period: period,
      completed: completed,
      segmentation:
          seg is DataSuccess<CustomerSegmentation> ? seg.value : null,
      mismatches: mis is DataSuccess<List<StockMismatchEvent>>
          ? mis.value
          : const <StockMismatchEvent>[],
      error: error,
    ));
  }
}
