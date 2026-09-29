import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/merchandising/product_bundle.dart';
import '../../../../core/domain/model/merchandising/store_showcase.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/bundle_cubit/bundle_cubit.dart';
import '../cubits/showcase_cubit/showcase_cubit.dart';
import 'widgets/bundle_form_sheet.dart';
import 'widgets/showcase_form_sheet.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// How the store groups its products: **bundles** sold as one, and
/// **showcases** — the shop's own shelves.
///
/// Two lists on one screen because they answer the same question from
/// different angles, and because each is small on its own. They behave
/// differently in one way worth remembering: a bundle can never be deleted or
/// have its contents changed, while a showcase can be edited freely.
class MerchandisingView extends StatelessWidget {
  const MerchandisingView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<BundleCubit>(create: (_) => BundleCubit()..load()),
        BlocProvider<ShowcaseCubit>(create: (_) => ShowcaseCubit()..load()),
      ],
      child: const _MerchandisingBody(),
    );
  }
}

enum _MerchandisingTab {
  bundle('Bundel'),
  showcase('Etalase');

  const _MerchandisingTab(this.label);

  final String label;
}

class _MerchandisingBody extends StatefulWidget {
  const _MerchandisingBody();

  @override
  State<_MerchandisingBody> createState() => _MerchandisingBodyState();
}

class _MerchandisingBodyState extends State<_MerchandisingBody> {
  _MerchandisingTab _tab = _MerchandisingTab.bundle;

  Future<void> _createBundle() async {
    final cubit = BundleCubit.get(context);
    final draft = await showBundleFormSheet(
      context,
      products: cubit.pickerProducts,
    );
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      bundlePrice: draft.bundlePrice,
      items: draft.items,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Bundel dibuat.');
  }

