import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/order/order.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../core/domain/repositories/order_repository.dart';
import '../../../../../di/injector.dart';

part 'order_list_state.dart';

/// The store's orders, across every status.
///
/// Loaded once without a status filter and split into tabs locally, so every
/// tab count is known without a request per tab. The list endpoint is capped at
/// 20 rows with no `meta`, so pages are walked until one comes back short.
///
/// List rows carry no items, while the order card shows the product, the total
/// and the SLA — so the orders on the visible tab are then read in full, a few
/// at a time. That is an N+1, deliberately bounded by [_detailLimit].
class OrderListCubit extends Cubit<OrderListState> {
  OrderListCubit({OrderFilter initial = OrderFilter.processing})
      : _filter = initial,
        super(const OrderListInProgress());

  static OrderListCubit get(BuildContext context) => BlocProvider.of(context);

  final OrderRepository _orders = injector<OrderRepository>();
  final AuthRepository _auth = injector<AuthRepository>();

  OrderFilter _filter;

  static const int _pageSize = 20;
  static const int _pageCap = 10;
  static const int _detailLimit = 30;
  static const int _batch = 5;

  Future<void> load() async {
    if (isClosed) return;

    final storeId = _auth.activeStoreId;
    if (storeId == null) {
      emit(const OrderListNoStore());
      return;
    }

    final previous = state;
    emit(const OrderListInProgress());

    final collected = <Order>[];
    for (var page = 1; page <= _pageCap; page++) {
      final result = await _orders.getStoreOrders(storeId, page: page);
      if (isClosed) return;

      switch (result) {
        case DataSuccess<List<Order>>(:final value):
          collected.addAll(value);
          if (value.length < _pageSize) page = _pageCap;
        case DataFailed<List<Order>>(:final failure):
          emit(OrderListFailure(failure));
          return;
        default:
          page = _pageCap;
      }
    }

    collected.sort((a, b) {
      final left = a.createdAt;
      final right = b.createdAt;
      if (left == null || right == null) return b.id.compareTo(a.id);
      return right.compareTo(left);
    });

    emit(OrderListLoaded(
      all: collected,
      filter: _filter,
      query: previous is OrderListLoaded ? previous.query : '',
    ));
    await _loadDetails();
  }

  Future<void> setFilter(OrderFilter filter) async {
    _filter = filter;
    final current = state;
    if (current is! OrderListLoaded) return;
    emit(current.copyWith(filter: filter));
    await _loadDetails();
  }

  void search(String query) {
    final current = state;
    if (current is OrderListLoaded) emit(current.copyWith(query: query));
  }

  Future<void> _loadDetails() async {
    final current = state;
    if (current is! OrderListLoaded) return;

    final missing = current.all
        .where((o) => current.filter.matches(o.status))
        .where((o) => !current.details.containsKey(o.id))
        .take(_detailLimit)
        .toList(growable: false);

    for (var i = 0; i < missing.length; i += _batch) {
      final chunk = missing.skip(i).take(_batch);
      final results = await Future.wait(chunk.map((o) => _orders.getOrder(o.id)));
      if (isClosed) return;

      final latest = state;
      if (latest is! OrderListLoaded) return;
      final details = Map<int, Order>.of(latest.details);
      for (final result in results) {
        if (result is DataSuccess<Order>) details[result.value.id] = result.value;
      }
      emit(latest.copyWith(details: details));
    }
  }
}
