import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/performance/store_performance.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/performance_cubit.dart';

/// "Partners Performance" (S-35): status score, rating, order, service, live.
///
/// Every figure is lifetime — the endpoint has no period — so the design's
/// month picker is replaced by a plain "sepanjang waktu" note. Trend deltas
/// ("+12,4% vs bln lalu") need a history the API does not keep and are left
/// out rather than invented.
class PerformanceView extends StatelessWidget {
  const PerformanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PerformanceCubit>(
      create: (_) => PerformanceCubit()..load(),
      child: BlocBuilder<PerformanceCubit, PerformanceSnapshot>(
        builder: (context, s) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Partners Performance'),
          body: s.loading
              ? const LoadingIndicatorView()
              : s.performance == null
                  ? ErrorStateView(
                      error: s.error!,
                      onRetry: PerformanceCubit.get(context).load,
                    )
                  : RefreshIndicator(
                      onRefresh: PerformanceCubit.get(context).load,
                      child: ListView(
                        padding: const EdgeInsets.all(XSpace.screen),
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.info_outline,
                                  size: 14, color: XColors.textTertiary),
                              const SizedBox(width: XSpace.s6),
                              Expanded(
                                child: Text(
                                  'Angka dihitung sepanjang waktu toko. '
                                  'Skor & tier diperbarui setiap malam.',
                                  style: XText.caption,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: XSpace.s12),
                          _StatusCard(tier: s.tier, health: s.health),
                          const SizedBox(height: XSpace.cardGap),
                          _RatingCard(rating: s.performance!.rating),
                          const SizedBox(height: XSpace.cardGap),
                          _OrderCard(orders: s.performance!.orders),
                          const SizedBox(height: XSpace.cardGap),
                          _ServiceCard(service: s.performance!.service),
                          const SizedBox(height: XSpace.cardGap),
                          _LiveCard(live: s.performance!.live),
                          const SizedBox(height: XSpace.s24),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.trailing});

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s20),
      decoration: BoxDecoration(
        color: XColors.surface,
        borderRadius: BorderRadius.circular(XRadius.lg),
        border: Border.all(color: XColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: XText.titleL)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: XSpace.s16),
          ...children,
        ],
      ),
    );
  }
}

