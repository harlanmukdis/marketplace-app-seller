import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';
import '../cubits/product_list_cubit/product_list_cubit.dart';
import 'widgets/product_card.dart';

/// "Daftar Produk" (S-26) — also the Produk tab of the shell.
class ProductListView extends StatelessWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductListCubit>(
      create: (_) => ProductListCubit()..load(),
      child: const _ProductListBody(),
    );
  }
}

class _ProductListBody extends StatelessWidget {
  const _ProductListBody();

  Future<void> _toggle(BuildContext context, Product product) async {
    final next =
        product.isActive ? ProductStatus.inactive : ProductStatus.active;

    final error =
        await ProductListCubit.get(context).setStatus(product.id, next);
    if (!context.mounted) return;

    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(
      context,
      next == ProductStatus.active
          ? '"${product.name}" sudah tayang.'
          : '"${product.name}" dinonaktifkan.',
    );
  }

  Future<void> _openForm(BuildContext context, {int? productId}) async {
    final cubit = ProductListCubit.get(context);
    await context.push(
      productId == null
          ? SellerRoutes.productCreate
          : SellerRoutes.productEditPath(productId),
    );
    // The form writes through its own cubit, so the list is stale on return —
    // unless this screen was popped while the form was open, in which case the
    // cubit is already closed and emitting into it would throw.
    if (cubit.isClosed) return;
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreCubit>().state;
    final store =
        storeState is StoreLoadSuccess ? storeState.activeStore : null;

    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Produk',
        subtitle: store?.name,
        actions: <Widget>[
          XIconAction(
            icon: Icons.fact_check_outlined,
            tooltip: 'Status Moderasi Produk',
            onPressed: () => context.push(SellerRoutes.productModeration),
          ),
          XIconAction(
            icon: Icons.trending_up_rounded,
            tooltip: 'Xpedia Growth',
            onPressed: () => context.push(SellerRoutes.growth),
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<ProductListCubit, ProductListState>(
        builder: (context, state) => state is ProductListNoStore
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                backgroundColor: XColors.primary,
                foregroundColor: XColors.textOnBrand,
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'),
              ),
      ),
      body: BlocBuilder<ProductListCubit, ProductListState>(
        builder: (context, state) => switch (state) {
          ProductListInProgress() => const LoadingIndicatorView(),
          ProductListNoStore() => XEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada toko yang dipilih',
              actionLabel: 'Pilih toko',
              onAction: () => context.push(SellerRoutes.storePicker),
            ),
          ProductListFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => ProductListCubit.get(context).load(),
            ),
          ProductListSuccess() => _content(context, state, store?.skuQuota),
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    ProductListSuccess state,
    int? skuQuota,
  ) {
    final cubit = ProductListCubit.get(context);
    if (state.isEmpty) {
      return XEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada produk',
        message: 'Produk baru dibuat sebagai draf, lalu ditayangkan.',
        actionLabel: 'Tambah produk',
        onAction: () => _openForm(context),
      );
    }

    final visible = state.visible;

    return Column(
      children: <Widget>[
        _Tabs(state: state),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                XSpace.screen,
                XSpace.s12,
                XSpace.screen,
                96,
              ),
              children: <Widget>[
                if (skuQuota != null) ...<Widget>[
                  _CapacityCard(used: state.products.length, quota: skuQuota),
                  const SizedBox(height: XSpace.cardGap),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        onChanged: cubit.search,
                        style: XText.bodyM,
                        decoration: const InputDecoration(
                          hintText: 'Cari nama produk',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    _ModeFilter(
                      value: state.mode,
                      onChanged: cubit.setMode,
                    ),
                  ],
                ),
                if (state.draftCount > 0 &&
                    state.filter != ProductStatusFilter.draft) ...<Widget>[
                  const SizedBox(height: XSpace.cardGap),
                  XBanner(
                    tone: XTone.warning,
                    message: '${state.draftCount} produk masih draf dan belum '
                        'terlihat pembeli. Tayangkan supaya bisa dijual.',
                  ),
                ],
                const SizedBox(height: XSpace.cardGap),
                if (visible.isEmpty)
                  const XEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Tidak ada produk yang cocok',
                    message: 'Ubah tab, mode stok, atau kata kunci.',
                  )
                else
                  for (final product in visible) ...<Widget>[
                    ProductCard(
                      product: product,
                      onTap: () => _openForm(context, productId: product.id),
                      onToggleStatus: product.status == ProductStatus.archived
                          ? null
                          : () => _toggle(context, product),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                  ],
                Padding(
                  padding: const EdgeInsets.only(top: XSpace.s4),
                  child: Text(
                    'Menampilkan ${visible.length} dari '
                    '${state.products.length} produk',
                    textAlign: TextAlign.center,
                    style: XText.caption,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.state});

  final ProductListSuccess state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: XColors.surface,
        border: Border(bottom: BorderSide(color: XColors.borderSubtle)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: XSpace.s8),
        children: <Widget>[
          for (final f in ProductStatusFilter.values)
            InkWell(
              onTap: () => ProductListCubit.get(context).setFilter(f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: XSpace.s12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: f == state.filter
                          ? XColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      f.label,
                      style: XText.labelL.copyWith(
                        color: f == state.filter
                            ? XColors.primary
                            : XColors.textSecondary,
                        fontWeight: f == state.filter
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: XSpace.s6),
                    Text('${state.countOf(f)}', style: XText.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeFilter extends StatelessWidget {
  const _ModeFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Mode stok',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: '', child: Text('Semua Mode Stok')),
        for (final m in FulfillmentMode.settable)
          PopupMenuItem<String>(value: m, child: Text(StockMode.label(m))),
      ],
      child: Container(
        height: XSize.controlMedium,
        padding: const EdgeInsets.symmetric(horizontal: XSpace.s12),
        decoration: BoxDecoration(
          color: value == null ? XColors.surface : XColors.brandSubtle,
          borderRadius: BorderRadius.circular(XRadius.md),
          border: Border.all(
            color: value == null ? XColors.borderDefault : XColors.primary,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.tune_rounded,
                size: 18,
                color: value == null ? XColors.textPrimary : XColors.primary),
            const SizedBox(width: XSpace.s4),
            Text(
              value == null ? 'Mode' : StockMode.label(value!),
              style: XText.labelM,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Kapasitas Katalog Toko" — only when the store has a quota (500 once a
/// business verification is approved; unlimited, and hidden, otherwise).
/// The count includes drafts and inactive products, as the server's does.
class _CapacityCard extends StatelessWidget {
  const _CapacityCard({required this.used, required this.quota});

  final int used;
  final int quota;

  @override
  Widget build(BuildContext context) {
    final ratio = quota == 0 ? 1.0 : (used / quota).clamp(0.0, 1.0);
    final full = used >= quota;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.inventory_outlined,
                  size: 20, color: XColors.textSecondary),
              const SizedBox(width: XSpace.s8),
              Expanded(
                  child: Text('Kapasitas Katalog Toko', style: XText.titleM)),
              Text('$used / $quota SKU',
                  style: XText.labelM.copyWith(
                    color: full ? XColors.danger : XColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(XRadius.full),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: XColors.sunken,
              color: full ? XColors.danger : XColors.primary,
            ),
          ),
          if (full) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            Text(
              'Kuota penuh — produk baru ditolak. Ajukan tambahan kapasitas '
              'lewat Xpedia 911.',
              style: XText.bodyS.copyWith(color: XColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
