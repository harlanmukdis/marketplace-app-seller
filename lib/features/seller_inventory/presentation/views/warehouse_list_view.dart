import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/inventory/warehouse.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/warehouse_cubit/warehouse_cubit.dart';
import 'widgets/warehouse_sheet.dart';

/// "Coverage & Lokasi Gudang" (S-25): the store's warehouses, at most three.
/// Stock hangs off these, so an empty list here is why a catalogue cannot be
/// sold.
///
/// The design's store-wide coverage (exclude cities / Java-Bali only) has no
/// store-level field in the API — coverage is set per product — so that
/// section points to the product form, and "Support Ongkir" points to a
/// free-shipping voucher, which is how the API models a seller subsidy.
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
    return BlocBuilder<WarehouseCubit, WarehouseState>(
      builder: (context, state) => Scaffold(
        backgroundColor: XColors.canvas,
        appBar: const XAppBar(title: 'Lokasi Gudang & Pengiriman'),
        body: switch (state) {
          WarehouseInProgress() => const LoadingIndicatorView(),
          WarehouseNoStore() => const XEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada toko aktif',
              message: 'Pilih toko dulu untuk melihat gudangnya.',
            ),
          WarehouseFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => WarehouseCubit.get(context).load(),
            ),
          WarehouseLoaded() => _content(context, state),
        },
      ),
    );
  }

  Widget _content(BuildContext context, WarehouseLoaded state) {
    final warehouses = <Warehouse>[...state.warehouses]
      ..sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
    final used = warehouses.length;
    final remaining = Warehouse.maxPerStore - used;
    final active = warehouses.where((w) => w.isActive).length;

    return RefreshIndicator(
      onRefresh: () => WarehouseCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warehouse_outlined, color: XColors.primary),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text('Lokasi Gudang', style: XText.headingM),
              ),
              XChip(
                label: '$used/${Warehouse.maxPerStore} Digunakan',
                tone: remaining > 0 ? XTone.success : XTone.warning,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XBanner(
            icon: Icons.verified_outlined,
            message: used == 0
                ? 'Belum ada gudang. Produk tidak bisa punya stok sampai ada '
                    'setidaknya satu.'
                : '$active gudang aktif mendistribusikan pesanan · '
                    'maks ${Warehouse.maxPerStore} lokasi',
          ),
          const SizedBox(height: XSpace.s12),
          for (final w in warehouses) ...<Widget>[
            _WarehouseCard(
              warehouse: w,
              onOpenStock: () =>
                  context.push(SellerRoutes.warehouseStockPath(w.id)),
              onEdit: () => _edit(context, w),
            ),
            const SizedBox(height: XSpace.s12),
          ],
          _AddWarehouse(
            remaining: remaining,
            onTap: remaining > 0 ? () => _create(context) : null,
          ),
          const SizedBox(height: XSpace.s24),
          Row(
            children: <Widget>[
              Icon(Icons.public, color: XColors.primary),
              const SizedBox(width: XSpace.s8),
              Text('Cakupan Pengiriman', style: XText.headingM),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Diatur per produk', style: XText.titleM),
                const SizedBox(height: XSpace.s4),
                Text(
                  'Kota yang dikecualikan atau hanya dilayani ditetapkan di '
                  'setiap produk (Tambah / Ubah Produk → Cakupan Pengiriman). '
                  'Kurir yang ditawarkan diatur di Pilih Kurir Aktif.',
                  style: XText.bodyS,
                ),
                const SizedBox(height: XSpace.s12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: XButton.secondary(
                        label: 'Produk',
                        icon: Icons.inventory_2_outlined,
                        onPressed: () => context.push(SellerRoutes.products),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    Expanded(
                      child: XButton.secondary(
                        label: 'Kurir',
                        icon: Icons.local_shipping_outlined,
                        onPressed: () => context.push(SellerRoutes.couriers),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s24),
          Row(
            children: <Widget>[
              Icon(Icons.local_offer_outlined, color: XColors.primary),
              const SizedBox(width: XSpace.s8),
              Text('Support Ongkir Toko', style: XText.headingM),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XCard(
            onTap: () => context.push(SellerRoutes.promotions),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Subsidi Ongkir lewat Voucher', style: XText.titleM),
                      const SizedBox(height: XSpace.s4),
                      Text(
                        'Buat voucher Gratis Ongkir di Campaign & Promo. '
                        'Potongannya dibagi dengan platform dan dipotong dari '
                        'settlement pesanan.',
                        style: XText.bodyS,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: XColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s24),
        ],
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
    final w = warehouse;
    final address = <String?>[w.address, w.shortAddress, w.postalCode]
        .where((p) => p != null && p.trim().isNotEmpty)
        .join(', ');
    return XCard(
      onTap: onOpenStock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              XChip(
                label: w.isDefault ? 'Gudang Utama' : 'Cabang',
                tone: w.isDefault ? XTone.info : XTone.neutral,
              ),
              const SizedBox(width: XSpace.s8),
              XChip(
                label: WarehouseStatus.label(w.status),
                tone: w.isActive ? XTone.success : XTone.neutral,
              ),
              const Spacer(),
              Icon(
                w.isDefault ? Icons.star_rounded : Icons.domain,
                color:
                    w.isDefault ? XColors.signatureGold : XColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(w.name, style: XText.titleL),
          const SizedBox(height: XSpace.s8),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.sunken,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.location_on_outlined,
                    size: 18, color: XColors.textTertiary),
                const SizedBox(width: XSpace.s8),
                Expanded(
                  child: Text(
                    address.isEmpty ? 'Alamat belum diisi' : address,
                    style: XText.bodyS.copyWith(color: XColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: _SoftAction(
                  label: 'Atur Stok',
                  icon: Icons.inventory_2_outlined,
                  onTap: onOpenStock,
                ),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: _SoftAction(
                  label: 'Ubah Alamat',
                  icon: Icons.edit_location_alt_outlined,
                  onTap: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XColors.brandSubtle,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: SizedBox(
          height: XSize.controlMedium,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: XColors.textPrimary),
              const SizedBox(width: XSpace.s8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: XText.labelM,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed "+ Tambah Lokasi Gudang Baru" tile, with the quota left.
class _AddWarehouse extends StatelessWidget {
  const _AddWarehouse({required this.remaining, required this.onTap});

  final int remaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? XColors.brandSubtle : XColors.sunken,
      borderRadius: BorderRadius.circular(XRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: Container(
          padding: const EdgeInsets.all(XSpace.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XRadius.md),
            border: Border.all(
              color: enabled
                  ? XColors.primary.withValues(alpha: 0.35)
                  : XColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    enabled ? XColors.primary : XColors.borderDefault,
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: XSpace.s12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      remaining == Warehouse.maxPerStore
                          ? 'Buat Gudang Pertama'
                          : '+ Tambah Lokasi Gudang Baru',
                      style: XText.titleM.copyWith(
                        color: enabled ? XColors.primary : XColors.textTertiary,
                      ),
                    ),
                    Text(
                      enabled
                          ? 'Sisa kuota: $remaining lokasi'
                          : 'Kuota ${Warehouse.maxPerStore} lokasi sudah '
                              'terpakai',
                      style: XText.bodyS,
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
