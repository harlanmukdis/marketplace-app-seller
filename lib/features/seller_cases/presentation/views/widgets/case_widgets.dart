import 'package:flutter/material.dart';

import '../../../../../core/domain/model/order/order_case.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// The amber strip at the top of S-18 / S-19: the deadline, the time left,
/// and what happens when it passes.
class CaseDeadlineBanner extends StatelessWidget {
  const CaseDeadlineBanner({
    super.key,
    required this.title,
    required this.deadline,
    required this.message,
  });

  final String title;
  final DateTime? deadline;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.warningSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
        border: Border.all(color: XColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.timer_outlined, color: XColors.warning),
          const SizedBox(width: XSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: XSpace.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      title,
                      style:
                          XText.titleM.copyWith(color: XColors.warningStrong),
                    ),
                    if (deadline != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: XColors.warning,
                          borderRadius: BorderRadius.circular(XRadius.full),
                        ),
                        child: Text(
                          remainingLabel(deadline),
                          style:
                              XText.labelS.copyWith(color: XColors.textOnBrand),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: XText.bodyS.copyWith(color: XColors.warningStrong),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CaseItemRow extends StatelessWidget {
  const CaseItemRow({super.key, required this.item});

  final CaseItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: XSpace.s4),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: XColors.sunken,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child:
                Icon(Icons.inventory_2_outlined, color: XColors.textTertiary),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: XText.titleM),
                Text(
                  <String>[
                    if (item.variant != null) 'Varian: ${item.variant}',
                    '${item.quantity} barang',
                  ].join(' • '),
                  style: XText.bodyS,
                ),
              ],
            ),
          ),
          Text(formatRupiah(item.price * item.quantity), style: XText.priceS),
        ],
      ),
    );
  }
}

XTone caseStatusTone(String status) => switch (status) {
      CaseStatus.pending => XTone.warning,
      CaseStatus.approved => XTone.success,
      CaseStatus.rejected => XTone.danger,
      _ => XTone.info,
    };

/// Title + value row inside the sunken detail box.
class CaseKeyValue extends StatelessWidget {
  const CaseKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) => XKeyValue(
        label: label,
        value: value,
        labelStyle: XText.bodyS,
        valueStyle: valueStyle ?? XText.titleM,
      );
}
