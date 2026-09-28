import '../../../utils/json_parse.dart';

/// One order placed against the store.
///
/// A checkout that spans several sellers produces **one order per store**, all
/// sharing a `checkout_session_id`. So an order here is always this store's
/// share and never the buyer's whole basket.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    this.storeId,
    this.buyerId,
    this.warehouseId,
    this.status = OrderStatus.pending,
    this.subtotal = 0,
    this.shippingCost = 0,
    this.discountTotal = 0,
    this.grandTotal = 0,
    this.courierCode,
    this.courierService,
    this.trackingNumber,
    this.shippingAddress = const <String, dynamic>{},
    this.paymentDeadline,
    this.createdAt,
    this.items = const <OrderItem>[],
    this.statusHistory = const <OrderStatusEvent>[],
    this.refund,
    this.settlement,
    this.requiresCustomConfirmation = false,
    this.customConfirmedAt,
    this.customLeadTimeDays,
    this.estimatedLeadTimeDays,
    this.partialFulfillmentProposedAt,
    this.partialFulfillmentDecision,
    this.cancellationFault,
  });

  final int id;

  /// What the buyer quotes when they get in touch — show this, not [id].
  final String orderNumber;

  final int? storeId;
  final int? buyerId;
  final int? warehouseId;
  final String status;
  final int subtotal;
  final int shippingCost;
  final int discountTotal;
  final int grandTotal;
  final String? courierCode;
  final String? courierService;

  /// The AWB. Null until the order ships.
  final String? trackingNumber;

  /// Since API v1.6.0 this is **masked per viewer**: the seller receives only
  /// `{city, province}` of the destination — never the buyer's name, phone or
  /// street. That is also the design system's first non-negotiable rule, so
  /// nothing on an order screen may try to show more. Null when the address
  /// row behind the order is gone.
  final Map<String, dynamic> shippingAddress;

  final DateTime? paymentDeadline;
  final DateTime? createdAt;

  /// Detail payload only; the list carries no items.
  final List<OrderItem> items;
  final List<OrderStatusEvent> statusHistory;

  /// The latest refund request, when there is one. This is the **only** place
  /// the seller can learn the refund id that `approve`/`reject` need.
  final OrderRefund? refund;

  /// `order_settlements`, written only when the order completes. Before that
  /// the server sends null and the earnings panel shows [estimatedSettlement].
  final OrderSettlement? settlement;

  /// An order with a `custom_order` item must be confirmed — with a lead time —
  /// before it can be packed (`422 CUSTOM_CONFIRMATION_REQUIRED` otherwise).
  final bool requiresCustomConfirmation;
  final DateTime? customConfirmedAt;
  final int? customLeadTimeDays;

  /// Longest pre-order lead time in the order; the whole order ships together
  /// after it.
  final int? estimatedLeadTimeDays;

  /// Partial fulfilment: the seller proposes which items are unavailable, and
  /// packing is blocked until the buyer decides.
  final DateTime? partialFulfillmentProposedAt;
  final String? partialFulfillmentDecision;

  /// `buyer` | `seller` | `system` — who a cancellation is attributed to. A
  /// seller-fault cancellation counts against the store's performance.
  final String? cancellationFault;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: asInt(json['id']),
        orderNumber: asString(json['order_number']),
        storeId: asIntOrNull(json['store_id']),
        buyerId: asIntOrNull(json['buyer_id']),
        warehouseId: asIntOrNull(json['warehouse_id']),
        status: asString(json['status'], fallback: OrderStatus.pending),
        subtotal: asInt(json['subtotal']),
        shippingCost: asInt(json['shipping_cost']),
        discountTotal: asInt(json['discount_total']),
        grandTotal: asInt(json['grand_total']),
        courierCode: asStringOrNull(json['courier_code']),
        courierService: asStringOrNull(json['courier_service']),
        trackingNumber: asStringOrNull(json['tracking_number']),
        // `shipping_address` is the masked v1.6.0 field; the raw snapshot is
        // no longer sent, but reading it as a fallback keeps an older server
        // working.
        shippingAddress: json.containsKey('shipping_address')
            ? asEncodedMap(json['shipping_address'])
            : asEncodedMap(json['shipping_address_snapshot']),
        paymentDeadline: asDateTime(json['payment_deadline']),
        createdAt: asCreatedDate(json),
        items: asModelList(json['items'], OrderItem.fromJson),
        statusHistory:
            asModelList(json['status_history'], OrderStatusEvent.fromJson),
        refund: json['refund'] == null
            ? null
            : OrderRefund.fromJson(asMap(json['refund'])),
        settlement: json['settlement'] == null
            ? null
            : OrderSettlement.fromJson(asMap(json['settlement'])),
        requiresCustomConfirmation:
            asBool(json['requires_custom_confirmation']),
        customConfirmedAt: asDateTime(json['custom_confirmed_at']),
        customLeadTimeDays: asIntOrNull(json['custom_lead_time_days']),
        estimatedLeadTimeDays: asIntOrNull(json['estimated_lead_time_days']),
        partialFulfillmentProposedAt:
            asDateTime(json['partial_fulfillment_proposed_at']),
        partialFulfillmentDecision:
            asStringOrNull(json['partial_fulfillment_decision']),
        cancellationFault: asStringOrNull(json['cancellation_fault']),
      );

  int get itemCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// The destination city — the only part of the address the seller sees.
  String get shippingCity => asString(shippingAddress['city']);

  String get shippingProvince => asString(shippingAddress['province']);

  /// When the buyer paid: the `paid` entry of the status history. Both SLAs
  /// are counted from here. Only the detail payload carries history.
  DateTime? get paidAt {
    for (final event in statusHistory) {
      if (event.toStatus == OrderStatus.paid) return event.createdAt;
    }
    return null;
  }

  bool get awaitsCustomConfirmation =>
      requiresCustomConfirmation && customConfirmedAt == null;

  bool get awaitsPartialDecision =>
      partialFulfillmentProposedAt != null && partialFulfillmentDecision == null;

  /// Whether the seller may act, and how. Deliberately decided here rather than
  /// by trying: the server answers an out-of-order transition with **HTTP 200
  /// and an HTML exception page**, so an action offered at the wrong moment
  /// fails in a way nothing can present usefully.
  ///
  /// There is no accept step any more (removed in API v1.6.0): a paid order is
  /// already Processing, and "Cetak Resi" — pack then ship — is the seller's
  /// one commitment. `processed` survives only on orders accepted under the
  /// old flow, and the server no longer has a transition out of it.
  bool get canPack =>
      status == OrderStatus.paid &&
      !awaitsCustomConfirmation &&
      !awaitsPartialDecision;
  bool get canShip => status == OrderStatus.packed;

  /// "Cetak Resi" covers both steps, so it is offered from either state.
  bool get canPrintWaybill => canPack || canShip;

  bool get canCustomConfirm =>
      status == OrderStatus.paid && awaitsCustomConfirmation;

  bool get canProposePartial =>
      status == OrderStatus.paid &&
      partialFulfillmentProposedAt == null &&
      items.length > 1;

  /// The server refuses a cancellation once the order is being worked on.
  /// For the seller this is "Tolak Pesanan", and it counts against them.
  bool get canCancel =>
      status == OrderStatus.pending || status == OrderStatus.paid;

  bool get canResolveRefund =>
      status == OrderStatus.refundRequested && refund != null;

  /// The Final Invoice exists only once an order is completed (design rule 5;
  /// `422 INVOICE_NOT_AVAILABLE` otherwise).
  bool get hasInvoice => status == OrderStatus.completed;

  /// Waiting on the buyer's money — nothing for the seller to do yet.
  bool get isAwaitingPayment => status == OrderStatus.pending;

  /// The seller's queue: everything that needs a hand right now.
  bool get needsAction =>
      canPrintWaybill || canCustomConfirm || canResolveRefund;

  /// The earnings panel, always six lines (design rule 4). The server's figures
  /// once the order completes; before that, what completion would credit today
  /// — 5% commission on the grand total, and Growth unknown until it is charged.
  OrderSettlement get effectiveSettlement =>
      settlement ??
      OrderSettlement.estimate(
        grossMerchandiseValue: subtotal,
        grandTotal: grandTotal,
      );
}

