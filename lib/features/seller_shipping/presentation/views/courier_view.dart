import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/shipping/courier.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/courier_cubit/courier_cubit.dart';

/// "Pilih Kurir Aktif" (S-24).
///
/// The API's list is an **optional whitelist**: a store that has chosen none
/// ships through every active courier, and choosing some narrows buyers to
/// those. The screen shows it the way the design does — one switch per
/// courier, all on by default — and the cubit maps that onto the whitelist,
/// refusing to switch the last one off (an empty list would mean "all").
///
/// Not drawn: the design's per-service toggles (REG/YES/BEST…) and the pickup
/// schedule and drop-off point. The API knows couriers by code and name only.
class CourierView extends StatelessWidget {
  const CourierView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CourierCubit>(
      create: (_) => CourierCubit()..load(),
      child: const _CourierBody(),
    );
  }
}

class _CourierBody extends StatelessWidget {
  const _CourierBody();

  Future<void> _save(BuildContext context) async {
    final error = await CourierCubit.get(context).save();
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, 'Pengaturan kurir tersimpan.');
  }

  void _toggle(BuildContext context, String code, bool on) {
    final ok = CourierCubit.get(context).setActive(code, on);
    if (!ok) {
      showSuccessSnackBar(context, 'Minimal satu kurir harus aktif.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourierCubit, CourierState>(
      builder: (context, state) => Scaffold(
        backgroundColor: XColors.canvas,
        appBar: const XAppBar(title: 'Pilih Kurir Aktif'),
        body: switch (state) {
          CourierInProgress() => const LoadingIndicatorView(),
          CourierNoStore() => const XEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Belum ada toko aktif',
              message: 'Pilih toko dulu untuk mengatur kurirnya.',
            ),
          CourierFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => CourierCubit.get(context).load(),
            ),
          CourierLoaded() => _content(context, state),
        },
        bottomNavigationBar: state is CourierLoaded &&
                state.available.isNotEmpty
            ? Material(
                color: XColors.surface,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(XSpace.screen),
                    child: XButton(
                      label: 'Simpan Pengaturan Kurir',
                      icon: Icons.check_circle_outline,
                      size: XButtonSize.large,
                      expand: true,
                      loading: state.isBusy,
                      onPressed: state.isDirty ? () => _save(context) : null,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _content(BuildContext context, CourierLoaded state) {
    if (state.available.isEmpty) {
      return const XEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Belum ada kurir',
        message: 'Platform belum punya kurir aktif.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        XBanner(
          title: 'Aturan Pengiriman Toko',
          message: state.hasNone
              ? 'Semua kurir aktif, jadi pembeli bisa memilih kurir mana pun. '
                  'Matikan kurir yang tidak bisa Anda layani — drop-off atau '
                  'pickup-nya tidak terjangkau.'
              : 'Pembeli hanya dapat memilih kurir yang Anda aktifkan di bawah '
                  'ini. Pastikan Anda punya akses gerai drop-off atau jadwal '
                  'pickup yang memadai.',
        ),
        const SizedBox(height: XSpace.s24),
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Daftar Mitra Ekspedisi', style: XText.headingM),
            ),
            XChip(
              label:
                  '${state.activeCount} dari ${state.available.length} Aktif',
              tone: XTone.success,
            ),
          ],
        ),
        const SizedBox(height: XSpace.s12),
        for (final courier in state.available) ...<Widget>[
          _CourierCard(
            courier: courier,
            on: state.isOn(courier.code),
            onChanged: state.isBusy
                ? null
                : (on) => _toggle(context, courier.code, on),
          ),
          const SizedBox(height: XSpace.s12),
        ],
        Text(
          'Menyimpan mengganti seluruh daftar. Kurir baru dari platform '
          'otomatis aktif selama semua kurir Anda nyalakan.',
          style: XText.bodyS,
        ),
        const SizedBox(height: XSpace.s24),
      ],
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({
    required this.courier,
    required this.on,
    required this.onChanged,
  });

  final Courier courier;
  final bool on;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: on ? 1 : 0.6,
      child: XCard(
        onTap: onChanged == null ? null : () => onChanged!(!on),
        child: Row(
          children: <Widget>[
            _CourierLogo(code: courier.code, name: courier.name),
            const SizedBox(width: XSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          courier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: XText.titleL,
                        ),
                      ),
                      const SizedBox(width: XSpace.s8),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: on ? XColors.success : XColors.textPlaceholder,
                      ),
                    ],
                  ),
                  Text(
                    on ? 'Ditawarkan ke pembeli' : 'Nonaktif untuk toko ini',
                    style: XText.bodyS,
                  ),
                ],
              ),
            ),
            XSwitch(
              value: on,
              onChanged: onChanged,
              semanticLabel: courier.name,
            ),
          ],
        ),
      ),
    );
  }
}

/// A wordmark tile in the courier's brand colour. Known couriers get their
/// own; anything else falls back to neutral initials.
class _CourierLogo extends StatelessWidget {
  const _CourierLogo({required this.code, required this.name});

  final String code;
  final String name;

  @override
  Widget build(BuildContext context) {
    final (String mark, Color fg, Color bg) = switch (code.toLowerCase()) {
      'jne' => ('JNE', const Color(0xff0056FE), const Color(0xffEBF2FF)),
      'sicepat' => (
          'SiCepat',
          const Color(0xffD10C22),
          const Color(0xffFFECEE)
        ),
      'jnt' => ('J&T', const Color(0xffD10C22), const Color(0xffFFECEE)),
      'anteraja' => ('AA', const Color(0xff6344D6), const Color(0xffF1EEFE)),
      'gosend' || 'grab' || 'instant' => (
          '⚡',
          const Color(0xff0C7A44),
          const Color(0xffE8F8EF)
        ),
      _ => (
          name.isEmpty
              ? '?'
              : name
                  .substring(0, name.length < 3 ? name.length : 3)
                  .toUpperCase(),
          XColors.textSecondary,
          XColors.sunken,
        ),
    };
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          mark,
          style: XText.titleM.copyWith(color: fg, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
