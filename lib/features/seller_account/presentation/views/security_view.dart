import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/account/login_session.dart';
import '../../../../core/domain/repositories/account_repository.dart';
import '../../../../core/utils/format_helper.dart';
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
          const _SessionsCard(),
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

/// "Riwayat Sesi Perangkat" (S-44). The API cannot say which session is this
/// one, so none is marked; revoking the one in use signs this device out once
/// its access token (15 minutes) runs out.
class _SessionsCard extends StatefulWidget {
  const _SessionsCard();

  @override
  State<_SessionsCard> createState() => _SessionsCardState();
}

class _SessionsCardState extends State<_SessionsCard> {
  final AccountRepository _account = injector<AccountRepository>();
  List<LoginSession>? _sessions;
  DataError? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _account.getSessions();
    if (!mounted) return;
    setState(() {
      _sessions = result is DataSuccess<List<LoginSession>>
          ? result.value
          : const <LoginSession>[];
      _error = result is DataFailed<List<LoginSession>> ? result.failure : null;
    });
  }

  Future<void> _revoke(LoginSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluarkan sesi ini?'),
        content: Text(
          '${session.clientLabel} (masuk ${formatDateTime(session.createdAt)}) '
          'akan dikeluarkan. Bila ini sesi yang sedang Anda pakai, aplikasi '
          'ini juga akan keluar dalam 15 menit.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: XColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = session.id);
    final result = await _account.revokeSession(session.id);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (result is DataSuccess<List<LoginSession>>) _sessions = result.value;
      if (result is DataEmpty<List<LoginSession>>) _sessions = const [];
    });
    if (result is DataFailed<List<LoginSession>>) {
      showErrorSnackBar(context, result.failure);
    } else {
      showSuccessSnackBar(context, 'Sesi dikeluarkan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Sesi Perangkat Aktif', style: XText.titleL),
              ),
              if (sessions != null)
                XChip(label: '${sessions.length} sesi', tone: XTone.info),
            ],
          ),
          const SizedBox(height: XSpace.s4),
          Text(
            'Keluarkan perangkat yang tidak Anda kenali.',
            style: XText.bodyS,
          ),
          const SizedBox(height: XSpace.s12),
          if (sessions == null)
            const LinearProgressIndicator()
          else if (_error != null)
            Text('Gagal memuat sesi: ${_error!.message}', style: XText.bodyS)
          else if (sessions.isEmpty)
            Text('Tidak ada sesi aktif.', style: XText.bodyS)
          else
            for (final s in sessions.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: XSpace.s8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      s.clientLabel.startsWith('Aplikasi')
                          ? Icons.phone_iphone_rounded
                          : Icons.devices_other_rounded,
                      color: XColors.textSecondary,
                    ),
                    const SizedBox(width: XSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.clientLabel, style: XText.titleM),
                          Text(
                            'Masuk ${formatDateTime(s.createdAt)}'
                            '${s.ipAddress == null ? '' : ' · ${s.ipAddress}'}',
                            style: XText.bodyS,
                          ),
                        ],
                      ),
                    ),
                    XButton.ghost(
                      label: 'Keluarkan',
                      size: XButtonSize.small,
                      loading: _busyId == s.id,
                      onPressed:
                          _busyId == null ? () => _revoke(s) : null,
                    ),
                  ],
                ),
              ),
          if (sessions != null && sessions.length > 10)
            Text('+${sessions.length - 10} sesi lebih lama', style: XText.caption),
        ],
      ),
    );
  }
}
