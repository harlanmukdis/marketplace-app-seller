import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import 'promotion_pill.dart';

/// One voucher in the store's list (S-31 campaign card).
///
/// Not tappable: there is nothing to open. A voucher has no detail endpoint and
/// cannot be edited, so the card shows everything there is to know about it.
class VoucherCard extends StatelessWidget {
  const VoucherCard({super.key, required this.voucher, required this.phase});

  final StoreVoucher voucher;
  final VoucherPhase phase;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final detail = <String>[
      VoucherDiscountType.label(v.discountType),
      if (v.discountType == VoucherDiscountType.percentage &&
          v.maxDiscount != null)
        'maks. ${formatRupiah(v.maxDiscount)}',
      if (v.minSpend > 0) 'min. belanja ${formatRupiah(v.minSpend)}',
    ].join(' · ');

    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              PromotionPill.voucher(phase),
              const Spacer(),
              Text(
                '${formatDate(v.validFrom)} – ${formatDate(v.validUntil)}',
                style: XText.caption,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(v.name, style: XText.titleL),
          Text(detail, style: XText.bodyS),
          const SizedBox(height: XSpace.s12),
          PromoStatStrip(
            stats: <(String, String, bool)>[
              ('Kode', v.code, false),
              ('Terpakai', '${v.usedCount} / ${v.quota}', false),
              ('Potongan', v.discountSummary, true),
            ],
          ),
        ],
      ),
    );
  }
}

/// The sunken three-column strip under a campaign card: label over value,
/// the last one in brand colour when [highlight] is set.
class PromoStatStrip extends StatelessWidget {
  const PromoStatStrip({super.key, required this.stats});

  /// (label, value, highlight).
  final List<(String, String, bool)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XSpace.s12,
        vertical: XSpace.s8,
      ),
      decoration: BoxDecoration(
        color: XColors.sunken,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        children: <Widget>[
          for (final (label, value, highlight) in stats)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: XText.caption),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XText.titleM.copyWith(
                      color: highlight ? XColors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