/// `order_settlements` — how a completed order's money was split.
///
/// `shippingSupportSeller` is informational: the subsidy already lowered what
/// the buyer paid, so it is not deducted a second time from the net.
class OrderSettlement {
  const OrderSettlement({
    this.grossMerchandiseValue = 0,
    this.shippingSupportSeller = 0,
    this.platformCommission = 0,
    this.growthCommission = 0,
    this.serviceAdjustment = 0,
    this.netSellerRevenue = 0,
    this.isEstimate = false,
  });

  /// The commission rate the platform charges since API v1.6.0.
  static const double commissionPercent = 5;

  factory OrderSettlement.estimate({
    required int grossMerchandiseValue,
    required int grandTotal,
  }) {
    final commission = (grandTotal * commissionPercent / 100).round();
    return OrderSettlement(
      grossMerchandiseValue: grossMerchandiseValue,
      platformCommission: commission,
      netSellerRevenue: grandTotal - commission,
      isEstimate: true,
    );
  }

  factory OrderSettlement.fromJson(Map<String, dynamic> json) =>
      OrderSettlement(
        grossMerchandiseValue: asInt(json['gross_merchandise_value']),
        shippingSupportSeller: asInt(json['shipping_support_seller']),
        platformCommission: asInt(json['platform_commission']),
        growthCommission: asInt(json['growth_commission']),
        serviceAdjustment: asInt(json['service_adjustment']),
        netSellerRevenue: asInt(json['net_seller_revenue']),
      );