/// A figure tile, as in the design's 2×2 grids.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.captionColor,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: XText.bodyS),
          const SizedBox(height: XSpace.s4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: XText.stat),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: XSpace.s2),
            Text(
              caption!,
              style: XText.labelS.copyWith(
                color: captionColor ?? XColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two tiles per row.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < tiles.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: XSpace.s8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[i]),
                const SizedBox(width: XSpace.s8),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _pct(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',')}%';

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.tier, required this.health});

  final SellerTier? tier;
  final HealthScore? health;

  @override
  Widget build(BuildContext context) {
    final score = health?.composite;
    final grade = score == null
        ? null
        : score >= 80
            ? ('Sangat Baik', XTone.success)
            : score >= 60
                ? ('Baik', XTone.info)
                : ('Perlu Perbaikan', XTone.warning);
    return Container(
      padding: const EdgeInsets.all(XSpace.s16),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: XColors.primary,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: const Icon(Icons.verified_outlined,
                color: XColors.textOnBrand),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        (tier?.name ?? 'Belum ada tier').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: XText.overline.copyWith(color: XColors.primary),
                      ),
                    ),
                    if (grade != null) ...<Widget>[
                      const SizedBox(width: XSpace.s8),
                      XChip(label: grade.$1, tone: grade.$2),
                    ],
                  ],
                ),
                const SizedBox(height: XSpace.s4),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: score == null ? '–' : score.toStringAsFixed(0),
                        style: XText.headingL,
                      ),
                      TextSpan(text: ' / 100 skor kesehatan', style: XText.bodyS),
                    ],
                  ),
                ),
                if (score == null)
                  Text(
                    'Skor dihitung otomatis setiap malam setelah ada transaksi.',
                    style: XText.caption,
                  )
                else
                  Text(
                    'Diperbarui ${formatDate(health!.date)}',
                    style: XText.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final PerformanceRating rating;

  @override
  Widget build(BuildContext context) {
    final max = rating.distribution.values.fold(0, (a, b) => a > b ? a : b);
    return _Card(
      title: 'Rating Toko & Kepuasan Pelanggan',
      trailing: Tooltip(
        message: 'Dihitung dari ulasan produk yang terbit.',
        child: Icon(Icons.help_outline, size: 18, color: XColors.textTertiary),
      ),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 104,
              padding: const EdgeInsets.all(XSpace.s12),
              decoration: BoxDecoration(
                color: XColors.canvas,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    rating.totalReviews == 0
                        ? '–'
                        : rating.average.toStringAsFixed(1).replaceAll('.', ','),
                    style: XText.headingXL,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= rating.average.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: XColors.warning,
                        ),
                    ],
                  ),
                  Text('${rating.totalReviews} ulasan', style: XText.caption),
                ],
              ),
            ),
            const SizedBox(width: XSpace.s16),
            Expanded(
              child: Column(
                children: <Widget>[
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 12,
                            child: Text('$star', style: XText.labelS),
                          ),
                          const SizedBox(width: XSpace.s6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(XRadius.full),
                              child: LinearProgressIndicator(
                                value: max == 0
                                    ? 0
                                    : rating.countOf(star) / max,
                                minHeight: 6,
                                backgroundColor: XColors.brandSubtle,
                                color: XColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: XSpace.s6),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${rating.countOf(star)}',
                              textAlign: TextAlign.end,
                              style: XText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.orders});

  final OrderPerformance orders;

  @override
  Widget build(BuildContext context) {
    final empty = orders.total == 0;
    final healthy = orders.cancellationRate < 2;
    return _Card(
      title: 'Order Performance',
      children: <Widget>[
        TileGrid(tiles: <Widget>[
          StatTile(
            label: 'Pesanan Selesai',
            value: formatThousands(orders.completed),
          ),
          StatTile(
            label: 'Rasio Pembatalan',
            value: empty ? '–' : _pct(orders.cancellationRate),
            caption: empty ? null : (healthy ? 'Aman (< 2%)' : 'Di atas 2%'),
            captionColor: healthy ? XColors.success : XColors.danger,
          ),
          StatTile(
            label: 'Rasio Pesanan Berhasil',
            value: empty ? '–' : _pct(orders.successRate),
          ),
          StatTile(
            label: 'Total Pesanan',
            value: formatThousands(orders.total),
          ),
        ]),
        if (!empty) ...<Widget>[
          const SizedBox(height: XSpace.s12),
          XBanner(
            tone: healthy ? XTone.success : XTone.warning,
            icon: healthy
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            message: healthy
                ? 'Kinerja pemenuhan pesanan: baik.'
                : 'Rasio pembatalan tinggi memengaruhi tier dan Xpedia Growth.',
          ),
        ],
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ServicePerformance service;

  @override
  Widget build(BuildContext context) {
    final rate = service.responseRate;
    final reply = service.avgReplyMinutes;
    final hours = service.operatingHours;
    return _Card(
      title: 'Service Performance',
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Response Rate Chat', style: XText.bodyM),
            const SizedBox(width: XSpace.s6),
            Text('(Target ≥ 90%)', style: XText.caption),
            const Spacer(),
            Text(rate == null ? '–' : _pct(rate), style: XText.titleM),
          ],
        ),
        const SizedBox(height: XSpace.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(XRadius.full),
          child: LinearProgressIndicator(
            value: rate == null ? 0 : rate / 100,
            minHeight: 8,
            backgroundColor: XColors.sunken,
            color: (rate ?? 0) >= 90 ? XColors.success : XColors.warning,
          ),
        ),
        const SizedBox(height: XSpace.s16),
        XKeyValue(
          label: 'Rata-rata Waktu Balas',
          value: reply == null
              ? 'Belum ada chat'
              : '${reply.toStringAsFixed(1).replaceAll('.', ',')} menit',
          valueStyle: XText.titleM,
        ),
        Text('Target operasional ≤ 5 menit', style: XText.caption),
        const SizedBox(height: XSpace.s12),
        XKeyValue(
          label: 'Jam Operasional',
          value: hours.isEmpty ? 'Belum diatur' : _hours(hours),
          valueStyle: XText.titleM.copyWith(color: XColors.brandNavy),
        ),
      ],
    );
  }

  static String _hours(Map<String, dynamic> h) {
    final open = h['open'] ?? h['start'];
    final close = h['close'] ?? h['end'];
    if (open != null && close != null) return '$open – $close';
    return '${h.length} hari diatur';
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live});

  final LivePerformance live;

  @override
  Widget build(BuildContext context) {
    final hours = live.minutes / 60;
    return _Card(
      title: 'Live Performance',
      trailing: Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: XColors.danger, shape: BoxShape.circle),
      ),
      children: <Widget>[
        TileGrid(tiles: <Widget>[
          StatTile(
            label: 'Total Jam Live',
            value: '${hours.toStringAsFixed(hours < 10 ? 1 : 0).replaceAll('.', ',')} jam',
          ),
          StatTile(label: 'Jumlah Sesi', value: '${live.sessions} sesi'),
          StatTile(
            label: 'Rata-rata Penonton',
            value: live.averageViewers.toStringAsFixed(0),
            caption: 'per sesi',
          ),
          const StatTile(
            label: 'Checkout dari Live',
            value: '–',
            caption: 'Belum dilacak server',
          ),
        ]),
      ],
    );
  }
}
