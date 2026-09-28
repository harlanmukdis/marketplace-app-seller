import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/domain/model/store/store_settings.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/store_repository.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import '../cubits/store_cubit/store_cubit.dart';

/// "Pengaturan Toko" (S-43): profile, operating status, private contacts.
///
/// "Auto accept" from the old settings row is deliberately absent: there is no
/// acceptance step since API v1.6.0, so the switch would do nothing.
class StoreSettingsView extends StatefulWidget {
  const StoreSettingsView({super.key});

  @override
  State<StoreSettingsView> createState() => _StoreSettingsViewState();
}

class _StoreSettingsViewState extends State<StoreSettingsView> {
  final StoreRepository _stores = injector<StoreRepository>();
  final int? _storeId = injector<AuthRepository>().activeStoreId;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _vacation = false;
  DataError? _error;
  Store? _store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _storeId;
    if (id == null) return;
    final storeState = StoreCubit.get(context).state;
    _store = storeState is StoreLoadSuccess ? storeState.activeStore : null;
    _name.text = _store?.name ?? '';
    _description.text = _store?.description ?? '';

    final result = await _stores.getSettings(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case DataSuccess<StoreSettings>(:final value):
          _vacation = value.vacationMode;
          _phone.text = value.contactPhone ?? '';
          _whatsapp.text = value.contactWhatsapp ?? '';
        case DataFailed<StoreSettings>(:final failure):
          _error = failure;
        default:
          break;
      }
    });
  }

  Future<void> _save() async {
    final id = _storeId;
    if (id == null) return;
    setState(() => _saving = true);

    final profile = await _stores.updateStore(
      id,
      name: _name.text.trim() == _store?.name ? null : _name.text.trim(),
      description: _description.text.trim(),
    );
    final settings = await _stores.updateSettings(
      id,
      vacationMode: _vacation,
      contactPhone: _phone.text.trim(),
      contactWhatsapp: _whatsapp.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final failure = profile is DataFailed<Store>
        ? profile.failure
        : settings is DataFailed<StoreSettings>
            ? settings.failure
            : null;
    if (failure != null) {
      showErrorSnackBar(context, failure);
      return;
    }
    await StoreCubit.get(context).load();
    if (!mounted) return;
    showSuccessSnackBar(context, 'Pengaturan toko tersimpan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Pengaturan Toko'),
      body: _loading
          ? const LoadingIndicatorView()
          : _error != null
              ? ErrorStateView(error: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(XSpace.screen),
                  children: <Widget>[
                    XCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text('Profil Toko', style: XText.titleL),
                          const SizedBox(height: XSpace.s12),
                          TextField(
                            controller: _name,
                            decoration:
                                const InputDecoration(labelText: 'Nama toko'),
                          ),
                          const SizedBox(height: XSpace.s12),
                          TextField(
                            controller: _description,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_store != null) ...<Widget>[
                            const SizedBox(height: XSpace.s12),
                            XKeyValue(
                              label: 'Status seller',
                              value: StorePrimaryStatus.label(
                                  _store!.primaryStatus),
                            ),
                            XKeyValue(
                              label: 'Kuota SKU',
                              value: _store!.skuQuota == null
                                  ? 'Tidak dibatasi'
                                  : '${_store!.skuQuota} produk',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                    XCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _vacation,
                        onChanged: (v) => setState(() => _vacation = v),
                        title: Text('Mode Libur', style: XText.titleM),
                        subtitle: Text(
                          'Toko ditandai tutup sementara untuk pembeli.',
                          style: XText.bodyS,
                        ),
                      ),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                    XCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text('Kontak Toko', style: XText.titleL),
                          Text(
                            'Hanya untuk tim Xpedia; tidak tampil ke pembeli.',
                            style: XText.bodyS,
                          ),
                          const SizedBox(height: XSpace.s12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'Telepon'),
                          ),
                          const SizedBox(height: XSpace.s12),
                          TextField(
                            controller: _whatsapp,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'WhatsApp'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: XSpace.cardGap),
                    XListGroup(
                      children: <Widget>[
                        XListRow(
                          icon: Icons.local_shipping_outlined,
                          title: 'Kurir Aktif',
                          onTap: () => context.push(SellerRoutes.couriers),
                        ),
                        XListRow(
                          icon: Icons.warehouse_outlined,
                          title: 'Gudang & Stok',
                          onTap: () => context.push(SellerRoutes.warehouses),
                        ),
                        XListRow(
                          icon: Icons.verified_user_outlined,
                          title: 'Verifikasi Toko',
                          onTap: () => context.push(SellerRoutes.verification),
                        ),
                      ],
                    ),
                    const SizedBox(height: XSpace.s24),
                  ],
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : Material(
              color: XColors.surface,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(XSpace.screen),
                  child: XButton(
                    label: 'Simpan',
                    size: XButtonSize.large,
                    expand: true,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ),
            ),
    );
  }
}
