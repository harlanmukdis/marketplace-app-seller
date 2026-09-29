import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/order/order_case.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/order_case_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import 'widgets/case_widgets.dart';

/// "Komplain & Pembatalan": every open case a buyer has raised, pending
/// first, each with the time left to answer.
class OrderCasesView extends StatefulWidget {
  const OrderCasesView({super.key});

  @override
  State<OrderCasesView> createState() => _OrderCasesViewState();
}

class _OrderCasesViewState extends State<OrderCasesView> {
  int _tab = 0;
  Key _reloadKey = UniqueKey();

  int get _storeId => injector<AuthRepository>().activeStoreId ?? 0;
  OrderCaseRepository get _repo => injector<OrderCaseRepository>();

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) setState(() => _reloadKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Komplain & Pembatalan',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: <Widget>[
              for (final (i, label) in <(int, String)>[
                (0, 'Pembatalan'),
                (1, 'Komplain & Retur'),
              ])
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tab == i
                                ? XColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        label,
                        style: XText.labelL.copyWith(
                          color: _tab == i
                              ? XColors.primary
                              : XColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: KeyedSubtree(
        key: _reloadKey,
        child: ListView(
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[
            const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
            const SizedBox(height: XSpace.s8),
            if (_tab == 0)
              PendingBuilder<List<CancellationRequest>>(
                key: const ValueKey<String>('cancel'),
                compact: true,
                load: () => _repo.getCancellationRequests(_storeId),
                empty: const XCard(
                  child: XEmptyState(
                    icon: Icons.cancel_outlined,
                    title: 'Tidak ada permintaan pembatalan',
                  ),
                ),
                builder: (context, list, _) => Column(
                  children: <Widget>[
                    for (final c in _sorted(list, (c) => c.isPending,
                        (c) => c.respondBy)) ...<Widget>[
                      _CaseCard(
                        title: '#${c.orderNumber}',
                        subtitle: c.reason,
                        status: c.status,
                        deadline: c.isPending ? c.respondBy : null,
                        amount: c.total,
                        onTap: () => _open(SellerRoutes.cancellationPath(c.id)),
                      ),
                      const SizedBox(height: XSpace.s8),
                    ],
                  ],
                ),
              )
            else
              PendingBuilder<List<Complaint>>(
                key: const ValueKey<String>('complaint'),
                compact: true,
                load: () => _repo.getComplaints(_storeId),
                empty: const XCard(
                  child: XEmptyState(
                    icon: Icons.assignment_return_outlined,
                    title: 'Tidak ada komplain',
                  ),
                ),
                builder: (context, list, _) => Column(
                  children: <Widget>[
                    for (final c in _sorted(list, (c) => c.isPending,
                        (c) => c.respondBy)) ...<Widget>[
                      _CaseCard(
                        title: c.number,
                        subtitle: '${c.issue} • ${c.requestedSolution}',
                        status: c.status,
                        deadline: c.isPending ? c.respondBy : null,
                        amount: c.amount,
                        onTap: () => _open(SellerRoutes.complaintPath(c.id)),
                      ),
                      const SizedBox(height: XSpace.s8),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static List<T> _sorted<T>(
    List<T> list,
    bool Function(T) pending,
    DateTime? Function(T) deadline,
  ) =>
      <T>[...list]..sort((a, b) {
          final p = (pending(b) ? 1 : 0).compareTo(pending(a) ? 1 : 0);
          if (p != 0) return p;
          return (deadline(a) ?? DateTime(9999))
              .compareTo(deadline(b) ?? DateTime(9999));
        });
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.deadline,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final DateTime? deadline;
  final int amount;
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
              Expanded(child: Text(title, style: XText.titleM)),
              XChip(
                label: CaseStatus.label(status),
                tone: caseStatusTone(status),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(subtitle, style: XText.bodyS),
          const SizedBox(height: XSpace.s8),
          Row(
            children: <Widget>[
              if (deadline != null)
                XChip(
                  label: remainingLabel(deadline),
                  tone: XTone.danger,
                  icon: Icons.alarm,
                ),
              const Spacer(),
              Text(formatRupiah(amount), style: XText.priceS),
              Icon(Icons.chevron_right, color: XColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }
}
