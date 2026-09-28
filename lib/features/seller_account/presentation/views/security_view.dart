import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/repositories/wallet_repository.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../di/injector.dart';

/// "Keamanan Akun" (S-44), trimmed to what the API supports.
///
/// The withdrawal PIN is the part that matters: since API v1.24.0 no
/// withdrawal goes through without one. The API has no change-password
/// endpoint (only the forgot/reset flow) and no 2FA, so those rows from the
/// design are not offered.
///
/// The server cannot say whether a PIN is already set, so the screen asks: the
/// seller picks "first time" or "change", and the server's answer corrects a
/// wrong guess ("PIN lama salah" means one exists).
class SecurityView extends StatefulWidget {
  const SecurityView({super.key});

  @override
  State<SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends State<SecurityView> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _changing = false;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _pin.text.length == 6 &&
      _pin.text == _confirm.text &&
      (!_changing || _current.text.length == 6);

  Future<void> _save() async {
    setState(() => _busy = true);
    final result = await injector<WalletRepository>().setWithdrawalPin(
      pin: _pin.text,
      currentPin: _changing ? _current.text : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result is DataFailed<void>) {
      final error = result.failure;
      if (!_changing && error.message.toLowerCase().contains('pin lama')) {
        setState(() => _changing = true);
      }
      showErrorSnackBar(context, error);
      return;
    }
    _current.clear();
    _pin.clear();
    _confirm.clear();
    showSuccessSnackBar(context, 'PIN penarikan tersimpan.');
    Navigator.of(context).maybePop();
  }

  Widget _pinField(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: XText.titleM),
          const SizedBox(height: XSpace.s8),
          Pinput(
            length: 6,
            controller: c,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            defaultPinTheme: PinTheme(
              width: 44,
              height: 52,
              textStyle: XText.headingM,
              decoration: BoxDecoration(
                color: XColors.sunken,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final mismatch = _confirm.text.length == 6 && _pin.text != _confirm.text;
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Keamanan Akun'),
      body: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          XCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('PIN Penarikan Dana', style: XText.titleL),
                const SizedBox(height: XSpace.s4),
                Text(
                  '6 digit angka, terpisah dari kata sandi. Wajib untuk setiap '
                  'penarikan saldo Xpedia Wallet. 5 kali salah dalam 15 menit '
                  'mengunci sementara.',
                  style: XText.bodyS,
                ),
                const SizedBox(height: XSpace.s16),
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Buat PIN')),
                    ButtonSegment<bool>(value: true, label: Text('Ganti PIN')),
                  ],
                  selected: <bool>{_changing},
                  onSelectionChanged: (s) =>
                      setState(() => _changing = s.first),
                ),
                const SizedBox(height: XSpace.s20),
                if (_changing) ...<Widget>[
                  _pinField('PIN lama', _current),
                  const SizedBox(height: XSpace.s16),
                ],
                _pinField('PIN baru', _pin),
                const SizedBox(height: XSpace.s16),
                _pinField('Ulangi PIN baru', _confirm),
                if (mismatch) ...<Widget>[
                  const SizedBox(height: XSpace.s8),
                  Text(
                    'PIN tidak sama.',
                    style: XText.bodyS.copyWith(color: XColors.danger),
                  ),
                ],
                const SizedBox(height: XSpace.s20),
                XButton(
                  label: 'Simpan PIN',
                  size: XButtonSize.large,
                  expand: true,
                  loading: _busy,
                  onPressed: _valid ? _save : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: XSpace.cardGap),
          const XBanner(
            tone: XTone.neutral,
            message: 'Kata sandi diganti lewat "Lupa kata sandi" di halaman '
                'masuk. Autentikasi dua langkah belum tersedia.',
          ),
        ],
      ),
    );
  }
}
