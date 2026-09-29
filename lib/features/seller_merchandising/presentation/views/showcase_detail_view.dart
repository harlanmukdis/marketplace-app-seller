import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/merchandising/store_showcase.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/showcase_detail_cubit/showcase_detail_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// What is on one showcase, and how to change it.
///
/// Unlike a bundle, this is fully editable — products go on and come off
/// freely. The one thing to watch is that the list is **active products
/// only**: a draft can be added and will simply never show, so the picker
/// warns rather than letting it disappear silently.
class ShowcaseDetailView extends StatelessWidget {
  const ShowcaseDetailView({super.key, required this.showcaseId});

  final int showcaseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShowcaseDetailCubit>(
      create: (_) => ShowcaseDetailCubit(showcaseId)..load(),
      child: const _ShowcaseDetailBody(),
    );
  }
}

class _ShowcaseDetailBody extends StatelessWidget {
  const _ShowcaseDetailBody();

  Future<void> _add(BuildContext context, ShowcaseDetailLoaded state) async {
    final cubit = ShowcaseDetailCubit.get(context);
    final productId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(
        products: cubit.pickerProducts,
        alreadyIn: state.productIds,
      ),
    );
    if (productId == null || !context.mounted) return;

    final error = await cubit.addProduct(productId);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Produk ditambahkan ke etalase.');
  }

  Future<void> _remove(BuildContext context, ShowcaseProduct product) async {
    final error =
        await ShowcaseDetailCubit.get(context).removeProduct(product.id);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Produk dikeluarkan dari etalase.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Isi etalase'),
      floatingActionButton:
          BlocBuilder<ShowcaseDetailCubit, ShowcaseDetailState>(
        builder: (context, state) => switch (state) {
          ShowcaseDetailLoaded() => FloatingActionButton(
              onPressed: state.isBusy ? null : () => _add(context, state),
              tooltip: 'Tambah produk',
              child: const Icon(Icons.add),
            ),
          _ => const SizedBox.shrink(),
        },
      ),
      body: SafeArea(
        child: BlocBuilder<ShowcaseDetailCubit, ShowcaseDetailState>(
          builder: (context, state) => switch (state) {
            ShowcaseDetailInProgress() => const LoadingIndicatorView(),
            ShowcaseDetailNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu untuk membuka etalasenya.',
              ),
            ShowcaseDetailFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => ShowcaseDetailCubit.get(context).load(),
              ),
            ShowcaseDetailLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ShowcaseDetailLoaded state) {
    return RefreshIndicator(
      onRefresh: () => ShowcaseDetailCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(state.showcase.name, style: XText.headingM),
                  4.sbh,
                  Text(
                    'Hanya produk aktif yang tampil di sini. Produk draf tetap '
                    'bisa dimasukkan, tapi tidak akan pernah muncul sampai '
                    'produknya diaktifkan.',
                    style: XText.caption.copyWith(color: kLightThirdColor),
                  ),
                  16.sbh,
                  if (state.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyStateView(
                        icon: Icons.shelves,
                        message: 'Belum ada produk aktif di etalase ini.',
                      ),
                    )
                  else
                    for (final product in state.products) ...<Widget>[
                      _ShowcaseProductCard(
                        product: product,
                        isBusy: state.isBusy,
                        onRemove: () => _remove(context, product),
                      ),
                      12.sbh,
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseProductCard extends StatelessWidget {
  const _ShowcaseProductCard({
    required this.product,
    required this.isBusy,
    required this.onRemove,
  });

  final ShowcaseProduct product;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(product.name, style: XText.bodyM),
                2.sbh,
                Text(
                  <String>[
                    formatRupiah(product.basePrice),
                    if (product.hasRating)
                      '${product.ratingAvg.toStringAsFixed(1)} '
                          '(${product.ratingCount})',
                  ].join(' · '),
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Keluarkan',
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            onPressed: isBusy ? null : onRemove,
          ),
        ],
      ),
    );
  }
}

/// Picks one product to put on the shelf.
///
/// Products already on it are hidden — the server refuses a duplicate with a
/// 422 — and drafts are shown but marked, because adding one succeeds and
/// then nothing appears.
class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.alreadyIn,
  });

  final Future<List<Product>> Function() products;
  final Set<int> alreadyIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: 20.pa,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Tambah produk', style: XText.headingM),
              12.sbh,
              Flexible(
                child: FutureBuilder<List<Product>>(
                  future: products(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingIndicatorView();
                    }

                    final available = (snapshot.data ?? const <Product>[])
                        .where((product) => !alreadyIn.contains(product.id))
                        .toList(growable: false);

                    if (available.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.inventory_2_outlined,
                        message: 'Tidak ada produk lain yang bisa '
                            'ditambahkan.',
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: available.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = available[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product.name,
                            style: XText.bodyM,
                          ),
                          subtitle: Text(
                            product.isDraft
                                ? '${formatRupiah(product.basePrice)} · draf — '
                                    'tidak akan tampil sampai diaktifkan'
                                : formatRupiah(product.basePrice),
                            style: XText.caption.copyWith(
                              color: product.isDraft
                                  ? kWarningColor
                                  : kLightThirdColor,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(product.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
