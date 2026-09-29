import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// The state of a promotion, at a glance.
///
/// Both kinds report a phase worked out from their own dates rather than the
/// `status` column, so the pill is the derived answer rather than what the
/// database happens to hold.
class PromotionPill extends StatelessWidget {
  const PromotionPill({super.key, required this.label, required this.tone});

  PromotionPill.voucher(VoucherPhase phase, {super.key})
      : label = phase == VoucherPhase.running ? 'Sedang Berjalan' : phase.label,
        tone = voucherTone(phase);

  PromotionPill.flashSale(FlashSalePhase phase, {super.key})
      : label =
            phase == FlashSalePhase.running ? 'Sedang Berjalan' : phase.label,
        tone = flashSaleTone(phase);

  final String label;
  final XTone tone;

  static XTone voucherTone(VoucherPhase phase) => switch (phase) {
        VoucherPhase.running => XTone.success,
        VoucherPhase.scheduled => XTone.info,
        VoucherPhase.exhausted => XTone.warning,
        VoucherPhase.expired || VoucherPhase.inactive => XTone.neutral,
      };

  static XTone flashSaleTone(FlashSalePhase phase) => switch (phase) {
        FlashSalePhase.running => XTone.success,
        FlashSalePhase.stalled => XTone.danger,
        FlashSalePhase.scheduled => XTone.info,
        FlashSalePhase.ended || FlashSalePhase.cancelled => XTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return XChip(label: label, tone: tone);
  }
}
