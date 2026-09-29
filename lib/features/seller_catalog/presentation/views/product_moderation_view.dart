import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data/demo/demo_support.dart';
import '../../../../core/domain/model/performance/store_insights.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/store_insights_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// "Status Moderasi Produk" (S-28): what the curation team decided about
/// each listing, and what to fix.
///
/// ⏳ The API has no seller-readable moderation state; the app otherwise
/// learns of it only from `RESTRICTION_REVIEW_PENDING` on publish.
class ProductModerationView extends StatelessWidget {
  const ProductModerationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Status Moderasi Produk'),
      body: PendingBuilder<List<ProductModeration>>(
        load: () => injector<CatalogQualityRepository>()
            .getModeration(injector<AuthRepository>().activeStoreId ?? 0),
        pending: (e) => ListView(
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[ApiPendingCard(message: e.message)],
        ),
        builder: (context, list, _) => _Body(items: list),
      ),
    );
  }
}

enum _Filter {
  all('Semua'),
  action('Perlu Tindakan'),
  review('Sedang Ditinjau'),
  approved('Disetujui');

  const _Filter(this.label);

  final String label;

  bool accepts(ProductModeration m) => switch (this) {
        all => true,
        action => m.state == ModerationState.needsFix ||
            m.state == ModerationState.rejected,
        review => m.state == ModerationState.inReview,
        approved => m.state == ModerationState.approved,
      };
}

class _Body extends StatefulWidget {
  const _Body({required this.items});

  final List<ProductModeration> items;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final shown = widget.items.where(_filter.accepts).toList();
    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: XSpace.s8),
                  child: ChoiceChip(
                    label: Text(
                        '${f.label} (${widget.items.where(f.accepts).length})'),
                    selected: _filter == f,
                    showCheckmark: false,
                    selectedColor: XColors.primary,
                    backgroundColor: XColors.sunken,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: XText.labelM.copyWith(
                      color: _filter == f
                          ? XColors.textOnBrand
                          : XColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: XSpace.s12),
        const XBanner(
          icon: Icons.verified_user_outlined,
          title: 'Kebijakan Kurasi Merchant',
          message: 'Tim Kurasi Xpedia meninjau produk dalam 1×24 jam kerja '
              'setelah diunggah atau diedit.',
        ),
        const SizedBox(height: XSpace.s12),
        const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
        const SizedBox(height: XSpace.s8),
        if (shown.isEmpty)
          const XCard(
            child: XEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Tidak Ada Produk',
              message: 'Tidak ada pengajuan produk pada filter ini.',
            ),
          )
        else
          for (final m in shown) ...<Widget>[
            _ModerationCard(item: m),
            const SizedBox(height: XSpace.s12),
          ],
        const SizedBox(height: XSpace.s12),
        Text('Pedoman Kepatuhan Listing', style: XText.titleL),
        const SizedBox(height: XSpace.s8),
        const Row(
          children: <Widget>[
            Expanded(
              child: _Guide(
                icon: Icons.verified_outlined,
                title: 'Klaim Merek & HAKI',
                body: 'Gunakan nama generik kecuali terverifikasi resmi.',
              ),
            ),
            SizedBox(width: XSpace.s8),
            Expanded(
              child: _Guide(
                icon: Icons.photo_camera_outlined,
                title: 'Foto Asli & Jelas',
                body: 'Sertakan foto label teknis dan spesifikasi.',
              ),
            ),
          ],
        ),
        const SizedBox(height: XSpace.s24),
      ],
    );
  }
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({required this.item});

  final ProductModeration item;

  Future<void> _simulate(BuildContext context, String done) async {
    final error = await demoWrite('Tindakan moderasi');
    if (!context.mounted) return;
    showDemoActionResult(context, error, done);
  }

  @override
  Widget build(BuildContext context) {
    final m = item;
    final (XTone tone, IconData icon) = switch (m.state) {
      ModerationState.needsFix => (XTone.danger, Icons.error_outline),
      ModerationState.rejected => (XTone.danger, Icons.block),
      ModerationState.inReview => (XTone.warning, Icons.schedule),
      _ => (XTone.success, Icons.check_circle_outline),
    };
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('SKU: ${m.sku}', style: XText.caption)),
              XChip(
                  label: ModerationState.label(m.state),
                  tone: tone,
                  icon: icon),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: XColors.sunken,
                  borderRadius: BorderRadius.circular(XRadius.md),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: XColors.textTertiary),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(m.productName, style: XText.titleM),
                    Text(m.category, style: XText.bodyS),
                  ],
                ),
              ),
            ],
          ),
          if (m.issueTitle != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.danger,
              icon: Icons.gavel_rounded,
              title: m.issueTitle,
              message: m.issueDetail ?? '',
            ),
          ],
          if (m.state == ModerationState.inReview) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.warning,
              icon: Icons.hourglass_top,
              title: 'Estimasi selesai: ${formatDateTime(m.estimatedDoneAt)}',
              message: 'Diajukan ${formatDateTime(m.submittedAt)}. Produk '
                  'otomatis tampil aktif setelah disetujui kurator.',
            ),
          ],
          if (m.state == ModerationState.approved) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            XBanner(
              tone: XTone.success,
              icon: Icons.verified,
              title: 'Aktif di Toko',
              message: 'Disetujui ${formatDateTime(m.decidedAt)}',
            ),
          ],
          const SizedBox(height: XSpace.s12),
          switch (m.state) {
            ModerationState.needsFix => Row(
                children: <Widget>[
                  XButton.ghost(
                    label: 'Hapus Pengajuan',
                    onPressed: () => _simulate(context, 'Pengajuan dihapus'),
                  ),
                  const Spacer(),
                  XButton(
                    label: 'Unggah & Edit',
                    icon: Icons.upload_file,
                    onPressed: m.productId == null
                        ? () => _simulate(context, 'Perbaikan dikirim')
                        : () => context
                            .push(SellerRoutes.productEditPath(m.productId!)),
                  ),
                ],
              ),
            ModerationState.rejected => Row(
                children: <Widget>[
                  Expanded(
                    child: XButton.secondary(
                      label: 'Banding / HAKI',
                      expand: true,
                      onPressed: () => context.push(SellerRoutes.support),
                    ),
                  ),
                  const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: XButton(
                      label: 'Ubah Nama & Teks',
                      expand: true,
                      onPressed: () => _simulate(context, 'Revisi dikirim'),
                    ),
                  ),
                ],
              ),
            ModerationState.inReview => const XButton.secondary(
                label: 'Sedang Diproses Kurasi',
                icon: Icons.lock_clock,
                expand: true,
                onPressed: null,
              ),
            _ => Align(
                alignment: Alignment.centerRight,
                child: XButton.secondary(
                  label: 'Pratinjau',
                  size: XButtonSize.small,
                  onPressed: m.productId == null
                      ? null
                      : () => context
                          .push(SellerRoutes.productEditPath(m.productId!)),
                ),
              ),
          },
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: XColors.warning),
          const SizedBox(height: XSpace.s4),
          Text(title, style: XText.titleM),
          Text(body, style: XText.bodyS),
        ],
      ),
    );
  }
}
