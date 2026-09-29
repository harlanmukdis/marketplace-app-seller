import 'package:flutter/material.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/promotion/platform_campaign.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/campaign_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// "Campaign Xpedia": platform campaigns open for registration, and the
/// products this store has put forward for each.
class PlatformCampaignView extends StatefulWidget {
  const PlatformCampaignView({super.key});

  @override
  State<PlatformCampaignView> createState() => _PlatformCampaignViewState();
}

class _PlatformCampaignViewState extends State<PlatformCampaignView> {
  Key _key = UniqueKey();

  int get _storeId => injector<AuthRepository>().activeStoreId ?? 0;

  Future<void> _register(PlatformCampaign c) async {
    final products =
        await injector<CatalogRepository>().getStoreProducts(_storeId);
    if (!mounted) return;
    final active = products is DataSuccess<List<Product>>
        ? products.value
            .where((p) =>
                p.status == ProductStatus.active &&
                !c.submittedProductIds.contains(p.id))
            .toList()
        : const <Product>[];
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPicker(campaign: c, products: active),
    );
    if (picked == null || !mounted) return;
    final error = await injector<CampaignRepository>()
        .submitProducts(_storeId, c.id, picked);
    if (!mounted) return;
    showDemoActionResult(
        context, error, '${picked.length} produk didaftarkan untuk ditinjau');
    if (error == null) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Campaign Xpedia'),
      body: KeyedSubtree(
        key: _key,
        child: PendingBuilder<List<PlatformCampaign>>(
          load: () => injector<CampaignRepository>().getOpenCampaigns(_storeId),
          pending: (e) => ListView(
            padding: const EdgeInsets.all(XSpace.screen),
            children: const <Widget>[
              ApiPendingCard(
                message: 'Pendaftaran produk ke campaign sudah ada di API, '
                    'tapi daftar campaign baru bisa dilihat admin.',
              ),
            ],
          ),
          empty: const XEmptyState(
            icon: Icons.campaign_outlined,
            title: 'Belum ada campaign yang dibuka',
          ),
          builder: (context, list, _) => ListView(
            padding: const EdgeInsets.all(XSpace.screen),
            children: <Widget>[
              const XBanner(
                icon: Icons.campaign_outlined,
                message: 'Produk yang didaftarkan ditinjau tim Xpedia. Yang '
                    'disetujui tampil di halaman campaign selama periode '
                    'berlangsung.',
              ),
              const SizedBox(height: XSpace.s12),
              const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
              const SizedBox(height: XSpace.s8),
              for (final c in list) ...<Widget>[
                _CampaignCard(campaign: c, onRegister: () => _register(c)),
                const SizedBox(height: XSpace.s12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, required this.onRegister});

  final PlatformCampaign campaign;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final open = c.isOpenAt(DateTime.now());
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              XChip(
                label: open ? 'Pendaftaran Dibuka' : 'Pendaftaran Ditutup',
                tone: open ? XTone.success : XTone.neutral,
              ),
              const Spacer(),
              Text('${formatDate(c.startAt)} – ${formatDate(c.endAt)}',
                  style: XText.caption),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(c.name, style: XText.titleL),
          Text(c.description, style: XText.bodyS),
          const SizedBox(height: XSpace.s12),
          Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.sunken,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Column(
              children: <Widget>[
                XKeyValue(
                  label: 'Syarat diskon',
                  value: 'Min. ${c.minDiscountPercent}%',
                ),
                if (c.benefit != null)
                  XKeyValue(label: 'Keuntungan', value: c.benefit!),
                XKeyValue(
                  label: 'Batas daftar',
                  value: formatDate(c.registerBy),
                ),
                XKeyValue(
                  label: 'Produk didaftarkan',
                  value: c.submittedProductIds.isEmpty
                      ? '-'
                      : '${c.submittedProductIds.length} • menunggu review',
                ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s12),
          XButton(
            label: 'Daftarkan Produk',
            icon: Icons.add_task,
            expand: true,
            onPressed: open ? onRegister : null,
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.campaign, required this.products});

  final PlatformCampaign campaign;
  final List<Product> products;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final Set<int> _picked = <int>{};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Pilih Produk', style: XText.headingM),
                  Text(
                    'Hanya produk aktif. Pastikan diskon minimal '
                    '${widget.campaign.minDiscountPercent}% selama campaign.',
                    style: XText.bodyS,
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.products.isEmpty
                  ? const XEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Tidak ada produk aktif yang bisa didaftarkan',
                    )
                  : ListView(
                      children: <Widget>[
                        for (final p in widget.products)
                          CheckboxListTile(
                            value: _picked.contains(p.id),
                            onChanged: (v) => setState(() => v == true
                                ? _picked.add(p.id)
                                : _picked.remove(p.id)),
                            title: Text(p.name, style: XText.bodyM),
                            subtitle: Text(formatRupiah(p.basePrice),
                                style: XText.bodyS),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: XButton(
                label: 'Daftarkan ${_picked.length} Produk',
                size: XButtonSize.large,
                expand: true,
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_picked.toList()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
