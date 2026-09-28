import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/live/live_session.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/live_cubit.dart';
import 'live_list_view.dart';

/// One live session: status, encoder settings, pinned products, vouchers.
///
/// The app does not broadcast video — there is no streaming client here, and
/// the ingest URL the API returns is a placeholder. The seller pushes from an
/// encoder such as OBS using the RTMP URL and stream key shown after start.
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
    final choices = s.storeVouchers.where((v) => !taken.contains(v.id)).toList();
    if (choices.isEmpty) {
      showSuccessSnackBar(context, 'Belum ada voucher toko untuk ditambahkan.');
      return;
    }
    final quotaController = TextEditingController(text: '50');
    int? chosen = choices.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Voucher Live'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<int>(
                initialValue: chosen,
                isExpanded: true,
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
                decoration: const InputDecoration(labelText: 'Kuota selama live'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || chosen == null || !context.mounted) return;
    final quota = int.tryParse(quotaController.text) ?? 0;
    await _run(context, () => cubit.addVoucher(chosen!, quota),
        'Voucher ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveSessionCubit, LiveSessionState>(
      builder: (context, s) {
        final session = s.session;
        final cubit = LiveSessionCubit.get(context);
        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: XAppBar(title: session?.title ?? 'Sesi Live'),
          body: session == null
              ? (s.error != null
                  ? ErrorStateView(error: s.error!, onRetry: cubit.load)
                  : const LoadingIndicatorView())
              : RefreshIndicator(
                  onRefresh: cubit.load,
                  child: ListView(
                    padding: const EdgeInsets.all(XSpace.screen),
                    children: <Widget>[
                      _StatusCard(session: session),
                      const SizedBox(height: XSpace.cardGap),
                      if (session.isLive || s.ingest != null) ...<Widget>[
                        _EncoderCard(session: session, ingest: s.ingest),
                        const SizedBox(height: XSpace.cardGap),
                      ],
                      _ProductsCard(
                        state: s,
                        onAdd: session.isOver
                            ? null
                            : () => _addProduct(context, s),
                        onPin: (id) =>
                            _run(context, () => cubit.pin(id), 'Produk di-pin.'),
                      ),
                      const SizedBox(height: XSpace.cardGap),
                      _VouchersCard(
                        vouchers: s.vouchers,
                        onAdd: session.isOver
                            ? null
                            : () => _addVoucher(context, s),
                      ),
                      const SizedBox(height: XSpace.s24),
                    ],
                  ),
                ),
          bottomNavigationBar: session == null || session.isOver
              ? null
              : Material(
                  color: XColors.surface,
                  elevation: 8,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(XSpace.screen),
                      child: session.canStart
                          ? XButton(
                              label: 'Mulai Live',
                              icon: Icons.sensors_rounded,
                              size: XButtonSize.large,
                              expand: true,
                              loading: s.busy,
                              onPressed: () => _run(
                                  context, cubit.start, 'Sesi live dimulai.'),
                            )
                          : XButton.danger(
                              label: 'Akhiri Live',
                              icon: Icons.stop_circle_outlined,
                              size: XButtonSize.large,
                              expand: true,
                              loading: s.busy,
                              onPressed: () => _run(
                                  context, cubit.end, 'Sesi live diakhiri.'),
                            ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final d = session.duration;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Status Sesi', style: XText.titleL)),
              XChip(
                label: LiveStatus.label(session.status),
                tone: liveTone(session.status),
                icon: session.isLive ? Icons.circle : null,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XKeyValue(
            label: 'Jadwal',
            value: session.scheduledAt == null
                ? '-'
                : formatDateTime(session.scheduledAt),
          ),
          XKeyValue(label: 'Mulai', value: formatDateTime(session.startedAt)),
          if (session.endedAt != null)
            XKeyValue(label: 'Selesai', value: formatDateTime(session.endedAt)),
          if (d != null)
            XKeyValue(
              label: 'Durasi',
              value: '${d.inHours} jam ${d.inMinutes % 60} mnt',
            ),
          XKeyValue(
            label: 'Penonton',
            value: '${session.viewerCount} · puncak ${session.peakViewerCount}',
          ),
        ],
      ),
    );
  }
}

class _EncoderCard extends StatelessWidget {
  const _EncoderCard({required this.session, required this.ingest});

  final LiveSession session;
  final LiveIngest? ingest;

  Widget _copyRow(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: XSpace.s8),
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: XColors.canvas,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Pengaturan Encoder (OBS)', style: XText.titleL),
          const SizedBox(height: XSpace.s4),
          Text(
            'Jangan bagikan stream key. Siapa pun yang memilikinya bisa '
            'menyiarkan atas nama toko Anda.',
            style: XText.bodyS,
          ),
          const SizedBox(height: XSpace.s12),
          _copyRow(context, 'RTMP URL', rtmp),
          _copyRow(context, 'STREAM KEY', key),
        ],
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
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
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Produk Live', style: XText.titleL)),
              if (onAdd != null)
                XButton.ghost(
                  label: 'Tambah',
                  icon: Icons.add_circle_outline,
                  size: XButtonSize.small,
                  onPressed: onAdd,
                ),
            ],
          ),
          Text(
            session.isLive
                ? 'Pin satu produk untuk ditampilkan ke penonton.'
                : 'Produk bisa di-pin saat sesi sedang live.',
            style: XText.bodyS,
          ),
          const SizedBox(height: XSpace.s12),
          if (session.products.isEmpty)
            Text('Belum ada produk.', style: XText.bodyS)
          else
            for (final lp in session.products)
              Padding(
                padding: const EdgeInsets.only(bottom: XSpace.s8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      lp.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.inventory_2_outlined,
                      color:
                          lp.isPinned ? XColors.primary : XColors.textTertiary,
                    ),
                    const SizedBox(width: XSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            state.productOf(lp.productId)?.name ??
                                'Produk #${lp.productId}',
                            style: XText.titleM,
                          ),
                          Text(
                            lp.livePrice == null
                                ? 'Harga normal'
                                : 'Harga live ${formatRupiah(lp.livePrice)}',
                            style: XText.bodyS,
                          ),
                        ],
                      ),
                    ),
                    if (lp.isPinned)
                      const XChip(label: 'Di-pin', tone: XTone.info)
                    else if (session.isLive)
                      XButton.secondary(
                        label: 'Pin',
                        size: XButtonSize.small,
                        onPressed:
                            state.busy ? null : () => onPin(lp.productId),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _VouchersCard extends StatelessWidget {
  const _VouchersCard({required this.vouchers, required this.onAdd});

  final List<LiveVoucher> vouchers;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Voucher Live', style: XText.titleL)),
              if (onAdd != null)
                XButton.ghost(
                  label: 'Tambah',
                  icon: Icons.add_circle_outline,
                  size: XButtonSize.small,
                  onPressed: onAdd,
                ),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          if (vouchers.isEmpty)
            Text('Belum ada voucher.', style: XText.bodyS)
          else
            for (final v in vouchers)
              XKeyValue(label: v.code, value: 'Kuota ${v.quota}'),
        ],
      ),
    );
  }
}

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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(XSpace.screen),
                child: Text('Tambah Produk ke Live', style: XText.headingM),
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
