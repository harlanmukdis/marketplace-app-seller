import 'package:flutter/material.dart';

import '../../../../../core/domain/model/order/order.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// The order status chip, coloured from the design system's status table.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final String status;

  static XTone toneOf(String status) => switch (status) {
        OrderStatus.paid ||
        OrderStatus.processed ||
        OrderStatus.packed =>
          XTone.processing,
        OrderStatus.shipped => XTone.shipping,
        OrderStatus.delivered => XTone.received,
        OrderStatus.completed => XTone.completed,
        OrderStatus.refundRequested => XTone.actionNeeded,
        _ => XTone.cancelled,
      };

  @override
  Widget build(BuildContext context) =>
      XChip(label: OrderStatus.label(status), tone: toneOf(status));
}
