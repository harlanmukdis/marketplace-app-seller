import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../core/domain/model/performance/store_insights.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/store_insights_repository.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../di/injector.dart';
import '../cubits/performance_cubit.dart';
import 'performance_view.dart';

/// "Analytics" (S-33). What has data, shown in the design's order: sales for
/// the period, new vs loyal buyers, stock mismatches. Funnel, traffic source,
/// visitors and best products have no server data: they come from
/// [StoreInsightsRepository], which shows sample data marked "Data contoh"
/// under `DEMO_DATA` and "Menunggu API" otherwise.
class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AnalyticsCubit>(
      create: (_) => AnalyticsCubit()..load(),
      child: BlocBuilder<AnalyticsCubit, AnalyticsSnapshot>(
        builder: (context, s) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: XAppBar(
            title: 'Analitik Toko',
            actions: <Widget>[
              XIconAction(
                icon: Icons.verified_outlined,
                tooltip: 'Partners Performance',
                onPressed: () => context.push(SellerRoutes.performance),
              ),
            ],
          ),
          body: s.loading
              ? const LoadingIndicatorView()
              : RefreshIndicator(
                  onRefresh: AnalyticsCubit.get(context).load,
                  child: ListView(
                    padding: const EdgeInsets.all(XSpace.screen),
                    children: <Widget>[
                      _PeriodChips(
                        value: s.period,
                        onChanged: AnalyticsCubit.get(context).setPeriod,
                      ),
                      const SizedBox(height: XSpace.s8),
                      Row(
                        children: <Widget>[
                          Icon(Icons.info_outline,
                              size: 14, color: XColors.textTertiary),
                          const SizedBox(width: XSpace.s6),
                          Expanded(
                            child: Text(
                              'Hanya pesanan Selesai, dibandingkan dengan '
                              'periode sebelumnya.',
                              style: XText.caption,
                            ),
                          ),
                        ],
                      ),
                      if (s.error != null) ...<Widget>[
                        const SizedBox(height: XSpace.s12),
                        XBanner(
                          tone: XTone.danger,
                          message: 'Sebagian pesanan gagal dimuat: '
                              '${s.error!.message}',
                        ),
                      ],
                      const SizedBox(height: XSpace.s12),
                      _SalesCard(snapshot: s),
                      const SizedBox(height: XSpace.cardGap),
                      _CustomersCard(snapshot: s),
                      const SizedBox(height: XSpace.cardGap),
                      _MismatchCard(snapshot: s),
                      const SizedBox(height: XSpace.cardGap),
                      _FunnelCard(
                        key: ValueKey<AnalyticsPeriod>(s.period),
                        days: switch (s.period) {
                          AnalyticsPeriod.today => 1,
                          AnalyticsPeriod.week => 7,
                          AnalyticsPeriod.month => 30,
                        },
                      ),
                      const SizedBox(height: XSpace.cardGap),
                      const _TrafficCard(),
                      const SizedBox(height: XSpace.cardGap),
                      const _TopProductsCard(),
                      const SizedBox(height: XSpace.s24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.value, required this.onChanged});

  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: XSpace.s8,
      children: <Widget>[
        for (final p in AnalyticsPeriod.values)
          ChoiceChip(
            label: Text(p.label),
            selected: p == value,
            showCheckmark: false,
            labelStyle: XText.labelL.copyWith(
              color: p == value ? XColors.textOnBrand : XColors.textPrimary,
            ),
            selectedColor: XColors.primary,
            backgroundColor: XColors.sunken,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            onSelected: (_) => onChanged(p),
          ),
      ],
    );
  }
}

String? _delta(int now, int before) {
  if (before == 0) return now == 0 ? null : 'baru';
  final d = (now - before) / before * 100;
  final s = d.abs().toStringAsFixed(1).replaceAll('.', ',');
  return d >= 0 ? '↑ +$s%' : '↓ −$s%';
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final (now, before) = snapshot.figures();
    final gmvDelta = _delta(now.gmv, before.gmv);
    Color tone(String? d) => d == null
        ? XColors.textTertiary
        : d.startsWith('↓')
            ? XColors.danger
            : XColors.success;

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
              Expanded(
                child: Text('Total Penjualan Kotor (GMV)', style: XText.bodyS),
              ),
              if (gmvDelta != null)
                XChip(
                  label: gmvDelta,
                  tone: gmvDelta.startsWith('↓') ? XTone.danger : XTone.success,
                ),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(formatRupiah(now.gmv), style: XText.headingXL),
          const SizedBox(height: XSpace.s16),
          TileGrid(tiles: <Widget>[
            StatTile(
              label: 'Total Pesanan',
              value: formatThousands(now.orders),
              caption: _delta(now.orders, before.orders),
              captionColor: tone(_delta(now.orders, before.orders)),
            ),
            StatTile(
              label: 'Rata-rata Nilai Pesanan',
              value: formatRupiah(now.averageOrder),
              caption: _delta(now.averageOrder, before.averageOrder),
              captionColor: tone(_delta(now.averageOrder, before.averageOrder)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CustomersCard extends StatelessWidget {
  const _CustomersCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final seg = snapshot.segmentation;
    String share(int part) => seg == null || seg.total == 0
        ? '–'
        : '${(part / seg.total * 100).round()}%';

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
          Text('Pelanggan Baru vs Pembeli Setia', style: XText.titleL),
          const SizedBox(height: XSpace.s16),
          TileGrid(tiles: <Widget>[
            StatTile(
              label: 'Pembeli Baru',
              value: share(seg?.newCustomers ?? 0),
              caption: '${seg?.newCustomers ?? 0} pembeli unik',
            ),
            StatTile(
              label: 'Pembeli Setia',
              value: share(seg?.loyalCustomers ?? 0),
              caption: '${seg?.loyalCustomers ?? 0} pembeli, '
                  '≥ ${seg?.loyalMinOrders ?? 2} pesanan',
            ),
          ]),
          if (seg == null) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text('Data pelanggan gagal dimuat.', style: XText.caption),
          ],
        ],
      ),
    );
  }
}

class _MismatchCard extends StatelessWidget {
  const _MismatchCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.mismatches;
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
          Text('Checkout Gagal karena Stok', style: XText.titleL),
          const SizedBox(height: XSpace.s4),
          Text(
            'Pembeli melihat stok tersedia, tapi saat checkout stoknya kurang. '
            'Sinkronkan stok gudang untuk menghindarinya.',
            style: XText.bodyS,
          ),
          const SizedBox(height: XSpace.s12),
          if (rows.isEmpty)
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, color: XColors.success),
                const SizedBox(width: XSpace.s8),
                Text('Tidak ada kejadian.', style: XText.bodyM),
              ],
            )
          else
            for (final e in rows.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: XSpace.s8),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.remove_shopping_cart_outlined,
                        size: 20, color: XColors.warningStrong),
                    const SizedBox(width: XSpace.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.productName, style: XText.titleM),
                          Text(
                            'Diminta ${e.requested}, tersedia ${e.available}'
                            ' · ${e.warehouseName ?? 'tidak ada di gudang mana pun'}',
                            style: XText.bodyS,
                          ),
                        ],
                      ),
                    ),
                    Text(formatDate(e.createdAt), style: XText.caption),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

