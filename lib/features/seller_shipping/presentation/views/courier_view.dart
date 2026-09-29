import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/courier_cubit/courier_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// Which couriers the store ships with.
///
/// The list is an **optional whitelist**, not a requirement: a store that has
/// chosen none is offered to buyers through every active courier, and choosing
/// some *narrows* that to the chosen ones. Getting this backwards is easy —
/// the screen says which way round it works rather than leaving the seller to
/// guess whether an empty list means "all" or "none".
class CourierView extends StatelessWidget {
  const CourierView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CourierCubit>(
      create: (_) => CourierCubit()..load(),
      child: const _CourierBody(),
    );
  }
}

class _CourierBody extends StatelessWidget {
  const _CourierBody();

  Future<void> _save(BuildContext context) async {
    final error = await CourierCubit.get(context).save();
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Pilihan kurir tersimpan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Kurir pengiriman'),
      body: SafeArea(
        child: BlocBuilder<CourierCubit, CourierState>(
          builder: (context, state) => switch (state) {
            CourierInProgress() => const LoadingIndicatorView(),
            CourierNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu untuk mengatur kurirnya.',
              ),
            CourierFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => CourierCubit.get(context).load(),
              ),
            CourierLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CourierLoaded state) {
    if (state.available.isEmpty) {
      return const EmptyStateView(
        icon: Icons.local_shipping_outlined,
        message: 'Platform belum punya kurir aktif.',
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: 20.pa,
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (state.hasNone) const _AllCouriersNotice(),
                      if (state.hasNone) 16.sbh,
                      Text(
                        state.hasNone
                            ? 'Centang kurir tertentu kalau ingin membatasi. '
                                'Menyimpan tanpa centang berarti kembali '
                                'terbuka untuk semua kurir.'
                            : 'Pembeli hanya bisa memilih kurir yang dicentang '
                                'di sini. Menyimpan akan mengganti seluruh '
                                'daftar, bukan menambah.',
                        style: XText.bodySPrimary
                            .copyWith(color: kLightThirdColor),
                      ),
                      16.sbh,
                      for (final courier in state.available)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.isSelected(courier.code),
                          onChanged: state.isBusy
                              ? null
                              : (_) => CourierCubit.get(context)
                                  .toggle(courier.code),
                          title: Text(
                            courier.name,
                            style: XText.bodyM,
                          ),
                          subtitle: Text(
                            courier.code,
                            style:
                                XText.caption.copyWith(color: kLightThirdColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: 20.pa,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FilledButton(
                onPressed: state.isBusy || !state.isDirty
                    ? null
                    : () => _save(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: state.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kWhiteColor,
                        ),
                      )
                    : const Text('Simpan pilihan'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An empty selection is "open to all", not "nothing ships" — the backend
/// applies the whitelist only when it is non-empty. Said plainly, because the
/// opposite reading is the natural one and would send a seller hunting for a
/// problem that is not there.
class _AllCouriersNotice extends StatelessWidget {
  const _AllCouriersNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: kLightPrimaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.local_shipping_outlined,
              size: 18, color: kLightPrimaryColor),
          8.sbw,
          Expanded(
            child: Text(
              'Belum ada batasan kurir, jadi pembeli bisa memilih semua kurir '
              'yang aktif di platform. Pengiriman tetap jalan.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
