import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/order/order.dart';
import '../../../../core/domain/model/shipping/courier.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/shipping_repository.dart';
import '../../../../core/domain/repositories/store_repository.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';
import '../cubits/order_detail_cubit/order_detail_cubit.dart';
import 'widgets/order_status_pill.dart';
import 'widgets/order_widgets.dart';

/// Opens S-21 for the order held by [cubit]. Resolves to true when the waybill
/// was printed, so the caller can leave or refresh.
Future<bool?> openPrintWaybill(BuildContext context, OrderDetailCubit cubit) =>
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BlocProvider<OrderDetailCubit>.value(
          value: cubit,
          child: const PrintWaybillView(),
        ),
      ),
    );

/// "Atur Pengiriman & Cetak Resi" (S-21) — the seller's one commitment.
///
/// Two things differ from the design, both because of the API:
///
/// * **The AWB is typed, not generated.** The design says the resi number is
///   issued automatically; `POST /orders/{id}/ship` still takes `awb_number`
///   from the caller and has no courier integration behind it. Until that
///   exists the seller enters the number the courier gave them.
/// * **Secure+ evidence appears on demand.** Nothing in the order payload says
///   whether an order is Secure+, so the photo and video uploads are offered
///   as optional and become required the moment the server answers
///   `SECURE_PLUS_EVIDENCE_REQUIRED`.
class PrintWaybillView extends StatefulWidget {
  const PrintWaybillView({super.key});

  @override
  State<PrintWaybillView> createState() => _PrintWaybillViewState();
}