int get _storeId => injector<AuthRepository>().activeStoreId ?? 0;

String _pct(double v) =>
    '${v.toStringAsFixed(v < 10 ? 2 : 1)}%'.replaceAll('.', ',');

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionHeader(
          title: 'Funnel Konversi Penjualan',
          subtitle: 'Dari kunjungan hingga checkout selesai',
        ),
        PendingBuilder<ConversionFunnel>(
          compact: true,
          load: () => injector<StoreInsightsRepository>()
              .getFunnel(_storeId, days: days),
          builder: (context, f, _) => XCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Kpi(
                        label: 'Pengunjung Unik Toko',
                        value: formatThousands(f.visitors),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    Expanded(
                      child: _Kpi(
                        label: 'Tingkat Konversi Toko',
                        value: _pct(f.conversion),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                for (var i = 0; i < f.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: XSpace.s8),
                    child: _FunnelBar(
                      index: i + 1,
                      step: f.steps[i],
                      percent: f.percentOf(f.steps[i]),
                    ),
                  ),
                if (f.bestCategory != null)
                  Text.rich(
                    TextSpan(
                      style: XText.bodyS,
                      children: <InlineSpan>[
                        const TextSpan(text: 'Konversi tertinggi: '),
                        TextSpan(
                          text: 'Kategori ${f.bestCategory}',
                          style: XText.labelM,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.sunken,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: XText.caption),
          Text(value, style: XText.stat),
        ],
      ),
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.index,
    required this.step,
    required this.percent,
  });

  final int index;
  final FunnelStep step;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('$index. ${step.label}', style: XText.bodyM)),
            Text(formatThousands(step.count), style: XText.titleM),
            Text('  (${_pct(percent)})', style: XText.caption),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(XRadius.full),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.02, 1.0),
            minHeight: 8,
            backgroundColor: XColors.sunken,
            valueColor: AlwaysStoppedAnimation<Color>(
              Color.lerp(XColors.primary, XColors.success, index / 5)!,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DemoSectionHeader(
          title: 'Sumber Trafik Pembeli',
          trailing: Text('30 Hari', style: XText.labelM),
        ),
        PendingBuilder<List<TrafficSource>>(
          compact: true,
          load: () =>
              injector<StoreInsightsRepository>().getTrafficSources(_storeId),
          builder: (context, sources, _) {
            final colors = <Color>[
              XColors.primary,
              XColors.success,
              XColors.warning,
              XTone.preOrder.foreground,
            ];
            return XCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(XRadius.full),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: <Widget>[
                          for (var i = 0; i < sources.length; i++)
                            Expanded(
                              flex: sources[i].percent.round(),
                              child:
                                  Container(color: colors[i % colors.length]),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: XSpace.s12),
                  for (var i = 0; i < sources.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.circle,
                              size: 10, color: colors[i % colors.length]),
                          const SizedBox(width: XSpace.s8),
                          Expanded(
                            child: Text(sources[i].label, style: XText.bodyM),
                          ),
                          Text('${sources[i].percent.round()}%',
                              style: XText.titleM),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionHeader(title: 'Produk Terbaik Berdasarkan Omzet'),
        PendingBuilder<List<TopProduct>>(
          compact: true,
          load: () =>
              injector<StoreInsightsRepository>().getTopProducts(_storeId),
          builder: (context, products, _) {
            final total = products.fold<int>(0, (n, p) => n + p.revenue);
            return XCard(
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < products.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: XColors.sunken,
                              borderRadius: BorderRadius.circular(XRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: Text('#${i + 1}',
                                style: XText.titleM
                                    .copyWith(color: XColors.primary)),
                          ),
                          const SizedBox(width: XSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(products[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: XText.titleM),
                                Text(
                                  '${formatThousands(products[i].unitsSold)} '
                                  'unit terjual',
                                  style: XText.bodyS,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(formatRupiah(products[i].revenue),
                                  style: XText.priceS),
                              Text(
                                '${_pct(total == 0 ? 0 : products[i].revenue * 100 / total)} '
                                'omzet',
                                style: XText.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
