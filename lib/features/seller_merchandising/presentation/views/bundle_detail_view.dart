import 'package:flutter/material.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/merchandising/product_bundle.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/bundle_detail_cubit/bundle_detail_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// One bundle: what is in it, and what it saves.
///
/// Read-only as to contents, because the API is: items are settled when the
/// bundle is created and no route changes them afterwards. The one control
/// here is the on/off switch — which is also what decides whether the
/// contents can be read at all.
class BundleDetailView extends StatelessWidget {
  const BundleDetailView({super.key, required this.bundleId});

  final int bundleId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BundleDetailCubit>(
      create: (_) => BundleDetailCubit(bundleId)..load(),
      child: const _BundleDetailBody(),
    );
  }
}

class _BundleDetailBody extends StatelessWidget {
  const _BundleDetailBody();

  Future<void> _toggle(BuildContext context, bool isActive) async {
    final error = await BundleDetailCubit.get(context).setActive(isActive);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(
      context,
      isActive ? 'Bundel diaktifkan.' : 'Bundel dinonaktifkan.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Detail bundel'),
      body: SafeArea(
        child: BlocBuilder<BundleDetailCubit, BundleDetailState>(
          builder: (context, state) => switch (state) {
            BundleDetailInProgress() => const LoadingIndicatorView(),
            BundleDetailNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu untuk membuka bundelnya.',
              ),
            BundleDetailFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => BundleDetailCubit.get(context).load(),
              ),
            BundleDetailLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, BundleDetailLoaded state) {
    final bundle = state.bundle;

    return RefreshIndicator(
      onRefresh: () => BundleDetailCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                        Text(bundle.name, style: XText.headingM),
                        8.sbh,
                        StatRow(
                          label: 'Harga bundel',
                          value: formatRupiah(bundle.bundlePrice),
                          emphasis: true,
                        ),
                        StatRow(
                          label: 'Status',
                          value: BundleStatus.label(bundle.status),
                        ),
                        if (!state.itemsAreHidden &&
                            bundle.items.isNotEmpty) ...<Widget>[
                          StatRow(
                            label: 'Bila dibeli satuan',
                            value: formatRupiah(bundle.itemsTotal),
                          ),
                          StatRow(
                            label: 'Hemat',
                            value: bundle.savings > 0
                                ? '${formatRupiah(bundle.savings)} '
                                    '(${bundle.discountPercent}%)'
                                : 'Tidak lebih murah',
                            valueColor: bundle.savings > 0
                                ? XColors.success
                                : XColors.warningStrong,
                          ),
                        ],
                        12.sbh,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: state.isBusy
                                ? null
                                : () => _toggle(context, !bundle.isActive),
                            child: Text(
                              bundle.isActive ? 'Nonaktifkan' : 'Aktifkan',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  20.sbh,
                  Text('Isi bundel', style: XText.labelL),
                  4.sbh,
                  Text(
                    'Isi tidak bisa diubah — tidak ada endpoint untuk '
                    'menambah atau mengeluarkan produk dari bundel yang sudah '
                    'jadi.',
                    style: XText.caption.copyWith(color: XColors.textTertiary),
                  ),
                  12.sbh,
                  if (state.itemsAreHidden)
                    const _HiddenItemsNotice()
                  else if (bundle.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyStateView(
                        icon: Icons.inventory_outlined,
                        message: 'Bundel ini tidak punya isi.',
                      ),
                    )
                  else
                    for (final item in bundle.items) ...<Widget>[
                      _ItemRow(item: item),
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

/// The bundle is switched off, so the endpoint carrying its items refuses it.
///
/// Worth saying at length, because the behaviour is surprising: the contents
/// are not gone, and switching the bundle back on brings them straight back.
class _HiddenItemsNotice extends StatelessWidget {
  const _HiddenItemsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: XColors.warningStrong.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.visibility_off_outlined,
              size: 18, color: XColors.warningStrong),
          8.sbw,
          Expanded(
            child: Text(
              'Isi bundel tidak bisa ditampilkan selama bundel nonaktif — '
              'API hanya melayani bundel yang aktif, termasuk untuk '
              'pemiliknya sendiri. Isinya tidak hilang: aktifkan kembali dan '
              'daftarnya muncul lagi.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final BundleItem item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.productName, style: XText.bodyM),
                2.sbh,
                Text(
                  <String>[
                    '${item.quantity} ×  ${formatRupiah(item.unitPrice)}',
                    if (item.variantId != null) 'varian #${item.variantId}',
                  ].join(' · '),
                  style: XText.caption.copyWith(color: XColors.textTertiary),
                ),
              ],
            ),
          ),
          12.sbw,
          Text(
            formatRupiah(item.lineTotal),
            style: XText.labelL,
          ),
        ],
      ),
    );
  }
}
