part of 'order_list_cubit.dart';

sealed class OrderListState {
  const OrderListState();
}

final class OrderListInProgress extends OrderListState {
  const OrderListInProgress();
}

final class OrderListNoStore extends OrderListState {
  const OrderListNoStore();
}

final class OrderListFailure extends OrderListState {
  const OrderListFailure(this.error);

  final DataError error;
}

final class OrderListLoaded extends OrderListState {
  const OrderListLoaded({
    required this.all,
    required this.filter,
    this.details = const <int, Order>{},
    this.query = '',
  });

  /// Every order of the store, as the list endpoint returns them — no items.
  final List<Order> all;
  final OrderFilter filter;

  /// Full detail rows for the orders on the visible tab, fetched afterwards so
  /// the card can show the product, the total and the SLA countdown.
  final Map<int, Order> details;

  /// Free-text search over the order number (the only searchable field the
  /// list rows carry) and, once loaded, product names.
  final String query;

  List<Order> get orders {
    final q = query.trim().toLowerCase();
    return all
        .where((order) => filter.matches(order.status))
        .map((order) => details[order.id] ?? order)
        .where((order) =>
            q.isEmpty ||
            order.orderNumber.toLowerCase().contains(q) ||
            order.items.any((i) => i.productName.toLowerCase().contains(q)))
        .toList(growable: false);
  }

  int countOf(OrderFilter f) =>
      all.where((order) => f.matches(order.status)).length;

  bool get isEmpty => orders.isEmpty;

  OrderListLoaded copyWith({
    OrderFilter? filter,
    Map<int, Order>? details,
    String? query,
  }) =>
      OrderListLoaded(
        all: all,
        filter: filter ?? this.filter,
        details: details ?? this.details,
        query: query ?? this.query,
      );
}

/// The tabs of "Daftar Pesanan" (S-13), in the design's order.
enum OrderFilter {
  all('Semua', <String>[]),
  processing('Processing', <String>[
    OrderStatus.paid,
    OrderStatus.processed,
    OrderStatus.packed,
  ]),
  shipping('Dalam Pengiriman', <String>[OrderStatus.shipped]),
  received('Diterima', <String>[OrderStatus.delivered]),
  completed('Selesai', <String>[OrderStatus.completed]),
  cancelled('Dibatalkan', <String>[
    OrderStatus.cancelled,
    OrderStatus.refundApproved,
  ]),
  complaint('Komplain', <String>[
    OrderStatus.refundRequested,
    OrderStatus.refundRejected,
  ]),
  unpaid('Belum Dibayar', <String>[OrderStatus.pending]);

  const OrderFilter(this.label, this.statuses);

  final String label;

  /// Empty means every status.
  final List<String> statuses;

  bool matches(String status) => statuses.isEmpty || statuses.contains(status);

  /// Tabs whose count is worth a number next to the label.
  bool get showsCount =>
      this == processing || this == shipping || this == complaint;
}
