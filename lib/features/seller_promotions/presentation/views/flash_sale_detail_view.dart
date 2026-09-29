import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../core/domain/model/promotion/flash_sale_product.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/flash_sale_detail_cubit/flash_sale_detail_cubit.dart';
import 'widgets/flash_sale_product_sheet.dart';
import 'widgets/promotion_pill.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// What is inside one flash sale, and the only way to put something there.
///
/// Additions are permanent: there is no endpoint that removes a variant from a
/// sale or changes its price once set.
class FlashSaleDetailView extends StatelessWidget {
  const FlashSaleDetailView({super.key, required this.flashSaleId});

  final int flashSaleId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FlashSaleDetailCubit>(
      create: (_) => FlashSaleDetailCubit(flashSaleId)..load(),
      child: const _FlashSaleDetailBody(),
    );
  }
}

class _FlashSaleDetailBody extends StatelessWidget {
  const _FlashSaleDetailBody();

  Future<void> _add(BuildContext context, FlashSaleDetailLoaded state) async {
    final cubit = FlashSaleDetailCubit.get(context);
    final draft = await showFlashSaleProductSheet(
      context,
      products: cubit.pickerProducts,
      variantsOf: cubit.variantsOf,
      takenVariantIds: state.takenVariantIds,
    );
    if (draft == null || !context.mounted) return;

    final error = await cubit.addProduct(
      productVariantId: draft.productVariantId,
      flashPrice: draft.flashPrice,
      stockQuota: draft.stockQuota,
      originalPrice: draft.originalPrice,
      maxQtyPerUser: draft.maxQtyPerUser,
    );
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Produk masuk ke flash sale.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Isi flash sale'),
      floatingActionButton:
          BlocBuilder<FlashSaleDetailCubit, FlashSaleDetailState>(
        builder: (context, state) => switch (state) {
          FlashSaleDetailLoaded() => FloatingActionButton(
              onPressed: state.isBusy ? null : () => _add(context, state),
              tooltip: 'Tambah produk',
              child: const Icon(Icons.add),
            ),
          _ => const SizedBox.shrink(),
        },
      ),
      body: SafeArea(
        child: BlocBuilder<FlashSaleDetailCubit, FlashSaleDetailState>(
          builder: (context, state) => switch (state) {
            FlashSaleDetailInProgress() => const LoadingIndicatorView(),
            FlashSaleDetailNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu untuk membuka flash sale-nya.',
              ),
            FlashSaleDetailFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => FlashSaleDetailCubit.get(context).load(),
              ),
            FlashSaleDetailLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, FlashSaleDetailLoaded state) {
    final sale = state.sale;
    final phase = sale.phaseAt(DateTime.now());

    return RefreshIndicator(
      onRefresh: () => FlashSaleDetailCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                sale.name,
                                style: XText.headingM,
                              ),
                            ),
                            8.sbw,
                            PromotionPill.flashSale(phase),
                          ],
                        ),
                        8.sbh,
                        StatRow(
                          label: 'Mulai',
                          value: formatDateTime(sale.startAt),
                        ),
                        StatRow(
                          label: 'Berakhir',
                          value: formatDateTime(sale.endAt),
                        ),
                        StatRow(label: 'Status di server', value: sale.status),
                      ],
                    ),
                  ),
                  if (phase == FlashSalePhase.stalled) ...<Widget>[
                    12.sbh,
                    const _StalledBanner(),
                  ],
                  20.sbh,
                  Text('Produk', style: XText.labelL),
                  4.sbh,
                  Text(
                    'Kuota di sini milik flash sale, terpisah dari stok gudang '
                    '— tidak ada yang mencocokkan keduanya.',
                    style: XText.caption.copyWith(color: kLightThirdColor),
                  ),
                  12.sbh,
                  if (state.products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyStateView(
                        icon: Icons.bolt_outlined,
                        message: 'Belum ada produk di flash sale ini.',
                      ),
                    )
                  else
                    for (final row in state.products) ...<Widget>[
                      _ProductRow(row: row),
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

class _StalledBanner extends StatelessWidget {
  const _StalledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: kErrorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 18, color: kErrorColor),
          8.sbw,
          Expanded(
            child: Text(
              'Jendela waktunya sudah berjalan, tapi status di server belum '
              '"active" — dan pembeli hanya melihat harga flash sale kalau '
              'kedua-duanya terpenuhi. Menambah produk ke sini sekarang tidak '
              'akan mengubah harga yang dilihat pembeli.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.row});

  final FlashSaleProduct row;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(row.productName, style: XText.labelL),
          2.sbh,
          Text(
            row.sku,
            style: XText.caption.copyWith(color: kLightThirdColor),
          ),
          12.sbh,
          Row(
            children: <Widget>[
              Text(
                formatRupiah(row.flashPrice),
                style: XText.headingM.copyWith(color: kLightPrimaryColor),
              ),
              8.sbw,
              if (row.isDiscounted) ...<Widget>[
                Text(
                  formatRupiah(row.originalPrice),
                  style: XText.bodySPrimary.copyWith(
                    color: kLightThirdColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                8.sbw,
                Text(
                  '-${row.discountPercent}%',
                  style: XText.bodySPrimary.copyWith(color: kSuccessColor),
                ),
              ] else
                // The server accepts a "discount" that is not one, so it has
                // to be said rather than shown as a saving.
                Expanded(
                  child: Text(
                    'Tidak lebih murah dari harga normal '
                    '(${formatRupiah(row.originalPrice)})',
                    style: XText.bodySPrimary.copyWith(color: kWarningColor),
                  ),
                ),
            ],
          ),
          12.sbh,
          StatRow(
            label: 'Kuota',
            value: '${row.soldCount} / ${row.stockQuota} terjual',
          ),
          StatRow(label: 'Maksimal per pembeli', value: '${row.maxQtyPerUser}'),
        ],
      ),
    );
  }
}
