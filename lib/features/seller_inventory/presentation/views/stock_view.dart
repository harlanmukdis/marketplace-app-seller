import 'package:flutter/material.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/inventory/stock_movement.dart';
import '../../../../core/domain/model/inventory/warehouse_stock.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/stock_cubit/stock_cubit.dart';
import 'widgets/stock_movement_sheet.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// One warehouse's stock, with the ledger behind it.
class StockView extends StatelessWidget {
  const StockView({super.key, required this.warehouseId});

  final int warehouseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StockCubit>(
      create: (_) => StockCubit(warehouseId)..load(),
      child: const _StockBody(),
    );
  }
}

class _StockBody extends StatelessWidget {
  const _StockBody();

  Future<void> _record(
    BuildContext context,
    StockAction action, {
    WarehouseStock? stock,
  }) async {
    final cubit = StockCubit.get(context);
    final draft =
        await showStockMovementSheet(context, action: action, stock: stock);
    if (draft == null || !context.mounted) return;

    final error = switch (action) {
      StockAction.stockIn => await cubit.stockIn(
          productVariantId: draft.productVariantId,
          quantity: draft.quantity,
          notes: draft.notes,
        ),
      StockAction.stockOut => await cubit.stockOut(
          productVariantId: draft.productVariantId,
          quantity: draft.quantity,
          notes: draft.notes,
        ),
      StockAction.adjustment => await cubit.adjust(
          productVariantId: draft.productVariantId,
          quantityDelta: draft.quantity,
          reason: draft.notes ?? 'Penyesuaian stok',
        ),
    };

    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, '${action.title} tercatat.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Stok gudang'),
      body: SafeArea(
        child: BlocBuilder<StockCubit, StockState>(
          builder: (context, state) => switch (state) {
            StockInProgress() => const LoadingIndicatorView(),
            StockFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => StockCubit.get(context).load(),
              ),
            StockLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, StockLoaded state) {
    return Column(
      children: <Widget>[
        _ActionBar(
          isBusy: state.isBusy,
          onAction: (action) => _record(context, action),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => StockCubit.get(context).load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: <Widget>[
                if (state.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: EmptyStateView(
                      icon: Icons.inventory_outlined,
                      message: 'Belum ada stok di gudang ini. Catat stok masuk '
                          'untuk mulai mengisinya.',
                      action: FilledButton(
                        onPressed: state.isBusy
                            ? null
                            : () => _record(context, StockAction.stockIn),
                        child: const Text('Catat stok masuk'),
                      ),
                    ),
                  )
                else ...<Widget>[
                  _Summary(state: state),
                  16.sbh,
                  Text('Stok per varian', style: XText.labelL),
                  8.sbh,
                  for (final stock in state.stocks)
                    _StockRow(
                      stock: stock,
                      onTap: state.isBusy
                          ? null
                          : () => _showRowActions(context, stock),
                    ),
                ],
                if (state.movements.isNotEmpty) ...<Widget>[
                  24.sbh,
                  Text('Riwayat pergerakan', style: XText.labelL),
                  4.sbh,
                  Text(
                    'Setiap perubahan stok tercatat di sini dan tidak pernah '
                    'ditimpa.',
                    style: XText.caption.copyWith(color: XColors.textTertiary),
                  ),
                  8.sbh,
                  for (final movement in state.movements)
                    _MovementRow(movement: movement),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRowActions(BuildContext context, WarehouseStock stock) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final action in StockAction.values)
              ListTile(
                title: Text(action.title),
                subtitle: Text(action.hint),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _record(context, action, stock: stock);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.isBusy, required this.onAction});

  final bool isBusy;
  final ValueChanged<StockAction> onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: <Widget>[
          for (final action in StockAction.values) ...<Widget>[
            OutlinedButton(
              onPressed: isBusy ? null : () => onAction(action),
              child: Text(action.title),
            ),
            8.sbw,
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final StockLoaded state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: XColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          _Metric(label: 'Total fisik', value: '${state.totalOnHand}'),
          _Metric(label: 'Direservasi', value: '${state.totalReserved}'),
          _Metric(label: 'Varian', value: '${state.stocks.length}'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: XText.titleL),
          2.sbh,
          Text(
            label,
            style: XText.caption.copyWith(color: XColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.stock, required this.onTap});

  final WarehouseStock stock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    stock.productName ?? stock.sku ?? '-',
                    style: XText.bodyM,
                  ),
                  2.sbh,
                  Text(
                    <String>[
                      if (stock.sku != null) stock.sku!,
                      if (stock.optionsLabel.isNotEmpty) stock.optionsLabel,
                    ].join(' · '),
                    style: XText.caption.copyWith(color: XColors.textTertiary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${stock.quantityAvailable}',
                  style: XText.titleL.copyWith(
                    color: stock.isOutOfStock
                        ? XColors.danger
                        : (stock.isLow ? XColors.warningStrong : null),
                  ),
                ),
                if (stock.quantityReserved > 0)
                  Text(
                    '${stock.quantityReserved} direservasi',
                    style: XText.caption.copyWith(color: XColors.textTertiary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: <Widget>[
          Text(
            movement.signedQuantity,
            style: XText.titleL.copyWith(
              color: movement.isIncoming ? XColors.success : XColors.danger,
            ),
          ),
          12.sbw,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  StockMovementType.label(movement.type),
                  style: XText.bodyM,
                ),
                if (movement.notes != null)
                  Text(
                    movement.notes!,
                    style: XText.caption.copyWith(color: XColors.textTertiary),
                  ),
              ],
            ),
          ),
          Text(
            formatDateTime(movement.createdAt),
            style: XText.caption.copyWith(color: XColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
