import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/promotion/flash_sale.dart';
import '../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/flash_sale_cubit/flash_sale_cubit.dart';
import '../cubits/voucher_cubit/voucher_cubit.dart';
import 'widgets/flash_sale_card.dart';
import 'widgets/flash_sale_form_sheet.dart';
import 'widgets/margin_protection_card.dart';
import 'widgets/voucher_card.dart';
import 'widgets/voucher_form_sheet.dart';

/// "Campaign & Promo Seller" (S-31): vouchers and flash sales.
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
  voucher('Voucher Toko', Icons.storefront_outlined),
  flashSale('Flash Sale', Icons.bolt);

  const _PromotionTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The design's three filter chips. Every derived phase lands in one.
enum _Group {
  active('Aktif'),
  scheduled('Terjadwal'),
  done('Selesai');

  const _Group(this.label);

  final String label;

  static _Group ofVoucher(VoucherPhase p) => switch (p) {
        VoucherPhase.running => active,
        VoucherPhase.scheduled => scheduled,
        _ => done,
      };

  // A stalled sale sits in Aktif: its window is open, and it needs attention.
  static _Group ofSale(FlashSalePhase p) => switch (p) {
        FlashSalePhase.running || FlashSalePhase.stalled => active,
        FlashSalePhase.scheduled => scheduled,
        _ => done,
      };
}

class _PromotionBody extends StatefulWidget {
  const _PromotionBody();

  @override
  State<_PromotionBody> createState() => _PromotionBodyState();
}

class _PromotionBodyState extends State<_PromotionBody> {
  _PromotionTab _tab = _PromotionTab.voucher;
  _Group? _group;

