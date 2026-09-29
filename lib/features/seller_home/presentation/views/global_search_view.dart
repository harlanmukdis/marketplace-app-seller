import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/notification/announcement.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../core/domain/repositories/discovery_repository.dart';
import '../../../../core/domain/repositories/order_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/local_network.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// Global search (S-12): orders, products and help articles in one box.
///
/// `/search/*` covers only public products and stores, so orders and
/// products are searched here, on the store's own lists — those results are
/// real. Help articles have no API and come from [DiscoveryRepository].
class GlobalSearchView extends StatefulWidget {
  const GlobalSearchView({super.key});

  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

enum _Scope { all, orders, products, help }

class _GlobalSearchViewState extends State<GlobalSearchView> {
  static const String _recentKey = 'globalSearchRecent';

  final TextEditingController _query = TextEditingController();
  _Scope _scope = _Scope.all;
  List<Order> _orders = const <Order>[];
  List<Product> _products = const <Product>[];
  DataState<List<HelpArticle>>? _help;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    if (storeId == null) {
      setState(() => _loading = false);
      return;
    }
    final orders = <Order>[];
    for (var page = 1; page <= 5; page++) {
      final r =
          await injector<OrderRepository>().getStoreOrders(storeId, page: page);
      if (r is! DataSuccess<List<Order>>) break;
      orders.addAll(r.value);
      if (r.value.length < 20) break;
    }
    final products =
        await injector<CatalogRepository>().getStoreProducts(storeId);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _products = products is DataSuccess<List<Product>>
          ? products.value
          : const <Product>[];
      _loading = false;
    });
    await _searchHelp();
  }

  Future<void> _searchHelp() async {
    final r = await injector<DiscoveryRepository>().searchHelp(_query.text);
    if (mounted) setState(() => _help = r);
  }

  List<String> get _recent {
    try {
      final v = CachedHelper.getData(_recentKey);
      return v is List ? v.cast<String>() : const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _remember(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    final next = <String>[t, ..._recent.where((r) => r != t)].take(6).toList();
    await CachedHelper.saveData(_recentKey, next);
  }

  void _run(String q) {
    _query.text = q;
    _remember(q);
    setState(() {});
    _searchHelp();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final orders = q.isEmpty
        ? const <Order>[]
        : _orders
            .where((o) =>
                o.orderNumber.toLowerCase().contains(q) ||
                (o.trackingNumber ?? '').toLowerCase().contains(q) ||
                o.items.any((i) => i.productName.toLowerCase().contains(q)))
            .toList();
    final products = q.isEmpty
        ? const <Product>[]
        : _products.where((p) => p.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Cari',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                XSpace.screen, 0, XSpace.screen, XSpace.s12),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: _run,
              decoration: InputDecoration(
                hintText: 'No. pesanan, resi, produk, atau bantuan…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () => _run(''),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const LoadingIndicatorView()
          : ListView(
              padding: const EdgeInsets.all(XSpace.screen),
              children: <Widget>[
                Wrap(
                  spacing: XSpace.s8,
                  children: <Widget>[
                    for (final (s, label) in <(_Scope, String)>[
                      (_Scope.all, 'Semua'),
                      (_Scope.orders, 'Pesanan'),
                      (_Scope.products, 'Produk'),
                      (_Scope.help, 'Pusat Bantuan'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _scope == s,
                        showCheckmark: false,
                        selectedColor: XColors.primary,
                        backgroundColor: XColors.sunken,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: XText.labelM.copyWith(
                          color: _scope == s
                              ? XColors.textOnBrand
                              : XColors.textSecondary,
                        ),
                        onSelected: (_) => setState(() => _scope = s),
                      ),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                const XBanner(
                  title: 'Tips Pencarian:',
                  message: 'Gunakan No. Resi kurir atau nomor pesanan lengkap '
                      'untuk menemukan pesanan secara langsung.',
                ),
                if (q.isEmpty && _recent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: XSpace.s16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('Pencarian Terakhir', style: XText.titleM),
                      ),
                      XButton.ghost(
                        label: 'Hapus Semua',
                        size: XButtonSize.small,
                        onPressed: () async {
                          await CachedHelper.removeData(_recentKey);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: XSpace.s8,
                    runSpacing: XSpace.s8,
                    children: <Widget>[
                      for (final r in _recent)
                        ActionChip(
                          avatar: const Icon(Icons.history, size: 16),
                          label: Text(r),
                          onPressed: () => _run(r),
                        ),
                    ],
                  ),
                ],
                if (q.isNotEmpty &&
                    (_scope == _Scope.all ||
                        _scope == _Scope.orders)) ...<Widget>[
                  const SizedBox(height: XSpace.s16),
                  _Header(
                    icon: Icons.local_shipping_outlined,
                    title: 'Pesanan Terkait',
                    trailing: '${orders.length} hasil',
                  ),
                  if (orders.isEmpty)
                    Text('Tidak ada pesanan yang cocok.', style: XText.bodyS)
                  else
                    for (final o in orders.take(10)) ...<Widget>[
                      _OrderResult(order: o),
                      const SizedBox(height: XSpace.s8),
                    ],
                ],
                if (q.isNotEmpty &&
                    (_scope == _Scope.all ||
                        _scope == _Scope.products)) ...<Widget>[
                  const SizedBox(height: XSpace.s16),
                  _Header(
                    icon: Icons.inventory_2_outlined,
                    title: 'Katalog & Produk Terkait',
                    trailing: '${products.length} SKU',
                  ),
                  if (products.isEmpty)
                    Text('Tidak ada produk yang cocok.', style: XText.bodyS)
                  else
                    for (final p in products.take(10)) ...<Widget>[
                      _ProductResult(product: p),
                      const SizedBox(height: XSpace.s8),
                    ],
                ],
                if (_scope == _Scope.all || _scope == _Scope.help) ...<Widget>[
                  const SizedBox(height: XSpace.s16),
                  const _Header(
                    icon: Icons.support_agent_outlined,
                    title: 'Bantuan & Xpedia 911',
                    trailing: 'Pusat Resolusi',
                    badge: true,
                  ),
                  switch (_help) {
                    null => const LinearProgressIndicator(minHeight: 2),
                    DataSuccess<List<HelpArticle>>(:final value) => Column(
                        children: <Widget>[
                          for (final a in value.take(5)) ...<Widget>[
                            _HelpResult(article: a),
                            const SizedBox(height: XSpace.s8),
                          ],
                        ],
                      ),
                    DataFailed<List<HelpArticle>>(:final failure)
                        when failure.isApiPending =>
                      ApiPendingCard(message: failure.message),
                    _ =>
                      Text('Tidak ada artikel yang cocok.', style: XText.bodyS),
                  },
                ],
                const SizedBox(height: XSpace.s24),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.trailing,
    this.badge = false,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: XColors.primary),
          const SizedBox(width: XSpace.s8),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(child: Text(title, style: XText.titleL)),
                if (badge) ...<Widget>[
                  const SizedBox(width: XSpace.s8),
                  const DemoBadge(),
                ],
              ],
            ),
          ),
          Text(trailing, style: XText.caption),
        ],
      ),
    );
  }
}

class _OrderResult extends StatelessWidget {
  const _OrderResult({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return XCard(
      onTap: () => context.push(SellerRoutes.orderDetailPath(o.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('#${o.orderNumber}',
                    style: XText.titleM.copyWith(color: XColors.brandNavy)),
              ),
              XChip(label: OrderStatus.label(o.status), tone: XTone.warning),
            ],
          ),
          if (o.shippingCity.isNotEmpty)
            Text('Pembeli • ${o.shippingCity}', style: XText.bodyS),
          if (o.items.isNotEmpty)
            Text(
              '${o.items.first.productName}'
              '${o.items.length > 1 ? ' +${o.items.length - 1} lainnya' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: XText.bodyM,
            ),
          const SizedBox(height: XSpace.s4),
          Row(
            children: <Widget>[
              Text('Total', style: XText.caption),
              const Spacer(),
              Text(formatRupiah(o.grandTotal), style: XText.priceS),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductResult extends StatelessWidget {
  const _ProductResult({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return XCard(
      onTap: () => context.push(SellerRoutes.productEditPath(p.id)),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: XColors.sunken,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child:
                Icon(Icons.inventory_2_outlined, color: XColors.textTertiary),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                XChip(
                  label: ProductStatus.label(p.status),
                  tone: p.status == 'active' ? XTone.success : XTone.neutral,
                ),
                const SizedBox(height: 2),
                Text(p.name, style: XText.titleM),
                Text(formatRupiah(p.basePrice),
                    style: XText.priceS.copyWith(color: XColors.brandNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpResult extends StatelessWidget {
  const _HelpResult({required this.article});

  final HelpArticle article;

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: () => context.push(SellerRoutes.support),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: XColors.brandSubtle,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Icon(Icons.menu_book_outlined, color: XColors.primary),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(article.category.toUpperCase(),
                    style: XText.overline.copyWith(color: XColors.primary)),
                Text(article.title, style: XText.titleM),
                if (article.updatedAt != null)
                  Text('Diperbarui ${formatDate(article.updatedAt)}',
                      style: XText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
