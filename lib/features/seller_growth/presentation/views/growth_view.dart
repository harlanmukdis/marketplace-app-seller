import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/catalog/product_growth.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/growth_cubit.dart';

/// "Xpedia Growth" (S-32) — extra commission on completed sales, 1–15%.
///
/// Design rule 10: this is commission, never advertising. The UI must not use
/// the words "ads", "iklan", "CPC" or "budget".
///
/// Departures from the design, because of the API: there is no endpoint that
/// reports the Natural Performance score (the server only refuses with
/// `NATURAL_PERFORMANCE_TOO_LOW`), no "aktif terus" duration (every change
/// simply locks for 7×24 hours), and no projection data — the design's
/// simulated table is replaced by the real 7-day report.
class GrowthView extends StatelessWidget {
  const GrowthView({super.key, this.productId});

  final int? productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GrowthCubit>(
      create: (_) => GrowthCubit(initialProductId: productId)..load(),
      child: const _GrowthBody(),
    );
  }
}

class _GrowthBody extends StatefulWidget {
  const _GrowthBody();

  @override
  State<_GrowthBody> createState() => _GrowthBodyState();
}

class _GrowthBodyState extends State<_GrowthBody> {
  /// The slider's value; null until the product loads, then its current one.
  int? _percent;
  int? _forProductId;

  void _sync(Product product) {
    if (_forProductId == product.id) return;
    _forProductId = product.id;
    _percent = product.growthCommissionPercent.round();
  }

  Future<void> _pick(BuildContext context, GrowthLoaded state) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[
            Text('Pilih Produk', style: XText.headingM),
            const SizedBox(height: XSpace.s12),
            for (final p in state.products)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name, style: XText.bodyM),
                subtitle: Text(formatRupiah(p.basePrice), style: XText.bodyS),
                trailing: p.isGrowthActive
                    ? XChip(
                        label:
                            '${p.growthCommissionPercent.toStringAsFixed(0)}%',
                        tone: XTone.info,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(p.id),
              ),
          ],
        ),
      ),
    );
    if (id != null && context.mounted) {
      await GrowthCubit.get(context).select(id);
    }
  }

  Future<void> _save(BuildContext context, int percent) async {
    final cubit = GrowthCubit.get(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(percent == 0 ? 'Nonaktifkan Growth?' : 'Simpan Growth?'),
        content: Text(
          'Setelah disimpan, pengaturan Growth produk ini terkunci 7×24 jam '
          'dan tidak bisa diubah — termasuk untuk dinonaktifkan.',
          style: XText.bodyM,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await cubit.save(percent);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(
      context,
      percent == 0 ? 'Growth dinonaktifkan.' : 'Growth $percent% disimpan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrowthCubit, GrowthState>(
      builder: (context, state) {
        final loaded = state is GrowthLoaded ? state : null;
        final product = loaded?.product;
        if (product != null) _sync(product);
        final locked = product?.isGrowthLockedAt(DateTime.now()) ?? false;
        final current = product?.growthCommissionPercent.round() ?? 0;
        final changed = _percent != null && _percent != current;

        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Xpedia Growth'),
          body: switch (state) {
            GrowthInProgress() => const LoadingIndicatorView(),
            GrowthFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: GrowthCubit.get(context).load,
              ),
            GrowthLoaded() when state.products.isEmpty => const XEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Belum ada produk',
                message: 'Growth diatur per produk.',
              ),
            GrowthLoaded() => ListView(
                padding: const EdgeInsets.all(XSpace.screen),
                children: <Widget>[
                  const _Hero(),
                  const SizedBox(height: XSpace.cardGap),
                  const XBanner(
                    tone: XTone.success,
                    icon: Icons.verified_outlined,
                    title: 'Syarat: skor Natural Performance ≥ 60.',
                    message: 'Skor dihitung dari rating, unit terjual, '
                        'tingkat pesanan sukses, dan ketersediaan stok. Bila '
                        'belum memenuhi, server menolak saat Growth '
                        'diaktifkan.',
                  ),
                  const SizedBox(height: XSpace.sectionGap),
                  Text('PILIH PRODUK', style: XText.overline),
                  const SizedBox(height: XSpace.s8),
                  XCard(
                    onTap: () => _pick(context, state),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: XColors.sunken,
                            borderRadius: BorderRadius.circular(XRadius.md),
                          ),
                          child: Icon(Icons.inventory_2_outlined,
                              color: XColors.textTertiary),
                        ),
                        const SizedBox(width: XSpace.s12),
                        Expanded(
                          child: product == null
                              ? const LinearProgressIndicator()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: XText.titleM,
                                    ),
                                    Text(formatRupiah(product.basePrice),
                                        style: XText.bodyS),
                                  ],
                                ),
                        ),
                        Text('Ganti',
                            style:
                                XText.labelL.copyWith(color: XColors.primary)),
                        Icon(Icons.chevron_right, color: XColors.primary),
                      ],
                    ),
                  ),
                  if (product != null) ...<Widget>[
                    const SizedBox(height: XSpace.cardGap),
                    _SliderCard(
                      value: _percent ?? current,
                      enabled: !locked && !state.isSaving,
                      onChanged: (v) => setState(() => _percent = v),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                    XBanner(
                      tone: XTone.warning,
                      icon: Icons.lock_clock_outlined,
                      title: locked
                          ? 'Terkunci sampai '
                              '${formatDateTime(product.growthLockedUntil)}.'
                          : 'Terkunci 7×24 jam setelah disimpan.',
                      message: 'Menjaga stabilitas algoritma rekomendasi dan '
                          'rotasi katalog. Berlaku juga untuk menonaktifkan.',
                    ),
                    const SizedBox(height: XSpace.cardGap),
                    _Report(performance: state.performance),
                    const SizedBox(height: XSpace.cardGap),
                    const XBanner(
                      tone: XTone.info,
                      icon: Icons.shield_outlined,
                      title: 'Perlindungan Penjual.',
                      message: 'Pesanan yang dibatalkan atau diretur tidak '
                          'dikenai komisi Growth sepeser pun.',
                    ),
                  ],
                  const SizedBox(height: XSpace.s24),
                ],
              ),
          },
          bottomNavigationBar: product == null
              ? null
              : Material(
                  color: XColors.surface,
                  elevation: 8,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        XSpace.screen,
                        XSpace.s12,
                        XSpace.screen,
                        XSpace.s4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          XButton(
                            label: 'Simpan Pengaturan Growth',
                            icon: Icons.check_circle_outline,
                            size: XButtonSize.large,
                            expand: true,
                            loading: loaded?.isSaving ?? false,
                            onPressed: changed && !locked
                                ? () => _save(context, _percent!)
                                : null,
                          ),
                          if (product.isGrowthActive && !locked)
                            TextButton.icon(
                              onPressed: () => _save(context, 0),
                              icon: const Icon(Icons.power_settings_new),
                              label: const Text(
                                  'Nonaktifkan Growth untuk Produk Ini'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(XSpace.s20),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const XChip(
            label: 'MODEL BEBAS RISIKO',
            tone: XTone.info,
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: XSpace.s12),
          Text('Lebih Banyak Dilihat, Lebih Banyak Terjual',
              style: XText.headingL),
          const SizedBox(height: XSpace.s8),
          Text(
            'Xpedia Growth murni berbasis bagi hasil penjualan. Komisi '
            'tambahan hanya dibayar saat produk benar-benar terjual dan '
            'pesanan selesai.',
            style: XText.bodyM.copyWith(color: XColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final boost = GrowthRules.boostPoints(value.toDouble());
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Atur Tambahan Komisi Sukses', style: XText.titleL),
          Text('Mendorong prioritas ranking rekomendasi', style: XText.bodyS),
          const SizedBox(height: XSpace.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                value == 0 ? 'Nonaktif' : '$value%',
                style: XText.headingXL.copyWith(color: XColors.primary),
              ),
              if (value > 0) ...<Widget>[
                const SizedBox(width: XSpace.s6),
                Padding(
                  padding: const EdgeInsets.only(bottom: XSpace.s4),
                  child: Text('tambahan', style: XText.bodyS),
                ),
              ],
              const Spacer(),
              XChip(
                label: '+${boost.toStringAsFixed(1)} poin Growth',
                tone: XTone.info,
                icon: Icons.rocket_launch_outlined,
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            max: GrowthRules.maxPercent.toDouble(),
            divisions: GrowthRules.maxPercent,
            label: '$value%',
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final t in <String>['0%', '5%', '10%', '15%'])
                Text(t, style: XText.caption),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          const XBanner(
            tone: XTone.info,
            message: 'Komisi tambahan dipotong dari hasil penjualan setelah '
                'pesanan Selesai. Komisi Xpedia reguler tetap 5%. Maksimal '
                '+50 poin ranking di 15%.',
          ),
        ],
      ),
    );
  }
}

