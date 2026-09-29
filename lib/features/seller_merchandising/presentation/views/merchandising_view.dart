import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data/datasources/remote/service/media_service.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/media/uploaded_file.dart';
import '../../../../core/domain/model/merchandising/product_bundle.dart';
import '../../../../core/domain/model/merchandising/store_showcase.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/domain/repositories/store_repository.dart';
import '../../../../core/widgets/demo/demo_widgets.dart';
import '../../../../core/domain/repositories/storefront_extras_repository.dart';
import '../../../../core/domain/model/store/storefront_extras.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import '../../../seller_store/presentation/cubits/store_cubit/store_cubit.dart';
import '../cubits/bundle_cubit/bundle_cubit.dart';
import '../cubits/showcase_cubit/showcase_cubit.dart';
import 'widgets/bundle_form_sheet.dart';
import 'widgets/showcase_form_sheet.dart';

/// "Kelola Storefront" (S-34): the store card, its banner, the showcases
/// (the shop's own shelves, drag to reorder) and product bundles.
///
/// Bundles and showcases behave differently in one way worth remembering: a
/// bundle can never be deleted or have its contents changed, while a showcase
/// can be edited freely.
///
/// The two mini banners and the home-page highlight switches have nowhere to
/// live in the store profile; they go through [StorefrontExtrasRepository]
/// (sample data under `DEMO_DATA`, "Menunggu API" otherwise).
class MerchandisingView extends StatelessWidget {
  const MerchandisingView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<BundleCubit>(create: (_) => BundleCubit()..load()),
        BlocProvider<ShowcaseCubit>(create: (_) => ShowcaseCubit()..load()),
      ],
      child: const _MerchandisingBody(),
    );
  }
}

class _MerchandisingBody extends StatefulWidget {
  const _MerchandisingBody();

  @override
  State<_MerchandisingBody> createState() => _MerchandisingBodyState();
}

class _MerchandisingBodyState extends State<_MerchandisingBody> {
  bool _uploadingBanner = false;

  Future<void> _createBundle() async {
    final cubit = BundleCubit.get(context);
    final draft = await showBundleFormSheet(
      context,
      products: cubit.pickerProducts,
    );
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      bundlePrice: draft.bundlePrice,
      items: draft.items,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Bundel dibuat.');
  }