  Future<void> _createShowcase() async {
    final cubit = ShowcaseCubit.get(context);
    final state = cubit.state;
    final draft = await showShowcaseFormSheet(
      context,
      defaultSortOrder: state is ShowcaseLoaded ? state.nextSortOrder : 0,
    );
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      sortOrder: draft.sortOrder,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Etalase dibuat.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Bundel & etalase'),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _tab == _MerchandisingTab.bundle ? _createBundle : _createShowcase,
        tooltip:
            _tab == _MerchandisingTab.bundle ? 'Bundel baru' : 'Etalase baru',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _MerchandisingTab.values.length,
                separatorBuilder: (_, __) => 8.sbw,
                itemBuilder: (context, index) {
                  final tab = _MerchandisingTab.values[index];
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
                _MerchandisingTab.bundle => const _BundleList(),
                _MerchandisingTab.showcase => const _ShowcaseList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleList extends StatelessWidget {
  const _BundleList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BundleCubit, BundleState>(
      builder: (context, state) => switch (state) {
        BundleInProgress() => const LoadingIndicatorView(),
        BundleNoStore() => const EmptyStateView(
            icon: Icons.storefront_outlined,
            message: 'Pilih toko dulu untuk melihat bundelnya.',
          ),
        BundleFailure(:final error) => ErrorStateView(
            error: error,
            onRetry: () => BundleCubit.get(context).load(),
          ),
        BundleLoaded() => _content(context, state),
      },
    );
  }

  Widget _content(BuildContext context, BundleLoaded state) {
    return RefreshIndicator(
      onRefresh: () => BundleCubit.get(context).load(),
      child: state.bundles.isEmpty
          ? ListView(
              children: <Widget>[
                SizedBox(height: context.screenHeight * 0.12),
                const EmptyStateView(
                  icon: Icons.inventory_outlined,
                  message: 'Belum ada bundel produk.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: state.bundles.length,
              separatorBuilder: (_, __) => 12.sbh,
              itemBuilder: (context, index) {
                final bundle = state.bundles[index];
                return _BundleCard(
                  bundle: bundle,
                  isBusy: state.isBusy,
                  onTap: () async {
                    final cubit = BundleCubit.get(context);
                    await context
                        .push(SellerRoutes.bundleDetailPath(bundle.id));
                    if (cubit.isClosed) return;
                    await cubit.load();
                  },
                  onToggle: (isActive) async {
                    final cubit = BundleCubit.get(context);
                    final error = await cubit.setActive(bundle.id, isActive);
                    if (!context.mounted) return;
                    if (error != null) showErrorSnackBar(context, error);
                  },
                );
              },
            ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.isBusy,
    required this.onTap,
    required this.onToggle,
  });

  final ProductBundle bundle;
  final bool isBusy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(bundle.name, style: XText.labelL),
              ),
              8.sbw,
              _StatusPill(isActive: bundle.isActive),
              4.sbw,
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          6.sbh,
          Text(
            formatRupiah(bundle.bundlePrice),
            style: XText.headingM.copyWith(color: kLightPrimaryColor),
          ),
          if (!bundle.isActive) ...<Widget>[
            8.sbh,
            Text(
              'Nonaktif — isinya juga tidak bisa dibaca selama begini, '
              'karena API hanya melayani bundel aktif.',
              style: XText.caption.copyWith(color: kWarningColor),
            ),
          ],
          8.sbh,
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: isBusy ? null : () => onToggle(!bundle.isActive),
              child: Text(bundle.isActive ? 'Nonaktifkan' : 'Aktifkan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? kSuccessColor : kLightThirdColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: XText.bodySPrimary.copyWith(color: color),
      ),
    );
  }
}

class _ShowcaseList extends StatelessWidget {
  const _ShowcaseList();

  Future<void> _rename(BuildContext context, StoreShowcase showcase) async {
    final cubit = ShowcaseCubit.get(context);
    final draft = await showShowcaseFormSheet(context, existing: showcase);
    if (draft == null || !context.mounted) return;

    final error = await cubit.rename(
      showcase.id,
      name: draft.name,
      sortOrder: draft.sortOrder,
    );
    if (!context.mounted) return;
    if (error != null) showErrorSnackBar(context, error);
  }

  Future<void> _delete(BuildContext context, StoreShowcase showcase) async {
    final cubit = ShowcaseCubit.get(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus etalase?'),
        content: Text(
          '"${showcase.name}" akan dihapus. Produknya sendiri tidak ikut '
          'terhapus — hanya pengelompokannya.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await cubit.remove(showcase.id);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Etalase dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShowcaseCubit, ShowcaseState>(
      builder: (context, state) => switch (state) {
        ShowcaseInProgress() => const LoadingIndicatorView(),
        ShowcaseNoStore() => const EmptyStateView(
            icon: Icons.storefront_outlined,
            message: 'Pilih toko dulu untuk melihat etalasenya.',
          ),
        ShowcaseFailure(:final error) => ErrorStateView(
            error: error,
            onRetry: () => ShowcaseCubit.get(context).load(),
          ),
        ShowcaseLoaded() => _content(context, state),
      },
    );
  }

  Widget _content(BuildContext context, ShowcaseLoaded state) {
    return RefreshIndicator(
      onRefresh: () => ShowcaseCubit.get(context).load(),
      child: state.showcases.isEmpty
          ? ListView(
              children: <Widget>[
                SizedBox(height: context.screenHeight * 0.12),
                const EmptyStateView(
                  icon: Icons.shelves,
                  message: 'Belum ada etalase.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: state.showcases.length,
              separatorBuilder: (_, __) => 12.sbh,
              itemBuilder: (context, index) {
                final showcase = state.showcases[index];
                return SectionCard(
                  onTap: () async {
                    final cubit = ShowcaseCubit.get(context);
                    await context
                        .push(SellerRoutes.showcaseDetailPath(showcase.id));
                    if (cubit.isClosed) return;
                    await cubit.load();
                  },
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              showcase.name,
                              style: XText.bodyM,
                            ),
                            2.sbh,
                            Text(
                              // The list carries no product count, so saying
                              // one would mean a call per showcase.
                              'Urutan ${showcase.sortOrder}',
                              style: XText.caption
                                  .copyWith(color: kLightThirdColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ubah',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: state.isBusy
                            ? null
                            : () => _rename(context, showcase),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: state.isBusy
                            ? null
                            : () => _delete(context, showcase),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