  final int grossMerchandiseValue;
  final int shippingSupportSeller;
  final int platformCommission;
  final int growthCommission;
  final int serviceAdjustment;
  final int netSellerRevenue;

  /// True until the order completes and the server writes the real row.
  final bool isEstimate;
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    this.productVariantId,
    this.options = const <String, dynamic>{},
    this.price = 0,
    this.quantity = 0,
    this.subtotal = 0,
    this.isAvailable = true,
  });

  final int id;

  /// A snapshot taken at checkout. If the product was renamed since, this still
  /// says what the buyer actually ordered — which is the point.
  final String productName;

  final int? productVariantId;
  final Map<String, dynamic> options;
  final int price;
  final int quantity;
  final int subtotal;

  /// False once the seller has proposed it as unavailable (partial fulfilment).
  final bool isAvailable;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: asInt(json['id']),
        productName: asString(json['product_name_snapshot']),
        productVariantId: asIntOrNull(json['product_variant_id']),
        options: asEncodedMap(json['variant_options_snapshot']),
        price: asInt(json['price_snapshot']),
        quantity: asInt(json['quantity']),
        subtotal: asInt(json['subtotal']),
        isAvailable: json['is_available'] == null
            ? true
            : asBool(json['is_available']),
      );

  String get optionsLabel => options.values.map((value) => '$value').join(' · ');
}

/// One row of `order_status_history`. `fromStatus` is null for the first entry.
class OrderStatusEvent {
  const OrderStatusEvent({
    required this.id,
    required this.toStatus,
    this.fromStatus,
    this.notes,
    this.createdAt,
  });

  final int id;
  final String toStatus;
  final String? fromStatus;

  /// Carries the cancellation reason when the transition was a cancel.
  final String? notes;

  final DateTime? createdAt;

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) =>
      OrderStatusEvent(
        id: asInt(json['id']),
        toStatus: asString(json['to_status']),
        fromStatus: asStringOrNull(json['from_status']),
        notes: asStringOrNull(json['notes']),
        createdAt: asCreatedDate(json),
      );
}

class OrderRefund {
  const OrderRefund({
    required this.id,
    this.amount = 0,
    this.reason,
    this.status,
    this.createdAt,
  });

  final int id;
  final int amount;
  final String? reason;
  final String? status;
  final DateTime? createdAt;

  factory OrderRefund.fromJson(Map<String, dynamic> json) => OrderRefund(
        id: asInt(json['id']),
        amount: asInt(json['amount']),
        reason: asStringOrNull(json['reason']),
        status: asStringOrNull(json['status']),
        createdAt: asCreatedDate(json),
      );

  bool get isPending => status == 'requested' || status == 'pending';
}

/// `GET /orders/{id}/tracking` — a single `order_shipments` row, or null before
/// the order ships.
class OrderShipment {
  const OrderShipment({
    required this.id,
    this.courierCode,
    this.serviceType,
    this.awbNumber,
    this.status,
    this.shippedAt,
    this.handoverMethod,
  });

  final int id;
  final String? courierCode;
  final String? serviceType;
  final String? awbNumber;
  final String? status;
  final DateTime? shippedAt;

  /// `drop_off` | `pickup` (API v1.15.0).
  final String? handoverMethod;

  factory OrderShipment.fromJson(Map<String, dynamic> json) => OrderShipment(
        id: asInt(json['id']),
        courierCode: asStringOrNull(json['courier_code']),
        serviceType: asStringOrNull(json['service_type']),
        awbNumber: asStringOrNull(json['awb_number']),
        status: asStringOrNull(json['status']),
        shippedAt: asDateTime(json['shipped_at']),
        handoverMethod: asStringOrNull(json['handover_method']),
      );
}

abstract class OrderStatus {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String processed = 'processed';
  static const String packed = 'packed';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String refundRequested = 'refund_requested';
  static const String refundApproved = 'refund_approved';
  static const String refundRejected = 'refund_rejected';

  /// The order the seller actually works through. `delivered` and `completed`
  /// are the buyer's to trigger, and the refund states arrive on their own.
  static const List<String> all = <String>[
    pending,
    paid,
    processed,
    packed,
    shipped,
    delivered,
    completed,
    cancelled,
    refundRequested,
    refundApproved,
    refundRejected,
  ];