  Future<void> _createShowcase() async {
    final cubit = ShowcaseCubit.get(context);
    final state = cubit.state;
    final draft = await showShowcaseFormSheet(
      context,
      defaultSortOrder: state is ShowcaseLoaded ? state.nextSortOrder : 0,
    );
    if (draft == null || !mounted) return;

    final error = await cubit.create(
      name: draft.name,
      sortOrder: draft.sortOrder,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Etalase dibuat.');
  }

  Future<void> _changeBanner(Store store) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    if (bytes.length > 2 * 1024 * 1024) {
      showErrorSnackBar(
        context,
        const DataError(
          code: 'FILE_TOO_LARGE',
          message: 'Banner maksimal 2 MB.',
        ),
      );
      return;
    }
    setState(() => _uploadingBanner = true);
    final stores = injector<StoreRepository>();
    final uploaded = await stores.upload(
      bytes: bytes,
      fileName: file!.name,
      context: 'store_banner',
    );
    DataError? error;
    if (uploaded is DataSuccess<UploadedFile>) {
      final saved =
          await stores.updateStore(store.id, bannerUrl: uploaded.value.url);
      if (saved is DataFailed<Store>) error = saved.failure;
    } else if (uploaded is DataFailed<UploadedFile>) {
      error = uploaded.failure;
    }
    if (!mounted) return;
    if (error == null) await StoreCubit.get(context).load();
    if (!mounted) return;
    setState(() => _uploadingBanner = false);
    error == null
        ? showSuccessSnackBar(context, 'Banner toko diperbarui.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _renameShowcase(StoreShowcase showcase) async {
    final cubit = ShowcaseCubit.get(context);
    final draft = await showShowcaseFormSheet(context, existing: showcase);
    if (draft == null || !mounted) return;

    final error = await cubit.rename(
      showcase.id,
      name: draft.name,
      sortOrder: draft.sortOrder,
    );
    if (!mounted) return;
    if (error != null) showErrorSnackBar(context, error);
  }

  Future<void> _deleteShowcase(StoreShowcase showcase) async {
    final cubit = ShowcaseCubit.get(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus etalase?', style: XText.headingM),
        content: Text(
          '"${showcase.name}" akan dihapus. Produknya sendiri tidak ikut '
          'terhapus — hanya pengelompokannya.',
          style: XText.bodyM,
        ),
        actions: <Widget>[
          XButton.ghost(
            label: 'Batal',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          XButton.danger(
            label: 'Hapus',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await cubit.remove(showcase.id);
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Etalase dihapus.');
  }

  Future<void> _reorder(List<StoreShowcase> list, int from, int to) async {
    final ordered = <StoreShowcase>[...list];
    final moved = ordered.removeAt(from);
    ordered.insert(to > from ? to - 1 : to, moved);
    final error = await ShowcaseCubit.get(context).reorder(ordered);
    if (!mounted) return;
    if (error != null) showErrorSnackBar(context, error);
  }

  Future<void> _reload() async {
    await Future.wait<void>(<Future<void>>[
      StoreCubit.get(context).load(),
      ShowcaseCubit.get(context).load(),
      BundleCubit.get(context).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final storeState = context.watch<StoreCubit>().state;
    final store =
        storeState is StoreLoadSuccess ? storeState.activeStore : null;
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Kelola Storefront'),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(XSpace.screen),
          children: <Widget>[
            if (store != null) ...<Widget>[
              _StoreHeader(store: store),
              const SizedBox(height: XSpace.s24),
              _BannerSection(
                store: store,
                uploading: _uploadingBanner,
                onChange: () => _changeBanner(store),
              ),
              const SizedBox(height: XSpace.s12),
              _MiniBanners(storeId: store.id),
              const SizedBox(height: XSpace.s24),
            ],
            _ShowcaseSection(
              onCreate: _createShowcase,
              onRename: _renameShowcase,
              onDelete: _deleteShowcase,
              onReorder: _reorder,
            ),
            const SizedBox(height: XSpace.s24),
            _BundleSection(onCreate: _createBundle),
            const SizedBox(height: XSpace.s24),
            if (store != null) ...<Widget>[
              _Highlights(storeId: store.id),
              const SizedBox(height: XSpace.s24),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final logo = store.logoUrl;
    return XCard(
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(XRadius.md),
            child: Container(
              width: 44,
              height: 44,
              color: XColors.successSubtle,
              child: logo == null || logo.isEmpty
                  ? Icon(Icons.storefront, color: XColors.success)
                  : Image.network(
                      normaliseUploadUrl(logo),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.storefront, color: XColors.success),
                    ),
            ),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: XText.titleL,
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    XChip(
                      label: store.isActive ? 'Publik Aktif' : 'Belum Aktif',
                      tone: store.isActive ? XTone.success : XTone.warning,
                    ),
                  ],
                ),
                if (store.slug != null)
                  Text('xpedia.co.id/${store.slug}', style: XText.bodyS),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSection extends StatelessWidget {
  const _BannerSection({
    required this.store,
    required this.uploading,
    required this.onChange,
  });

  final Store store;
  final bool uploading;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final banner = store.bannerUrl;
    final placeholder = Container(
      color: XColors.sunken,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.image_outlined, size: 32, color: XColors.textTertiary),
          const SizedBox(height: XSpace.s4),
          Text('Belum ada banner', style: XText.bodyS),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Banner Promosi Toko', style: XText.headingM),
            ),
            Text('1 Utama',
                style: XText.labelM.copyWith(color: XColors.primary)),
          ],
        ),
        Text(
          'Format banner terstandar untuk memaksimalkan konversi pembeli.',
          style: XText.bodyS,
        ),
        const SizedBox(height: XSpace.s12),
        ClipRRect(
          borderRadius: BorderRadius.circular(XRadius.md),
          child: AspectRatio(
            aspectRatio: 2,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (banner == null || banner.isEmpty)
                  placeholder
                else
                  Image.network(
                    normaliseUploadUrl(banner),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder,
                  ),
                if (banner != null && banner.isNotEmpty)
                  const Positioned(
                    top: XSpace.s8,
                    left: XSpace.s8,
                    child: XChip(
                      label: 'Banner Utama (Aktif)',
                      tone: XTone.info,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: XSpace.s8),
        XButton.secondary(
          label: banner == null || banner.isEmpty
              ? 'Unggah Banner'
              : 'Ganti Banner',
          icon: Icons.photo_library_outlined,
          expand: true,
          loading: uploading,
          onPressed: onChange,
        ),
        const SizedBox(height: XSpace.s8),
        const XBanner(
          message: 'Rekomendasi ukuran banner utama 1200×600 px, banner mini '
              '600×600 px (maks. 2 MB), JPG/PNG.',
        ),
      ],
    );
  }
}

class _ShowcaseSection extends StatelessWidget {
  const _ShowcaseSection({
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
  });

  final VoidCallback onCreate;
  final ValueChanged<StoreShowcase> onRename;
  final ValueChanged<StoreShowcase> onDelete;
  final void Function(List<StoreShowcase> list, int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShowcaseCubit, ShowcaseState>(
      builder: (context, state) {
        final list =
            state is ShowcaseLoaded ? state.showcases : const <StoreShowcase>[];
        final busy = state is ShowcaseLoaded && state.isBusy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Etalase Toko', style: XText.headingM),
                      Text('${list.length} etalase ditampilkan',
                          style: XText.bodyS),
                    ],
                  ),
                ),
                XButton.ghost(
                  label: 'Tambah Etalase',
                  icon: Icons.add,
                  size: XButtonSize.small,
                  onPressed: onCreate,
                ),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            switch (state) {
              ShowcaseInProgress() => const Padding(
                  padding: EdgeInsets.all(XSpace.s24),
                  child: LoadingIndicatorView(),
                ),
              ShowcaseNoStore() => const XCard(
                  child: XEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Pilih toko dulu untuk melihat etalasenya.',
                  ),
                ),
              ShowcaseFailure(:final error) => ErrorStateView(
                  error: error,
                  onRetry: () => ShowcaseCubit.get(context).load(),
                ),
              ShowcaseLoaded() when list.isEmpty => const XCard(
                  child: XEmptyState(
                    icon: Icons.shelves,
                    title: 'Belum ada etalase.',
                  ),
                ),
              ShowcaseLoaded() => ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: list.length,
                  onReorder: (from, to) {
                    if (!busy) onReorder(list, from, to);
                  },
                  itemBuilder: (context, i) {
                    final showcase = list[i];
                    return Padding(
                      key: ValueKey<int>(showcase.id),
                      padding: const EdgeInsets.only(bottom: XSpace.s8),
                      child: XCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: XSpace.s8,
                          vertical: XSpace.s4,
                        ),
                        onTap: () async {
                          final cubit = ShowcaseCubit.get(context);
                          await context.push(
                              SellerRoutes.showcaseDetailPath(showcase.id));
                          if (cubit.isClosed) return;
                          await cubit.load();
                        },
                        child: Row(
                          children: <Widget>[
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(XSpace.s8),
                                child: Icon(Icons.drag_indicator,
                                    color: XColors.textTertiary),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(showcase.name, style: XText.titleM),
                                  // The list carries no product count, so
                                  // saying one would mean a call per showcase.
                                  Text('Urutan ${i + 1}', style: XText.caption),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ubah',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: busy ? null : () => onRename(showcase),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: busy ? null : () => onDelete(showcase),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            },
            if (list.length > 1)
              Row(
                children: <Widget>[
                  Icon(Icons.touch_app_outlined,
                      size: 16, color: XColors.textTertiary),
                  const SizedBox(width: XSpace.s4),
                  Expanded(
                    child: Text(
                      'Tahan dan geser ikon titik untuk mengubah urutan '
                      'etalase pembeli.',
                      style: XText.caption,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _BundleSection extends StatelessWidget {
  const _BundleSection({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BundleCubit, BundleState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Bundel Produk', style: XText.headingM),
                    Text('Beberapa produk dijual dengan satu harga',
                        style: XText.bodyS),
                  ],
                ),
              ),
              XButton.ghost(
                label: 'Tambah Bundel',
                icon: Icons.add,
                size: XButtonSize.small,
                onPressed: state is BundleLoaded ? onCreate : null,
              ),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          switch (state) {
            BundleInProgress() => const Padding(
                padding: EdgeInsets.all(XSpace.s24),
                child: LoadingIndicatorView(),
              ),
            BundleNoStore() => const XCard(
                child: XEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Pilih toko dulu untuk melihat bundelnya.',
                ),
              ),
            BundleFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => BundleCubit.get(context).load(),
              ),
            BundleLoaded(:final bundles) when bundles.isEmpty => const XCard(
                child: XEmptyState(
                  icon: Icons.inventory_outlined,
                  title: 'Belum ada bundel produk.',
                ),
              ),
            BundleLoaded(:final bundles, :final isBusy) => Column(
                children: <Widget>[
                  for (final bundle in bundles) ...<Widget>[
                    _BundleCard(
                      bundle: bundle,
                      isBusy: isBusy,
                      onTap: () async {
                        final cubit = BundleCubit.get(context);
                        await context
                            .push(SellerRoutes.bundleDetailPath(bundle.id));
                        if (cubit.isClosed) return;
                        await cubit.load();
                      },
                      onToggle: (isActive) async {
                        final cubit = BundleCubit.get(context);
                        final error =
                            await cubit.setActive(bundle.id, isActive);
                        if (!context.mounted) return;
                        if (error != null) showErrorSnackBar(context, error);
                      },
                    ),
                    const SizedBox(height: XSpace.s8),
                  ],
                ],
              ),
          },
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({
    required this.bundle,
    required this.isBusy,
    required this.onTap,
    required this.onToggle,
  });

  final ProductBundle bundle;
  final bool isBusy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: XColors.brandSubtle,
                  borderRadius: BorderRadius.circular(XRadius.md),
                ),
                child: Icon(Icons.inventory_2_outlined, color: XColors.primary),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(bundle.name, style: XText.titleM),
                    Text(
                      formatRupiah(bundle.bundlePrice),
                      style: XText.priceS.copyWith(color: XColors.primary),
                    ),
                  ],
                ),
              ),
              XChip(
                label: bundle.isActive ? 'Aktif' : 'Nonaktif',
                tone: bundle.isActive ? XTone.success : XTone.neutral,
              ),
              const SizedBox(width: XSpace.s8),
              XSwitch(
                value: bundle.isActive,
                onChanged: isBusy ? null : onToggle,
                semanticLabel: 'Aktifkan ${bundle.name}',
              ),
            ],
          ),
          if (!bundle.isActive) ...<Widget>[
            const SizedBox(height: XSpace.s8),
            const XBanner(
              tone: XTone.warning,
              message: 'Nonaktif — isinya juga tidak bisa dibaca selama '
                  'begini, karena API hanya melayani bundel aktif.',
            ),
          ],
        ],
      ),
    );
  }
}

/// "1 Utama + 2 Mini": the two small panels beside the main banner.
class _MiniBanners extends StatefulWidget {
  const _MiniBanners({required this.storeId});

