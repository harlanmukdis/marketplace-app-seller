import 'package:flutter/material.dart';

import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

/// The frame of S-01 "Masuk & Daftar Partner": wordmark, headline, a benefit
/// banner, the Daftar / Masuk switch, the form, and a sticky primary action.
///
/// Sign-in on this API is email + password — there is no OTP endpoint — so
/// the design's OTP step is not offered; the rest of the frame is.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.isRegister,
    required this.onSwitch,
    required this.form,
    required this.actionLabel,
    required this.onAction,
    required this.busy,
    this.footer,
  });

  final bool isRegister;
  final VoidCallback onSwitch;
  final Widget form;
  final String actionLabel;
  final VoidCallback onAction;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Desktop/web: an unconstrained form stretches across the window.
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(XSpace.screen),
              children: <Widget>[
                const _Wordmark(),
                const SizedBox(height: XSpace.s24),
                Text(
                  isRegister ? 'Mulai Jualan di Xpedia' : 'Masuk sebagai Toko',
                  style: XText.headingXL,
                ),
                const SizedBox(height: XSpace.s4),
                Text(
                  isRegister
                      ? 'Kelola toko, pesanan, dan jangkau pembeli di seluruh '
                          'Indonesia.'
                      : 'Kelola pesanan, stok, dan pencairan dana toko Anda.',
                  style: XText.bodyM.copyWith(color: XColors.textSecondary),
                ),
                const SizedBox(height: XSpace.s16),
                Container(
                  padding: const EdgeInsets.all(XSpace.s12),
                  decoration: BoxDecoration(
                    color: XColors.brandSubtle,
                    borderRadius: BorderRadius.circular(XRadius.lg),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: XColors.surface,
                          borderRadius: BorderRadius.circular(XRadius.md),
                        ),
                        child: Icon(Icons.storefront_outlined,
                            color: XColors.primary),
                      ),
                      const SizedBox(width: XSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Bebas Biaya Registrasi Toko',
                                style: XText.titleM),
                            Text(
                              'Komisi hanya dari transaksi yang selesai.',
                              style: XText.bodyS,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: XSpace.s24),
                _ModeSwitch(isRegister: isRegister, onSwitch: onSwitch),
                const SizedBox(height: XSpace.s12),
                Container(
                  padding: const EdgeInsets.all(XSpace.s16),
                  decoration: BoxDecoration(
                    color: XColors.surface,
                    borderRadius: BorderRadius.circular(XRadius.lg),
                    border: Border.all(color: XColors.borderSubtle),
                  ),
                  child: form,
                ),
                const SizedBox(height: XSpace.s12),
                const XBanner(
                  tone: XTone.info,
                  icon: Icons.shield_outlined,
                  title: 'Keamanan Akun Terjamin.',
                  message: '1 KTP, 1 nomor HP, dan 1 email hanya bisa '
                      'didaftarkan untuk satu akun partner.',
                ),
                const SizedBox(height: XSpace.s24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        color: XColors.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
                      label: actionLabel,
                      size: XButtonSize.large,
                      expand: true,
                      loading: busy,
                      onPressed: onAction,
                    ),
                    if (footer != null) footer!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          'Xpedia',
          style: XText.headingL.copyWith(
            color: XColors.brandNavy,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: XSpace.s6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: XColors.brandSubtle,
            borderRadius: BorderRadius.circular(XRadius.xs),
          ),
          child: Text(
            'PARTNER',
            style: XText.overline.copyWith(color: XColors.primary),
          ),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isRegister, required this.onSwitch});

  final bool isRegister;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected) => Expanded(
          child: GestureDetector(
            onTap: selected ? null : onSwitch,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? XColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Text(
                label,
                style: XText.labelL.copyWith(
                  color: selected ? XColors.primary : XColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(XSpace.s4),
      decoration: BoxDecoration(
        color: XColors.brandSubtle,
        borderRadius: BorderRadius.circular(XRadius.lg),
      ),
      child: Row(
        children: <Widget>[
          tab('Daftar Akun Baru', isRegister),
          tab('Masuk', !isRegister),
        ],
      ),
    );
  }
}

/// A form label above its field, with an optional red asterisk.
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key, this.required = true});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s8),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: text),
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: XColors.danger)),
          ],
        ),
        style: XText.labelL,
      ),
    );
  }
}
