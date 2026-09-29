import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/inventory/warehouse.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/warehouse_cubit/warehouse_cubit.dart';
import 'widgets/warehouse_sheet.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// The store's warehouses. Stock hangs off these, so an empty list here is why
/// a catalogue cannot be sold.
class WarehouseListView extends StatelessWidget {
  const WarehouseListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WarehouseCubit>(
      create: (_) => WarehouseCubit()..load(),
      child: const _WarehouseListBody(),
    );
  }
}

class _WarehouseListBody extends StatelessWidget {
  const _WarehouseListBody();

  Future<void> _create(BuildContext context) async {
    final cubit = WarehouseCubit.get(context);
    final draft = await showWarehouseSheet(
      context,
      provinces: cubit.provinces,
      citiesOf: cubit.citiesOf,
    );
    if (draft == null || !context.mounted) return;

    final (error, _) = await cubit.create(
      name: draft.name,
      address: draft.address,
      city: draft.city,
      province: draft.province,
      postalCode: draft.postalCode,
      cityId: draft.cityId,
    );
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Gudang dibuat.');
  }

  Future<void> _edit(BuildContext context, Warehouse warehouse) async {
    final cubit = WarehouseCubit.get(context);
    final draft = await showWarehouseSheet(
      context,
      existing: warehouse,
      provinces: cubit.provinces,
      citiesOf: cubit.citiesOf,
    );
    if (draft == null || !context.mounted) return;

    final error = await cubit.update(
      warehouse.id,
      name: draft.name,
      address: draft.address,
      city: draft.city,
      province: draft.province,
      postalCode: draft.postalCode,
      status: draft.status,
      cityId: draft.cityId,
    );
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Gudang diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Gudang'),
      floatingActionButton: BlocBuilder<WarehouseCubit, WarehouseState>(
        builder: (context, state) => state is WarehouseLoaded
            ? FloatingActionButton.extended(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add),
                label: const Text('Gudang'),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: BlocBuilder<WarehouseCubit, WarehouseState>(
          builder: (context, state) => switch (state) {
            WarehouseInProgress() => const LoadingIndicatorView(),
            WarehouseNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu untuk melihat gudangnya.',
              ),
            WarehouseFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => WarehouseCubit.get(context).load(),
              ),
            WarehouseLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WarehouseLoaded state) {
    if (state.isEmpty) {
      return EmptyStateView(
        icon: Icons.warehouse_outlined,
        message: 'Belum ada gudang. Produk tidak bisa punya stok sampai ada '
            'setidaknya satu.',
        action: FilledButton(
          onPressed: () => _create(context),
          // Deliberately not the same words as the sheet's own submit button:
          // the two would otherwise sit on screen together, one behind the
          // other, saying the same thing.
          child: const Text('Buat gudang pertama'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => WarehouseCubit.get(context).load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: state.warehouses.length,
        separatorBuilder: (_, __) => 12.sbh,
        itemBuilder: (context, index) {
          final warehouse = state.warehouses[index];
          return _WarehouseCard(
            warehouse: warehouse,
            onOpenStock: () =>
                context.push(SellerRoutes.warehouseStockPath(warehouse.id)),
            onEdit: () => _edit(context, warehouse),
          );
        },
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({
    required this.warehouse,
    required this.onOpenStock,
    required this.onEdit,
  });

  final Warehouse warehouse;
  final VoidCallback onOpenStock;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenStock,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: 16.pa,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLightThirdColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    warehouse.name,
                    style: XText.labelL,
                  ),
                ),
                if (warehouse.isDefault)
                  const _Pill(
                    label: 'Utama',
                    color: kLightPrimaryColor,
                  ),
                if (!warehouse.isActive) ...<Widget>[
                  6.sbw,
                  const _Pill(label: 'Nonaktif', color: kLightThirdColor),
                ],
              ],
            ),
            6.sbh,
            Text(
              warehouse.shortAddress.isEmpty ? '-' : warehouse.shortAddress,
              style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
            ),
            8.sbh,
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: onOpenStock,
                  icon: const Icon(Icons.inventory_outlined, size: 18),
                  label: const Text('Stok'),
                ),
                const Spacer(),
                TextButton(onPressed: onEdit, child: const Text('Ubah')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: XText.bodySPrimary.copyWith(color: color),
      ),
    );
  }
}
