import 'package:flutter/material.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data/local/session_store.dart';
import '../../../../core/function/components.dart';
import '../../../../core/utils/app_routes.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../di/injector.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// The app's entry point.
///
/// Deliberately asset-free. The UI kit's animated splash renders four SVGs from
/// `assets/images/`, and that directory does not exist in this repo — so it
/// throws on every frame. This screen decides where to go and gets out of the
/// way; the original splash stays registered for when the assets are restored.
class SellerBootstrapView extends StatefulWidget {
  const SellerBootstrapView({super.key});

  @override
  State<SellerBootstrapView> createState() => _SellerBootstrapViewState();
}

class _SellerBootstrapViewState extends State<SellerBootstrapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  void _route() {
    final session = injector<SessionStore>();

    if (!session.isLoggedIn) {
      router.go(SellerRoutes.login);
      return;
    }

    // Logged in but no store chosen. An account can own several — or none at
    // all, since every account starts as a buyer — so the picker is where that
    // gets settled, and it offers opening the first one.
    if (!session.hasStoreContext) {
      router.go(SellerRoutes.storePicker);
      return;
    }

    router.go(SellerRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isAppDarkMode() ? kDarkColor : kWhiteColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Marketplace Seller', style: XText.headingXL),
            24.sbh,
            CircularProgressIndicator(
              color: isAppDarkMode() ? kDarkPrimaryColor : kLightPrimaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
