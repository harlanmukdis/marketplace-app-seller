import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/function/components.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/store_cubit/store_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// Which of the account's stores the app is acting as.
///
/// This screen has no counterpart in the previous backend, where an account
/// *was* a store. Here the choice is real, it travels as `X-Store-Id` on every
/// seller-side call, and getting it wrong means editing another shop's
/// catalogue.
class StorePickerView extends StatelessWidget {
  const StorePickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Pilih toko'),
      body: SafeArea(
        child: BlocBuilder<StoreCubit, StoreState>(
          builder: (context, state) => switch (state) {
            StoreLoadInProgress() => const LoadingIndicatorView(),
            StoreLoadFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => StoreCubit.get(context).load(),
              ),
            StoreLoadSuccess() => _content(context, state),
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(SellerRoutes.storeCreate),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Toko baru'),
      ),
    );
  }

  Widget _content(BuildContext context, StoreLoadSuccess state) {
    if (!state.hasStore) {
      return const EmptyStateView(
        icon: Icons.storefront_outlined,
        message: 'Akun ini belum punya toko.\n'
            'Buka toko dulu untuk mulai berjualan.',
      );
    }

    return ListView.separated(
      padding: 20.pa,
      itemCount: state.stores.length,
      separatorBuilder: (_, __) => 12.sbh,
      itemBuilder: (context, index) {
        final store = state.stores[index];
        final isActive = store.id == state.activeStoreId;

        return SectionCard(
          accent: isActive
              ? (isAppDarkMode() ? kDarkPrimaryColor : kLightPrimaryColor)
              : null,
          onTap: () async {
            await StoreCubit.get(context).select(store.id);
            if (!context.mounted) return;
            context.go(SellerRoutes.home);
          },
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(store.name, style: XText.titleL),
                    4.sbh,
                    Text(
                      '${StoreType.label(store.type)} · '
                      '${StoreStatus.label(store.status)}',
                      style:
                          XText.bodySPrimary.copyWith(color: kLightThirdColor),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: kSuccessColor, size: 20),
            ],
          ),
        );
      },
    );
  }
}
