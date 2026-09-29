import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../seller_home/presentation/views/widgets/section_card.dart';
import 'promotion_pill.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// One flash sale in the store's list. Tappable, because a sale does have
/// contents to open — unlike a voucher.
class FlashSaleCard extends StatelessWidget {
  const FlashSaleCard({
    super.key,
    required this.sale,
    required this.phase,
    required this.onTap,
  });

  final FlashSale sale;
  final FlashSalePhase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(sale.name, style: XText.labelL),
              ),
              8.sbw,
              PromotionPill.flashSale(phase),
              4.sbw,
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          8.sbh,
          Text(
            '${formatDateTime(sale.startAt)} – ${formatDateTime(sale.endAt)}',
            style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
          ),
          if (phase == FlashSalePhase.stalled) ...<Widget>[
            10.sbh,
            _StalledNotice(sale: sale),
          ],
          if (sale.hasImpossibleWindow) ...<Widget>[
            10.sbh,
            const _ImpossibleWindowNotice(),
          ],
        ],
      ),
    );
  }
}

/// The window is open but the sale never went `active`, so buyers see the
/// ordinary price.
///
/// The status is set once at creation and moved afterwards only by a
/// five-minute cron worker. A sale scheduled for later therefore depends
/// entirely on that worker running — and no endpoint exists to force it, so the
/// only reliable remedy is to create a replacement sale whose window is already
/// open, which is born `active`.
class _StalledNotice extends StatelessWidget {
  const _StalledNotice({required this.sale});

  final FlashSale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 12.pa,
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 16, color: kErrorColor),
          8.sbw,
          Expanded(
            child: Text(
              'Waktunya sudah masuk, tapi statusnya masih '
              '"${sale.status}" — jadi pembeli belum melihat harga flash sale '
              'ini. Status dipindahkan oleh proses terjadwal di server dan '
              'tidak ada tombol untuk memaksanya. Kalau tetap begini, buat '
              'flash sale baru yang waktu mulainya sudah lewat.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A window that ends before it starts. The server stores one without
/// complaint, and the sale can never run.
class _ImpossibleWindowNotice extends StatelessWidget {
  const _ImpossibleWindowNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 12.pa,
      decoration: BoxDecoration(
        color: kWarningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: kWarningColor),
          8.sbw,
          Expanded(
            child: Text(
              'Waktu berakhirnya lebih awal dari waktu mulai, jadi flash sale '
              'ini tidak akan pernah berjalan.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
