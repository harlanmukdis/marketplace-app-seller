import 'package:flutter/material.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/order/order_case.dart';
import '../../../../core/domain/repositories/order_case_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import 'widgets/case_widgets.dart';

/// "Permintaan Pembatalan" (S-18): a buyer asks to cancel after the waybill
/// is out. Approve, or refuse with one of three fixed reasons.
class CancellationRequestView extends StatefulWidget {
  const CancellationRequestView({super.key, required this.requestId});

  final int requestId;

  @override
  State<CancellationRequestView> createState() =>
      _CancellationRequestViewState();
}

class _CancellationRequestViewState extends State<CancellationRequestView> {
  Key _key = UniqueKey();
  bool _busy = false;

  OrderCaseRepository get _repo => injector<OrderCaseRepository>();

  Future<void> _approve(CancellationRequest c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Setujui Pembatalan?', style: XText.headingM),
        content: Text(
          'Pesanan #${c.orderNumber}\n\nResi kurir ${c.courier ?? ''} akan '
          'dibatalkan otomatis. Anda tidak perlu mengirimkan pesanan ini dan '
          'stok ${c.items.length} produk dikembalikan ke etalase.',
          style: XText.bodyM,
        ),
        actions: <Widget>[
          XButton.ghost(
            label: 'Kembali',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          XButton(
            label: 'Ya, Setujui',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _decide(() => _repo.respondCancellation(c.id, approve: true),
        'Permintaan pembatalan disetujui');
  }

  Future<void> _reject(CancellationRequest c) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _RejectSheet(),
    );
    if (reason == null) return;
    await _decide(
      () =>
          _repo.respondCancellation(c.id, approve: false, rejectReason: reason),
      'Permintaan pembatalan ditolak',
    );
  }

  Future<void> _decide(Future<DataError?> Function() call, String done) async {
    setState(() => _busy = true);
    final error = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _key = UniqueKey();
    });
    showDemoActionResult(context, error, done);
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: PendingBuilder<CancellationRequest>(
        load: () => _repo.getCancellationRequest(widget.requestId),
        builder: (context, c, _) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Permintaan Pembatalan'),
          body: ListView(
            padding: const EdgeInsets.all(XSpace.screen),
            children: <Widget>[
              if (c.isPending) ...<Widget>[
                CaseDeadlineBanner(
                  title: 'Respon sebelum ${formatDateTime(c.respondBy)}',
                  deadline: c.respondBy,
                  message: 'Jika tidak direspon, pembatalan disetujui otomatis '
                      'oleh sistem demi perlindungan pembeli.',
                ),
                const SizedBox(height: XSpace.cardGap),
              ],
              XCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Detail Pengajuan', style: XText.titleL),
                        ),
                        XChip(
                          label: CaseStatus.label(c.status),
                          tone: caseStatusTone(c.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: XSpace.s4),
                    const DemoBadge(),
                    const SizedBox(height: XSpace.s8),
                    Container(
                      padding: const EdgeInsets.all(XSpace.s12),
                      decoration: BoxDecoration(
                        color: XColors.sunken,
                        borderRadius: BorderRadius.circular(XRadius.md),
                      ),
                      child: Column(
                        children: <Widget>[
                          CaseKeyValue(
                              label: 'Diajukan oleh', value: c.buyerName),
                          CaseKeyValue(
                            label: 'Waktu Pengajuan',
                            value: formatDateTime(c.requestedAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: XSpace.s12),
                    Text('ALASAN PEMBATALAN', style: XText.overline),
                    const SizedBox(height: XSpace.s4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.help_outline,
                            size: 18, color: XColors.primary),
                        const SizedBox(width: XSpace.s8),
                        Expanded(child: Text(c.reason, style: XText.titleM)),
                      ],
                    ),
                    if (c.buyerNote != null) ...<Widget>[
                      const SizedBox(height: XSpace.s12),
                      Container(
                        padding: const EdgeInsets.all(XSpace.s12),
                        decoration: BoxDecoration(
                          color: XColors.brandSubtle,
                          borderRadius: BorderRadius.circular(XRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Catatan dari Pembeli:', style: XText.labelM),
                            const SizedBox(height: XSpace.s4),
                            Text(
                              '“${c.buyerNote}”',
                              style: XText.bodyM
                                  .copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (c.rejectReason != null) ...<Widget>[
                      const SizedBox(height: XSpace.s12),
                      XBanner(
                        tone: XTone.danger,
                        title: 'Alasan penolakan',
                        message: c.rejectReason!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: XSpace.cardGap),
              XCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('ID PESANAN', style: XText.overline),
                              Text(
                                '#${c.orderNumber}',
                                style: XText.headingM
                                    .copyWith(color: XColors.brandNavy),
                              ),
                            ],
                          ),
                        ),
                        if (c.orderStage != null)
                          XChip(label: c.orderStage!, tone: XTone.info),
                      ],
                    ),
                    if (c.awb != null) ...<Widget>[
                      const SizedBox(height: XSpace.s8),
                      Container(
                        padding: const EdgeInsets.all(XSpace.s12),
                        decoration: BoxDecoration(
                          color: XColors.sunken,
                          borderRadius: BorderRadius.circular(XRadius.md),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.local_shipping_outlined,
                                color: XColors.textTertiary),
                            const SizedBox(width: XSpace.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Resi Telah Terbit (${c.courier ?? '-'})',
                                    style: XText.caption,
                                  ),
                                  Text(c.awb!, style: XText.titleM),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: XSpace.s8),
                    for (final item in c.items) CaseItemRow(item: item),
                    const Divider(height: XSpace.s24),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Total Nilai Barang (${c.items.length} Produk)',
                            style: XText.bodyM,
                          ),
                        ),
                        Text(
                          formatRupiah(c.total),
                          style:
                              XText.priceL.copyWith(color: XColors.brandNavy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.cardGap),
              XCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, color: XColors.primary),
                        const SizedBox(width: XSpace.s8),
                        Text('Konsekuensi Keputusan', style: XText.titleL),
                      ],
                    ),
                    const SizedBox(height: XSpace.s12),
                    const XBanner(
                      tone: XTone.success,
                      icon: Icons.check_circle,
                      title: 'Jika Disetujui',
                      message: 'Resi otomatis dibatalkan, dana pembeli '
                          'dikembalikan 100%, dan performa toko TIDAK '
                          'terpotong karena pembatalan atas inisiatif pembeli.',
                    ),
                    const SizedBox(height: XSpace.s8),
                    const XBanner(
                      tone: XTone.danger,
                      icon: Icons.cancel,
                      title: 'Jika Ditolak',
                      message: 'Pesanan tetap berjalan dan wajib diserahkan ke '
                          'kurir sebelum batas SLA handover berakhir untuk '
                          'menghindari penalti keterlambatan.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.verified_user_outlined,
                      size: 14, color: XColors.textTertiary),
                  const SizedBox(width: XSpace.s4),
                  Text('Dilindungi oleh Kebijakan Penjual Xpedia',
                      style: XText.caption),
                ],
              ),
              const SizedBox(height: XSpace.s24),
            ],
          ),
          bottomNavigationBar: c.isPending
              ? Material(
                  color: XColors.surface,
                  elevation: 8,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(XSpace.screen),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: XButton.secondary(
                              label: 'Tolak',
                              icon: Icons.close,
                              size: XButtonSize.large,
                              expand: true,
                              onPressed: _busy ? null : () => _reject(c),
                            ),
                          ),
                          const SizedBox(width: XSpace.s12),
                          Expanded(
                            flex: 2,
                            child: XButton(
                              label: 'Setujui Pembatalan',
                              icon: Icons.check,
                              size: XButtonSize.large,
                              expand: true,
                              loading: _busy,
                              onPressed: () => _approve(c),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(XSpace.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Tolak Permintaan Pembatalan', style: XText.headingM),
            const SizedBox(height: XSpace.s4),
            Text(
              'Pilih alasan penolakan untuk diinformasikan kepada pembeli:',
              style: XText.bodyS,
            ),
            const SizedBox(height: XSpace.s8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: <Widget>[
                  for (final r in CancellationRequest.rejectReasons)
                    RadioListTile<String>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r, style: XText.bodyM),
                    ),
                ],
              ),
            ),
            const SizedBox(height: XSpace.s8),
            Row(
              children: <Widget>[
                Expanded(
                  child: XButton.secondary(
                    label: 'Batal',
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: XButton.danger(
                    label: 'Konfirmasi Tolak',
                    expand: true,
                    onPressed: _reason == null
                        ? null
                        : () => Navigator.of(context).pop(_reason),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