  final int storeId;

  @override
  State<_MiniBanners> createState() => _MiniBannersState();
}

class _MiniBannersState extends State<_MiniBanners> {
  Key _key = UniqueKey();
  int? _uploading;

  Future<void> _replace(int slot) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _uploading = slot);
    final uploaded = await injector<StoreRepository>().upload(
      bytes: bytes,
      fileName: file!.name,
      context: 'store_banner',
    );
    DataError? error;
    if (uploaded is DataSuccess<UploadedFile>) {
      error = await injector<StorefrontExtrasRepository>()
          .setMiniBanner(widget.storeId, slot, uploaded.value.url);
    } else if (uploaded is DataFailed<UploadedFile>) {
      error = uploaded.failure;
    }
    if (!mounted) return;
    setState(() {
      _uploading = null;
      _key = UniqueKey();
    });
    showDemoActionResult(context, error, 'Banner mini $slot diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: PendingBuilder<List<MiniBanner>>(
        compact: true,
        load: () => injector<StorefrontExtrasRepository>()
            .getMiniBanners(widget.storeId),
        pending: (e) => const ApiPendingCard(
          message: 'Dua banner mini di samping banner utama menunggu API — '
              'toko baru punya satu kolom banner.',
        ),
        builder: (context, banners, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Banner Mini', style: XText.titleM),
                const SizedBox(width: XSpace.s8),
                const DemoBadge(),
              ],
            ),
            const SizedBox(height: XSpace.s8),
            Row(
              children: <Widget>[
                for (final b in banners) ...<Widget>[
                  if (b.slot > 1) const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: XCard(
                      padding: EdgeInsets.zero,
                      onTap: _uploading == null ? () => _replace(b.slot) : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AspectRatio(
                            aspectRatio: 1.4,
                            child: _uploading == b.slot
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : b.imageUrl == null
                                    ? Container(
                                        color: XColors.sunken,
                                        child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: XColors.textTertiary),
                                      )
                                    : Image.network(
                                        normaliseUploadUrl(b.imageUrl!),
                                        fit: BoxFit.cover,
                                      ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(XSpace.s8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                XChip(
                                  label:
                                      b.imageUrl == null ? 'Kosong' : 'Aktif',
                                  tone: b.imageUrl == null
                                      ? XTone.neutral
                                      : XTone.success,
                                ),
                                const SizedBox(height: 2),
                                Text(b.caption ?? 'Banner mini ${b.slot}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: XText.labelM),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sorotan Produk Beranda Toko": optional blocks on the store's home tab.
class _Highlights extends StatefulWidget {
  const _Highlights({required this.storeId});

  final int storeId;

  @override
  State<_Highlights> createState() => _HighlightsState();
}

class _HighlightsState extends State<_Highlights> {
  final Map<String, bool> _local = <String, bool>{};

  Future<void> _set(StorefrontHighlight h, bool value) async {
    setState(() => _local[h.key] = value);
    final error = await injector<StorefrontExtrasRepository>()
        .setHighlight(widget.storeId, h.key, value);
    if (!mounted) return;
    if (error != null) setState(() => _local.remove(h.key));
    showDemoActionResult(context, error,
        '${h.title} ${value ? 'ditampilkan' : 'disembunyikan'}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionHeader(
          title: 'Sorotan Produk Beranda Toko',
          subtitle: 'Komponen tambahan pada beranda toko Anda.',
        ),
        PendingBuilder<List<StorefrontHighlight>>(
          compact: true,
          load: () => injector<StorefrontExtrasRepository>()
              .getHighlights(widget.storeId),
          builder: (context, list, _) => XListGroup(
            children: <Widget>[
              for (final h in list)
                XListRow(
                  icon: switch (h.key) {
                    HighlightKey.flashSale => Icons.bolt,
                    HighlightKey.signature => Icons.verified,
                    _ => Icons.play_circle_outline,
                  },
                  iconColor: XColors.primary,
                  title: h.title,
                  subtitle: h.description,
                  trailing: XSwitch(
                    value: _local[h.key] ?? h.enabled,
                    onChanged: (v) => _set(h, v),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
