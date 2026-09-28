import 'package:flutter/material.dart';

import '../utils/xpedia_tokens.dart';

/// The app bar used by every screen not yet rebuilt on `XAppBar`.
///
/// Restyled to the Xpedia Partners rules (design.md §3–4): 56dp, surface
/// background, hairline below, left-aligned Heading/M title, and a plain back
/// arrow only when there is a route to go back to — so a screen used as a
/// bottom-navigation tab shows none.
PreferredSizeWidget customAppBar(
  BuildContext context,
  String title, {
  Widget? action,
}) {
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    backgroundColor: XColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    toolbarHeight: XSize.appBar,
    automaticallyImplyLeading: false,
    titleSpacing: canPop ? 0 : XSpace.screen,
    leading: canPop
        ? IconButton(
            tooltip: 'Kembali',
            icon: Icon(Icons.arrow_back, color: XColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    title: Text(title, style: XText.headingM),
    actions: <Widget>[
      if (action != null) action,
      const SizedBox(width: XSpace.s8),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(height: 1, thickness: 1, color: XColors.borderSubtle),
    ),
  );
}
