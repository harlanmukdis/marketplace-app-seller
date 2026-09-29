import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/live/live_session.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/live_cubit.dart';
import 'live_list_view.dart';

/// "Live Selling Toko" (S-36): monitor, pinned product, live product list,
/// comments, next session.
///
/// The app does not broadcast video — there is no streaming client here, and
/// the ingest URL the API returns is a placeholder. The seller pushes from an
/// encoder such as OBS using the RTMP URL and stream key shown after start.
///
/// Parts of the design have nothing behind them yet and are drawn as empty:
/// orders and gross sales per session, the live comment feed, and the
/// remaining live quota of a pinned product.
class LiveSessionView extends StatelessWidget {
  const LiveSessionView({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LiveSessionCubit>(
      create: (_) => LiveSessionCubit(sessionId)..load(),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  Future<void> _run(
    BuildContext context,
    Future<dynamic> Function() action,
    String ok,
  ) async {
    final error = await action();
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, ok)
        : showErrorSnackBar(context, error);
  }

  Future<void> _addProduct(BuildContext context, LiveSessionState s) async {
    final cubit = LiveSessionCubit.get(context);
    final taken = s.session!.products.map((p) => p.productId).toSet();
    final choices =
        s.products.where((p) => !taken.contains(p.id)).toList(growable: false);
    final picked = await showModalBottomSheet<(int, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _ProductPicker(choices: choices),
    );
    if (picked == null || !context.mounted) return;
    await _run(context, () => cubit.addProduct(picked.$1, picked.$2),
        'Produk ditambahkan.');
  }

  Future<void> _addVoucher(BuildContext context, LiveSessionState s) async {
    final cubit = LiveSessionCubit.get(context);
    final taken = s.vouchers.map((v) => v.voucherId).toSet();
    final choices =
        s.storeVouchers.where((v) => !taken.contains(v.id)).toList();
    if (choices.isEmpty) {
      showSuccessSnackBar(context, 'Belum ada voucher toko untuk dikirim.');
      return;
    }
    final quotaController = TextEditingController(text: '50');
    int? chosen = choices.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Kirim Voucher ke Live', style: XText.headingM),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<int>(
                initialValue: chosen,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Voucher toko'),
                items: <DropdownMenuItem<int>>[
                  for (final v in choices)
                    DropdownMenuItem<int>(
                      value: v.id,
                      child: Text('${v.code} · ${v.name}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => chosen = v),
              ),
              const SizedBox(height: XSpace.s12),
              TextField(
                controller: quotaController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration:
                    const InputDecoration(labelText: 'Kuota selama live'),
              ),
            ],
          ),
          actions: <Widget>[
            XButton.ghost(
              label: 'Batal',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            XButton(
              label: 'Kirim',
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || chosen == null || !context.mounted) return;
    final quota = int.tryParse(quotaController.text) ?? 0;
    await _run(context, () => cubit.addVoucher(chosen!, quota),
        'Voucher dikirim ke live.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveSessionCubit, LiveSessionState>(
      builder: (context, s) {
        final session = s.session;
        final cubit = LiveSessionCubit.get(context);
        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Live Selling Toko'),
          body: session == null
              ? (s.error != null
                  ? ErrorStateView(error: s.error!, onRetry: cubit.load)
                  : const LoadingIndicatorView())
              : RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: const EdgeInsets.all(XSpace.screen),
                    children: <Widget>[
                      _Monitor(session: session),
                      const SizedBox(height: XSpace.cardGap),
                      _PinnedCard(
                        state: s,
                        onVoucher: session.isOver
                            ? null
                            : () => _addVoucher(context, s),
                      ),
                      if (s.vouchers.isNotEmpty) ...<Widget>[
                        const SizedBox(height: XSpace.s8),
                        _VoucherStrip(vouchers: s.vouchers),
                      ],
                      const SizedBox(height: XSpace.s24),
                      _ProductSection(
                        state: s,
                        onAdd: session.isOver
                            ? null
                            : () => _addProduct(context, s),
                        onPin: (id) => _run(
                            context, () => cubit.pin(id), 'Produk di-pin.'),
                      ),
                      const SizedBox(height: XSpace.s24),
                      _Comments(isLive: session.isLive),
                      if (session.isLive || s.ingest != null) ...<Widget>[
                        const SizedBox(height: XSpace.s24),
                        _EncoderCard(session: session, ingest: s.ingest),
                      ],
                      const SizedBox(height: XSpace.s24),
                      _NextSchedule(
                        next: s.nextSession,
                        current: session,
                      ),
                      const SizedBox(height: XSpace.s24),
                    ],
                  ),
                ),
          bottomNavigationBar: session == null || session.isOver
              ? null
              : _BottomBar(
                  session: session,
                  busy: s.busy,
                  onStart: () =>
                      _run(context, cubit.start, 'Sesi live dimulai.'),
                  onEnd: () => _confirmEnd(context, cubit),
                ),
        );
      },
    );
  }

  Future<void> _confirmEnd(BuildContext context, LiveSessionCubit cubit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Akhiri live?', style: XText.headingM),
        content: Text(
          'Penonton tidak bisa lagi melihat produk yang di-pin. Sesi yang '
          'sudah diakhiri tidak bisa dilanjutkan.',
          style: XText.bodyM,
        ),
        actions: <Widget>[
          XButton.ghost(
            label: 'Batal',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          XButton.danger(
            label: 'Akhiri Live',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, cubit.end, 'Sesi live diakhiri.');
  }
}

// ── Monitor ────────────────────────────────────────────────────────────────

/// The dark studio panel. There is no video in the app, so the frame shows
/// where the broadcast comes from instead of a picture.
class _Monitor extends StatefulWidget {
  const _Monitor({required this.session});

  final LiveSession session;

  @override
  State<_Monitor> createState() => _MonitorState();
}

class _MonitorState extends State<_Monitor> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _Monitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (widget.session.isLive) {
      _tick ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final d = s.duration;
    const white70 = Color(0xB3FFFFFF);

    final (IconData icon, String headline, String sub) = s.isLive
        ? (
            Icons.sensors_rounded,
            'Siaran berjalan dari encoder',
            'Video tampil di aplikasi pembeli',
          )
        : s.isOver
            ? (
                Icons.videocam_off_outlined,
                'Sesi telah selesai',
                d == null ? '' : 'Durasi ${_clock(d)}',
              )
            : (
                Icons.videocam_outlined,
                s.title,
                s.scheduledAt == null
                    ? 'Belum dijadwalkan'
                    : 'Dijadwalkan ${formatDateTime(s.scheduledAt)}',
              );

    return ClipRRect(
      borderRadius: BorderRadius.circular(XRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: XColors.signatureBlack,
          child: Stack(
            children: <Widget>[
              // Frame body.
              Positioned.fill(
                bottom: 56,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      XSpace.s16, XSpace.s32, XSpace.s16, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(icon, color: white70, size: 32),
                      const SizedBox(height: XSpace.s8),
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: XText.titleM.copyWith(color: Colors.white),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          textAlign: TextAlign.center,
                          style: XText.bodyS.copyWith(color: white70),
                        ),
                    ],
                  ),
                ),
              ),
              // Top-left: LIVE + running clock, or the status.
              Positioned(
                top: XSpace.s12,
                left: XSpace.s12,
                child: Row(
                  children: <Widget>[
                    _Pill(
                      color: s.isLive
                          ? XColors.danger
                          : Colors.white.withValues(alpha: 0.16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (s.isLive) ...<Widget>[
                            const Icon(Icons.circle,
                                size: 8, color: Colors.white),
                            const SizedBox(width: XSpace.s4),
                          ],
                          Text(
                            s.isLive
                                ? 'LIVE'
                                : LiveStatus.label(s.status).toUpperCase(),
                            style: XText.labelS.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.isLive && d != null) ...<Widget>[
                      const SizedBox(width: XSpace.s8),
                      Text(
                        _clock(d),
                        style: XText.labelM.copyWith(
                          color: Colors.white,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Top-right: where the picture comes from.
              Positioned(
                top: XSpace.s12,
                right: XSpace.s12,
                child: _Pill(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.circle,
                          size: 6,
                          color: s.isLive
                              ? const Color(0xff34D399)
                              : XColors.textPlaceholder),
                      const SizedBox(width: XSpace.s4),
                      Text(
                        s.isLive ? 'RTMP · Encoder' : 'Encoder belum aktif',
                        style: XText.labelS.copyWith(
                          color: s.isLive
                              ? const Color(0xff34D399)
                              : white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom stats strip.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XSpace.s8,
                    vertical: XSpace.s8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x00000000), Color(0xCC000000)],
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _Stat(
                        icon: Icons.visibility_outlined,
                        iconColor: XColors.danger,
                        label: 'Aktif',
                        value: formatThousands(s.viewerCount),
                      ),
                      _Stat(
                        label: 'Puncak',
                        value: formatThousands(s.peakViewerCount),
                      ),
                      const _Stat(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: Color(0xff60A5FA),
                        label: 'Pesanan',
                        value: '—',
                        valueColor: Color(0xff34D399),
                      ),
                      const _Stat(
                        label: 'Penjualan',
                        value: '—',
                        valueColor: XColors.signatureGoldLight,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: XSpace.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(XRadius.xs),
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 2),
              ],
              Text(
                label,
                style: XText.labelS.copyWith(color: const Color(0xB3FFFFFF)),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: XText.titleL.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pinned product ─────────────────────────────────────────────────────────

class _PinnedCard extends StatelessWidget {
  const _PinnedCard({required this.state, required this.onVoucher});

  final LiveSessionState state;
  final VoidCallback? onVoucher;

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    LiveProduct? pinned;
    for (final p in session.products) {
      if (p.isPinned) pinned = p;
    }
    final product = pinned == null ? null : state.productOf(pinned.productId);
    final base = product?.basePrice;
    final live = pinned?.livePrice;
    final discount = base != null && live != null && live < base && base > 0
        ? ((base - live) * 100 / base).round()
        : null;

    return Container(
      padding: const EdgeInsets.all(XSpace.card),
      decoration: BoxDecoration(
        color: XColors.surface,
        borderRadius: BorderRadius.circular(XRadius.md),
        border: Border.all(
          color: pinned == null
              ? XColors.borderSubtle
              : XColors.signatureGoldLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.push_pin,
                  size: 16, color: XColors.signatureGoldDark),
              const SizedBox(width: XSpace.s4),
              Expanded(
                child: Text(
                  'SEDANG DITAMPILKAN DI LIVE',
                  style: XText.overline
                      .copyWith(color: XColors.signatureGoldDark),
                ),
              ),
              if (discount != null)
                XChip(label: 'Harga Live -$discount%', tone: XTone.preOrder),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          if (pinned == null)
            Text(
              session.isLive
                  ? 'Belum ada produk di-pin. Pilih "Pin Layar" di daftar '
                      'produk agar penonton bisa langsung checkout.'
                  : 'Produk bisa di-pin setelah live dimulai.',
              style: XText.bodyS,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _Thumb(size: 64, rank: 1),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product?.name ?? 'Produk #${pinned.productId}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: XText.titleM,
                      ),
                      const SizedBox(height: XSpace.s4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: XSpace.s8,
                        children: <Widget>[
                          Text(
                            formatRupiah(live ?? base ?? 0),
                            style: XText.priceL
                                .copyWith(color: XColors.primary),
                          ),
                          if (discount != null)
                            Text(
                              formatRupiah(base),
                              style: XText.bodyS.copyWith(
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: XSpace.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: XButton.secondary(
                  label: 'Lepas Pin',
                  icon: Icons.cancel_outlined,
                  onPressed: pinned == null
                      ? null
                      : () => showSuccessSnackBar(
                            context,
                            'Pin produk lain untuk menggantinya — API belum '
                            'menyediakan lepas pin.',
                          ),
                ),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: _SoftButton(
                  label: 'Kirim Voucher',
                  icon: Icons.confirmation_number_outlined,
                  onPressed: onVoucher,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Brand-tinted button used once in the design ("Kirim Voucher").
class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = onPressed == null ? XColors.textPlaceholder : XColors.primary;
    return Material(
      color: XColors.brandSubtle,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: SizedBox(
          height: XSize.controlMedium,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: XSpace.s8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XText.labelL.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherStrip extends StatelessWidget {
  const _VoucherStrip({required this.vouchers});

  final List<LiveVoucher> vouchers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: XSpace.s8,
      runSpacing: XSpace.s8,
      children: <Widget>[
        for (final v in vouchers)
          XChip(
            label: '${v.code} · kuota ${v.quota}',
            tone: XTone.info,
            icon: Icons.confirmation_number_outlined,
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.size, this.rank});

  final double size;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: XColors.sunken,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  color: XColors.textTertiary),
            ),
          ),
          if (rank != null)
            Positioned(
              top: 4,
              left: 4,
              child: _Pill(
                color: XColors.signatureBlack,
                child: Text(
                  '#$rank',
                  style: XText.labelS.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Live product list ──────────────────────────────────────────────────────

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.state,
    required this.onAdd,
    required this.onPin,
  });

  final LiveSessionState state;
  final VoidCallback? onAdd;
  final ValueChanged<int> onPin;

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    final items = <LiveProduct>[...session.products]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Daftar Produk Live', style: XText.headingM),
            const SizedBox(width: XSpace.s8),
            XChip(label: '${items.length} SKU'),
            const Spacer(),
            if (onAdd != null)
              XButton.ghost(
                label: 'Tambah SKU',
                icon: Icons.add,
                size: XButtonSize.small,
                onPressed: onAdd,
              ),
          ],
        ),
        const SizedBox(height: XSpace.s8),
        if (items.isEmpty)
          XCard(
            child: Text(
              'Belum ada produk. Tambahkan produk yang akan ditawarkan '
              'selama live.',
              style: XText.bodyS,
            ),
          )
        else
          for (final lp in items) ...<Widget>[
            _ProductRow(
              item: lp,
              product: state.productOf(lp.productId),
              canPin: session.isLive && !state.busy,
              onPin: () => onPin(lp.productId),
            ),
            const SizedBox(height: XSpace.s8),
          ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.product,
    required this.canPin,
    required this.onPin,
  });

  final LiveProduct item;
  final Product? product;
  final bool canPin;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final base = product?.basePrice;
    final live = item.livePrice;
    final stock = product?.stock;
    return XCard(
      padding: const EdgeInsets.all(XSpace.s12),
      child: Row(
        children: <Widget>[
          const _Thumb(size: 56),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product?.name ?? 'Produk #${item.productId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XText.titleM,
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: XSpace.s4,
                  children: <Widget>[
                    Text(formatRupiah(live ?? base ?? 0),
                        style: XText.priceS),
                    if (live != null && base != null && live < base)
                      Text(
                        formatRupiah(base),
                        style: XText.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    style: XText.caption,
                    children: <InlineSpan>[
                      if (stock != null) ...<InlineSpan>[
                        TextSpan(
                          text: 'Stok: $stock',
                          style: stock <= 5
                              ? TextStyle(color: XColors.danger)
                              : null,
                        ),
                        const TextSpan(text: '  •  '),
                      ],
                      TextSpan(
                        text: 'Terjual: ${product?.soldCount ?? 0}',
                        style: TextStyle(color: XColors.success),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: XSpace.s8),
          if (item.isPinned)
            Container(
              height: XSize.controlSmall,
              padding: const EdgeInsets.symmetric(horizontal: XSpace.s12),
              decoration: BoxDecoration(
                color: XColors.primary,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.push_pin,
                      size: 16, color: XColors.textOnBrand),
                  const SizedBox(width: XSpace.s4),
                  Text('Di-pin',
                      style:
                          XText.labelM.copyWith(color: XColors.textOnBrand)),
                ],
              ),
            )
          else
            XButton.secondary(
              label: 'Pin Layar',
              icon: Icons.push_pin_outlined,
              size: XButtonSize.small,
              onPressed: canPin ? onPin : null,
            ),
        ],
      ),
    );
  }
}

// ── Comments ───────────────────────────────────────────────────────────────

/// "Interaksi & Komentar". The API has no live comment feed yet, so the card
/// keeps its place in the layout and says so; the anti-bypass rule applies
/// the moment one exists.
class _Comments extends StatelessWidget {
  const _Comments({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Interaksi & Komentar', style: XText.headingM),
            if (isLive) ...<Widget>[
              const SizedBox(width: XSpace.s8),
              Icon(Icons.circle, size: 8, color: XColors.success),
            ],
          ],
        ),
        const SizedBox(height: XSpace.s8),
        XCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.forum_outlined, color: XColors.textTertiary),
                  const SizedBox(width: XSpace.s12),
                  Expanded(
                    child: Text(
                      'Komentar penonton akan tampil di sini. Pesanan dari '
                      'live tetap masuk ke tab Pesanan.',
                      style: XText.bodyS,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSpace.s12),
              const XBanner(
                tone: XTone.warning,
                icon: Icons.shield_outlined,
                title: 'Anti-Bypass',
                message: 'Dilarang menyebut nomor kontak atau transaksi di '
                    'luar Xpedia.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Encoder ────────────────────────────────────────────────────────────────

class _EncoderCard extends StatelessWidget {
  const _EncoderCard({required this.session, required this.ingest});

  final LiveSession session;
  final LiveIngest? ingest;

  Widget _copyRow(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: XSpace.s8),
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.sunken,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: XText.overline),
                SelectableText(value, style: XText.bodyM),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Salin',
            icon: Icon(Icons.copy_rounded, size: 18, color: XColors.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showSuccessSnackBar(context, '$label disalin.');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtmp = ingest?.rtmpUrl ?? 'rtmp://ingest.marketplace.id/live';
    final key = ingest?.streamKey ?? session.streamKey ?? '-';
    return XCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: XSpace.card),
          childrenPadding:
              const EdgeInsets.fromLTRB(XSpace.card, 0, XSpace.card, XSpace.s8),
          leading: Icon(Icons.settings_input_antenna, color: XColors.primary),
          title: Text('Pengaturan Encoder (OBS)', style: XText.titleM),
          subtitle: Text('RTMP URL & stream key', style: XText.bodyS),
          children: <Widget>[
            Text(
              'Jangan bagikan stream key. Siapa pun yang memilikinya bisa '
              'menyiarkan atas nama toko Anda.',
              style: XText.bodyS,
            ),
            const SizedBox(height: XSpace.s8),
            _copyRow(context, 'RTMP URL', rtmp),
            _copyRow(context, 'STREAM KEY', key),
          ],
        ),
      ),
    );
  }
}

// ── Next session ───────────────────────────────────────────────────────────

class _NextSchedule extends StatelessWidget {
  const _NextSchedule({required this.next, required this.current});

  final LiveSession? next;
  final LiveSession current;

  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} WIB';
  }

  @override
  Widget build(BuildContext context) {
    final n = next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Jadwal Sesi Live Berikutnya', style: XText.headingM),
        const SizedBox(height: XSpace.s8),
        if (n == null || n.scheduledAt == null)
          XCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.event_outlined, color: XColors.textTertiary),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Text(
                    'Belum ada sesi berikutnya. Jadwalkan dari daftar Live '
                    'Selling.',
                    style: XText.bodyS,
                  ),
                ),
              ],
            ),
          )
        else
          XCard(
            onTap: () => context.pushReplacement(
                SellerRoutes.liveSessionPath(n.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    XChip(
                      label: LiveStatus.label(n.status),
                      tone: liveTone(n.status),
                    ),
                    const SizedBox(width: XSpace.s8),
                    Text(formatDate(n.scheduledAt), style: XText.bodyS),
                  ],
                ),
                const SizedBox(height: XSpace.s8),
                Text(n.title, style: XText.titleM),
                const SizedBox(height: XSpace.s4),
                Row(
                  children: <Widget>[
                    Icon(Icons.schedule, size: 16, color: XColors.primary),
                    const SizedBox(width: XSpace.s4),
                    Text(
                      _time(n.scheduledAt!),
                      style: XText.labelM.copyWith(color: XColors.primary),
                    ),
                    const SizedBox(width: XSpace.s16),
                    Icon(Icons.inventory_2_outlined,
                        size: 16, color: XColors.success),
                    const SizedBox(width: XSpace.s4),
                    Text(
                      '${n.products.length} produk',
                      style: XText.labelM.copyWith(color: XColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Bottom bar ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.session,
    required this.busy,
    required this.onStart,
    required this.onEnd,
  });

  final LiveSession session;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    void promo() => context.push(SellerRoutes.promotions);
    return Material(
      color: XColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Row(
            children: <Widget>[
              Expanded(
                child: session.canStart
                    ? XButton.secondary(
                        label: 'Atur Promo Flash',
                        icon: Icons.bolt,
                        size: XButtonSize.large,
                        expand: true,
                        onPressed: promo,
                      )
                    : XButton.danger(
                        label: 'Akhiri Live',
                        icon: Icons.call_end,
                        size: XButtonSize.large,
                        expand: true,
                        loading: busy,
                        onPressed: onEnd,
                      ),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: session.canStart
                    ? XButton(
                        label: 'Mulai Live',
                        icon: Icons.sensors_rounded,
                        size: XButtonSize.large,
                        expand: true,
                        loading: busy,
                        onPressed: onStart,
                      )
                    : XButton(
                        label: 'Atur Promo Flash',
                        icon: Icons.bolt,
                        size: XButtonSize.large,
                        expand: true,
                        onPressed: promo,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add-product sheet ──────────────────────────────────────────────────────

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.choices});

  final List<Product> choices;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  int? _id;
  final TextEditingController _price = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(XSpace.screen),
                child: Text('Tambah SKU ke Live', style: XText.headingM),
              ),
              Expanded(
                child: widget.choices.isEmpty
                    ? const XEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Semua produk sudah ditambahkan',
                      )
                    : RadioGroup<int>(
                        groupValue: _id,
                        onChanged: (v) => setState(() => _id = v),
                        child: ListView(
                          children: <Widget>[
                            for (final p in widget.choices)
                              RadioListTile<int>(
                                value: p.id,
                                title: Text(p.name, style: XText.bodyM),
                                subtitle: Text(formatRupiah(p.basePrice),
                                    style: XText.bodyS),
                              ),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(XSpace.screen),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Harga khusus live (opsional)',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: XSpace.s12),
                    XButton(
                      label: 'Tambah',
                      size: XButtonSize.large,
                      expand: true,
                      onPressed: _id == null
                          ? null
                          : () => Navigator.of(context).pop(
                                (_id!, int.tryParse(_price.text.trim())),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