/// The real 7-day comparison from `/growth/performance`.
class _Report extends StatelessWidget {
  const _Report({required this.performance});

  final GrowthPerformance? performance;

  @override
  Widget build(BuildContext context) {
    final p = performance;
    TableRow row(String label, String a, String b, {bool bold = false}) =>
        TableRow(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: XSpace.s8),
              child: Text(label, style: bold ? XText.titleM : XText.bodyM),
            ),
            Text(a, textAlign: TextAlign.end, style: XText.bodyM),
            Text(b,
                textAlign: TextAlign.end,
                style: (bold ? XText.priceS : XText.bodyM)
                    .copyWith(color: XColors.primary)),
          ],
        );

    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Laporan Performa 7 Hari', style: XText.titleL),
          Text('Hanya pesanan yang sudah Selesai.', style: XText.bodyS),
          const SizedBox(height: XSpace.s12),
          if (p == null)
            Text('Laporan belum bisa dimuat.', style: XText.bodyS)
          else
            Table(
              columnWidths: const <int, TableColumnWidth>{
                0: FlexColumnWidth(1.4),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: <TableRow>[
                TableRow(
                  children: <Widget>[
                    Text('METRIK', style: XText.overline),
                    Text('7 HARI SEBELUMNYA',
                        textAlign: TextAlign.end, style: XText.overline),
                    Text('7 HARI TERAKHIR',
                        textAlign: TextAlign.end,
                        style: XText.overline.copyWith(color: XColors.primary)),
                  ],
                ),
                row('Unit Terjual', '${p.previous.unitsSold}',
                    '${p.current.unitsSold}'),
                row('Omzet', formatRupiah(p.previous.revenue),
                    formatRupiah(p.current.revenue),
                    bold: true),
                row(
                  'Komisi Growth',
                  formatRupiah(p.previous.commissionCharged),
                  formatRupiah(p.current.commissionCharged),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
