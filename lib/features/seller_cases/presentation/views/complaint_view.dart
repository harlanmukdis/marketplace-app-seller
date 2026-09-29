import 'package:flutter/material.dart';

import '../../../../core/domain/model/order/order_case.dart';
import '../../../../core/domain/repositories/order_case_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import 'widgets/case_widgets.dart';

/// "Komplain & Retur" (S-19): the buyer's claim with its evidence, and the
/// seller's four possible answers.
class ComplaintView extends StatefulWidget {
  const ComplaintView({super.key, required this.complaintId});

  final int complaintId;

  @override
  State<ComplaintView> createState() => _ComplaintViewState();
}

class _ComplaintViewState extends State<ComplaintView> {
  Key _key = UniqueKey();
  ComplaintResolution _choice = ComplaintResolution.refund;
  bool _busy = false;

  OrderCaseRepository get _repo => injector<OrderCaseRepository>();

  Future<void> _submit(Complaint c) async {
    setState(() => _busy = true);
    final error = await _repo.resolveComplaint(c.id, _choice);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _key = UniqueKey();
    });
    showDemoActionResult(context, error, 'Solusi komplain disimpan');
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: PendingBuilder<Complaint>(
        load: () => _repo.getComplaint(widget.complaintId),
        builder: (context, c, _) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Komplain & Retur'),
          body: ListView(
            padding: const EdgeInsets.all(XSpace.screen),
            children: <Widget>[
              if (c.isPending) ...<Widget>[
                CaseDeadlineBanner(
                  title: 'Batas Respon: 2×24 Jam Kerja',
                  deadline: c.respondBy,
                  message: 'Lewat batas waktu, permohonan disetujui otomatis '
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('NOMOR KOMPLAIN', style: XText.overline),
                              Text(c.number, style: XText.titleL),
                            ],
                          ),
                        ),
                        XChip(
                          label: c.isPending
                              ? 'Perlu Respon Seller'
                              : CaseStatus.label(c.status),
                          tone: c.isPending
                              ? XTone.danger
                              : caseStatusTone(c.status),
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
                          CaseKeyValue(label: 'Tipe Masalah', value: c.issue),
                          CaseKeyValue(
                            label: 'Solusi Diajukan',
                            value: c.requestedSolution,
                            valueStyle:
                                XText.titleM.copyWith(color: XColors.primary),
                          ),
                          CaseKeyValue(
                            label: 'Nominal Komplain',
                            value: formatRupiah(c.amount),
                            valueStyle:
                                XText.priceL.copyWith(color: XColors.brandNavy),
                          ),
                        ],
                      ),
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
                        const Icon(Icons.perm_media_outlined),
                        const SizedBox(width: XSpace.s8),
                        Expanded(
                          child:
                              Text('Bukti dari Pembeli', style: XText.titleL),
                        ),
                        Text('${c.evidence.length} Lampiran',
                            style: XText.caption),
                      ],
                    ),
                    const SizedBox(height: XSpace.s12),
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: c.evidence.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: XSpace.s8),
                        itemBuilder: (context, i) =>
                            _EvidenceTile(evidence: c.evidence[i]),
                      ),
                    ),
                    if (c.buyerNote != null) ...<Widget>[
                      const SizedBox(height: XSpace.s12),
                      Container(
                        padding: const EdgeInsets.all(XSpace.s12),
                        decoration: BoxDecoration(
                          color: XColors.brandSubtle,
                          borderRadius: BorderRadius.circular(XRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(Icons.format_quote,
                                size: 18, color: XColors.primary),
                            const SizedBox(width: XSpace.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('Keluhan Pembeli:',
                                      style: XText.caption),
                                  Text(
                                    '“${c.buyerNote}”',
                                    style: XText.bodyM
                                        .copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                          child: Text('Produk Terkait', style: XText.titleL),
                        ),
                        const XChip(
                            label: 'Paket Terkirim', tone: XTone.success),
                      ],
                    ),
                    const SizedBox(height: XSpace.s8),
                    CaseItemRow(item: c.item),
                    const SizedBox(height: XSpace.s8),
                    Container(
                      padding: const EdgeInsets.all(XSpace.s12),
                      decoration: BoxDecoration(
                        color: XColors.sunken,
                        borderRadius: BorderRadius.circular(XRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          CaseKeyValue(
                            label: 'Pembeli',
                            value: <String>[
                              c.buyerName,
                              if (c.buyerCity != null) '(${c.buyerCity})',
                            ].join(' '),
                          ),
                          if (c.awb != null)
                            CaseKeyValue(
                                label: 'No. Resi Pengiriman', value: c.awb!),
                          if (c.receivedAt != null)
                            Text(
                              'Telah Diterima: '
                              '${formatDateTime(c.receivedAt)}',
                              style: XText.caption,
                            ),
                        ],
                      ),
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
                        Expanded(
                          child: Text('Pilihan Solusi Seller',
                              style: XText.titleL),
                        ),
                        if (c.isPending)
                          Text('Pilih 1 Opsi', style: XText.caption),
                      ],
                    ),
                    const SizedBox(height: XSpace.s8),
                    if (!c.isPending && c.resolution != null)
                      XBanner(
                        tone: XTone.success,
                        icon: Icons.check_circle,
                        title: 'Keputusan:',
                        message: c.resolution!.title,
                      )
                    else
                      RadioGroup<ComplaintResolution>(
                        groupValue: _choice,
                        onChanged: (v) {
                          if (v != null) setState(() => _choice = v);
                        },
                        child: Column(
                          children: <Widget>[
                            for (final r in ComplaintResolution.values)
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: XSpace.s8),
                                decoration: BoxDecoration(
                                  color: _choice == r
                                      ? XColors.brandSubtle
                                      : XColors.sunken,
                                  borderRadius:
                                      BorderRadius.circular(XRadius.md),
                                ),
                                child: RadioListTile<ComplaintResolution>(
                                  value: r,
                                  title: Text(
                                    r.title,
                                    style: XText.titleM.copyWith(
                                      color: r == ComplaintResolution.reject
                                          ? XColors.danger
                                          : null,
                                    ),
                                  ),
                                  subtitle:
                                      Text(r.description, style: XText.bodyS),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
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
                              label: 'Chat',
                              icon: Icons.chat_outlined,
                              size: XButtonSize.large,
                              expand: true,
                              onPressed: () => showSuccessSnackBar(
                                context,
                                'Chat pembeli dibuka dari tab Chat.',
                              ),
                            ),
                          ),
                          const SizedBox(width: XSpace.s12),
                          Expanded(
                            flex: 2,
                            child: _choice == ComplaintResolution.reject
                                ? XButton.danger(
                                    label: 'Tolak Komplain',
                                    size: XButtonSize.large,
                                    expand: true,
                                    loading: _busy,
                                    onPressed: () => _submit(c),
                                  )
                                : XButton(
                                    label: switch (_choice) {
                                      ComplaintResolution.refund =>
                                        'Setujui Retur & Refund',
                                      ComplaintResolution.replacement =>
                                        'Setujui Penggantian',
                                      _ => 'Eskalasi ke Mediasi',
                                    },
                                    icon: Icons.check_circle_outline,
                                    size: XButtonSize.large,
                                    expand: true,
                                    loading: _busy,
                                    onPressed: () => _submit(c),
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

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.evidence});

  final CaseEvidence evidence;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(XRadius.md),
      child: Container(
        width: 136,
        color: XColors.sunken,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Icon(
              evidence.isVideo
                  ? Icons.play_circle_outline
                  : Icons.image_outlined,
              size: 36,
              color: XColors.textTertiary,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  evidence.label,
                  textAlign: TextAlign.center,
                  style: XText.labelS.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