  /// The create card sits below the list, so after creating something the
  /// list scrolls back up to show it.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showTop() {
    setState(() => _group = null);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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
    _showTop();
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
    _showTop();
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
    final isVoucher = _tab == _PromotionTab.voucher;
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Campaign & Promo Seller',
        actions: <Widget>[
          XIconAction(
            icon: Icons.campaign_outlined,
            tooltip: 'Campaign Xpedia',
            onPressed: () => context.push(SellerRoutes.platformCampaigns),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                XSpace.screen, 0, XSpace.screen, XSpace.s12),
            child: _Segmented(
              value: _tab,
              onChanged: (t) => setState(() {
                _tab = t;
                _group = null;
              }),
            ),
          ),
        ),
      ),
      body: isVoucher
          ? _VoucherList(
              controller: _scroll,
              group: _group,
              onGroup: (g) => setState(() => _group = g),
              onCreate: _createVoucher,
            )
          : _FlashSaleList(
              controller: _scroll,
              group: _group,
              onGroup: (g) => setState(() => _group = g),
              onCreate: _createFlashSale,
              onOpen: _openSale,
            ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final _PromotionTab value;
  final ValueChanged<_PromotionTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        children: <Widget>[
          for (final t in _PromotionTab.values)
            Expanded(
              child: Material(
                color: t == value ? XColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(XRadius.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(XRadius.sm),
                  onTap: () => onChanged(t),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        t.icon,
                        size: 18,
                        color: t == value
                            ? XColors.textOnBrand
                            : XColors.textSecondary,
                      ),
                      const SizedBox(width: XSpace.s8),
                      Text(
                        t.label,
                        style: XText.labelL.copyWith(
                          color: t == value
                              ? XColors.textOnBrand
                              : XColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aktif (n) · Terjadwal (n) · Selesai (n). [selected] null means "all".
class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final Map<_Group, int> counts;
  final _Group? selected;
  final ValueChanged<_Group?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: XSpace.s8,
      runSpacing: XSpace.s8,
      children: <Widget>[
        for (final g in _Group.values)
          ChoiceChip(
            label: Text('${g.label} (${counts[g] ?? 0})'),
            selected: selected == g,
            showCheckmark: false,
            labelStyle: XText.labelM.copyWith(
              color: selected == g ? XColors.primary : XColors.textSecondary,
            ),
            side: BorderSide.none,
            backgroundColor: XColors.sunken,
            selectedColor: XColors.brandSubtle,
            shape: const StadiumBorder(),
            onSelected: (on) => onChanged(on ? g : null),
          ),
      ],
    );
  }
}

/// "Buat Promosi Mandiri Seller": the entry point, and the place to say —
/// before anything is created — that nothing here can be edited afterwards.
class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.title,
    required this.message,
    required this.action,
    required this.onCreate,
  });

  final String title;
  final String message;
  final String action;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: XColors.brandSubtle,
                child: Icon(Icons.campaign_outlined, color: XColors.primary),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: XText.titleL),
                    Text(
                      'Diskon katalog dengan perlindungan HPP',
                      style: XText.bodyS,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          XBanner(tone: XTone.warning, message: message),
          const SizedBox(height: XSpace.s12),
          XButton(
            label: action,
            icon: Icons.add,
            expand: true,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({
    required this.controller,
    required this.group,
    required this.onGroup,
    required this.onCreate,
  });

  final ScrollController controller;
  final _Group? group;
  final ValueChanged<_Group?> onGroup;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoucherCubit, VoucherState>(
      builder: (context, state) => switch (state) {
        VoucherInProgress() => const LoadingIndicatorView(),
        VoucherNoStore() => const XEmptyState(
            icon: Icons.storefront_outlined,
            title: 'Belum ada toko aktif',
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
    final counts = <_Group, int>{};
    for (final r in rows) {
      final g = _Group.ofVoucher(r.phase);
      counts[g] = (counts[g] ?? 0) + 1;
    }
    final shown = group == null
        ? rows
        : rows.where((r) => _Group.ofVoucher(r.phase) == group).toList();

    return RefreshIndicator(
      onRefresh: () => VoucherCubit.get(context).load(),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          _GroupChips(counts: counts, selected: group, onChanged: onGroup),
          const SizedBox(height: XSpace.s12),
          if (rows.isEmpty)
            const XCard(
              child: XEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'Belum ada voucher toko.',
              ),
            )
          else if (shown.isEmpty)
            XCard(
              child: Text(
                'Tidak ada voucher ${group!.label.toLowerCase()}.',
                style: XText.bodyS,
              ),
            )
          else
            for (final r in shown) ...<Widget>[
              VoucherCard(voucher: r.voucher, phase: r.phase),
              const SizedBox(height: XSpace.s12),
            ],
          const SizedBox(height: XSpace.s12),
          _CreateCard(
            title: 'Buat Promosi Mandiri Seller',
            message: 'Voucher hanya bisa dibuat dan dilihat. Setelah dibuat, '
                'tidak ada cara mengubah, menjeda, atau menghapusnya — '
                'berhentinya saat kuota habis atau masa berlakunya lewat.',
            action: 'Buat Voucher',
            onCreate: onCreate,
          ),
          const SizedBox(height: XSpace.s24),
          const MarginProtectionCard(),
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }
}

class _FlashSaleList extends StatelessWidget {
  const _FlashSaleList({
    required this.controller,
    required this.group,
    required this.onGroup,
    required this.onCreate,
    required this.onOpen,
  });

  final ScrollController controller;
  final _Group? group;
  final ValueChanged<_Group?> onGroup;
  final VoidCallback onCreate;
  final Future<void> Function(int saleId) onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlashSaleCubit, FlashSaleState>(
      builder: (context, state) => switch (state) {
        FlashSaleInProgress() => const LoadingIndicatorView(),
        FlashSaleNoStore() => const XEmptyState(
            icon: Icons.storefront_outlined,
            title: 'Belum ada toko aktif',
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
    final counts = <_Group, int>{};
    for (final s in state.sales) {
      final g = _Group.ofSale(s.phaseAt(now));
      counts[g] = (counts[g] ?? 0) + 1;
    }
    final shown = group == null
        ? state.sales
        : state.sales
            .where((s) => _Group.ofSale(s.phaseAt(now)) == group)
            .toList();

    return RefreshIndicator(
      onRefresh: () => FlashSaleCubit.get(context).load(),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          _GroupChips(counts: counts, selected: group, onChanged: onGroup),
          const SizedBox(height: XSpace.s12),
          if (state.sales.isEmpty)
            const XCard(
              child: XEmptyState(
                icon: Icons.bolt_outlined,
                title: 'Belum ada flash sale.',
              ),
            )
          else if (shown.isEmpty)
            XCard(
              child: Text(
                'Tidak ada flash sale ${group!.label.toLowerCase()}.',
                style: XText.bodyS,
              ),
            )
          else
            for (final sale in shown) ...<Widget>[
              FlashSaleCard(
                sale: sale,
                phase: sale.phaseAt(now),
                onTap: () => onOpen(sale.id),
              ),
              const SizedBox(height: XSpace.s12),
            ],
          const SizedBox(height: XSpace.s12),
          _CreateCard(
            title: 'Buat Flash Sale',
            message: 'Flash sale juga tidak bisa diubah atau dibatalkan '
                'setelah dibuat. Produk yang sudah dimasukkan pun tidak bisa '
                'dikeluarkan lagi.',
            action: 'Buat Flash Sale',
            onCreate: onCreate,
          ),
          const SizedBox(height: XSpace.s24),
          const MarginProtectionCard(),
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }
}