  /// Xpedia vocabulary: a paid order is already "Processing" — there is no
  /// separate acceptance step to wait on.
  static String label(String? status) => switch (status) {
        pending => 'Belum dibayar',
        paid => 'Processing',
        processed => 'Processing',
        packed => 'Siap kirim',
        shipped => 'Dalam Pengiriman',
        delivered => 'Diterima',
        completed => 'Selesai',
        cancelled => 'Dibatalkan',
        refundRequested => 'Refund diajukan',
        refundApproved => 'Refund disetujui',
        refundRejected => 'Refund ditolak',
        _ => status ?? '-',
      };
}

/// `GET /orders/{id}/invoice` — the Final Invoice. A separate document from
/// the waybill, available only after the order completes; the server numbers
/// it once and returns the same number on every later read. It is data, not a
/// PDF — rendering is the client's job.
class OrderInvoice {
  const OrderInvoice({
    required this.invoiceNumber,
    required this.orderNumber,
    this.generatedAt,
    this.orderDate,
    this.storeName = '',
    this.shippingAddress = const <String, dynamic>{},
    this.items = const <OrderItem>[],
    this.subtotal = 0,
    this.shippingCost = 0,
    this.discountTotal = 0,
    this.grandTotal = 0,
  });

  final String invoiceNumber;
  final String orderNumber;
  final DateTime? generatedAt;
  final DateTime? orderDate;
  final String storeName;
  final Map<String, dynamic> shippingAddress;
  final List<OrderItem> items;
  final int subtotal;
  final int shippingCost;
  final int discountTotal;
  final int grandTotal;

  factory OrderInvoice.fromJson(Map<String, dynamic> json) => OrderInvoice(
        invoiceNumber: asString(json['invoice_number']),
        orderNumber: asString(json['order_number']),
        generatedAt: asDateTime(json['generated_at']),
        orderDate: asDateTime(json['order_date']),
        storeName: asString(asMap(json['store'])['name']),
        shippingAddress: asEncodedMap(json['shipping_address']),
        items: asModelList(json['items'], OrderItem.fromJson),
        subtotal: asInt(json['subtotal']),
        shippingCost: asInt(json['shipping_cost']),
        discountTotal: asInt(json['discount_total']),
        grandTotal: asInt(json['grand_total']),
      );
}

/// Pre-handover proof on a Secure+ order: at least one photo and one video.
class ShipmentEvidence {
  const ShipmentEvidence({
    required this.mediaType,
    required this.url,
    this.createdAt,
  });

  factory ShipmentEvidence.fromJson(Map<String, dynamic> json) =>
      ShipmentEvidence(
        mediaType: asString(json['media_type']),
        url: asString(json['url']),
        createdAt: asCreatedDate(json),
      );

  final DateTime? createdAt;

  /// `photo` | `video`.
  final String mediaType;
  final String url;

  bool get isVideo => mediaType == 'video';
}

/// How the parcel reaches the courier (API v1.15.0).
abstract class HandoverMethod {
  static const String dropOff = 'drop_off';
  static const String pickup = 'pickup';
}

/// The deadline the server enforces on a paid order.
///
/// Design.md describes two SLAs in working days (payment -> waybill, waybill
/// -> handover). The backend implements **one** window of `order_resi_sla_hours`
/// (48 by default) from payment to `shipped`, counted in plain hours, and
/// `order_resi_sla_worker` auto-cancels and refunds when it lapses. A countdown
/// that followed the design's working days would tell a seller they had time
/// the server does not give them, so this follows the server.
abstract class OrderSla {
  static const Duration resiWindow = Duration(hours: 48);

  /// Under this, the design asks for a countdown chip.
  static const Duration urgentUnder = Duration(hours: 24);

  static DateTime? deadlineFor(Order order) {
    if (order.status != OrderStatus.paid &&
        order.status != OrderStatus.processed &&
        order.status != OrderStatus.packed) {
      return null;
    }
    final paidAt = order.paidAt;
    return paidAt?.add(resiWindow);
  }

  static Duration? remaining(Order order, {DateTime? now}) {
    final deadline = deadlineFor(order);
    if (deadline == null) return null;
    return deadline.difference(now ?? DateTime.now());
  }

  /// "6 jam 45 mnt" / "1 hari 3 jam" / "lewat batas".
  static String format(Duration remaining) {
    if (remaining.isNegative) return 'lewat batas';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    if (days > 0) return '$days hari $hours jam';
    if (remaining.inHours > 0) return '${remaining.inHours} jam $minutes mnt';
    return '$minutes mnt';
  }
}
