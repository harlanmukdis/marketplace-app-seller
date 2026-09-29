import 'package:flutter/material.dart';

import '../../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import 'promotion_pill.dart';
import 'voucher_card.dart';

/// One flash sale in the store's list (S-31 campaign card). Tappable, because
/// a sale does have contents to open — unlike a voucher.
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
    return XCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              PromotionPill.flashSale(phase),
              const Spacer(),
              const Icon(Icons.bolt, size: 16, color: XColors.warning),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(sale.name, style: XText.titleL),
          const SizedBox(height: XSpace.s12),
          PromoStatStrip(
            stats: <(String, String, bool)>[
              ('Mulai', formatDateTime(sale.startAt), false),
              ('Berakhir', formatDateTime(sale.endAt), false),
            ],
          ),
          if (phase == FlashSalePhase.stalled) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            _StalledNotice(sale: sale),
          ],
          if (sale.hasImpossibleWindow) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            const _ImpossibleWindowNotice(),
          ],
          const SizedBox(height: XSpace.s8),
          Align(
            alignment: Alignment.centerRight,
            child: XButton.secondary(
              label: 'Produk & Harga',
              icon: Icons.chevron_right,
              size: XButtonSize.small,
              onPressed: onTap,
            ),
          ),
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
    return XBanner(
      tone: XTone.danger,
      icon: Icons.warning_amber_rounded,
      message: 'Waktunya sudah masuk, tapi statusnya masih '
          '"${sale.status}" — jadi pembeli belum melihat harga flash sale '
          'ini. Status dipindahkan oleh proses terjadwal di server dan '
          'tidak ada tombol untuk memaksanya. Kalau tetap begini, buat '
          'flash sale baru yang waktu mulainya sudah lewat.',
    );
  }
}

/// A window that ends before it starts. The server stores one without
/// complaint, and the sale can never run.
class _ImpossibleWindowNotice extends StatelessWidget {
  const _ImpossibleWindowNotice();

  @override
  Widget build(BuildContext context) {
    return const XBanner(
      tone: XTone.warning,
      icon: Icons.error_outline,
      message: 'Waktu berakhirnya lebih awal dari waktu mulai, jadi flash sale '
          'ini tidak akan pernah berjalan.',
    );
  }
}
