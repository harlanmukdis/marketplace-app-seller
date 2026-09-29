import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// The state of a promotion, at a glance.
///
/// Both kinds report a phase worked out from their own dates rather than the
/// `status` column, so the pill is the derived answer rather than what the
/// database happens to hold.
class PromotionPill extends StatelessWidget {
  const PromotionPill({super.key, required this.label, required this.color});

  PromotionPill.voucher(VoucherPhase phase, {super.key})
      : label = phase.label,
        color = switch (phase) {
          VoucherPhase.running => kSuccessColor,
          VoucherPhase.scheduled => kLightPrimaryColor,
          VoucherPhase.exhausted => kWarningColor,
          VoucherPhase.expired || VoucherPhase.inactive => kLightThirdColor,
        };

  PromotionPill.flashSale(FlashSalePhase phase, {super.key})
      : label = phase.label,
        color = switch (phase) {
          FlashSalePhase.running => kSuccessColor,
          FlashSalePhase.stalled => kErrorColor,
          FlashSalePhase.scheduled => kLightPrimaryColor,
          FlashSalePhase.ended || FlashSalePhase.cancelled => kLightThirdColor,
        };

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: XText.bodySPrimary.copyWith(color: color),
      ),
    );
  }
}
