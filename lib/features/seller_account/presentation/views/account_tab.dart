import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data/local/session_store.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';

/// "Akun" — the fifth tab, and the way into everything the other four do not
/// cover. The design's bottom navigation allows five items at most, so the
/// long tail of modules lives here, grouped as the screen architecture map
/// groups them.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await injector<AuthRepository>().logout();
    if (!context.mounted) return;
    context.go(SellerRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final session = injector<SessionStore>();
    final storeState = context.watch<StoreCubit>().state;
    final store =
        storeState is StoreLoadSuccess ? storeState.activeStore : null;
    final storeCount =
        storeState is StoreLoadSuccess ? storeState.stores.length : 0;

    Widget group(String title, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                bottom: XSpace.s8,
                top: XSpace.s8,
              ),
              child: Text(title.toUpperCase(), style: XText.overline),
            ),
            XListGroup(children: rows),
            const SizedBox(height: XSpace.s16),
          ],
        );

    XListRow row(IconData icon, String title, String route,
            {String? subtitle}) =>
        XListRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => context.push(route),
        );

    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Akun', showBack: false),
      // A short, fixed menu: built in full rather than lazily, so every row
      // exists (and can be scrolled to) from the start.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(XSpace.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            XCard(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: XColors.brandSubtle,
                    child: Icon(Icons.person_outline, color: XColors.primary),
                  ),
                  const SizedBox(width: XSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(session.fullName ?? '-', style: XText.titleL),
                        Text(session.email ?? '', style: XText.bodyS),
                        if (store != null) ...<Widget>[
                          const SizedBox(height: XSpace.s4),
                          XChip(
                            label:
                                StorePrimaryStatus.label(store.primaryStatus),
                            tone: StorePrimaryStatus.isVerified(
                                    store.primaryStatus)
                                ? XTone.success
                                : XTone.warning,
                            icon: Icons.verified_outlined,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: XSpace.s16),
            group('Toko', <Widget>[
              row(Icons.storefront_outlined, 'Pengaturan Toko',
                  SellerRoutes.storeSettings,
                  subtitle: store?.name),
              if (storeCount > 1)
                row(Icons.swap_horiz_rounded, 'Pindah Toko',
                    SellerRoutes.storePicker,
                    subtitle: '$storeCount toko'),
              row(Icons.verified_user_outlined, 'Verifikasi Toko',
                  SellerRoutes.verification),
              row(Icons.warehouse_outlined, 'Gudang & Stok',
                  SellerRoutes.warehouses),
              row(Icons.local_shipping_outlined, 'Kurir Aktif',
                  SellerRoutes.couriers),
              row(Icons.travel_explore_outlined, 'Monitoring Pengiriman',
                  SellerRoutes.shipmentMonitor),
              row(Icons.groups_outlined, 'Staf & Peran', SellerRoutes.staff),
            ]),
            group('Penjualan', <Widget>[
              row(Icons.assignment_return_outlined, 'Komplain & Pembatalan',
                  SellerRoutes.cases),
              row(Icons.local_offer_outlined, 'Campaign & Promo',
                  SellerRoutes.promotions),
              row(Icons.trending_up_rounded, 'Xpedia Growth',
                  SellerRoutes.growth),
              row(Icons.insights_outlined, 'Analitik Toko',
                  SellerRoutes.analytics),
              row(Icons.verified_outlined, 'Partners Performance',
                  SellerRoutes.performance),
              row(Icons.live_tv_outlined, 'Live Selling', SellerRoutes.live),
              row(Icons.rate_review_outlined, 'Ulasan Produk',
                  SellerRoutes.reviews),
              row(Icons.fact_check_outlined, 'Status Moderasi Produk',
                  SellerRoutes.productModeration),
              row(Icons.storefront_outlined, 'Kelola Storefront',
                  SellerRoutes.merchandising),
            ]),
            group('Keuangan', <Widget>[
              row(Icons.account_balance_wallet_outlined, 'Xpedia Wallet',
                  SellerRoutes.wallet),
              row(Icons.lock_outline_rounded, 'Keamanan Akun & PIN',
                  SellerRoutes.security),
            ]),
            group('Bantuan', <Widget>[
              row(Icons.notifications_none_rounded, 'Pusat Notifikasi',
                  SellerRoutes.notifications),
              row(Icons.support_agent_outlined, 'Xpedia 911',
                  SellerRoutes.support),
            ]),
            XButton.secondary(
              label: 'Keluar',
              icon: Icons.logout_rounded,
              expand: true,
              onPressed: () => _logout(context),
            ),
            const SizedBox(height: XSpace.s24),
          ],
        ),
      ),
    );
  }
}
