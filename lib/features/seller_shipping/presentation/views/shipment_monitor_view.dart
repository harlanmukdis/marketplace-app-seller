import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/shipping/tracked_shipment.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/shipment_monitor_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// "Monitoring Pengiriman" (S-23): parcels in transit, stuck, or delivered,
/// each with its last courier scan.
class ShipmentMonitorView extends StatelessWidget {
  const ShipmentMonitorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Monitoring Pengiriman'),
      body: PendingBuilder<List<TrackedShipment>>(
        load: () => injector<ShipmentMonitorRepository>()
            .getShipments(injector<AuthRepository>().activeStoreId ?? 0),
        pending: (e) => ListView(
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[ApiPendingCard(message: e.message)],
        ),
        empty: const XEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'Tidak ada paket dalam perjalanan',
        ),
        builder: (context, list, _) => _Monitor(shipments: list),
      ),
    );
  }
}

class _Monitor extends StatefulWidget {
  const _Monitor({required this.shipments});

  final List<TrackedShipment> shipments;

  @override
  State<_Monitor> createState() => _MonitorState();
}

class _MonitorState extends State<_Monitor> {
  String? _state;
  String? _courier;

  @override
  Widget build(BuildContext context) {
    final all = widget.shipments;
    final couriers = all.map((s) => s.courierCompany).toSet().toList();
    int count(String s) => all.where((x) => x.state == s).length;
    final shown = all
        .where((s) => _state == null || s.state == _state)
        .where((s) => _courier == null || s.courierCompany == _courier)
        .toList()
      ..sort((a, b) => _rank(a.state).compareTo(_rank(b.state)));
    final problems = count(ShipmentState.problem);

    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final (value, label, n) in <(String?, String, int)>[
                (null, 'Semua', all.length),
                (
                  ShipmentState.inTransit,
                  'Dalam Perjalanan',
                  count(ShipmentState.inTransit)
                ),
                (ShipmentState.problem, 'Kendala / Tertahan', problems),
                (
                  ShipmentState.delivered,
                  'Tiba di Tujuan',
                  count(ShipmentState.delivered)
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: XSpace.s8),
                  child: ChoiceChip(
                    label: Text('$label ($n)'),
                    selected: _state == value,
                    showCheckmark: false,
                    selectedColor: XColors.primary,
                    backgroundColor: XColors.sunken,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: XText.labelM.copyWith(
                      color: _state == value
                          ? XColors.textOnBrand
                          : XColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _state = value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: XSpace.s8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final c in <String?>[null, ...couriers])
                Padding(
                  padding: const EdgeInsets.only(right: XSpace.s8),
                  child: FilterChip(
                    label: Text(c ?? 'Semua Kurir'),
                    selected: _courier == c,
                    showCheckmark: false,
                    selectedColor: XColors.brandSubtle,
                    labelStyle: XText.labelM.copyWith(
                      color: _courier == c
                          ? XColors.primary
                          : XColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _courier = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: XSpace.s12),
        if (problems > 0) ...<Widget>[
          XBanner(
            tone: XTone.danger,
            icon: Icons.warning_amber_rounded,
            title: '$problems Pengiriman Membutuhkan Perhatian',
            message: 'Pantau pembaruan scan berkala, dan laporkan ke Xpedia '
                '911 bila paket tertahan lebih dari 2×24 jam.',
          ),
          const SizedBox(height: XSpace.s12),
        ],
        const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
        const SizedBox(height: XSpace.s8),
        for (final s in shown) ...<Widget>[
          _ShipmentCard(shipment: s),
          const SizedBox(height: XSpace.s12),
        ],
      ],
    );
  }

  static int _rank(String state) => switch (state) {
        ShipmentState.problem => 0,
        ShipmentState.inTransit => 1,
        _ => 2,
      };
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment});

  final TrackedShipment shipment;

  static String _when(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)} WIB';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) return 'Hari ini, $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin, $time';
    return '${formatDate(t)}, $time';
  }

  void _history(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Riwayat Scan', style: XText.headingM),
              Text('${shipment.courier} • ${shipment.awb}', style: XText.bodyS),
              const SizedBox(height: XSpace.s12),
              for (var i = 0; i < shipment.checkpoints.length; i++)
                _TimelineRow(
                  checkpoint: shipment.checkpoints[i],
                  when: _when(shipment.checkpoints[i].at),
                  first: i == 0,
                  last: i == shipment.checkpoints.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final last = s.last;
    final tone = switch (s.state) {
      ShipmentState.problem => XTone.danger,
      ShipmentState.delivered => XTone.success,
      _ => XTone.info,
    };
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: s.awb));
                    showSuccessSnackBar(context, 'Nomor resi disalin.');
                  },
                  child: Text(
                    '${s.courier} • ${s.awb}',
                    style: XText.labelM,
                  ),
                ),
              ),
              XChip(label: ShipmentState.label(s.state), tone: tone),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(
            '#${s.orderNumber} • Tujuan: ${s.destinationCity ?? '-'}',
            style: XText.titleM,
          ),
          if (s.buyerName != null) Text(s.buyerName!, style: XText.bodyS),
          if (last != null) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Container(
              padding: const EdgeInsets.all(XSpace.s12),
              decoration: BoxDecoration(
                color: tone.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    s.state == ShipmentState.delivered
                        ? Icons.check_circle
                        : s.state == ShipmentState.problem
                            ? Icons.error_outline
                            : Icons.local_shipping_outlined,
                    size: 18,
                    color: tone.foreground,
                  ),
                  const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(last.location, style: XText.titleM),
                            ),
                            Text(_when(last.at), style: XText.caption),
                          ],
                        ),
                        Text(last.description, style: XText.bodyS),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (s.state == ShipmentState.delivered) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text(
              'Menunggu konfirmasi selesai pembeli atau otomatis selesai '
              'dalam 2×24 jam untuk pencairan saldo.',
              style: XText.caption,
            ),
          ],
          const SizedBox(height: XSpace.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (s.state == ShipmentState.problem) ...<Widget>[
                XButton.secondary(
                  label: 'Laporkan (Xpedia 911)',
                  size: XButtonSize.small,
                  onPressed: () => context.push(SellerRoutes.support),
                ),
                const SizedBox(width: XSpace.s8),
              ],
              XButton.ghost(
                label: s.state == ShipmentState.delivered
                    ? 'Detail Penerimaan'
                    : 'Riwayat Scan',
                size: XButtonSize.small,
                onPressed: () => _history(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.checkpoint,
    required this.when,
    required this.first,
    required this.last,
  });

  final ShipmentCheckpoint checkpoint;
  final String when;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: first ? XColors.primary : XColors.borderDefault,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: XColors.borderSubtle),
                  ),
              ],
            ),
          ),
          const SizedBox(width: XSpace.s8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: XSpace.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(checkpoint.location, style: XText.titleM),
                  Text(checkpoint.description, style: XText.bodyS),
                  Text(when, style: XText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
