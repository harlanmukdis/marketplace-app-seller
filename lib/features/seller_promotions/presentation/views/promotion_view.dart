import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/flash_sale_cubit/flash_sale_cubit.dart';
import '../cubits/voucher_cubit/voucher_cubit.dart';
import 'widgets/flash_sale_card.dart';
import 'widgets/flash_sale_form_sheet.dart';
import 'widgets/voucher_card.dart';
import 'widgets/voucher_form_sheet.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// The store's promotions: vouchers and flash sales.
///
/// Two lists rather than two screens, because they are the same decision seen
/// from two angles — and because both share the one constraint that shapes
/// everything here: the API can create and list them, and nothing else. There
/// is no edit, no pause and no delete on either.
class PromotionView extends StatelessWidget {
  const PromotionView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<VoucherCubit>(create: (_) => VoucherCubit()..load()),
        BlocProvider<FlashSaleCubit>(create: (_) => FlashSaleCubit()..load()),
      ],
      child: const _PromotionBody(),
    );
  }
}

enum _PromotionTab {
  voucher('Voucher'),
  flashSale('Flash sale');

  const _PromotionTab(this.label);

  final String label;
}

class _PromotionBody extends StatefulWidget {
  const _PromotionBody();

  @override
  State<_PromotionBody> createState() => _PromotionBodyState();
}

class _PromotionBodyState extends State<_PromotionBody> {
  _PromotionTab _tab = _PromotionTab.voucher;

  Future<void> _createVoucher() async {
    final cubit = VoucherCubit.get(context);
    final draft = await showVoucherFormSheet(context);
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      discountType: draft.discountType,
      discountValue: draft.discountValue,
      quota: draft.quota,
      validFrom: draft.validFrom,
      validUntil: draft.validUntil,
      code: draft.code,
      maxDiscount: draft.maxDiscount,
      minSpend: draft.minSpend,
      maxUsePerUser: draft.maxUsePerUser,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Voucher dibuat.');
  }

  Future<void> _createFlashSale() async {
    final cubit = FlashSaleCubit.get(context);
    final draft = await showFlashSaleFormSheet(context);
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      startAt: draft.startAt,
      endAt: draft.endAt,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Flash sale dibuat.');
  }

  Future<void> _openSale(int saleId) async {
    final cubit = FlashSaleCubit.get(context);
    await context.push(SellerRoutes.flashSaleDetailPath(saleId));
    // The detail screen adds products through its own cubit, and the list
    // shows nothing about contents — but a reload keeps the phase pills honest
    // after time has passed on the detail screen.
    if (cubit.isClosed) return;
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Promosi'),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _tab == _PromotionTab.voucher ? _createVoucher : _createFlashSale,
        tooltip:
            _tab == _PromotionTab.voucher ? 'Voucher baru' : 'Flash sale baru',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _PromotionTab.values.length,
                separatorBuilder: (_, __) => 8.sbw,
                itemBuilder: (context, index) {
                  final tab = _PromotionTab.values[index];
                  return ChoiceChip(
                    label: Text(tab.label),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                  );
                },
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _PromotionTab.voucher => const _VoucherList(),
                _PromotionTab.flashSale => _FlashSaleList(onOpen: _openSale),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Said once above each list: the fact that shapes every decision on this
/// screen.
class _OneWayNotice extends StatelessWidget {
  const _OneWayNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: 12.pa,
      decoration: BoxDecoration(
        color: kLightPrimaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded,
              size: 16, color: kLightPrimaryColor),
          8.sbw,
          Expanded(
            child: Text(message, style: XText.bodySPrimary),
          ),
        ],
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoucherCubit, VoucherState>(
      builder: (context, state) => switch (state) {
        VoucherInProgress() => const LoadingIndicatorView(),
        VoucherNoStore() => const EmptyStateView(
            icon: Icons.storefront_outlined,
            message: 'Pilih toko dulu untuk melihat vouchernya.',
          ),
        VoucherFailure(:final error) => ErrorStateView(
            error: error,
            onRetry: () => VoucherCubit.get(context).load(),
          ),
        VoucherLoaded() => _content(context, state),
      },
    );
  }

  Widget _content(BuildContext context, VoucherLoaded state) {
    // One instant for the whole list, so two pills cannot disagree about "now".
    final rows = state.phased(DateTime.now());

    return RefreshIndicator(
      onRefresh: () => VoucherCubit.get(context).load(),
      child: Column(
        children: <Widget>[
          const _OneWayNotice(
            message: 'Voucher hanya bisa dibuat dan dilihat. Setelah dibuat, '
                'tidak ada cara mengubah, menjeda, atau menghapusnya — '
                'berhentinya saat kuota habis atau masa berlakunya lewat.',
          ),
          Expanded(
            child: rows.isEmpty
                ? ListView(
                    children: <Widget>[
                      SizedBox(height: context.screenHeight * 0.1),
                      const EmptyStateView(
                        icon: Icons.confirmation_number_outlined,
                        message: 'Belum ada voucher toko.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => 12.sbh,
                    itemBuilder: (context, index) => VoucherCard(
                      voucher: rows[index].voucher,
                      phase: rows[index].phase,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlashSaleList extends StatelessWidget {
  const _FlashSaleList({required this.onOpen});

  final Future<void> Function(int saleId) onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlashSaleCubit, FlashSaleState>(
      builder: (context, state) => switch (state) {
        FlashSaleInProgress() => const LoadingIndicatorView(),
        FlashSaleNoStore() => const EmptyStateView(
            icon: Icons.storefront_outlined,
            message: 'Pilih toko dulu untuk melihat flash sale-nya.',
          ),
        FlashSaleFailure(:final error) => ErrorStateView(
            error: error,
            onRetry: () => FlashSaleCubit.get(context).load(),
          ),
        FlashSaleLoaded() => _content(context, state),
      },
    );
  }

  Widget _content(BuildContext context, FlashSaleLoaded state) {
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () => FlashSaleCubit.get(context).load(),
      child: Column(
        children: <Widget>[
          const _OneWayNotice(
            message: 'Flash sale juga tidak bisa diubah atau dibatalkan '
                'setelah dibuat. Produk yang sudah dimasukkan pun tidak bisa '
                'dikeluarkan lagi.',
          ),
          Expanded(
            child: state.sales.isEmpty
                ? ListView(
                    children: <Widget>[
                      SizedBox(height: context.screenHeight * 0.1),
                      const EmptyStateView(
                        icon: Icons.bolt_outlined,
                        message: 'Belum ada flash sale.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                    itemCount: state.sales.length,
                    separatorBuilder: (_, __) => 12.sbh,
                    itemBuilder: (context, index) {
                      final sale = state.sales[index];
                      return FlashSaleCard(
                        sale: sale,
                        phase: sale.phaseAt(now),
                        onTap: () => onOpen(sale.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