class _PrintWaybillViewState extends State<PrintWaybillView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _awb = TextEditingController();

  String _handover = HandoverMethod.dropOff;
  List<Courier>? _couriers;
  String? _courierCode;
  bool _securePlusRequired = false;
  final List<ShipmentEvidence> _evidence = <ShipmentEvidence>[];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final state = OrderDetailCubit.get(context).state;
    if (state is OrderDetailLoaded) _courierCode = state.order.courierCode;
    _loadCouriers();
  }

  @override
  void dispose() {
    _awb.dispose();
    super.dispose();
  }

  Future<void> _loadCouriers() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    final shipping = injector<ShippingRepository>();

    // The store's own whitelist first; empty means "every courier", so fall
    // back to the platform list rather than offering nothing.
    var result = storeId == null
        ? await shipping.getCouriers()
        : await shipping.getStoreCouriers(storeId);
    if (result is DataEmpty<List<Courier>>) {
      result = await shipping.getCouriers();
    }
    if (!mounted) return;
    setState(() {
      _couriers = result is DataSuccess<List<Courier>>
          ? result.value
          : const <Courier>[];
      final known = _couriers!.any((c) => c.code == _courierCode);
      if (!known) {
        _courierCode = _couriers!.isEmpty ? null : _couriers!.first.code;
      }
    });
  }

  bool get _hasPhoto => _evidence.any((e) => !e.isVideo);
  bool get _hasVideo => _evidence.any((e) => e.isVideo);

  Future<void> _addEvidence({required bool video}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: video
          ? const <String>['mp4', 'mov', 'webm']
          : const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;

    setState(() => _uploading = true);
    final result = await injector<StoreRepository>().upload(
      bytes: bytes,
      fileName: file!.name,
      storeId: injector<AuthRepository>().activeStoreId,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    switch (result) {
      case DataSuccess(:final value):
        setState(() => _evidence.add(ShipmentEvidence(
              mediaType: video ? 'video' : 'photo',
              url: value.url,
            )));
      case DataFailed(:final failure):
        showErrorSnackBar(context, failure);
      default:
        break;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final courier = _courierCode;
    if (courier == null) return;

    if (_securePlusRequired && (!_hasPhoto || !_hasVideo)) {
      showErrorSnackBar(
        context,
        const DataError(
          code: 'SECURE_PLUS_EVIDENCE_REQUIRED',
          message: 'Pesanan Secure+ wajib minimal 1 foto dan 1 video bukti '
              'pengemasan.',
        ),
      );
      return;
    }

    final cubit = OrderDetailCubit.get(context);
    final error = await cubit.printWaybill(
      courierCode: courier,
      awbNumber: _awb.text.trim(),
      handoverMethod: _handover,
      evidence: _evidence,
    );
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (error.code == 'SECURE_PLUS_EVIDENCE_REQUIRED') {
      setState(() => _securePlusRequired = true);
    }
    showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderDetailCubit, OrderDetailState>(
      builder: (context, state) {
        if (state is! OrderDetailLoaded) {
          return const Scaffold(body: LoadingIndicatorView());
        }
        final order = state.order;
        final busy = state.isBusy || _uploading;

        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Atur Pengiriman'),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(XSpace.screen),
              children: <Widget>[
                OrderSlaBanner(order: order),
                const SizedBox(height: XSpace.cardGap),
                _OrderSummary(order: order),
                const SizedBox(height: XSpace.sectionGap),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('Metode Penyerahan Paket',
                          style: XText.titleL),
                    ),
                    Text('Pilih salah satu', style: XText.caption),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                _HandoverOption(
                  title: 'Drop-off ke Gerai Kurir',
                  subtitle: 'Serahkan paket langsung ke agen / drop point '
                      'kurir terdekat.',
                  recommended: true,
                  selected: _handover == HandoverMethod.dropOff,
                  onTap: () =>
                      setState(() => _handover = HandoverMethod.dropOff),
                ),
                const SizedBox(height: XSpace.s12),
                _HandoverOption(
                  title: 'Pickup / Dijemput Kurir',
                  subtitle: 'Kurir menjemput paket di alamat gudang toko.',
                  selected: _handover == HandoverMethod.pickup,
                  onTap: () =>
                      setState(() => _handover = HandoverMethod.pickup),
                ),
                const SizedBox(height: XSpace.cardGap),
                XCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Kurir', style: XText.titleM),
                      const SizedBox(height: XSpace.s8),
                      if (_couriers == null)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _courierCode,
                          isExpanded: true,
                          items: <DropdownMenuItem<String>>[
                            for (final c in _couriers!)
                              DropdownMenuItem<String>(
                                value: c.code,
                                child: Text(c.name, style: XText.bodyM),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (v) => setState(() => _courierCode = v),
                          validator: (v) =>
                              v == null ? 'Pilih kurir pengiriman' : null,
                        ),
                      const SizedBox(height: XSpace.s16),
                      Text('Nomor Resi / AWB', style: XText.titleM),
                      const SizedBox(height: XSpace.s8),
                      TextFormField(
                        controller: _awb,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.characters,
                        style: XText.bodyM,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: JNE0123456789',
                          prefixIcon: Icon(Icons.qr_code_2_rounded),
                        ),
                        validator: (v) => (v ?? '').trim().length < 6
                            ? 'Isi nomor resi dari kurir (min. 6 karakter)'
                            : null,
                      ),
                      const SizedBox(height: XSpace.s8),
                      Text(
                        'Nomor resi dikunci setelah dicetak dan tidak bisa '
                        'diubah.',
                        style: XText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: XSpace.cardGap),
                _SecurePlusCard(
                  required: _securePlusRequired,
                  evidence: _evidence,
                  busy: busy,
                  onAddPhoto: () => _addEvidence(video: false),
                  onAddVideo: () => _addEvidence(video: true),
                  onRemove: (e) => setState(() => _evidence.remove(e)),
                ),
                const SizedBox(height: XSpace.sectionGap),
                const _PackingGuide(),
                const SizedBox(height: XSpace.s24),
              ],
            ),
          ),
          bottomNavigationBar: _BottomAction(
            busy: busy,
            onPressed: order.canPrintWaybill ? _submit : null,
          ),
        );
      },
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final first = order.items.isEmpty ? null : order.items.first;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('No. Pesanan ', style: XText.bodyS),
              Expanded(child: Text(order.orderNumber, style: XText.titleL)),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          OrderBuyerLine(order: order),
          if (first != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            Row(
              children: <Widget>[
                const OrderThumb(),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        first.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: XText.titleM,
                      ),
                      Text('${order.itemCount} barang', style: XText.bodyS),
                    ],
                  ),
                ),
                Text(formatRupiah(order.subtotal), style: XText.priceM),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HandoverOption extends StatelessWidget {
  const _HandoverOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.recommended = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? XColors.brandSubtle : XColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(
          color: selected ? XColors.primary : XColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(XSpace.card),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? XColors.primary : XColors.borderStrong,
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: XSpace.s8,
                      runSpacing: XSpace.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(title, style: XText.titleL),
                        if (recommended)
                          const XChip(
                            label: 'Direkomendasikan',
                            tone: XTone.info,
                          ),
                      ],
                    ),
                    const SizedBox(height: XSpace.s4),
                    Text(subtitle, style: XText.bodyS),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurePlusCard extends StatelessWidget {
  const _SecurePlusCard({
    required this.required,
    required this.evidence,
    required this.busy,
    required this.onAddPhoto,
    required this.onAddVideo,
    required this.onRemove,
  });

  final bool required;
  final List<ShipmentEvidence> evidence;
  final bool busy;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;
  final ValueChanged<ShipmentEvidence> onRemove;

  @override
  Widget build(BuildContext context) {
    return XCard(
      color: required ? XColors.brandSubtle : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const XChip(
                label: 'Xpedia Secure+',
                tone: XTone.securePlus,
                icon: Icons.shield_outlined,
              ),
              const Spacer(),
              Text(required ? 'Wajib' : 'Jika pesanan Secure+',
                  style: XText.caption),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(
            'Bukti pengemasan: minimal 1 foto dan 1 video sebelum paket '
            'diserahkan ke kurir. Pembeli akan menerima kode segel untuk '
            'konfirmasi penerimaan.',
            style: XText.bodyS,
          ),
          if (evidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            Wrap(
              spacing: XSpace.s8,
              runSpacing: XSpace.s8,
              children: <Widget>[
                for (final e in evidence)
                  InputChip(
                    avatar: Icon(
                      e.isVideo ? Icons.videocam_outlined : Icons.photo_outlined,
                      size: 18,
                    ),
                    label: Text(e.isVideo ? 'Video' : 'Foto',
                        style: XText.labelM),
                    onDeleted: busy ? null : () => onRemove(e),
                  ),
              ],
            ),
          ],
          const SizedBox(height: XSpace.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: XButton.secondary(
                  label: 'Foto',
                  icon: Icons.add_a_photo_outlined,
                  size: XButtonSize.small,
                  onPressed: busy ? null : onAddPhoto,
                ),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: XButton.secondary(
                  label: 'Video',
                  icon: Icons.videocam_outlined,
                  size: XButtonSize.small,
                  onPressed: busy ? null : onAddVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackingGuide extends StatelessWidget {
  const _PackingGuide();

  static const List<String> _tips = <String>[
    'Tempel label pengiriman pada permukaan datar dan kering.',
    'Jangan menutup barcode dengan lakban bertekstur atau gelap.',
    'Pastikan paket tersegel rapat dengan pelindung bubble wrap.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.info_outline, size: 20, color: XColors.textSecondary),
            const SizedBox(width: XSpace.s8),
            Text('Panduan Standar Pengemasan', style: XText.titleM),
          ],
        ),
        const SizedBox(height: XSpace.s8),
        for (final tip in _tips)
          Padding(
            padding: const EdgeInsets.only(left: XSpace.s8, top: XSpace.s4),
            child: Text('•  $tip', style: XText.bodyS),
          ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            XSpace.screen,
            XSpace.s12,
            XSpace.screen,
            XSpace.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              XButton(
                label: 'Konfirmasi & Cetak Resi',
                icon: Icons.print_outlined,
                size: XButtonSize.large,
                expand: true,
                loading: busy,
                onPressed: onPressed,
              ),
              const SizedBox(height: XSpace.s6),
              Text(
                'Cetak resi mengunci pesanan dan memindahkannya ke Dalam '
                'Pengiriman.',
                textAlign: TextAlign.center,
                style: XText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
