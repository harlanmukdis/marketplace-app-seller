import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../seller_account/presentation/views/account_tab.dart';
import '../../../seller_catalog/presentation/views/product_list_view.dart';
import '../../../seller_chat/presentation/views/chat_inbox_view.dart';
import '../../../seller_orders/presentation/cubits/order_list_cubit/order_list_cubit.dart';
import '../../../seller_orders/presentation/views/order_list_view.dart';
import '../cubits/home_summary_cubit.dart';
import 'dashboard_tab.dart';

/// The shell the store works in: five tabs, the design system's maximum —
/// Beranda, Pesanan, Produk, Chat, Akun (design.md §4, S-11).
///
/// The orders cubit lives here rather than in the Pesanan tab, so Beranda's
/// counts, the Pesanan list and its badge all read one load.
class SellerHomeShell extends StatefulWidget {
  const SellerHomeShell({super.key});

  @override
  State<SellerHomeShell> createState() => _SellerHomeShellState();
}

class _SellerHomeShellState extends State<SellerHomeShell> {
  int _index = 0;

  static const List<(IconData, IconData, String)> _items =
      <(IconData, IconData, String)>[
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Beranda'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pesanan'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Produk'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
    (Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, 'Akun'),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OrderListCubit>(create: (_) => OrderListCubit()..load()),
        BlocProvider<HomeSummaryCubit>(
          create: (_) => HomeSummaryCubit()..load(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final orders = context.watch<OrderListCubit>().state;
          final toProcess = orders is OrderListLoaded
              ? orders.countOf(OrderFilter.processing)
              : 0;

          return Scaffold(
            backgroundColor: XColors.canvas,
            body: IndexedStack(
              index: _index,
              children: <Widget>[
                DashboardTab(onOpenTab: _select),
                const OrderListView(embedded: true),
                const ProductListView(),
                const ChatInboxView(),
                const AccountTab(),
              ],
            ),
            bottomNavigationBar: _BottomNav(
              index: _index,
              items: _items,
              badges: <int, int>{1: toProcess},
              onSelect: _select,
            ),
          );
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.items,
    required this.badges,
    required this.onSelect,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final Map<int, int> badges;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XColors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          height: XSize.bottomNav,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: XColors.borderSubtle)),
          ),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        XBadge(
                          count: badges[i],
                          child: Icon(
                            i == index ? items[i].$2 : items[i].$1,
                            color: i == index
                                ? XColors.primary
                                : XColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: XSpace.s4),
                        Text(
                          items[i].$3,
                          style: XText.labelM.copyWith(
                            color: i == index
                                ? XColors.primary
                                : XColors.textTertiary,
                            fontWeight:
                                i == index ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
