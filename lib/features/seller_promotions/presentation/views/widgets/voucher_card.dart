import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../seller_home/presentation/views/widgets/section_card.dart';
import 'promotion_pill.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// One voucher in the store's list.
///
/// Not tappable: there is nothing to open. A voucher has no detail endpoint and
/// cannot be edited, so the card shows everything there is to know about it.
class VoucherCard extends StatelessWidget {
  const VoucherCard({super.key, required this.voucher, required this.phase});

  final StoreVoucher voucher;
  final VoucherPhase phase;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  voucher.name,
                  style: XText.labelL,
                ),
              ),
              8.sbw,
              PromotionPill.voucher(phase),
            ],
          ),
          6.sbh,
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: kBorderColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  voucher.code,
                  style: XText.bodySPrimary,
                ),
              ),
              8.sbw,
              Expanded(
                child: Text(
                  VoucherDiscountType.label(voucher.discountType),
                  style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
                ),
              ),
            ],
          ),
          12.sbh,
          StatRow(label: 'Potongan', value: voucher.discountSummary),
          if (voucher.discountType == VoucherDiscountType.percentage &&
              voucher.maxDiscount != null)
            StatRow(
              label: 'Maksimal potongan',
              value: formatRupiah(voucher.maxDiscount),
            ),
          if (voucher.minSpend > 0)
            StatRow(
              label: 'Minimal belanja',
              value: formatRupiah(voucher.minSpend),
            ),
          StatRow(
            label: 'Kuota',
            value: '${voucher.usedCount} / ${voucher.quota} terpakai',
          ),
          StatRow(
            label: 'Berlaku',
            value: '${formatDate(voucher.validFrom)} – '
                '${formatDate(voucher.validUntil)}',
          ),
        ],
      ),
    );
  }
}
